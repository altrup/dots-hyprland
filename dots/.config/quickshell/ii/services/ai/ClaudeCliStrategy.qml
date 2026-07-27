import QtQuick
import qs.services
import qs.modules.common.functions as CF

/**
 * Claude via the Claude Code CLI (`claude -p`) run as a local process:
 * finalizeScriptContent() discards the assembled curl script, input goes over stdin
 * as stream-json, and conversation continuity uses CLI sessions (--resume).
 */
ApiStrategy {
    isCli: true
    // The request captured by buildRequestData: {model, messages, systemPrompt, filePath, sessionId}
    property var pendingRequest: null
    property bool inThinkingBlock: false
    // Tool calls are buffered while streaming and rendered once: on the permission
    // request, or on the tool result for auto-approved ones. Entries are registered at
    // content_block_start because the permission request can beat the block's stop event
    property string currentToolId: ""
    property var pendingTools: ({})
    property bool interruptRequested: false

    function buildEndpoint(model: AiModel): string { return "" }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { return "" }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools, filePath: string) {
        // Resume the newest session found in the chat; none means a fresh one
        const sessionId = messages.map(m => m.cliSessionId).filter(id => id && id.length > 0).pop() ?? "";
        pendingRequest = ({
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            filePath: filePath,
            sessionId: sessionId,
        });
        return {};
    }

    // Written to the process's stdin by the service right after launch; stdin then
    // stays open for permission responses
    function buildStdinPayload(): string {
        const request = pendingRequest;
        // Resuming: only the newest message is sent, the session carries the rest.
        // Fresh session: serialize the whole chat so context survives model switches and loaded chats
        let prompt = request.sessionId.length > 0
            ? (request.messages[request.messages.length - 1]?.rawContent ?? "")
            : request.messages.map(m => `${m.role}: ${m.rawContent}`).join("\n\n");
        if (request.filePath && request.filePath.length > 0) {
            prompt += `\n\n[Attached file: ${request.filePath}]`;
        }
        return JSON.stringify({
            type: "user",
            message: { role: "user", content: [{ type: "text", text: prompt }] }
        });
    }

    // The CLI stops the turn gracefully and records it in the session, unlike a signal
    function buildInterruptRequest(): string {
        interruptRequested = true;
        return JSON.stringify({
            type: "control_request",
            request_id: "interrupt",
            request: { subtype: "interrupt" }
        });
    }

    function buildPermissionResponse(permissionRequest, allow: bool): string {
        return JSON.stringify({
            type: "control_response",
            response: {
                subtype: "success",
                request_id: permissionRequest.requestId,
                response: allow
                    ? { behavior: "allow", updatedInput: permissionRequest.input }
                    : { behavior: "deny", message: "User rejected this command" }
            }
        });
    }

    function finalizeScriptContent(scriptContent: string): string {
        const request = pendingRequest;
        // stdio permission prompts let the shell approve/deny gated tool calls over stdin
        let command = "claude -p --input-format stream-json --output-format stream-json"
            + " --include-partial-messages --verbose --permission-prompt-tool stdio";
        if (request.model.model.length > 0) {
            command += ` --model '${CF.StringUtils.shellSingleQuoteEscape(request.model.model)}'`;
        }
        if (request.sessionId.length > 0) {
            command += ` --resume '${CF.StringUtils.shellSingleQuoteEscape(request.sessionId)}'`;
        } else if (request.systemPrompt.length > 0) {
            command += ` --append-system-prompt '${CF.StringUtils.shellSingleQuoteEscape(request.systemPrompt)}'`;
        }
        // exec so the stop button's kill reaches claude itself, not just the wrapping bash
        return "#!/usr/bin/env bash\nexec " + command + "\n";
    }

    function appendContent(message, text) {
        message.content += text;
        message.rawContent += text;
    }

    function appendCommandFence(message, name, input, requestApproval) {
        if (requestApproval) {
            // The same splitter the renderer uses, so the ordinal can't desync from it
            message.pendingCommandIndex = CF.StringUtils.splitMarkdownBlocks(message.content)
                .filter(b => b.type === "code" && b.lang === "command").length;
        }
        const header = requestApproval ? `**${Translation.tr("Command execution request")}**\n\n` : "";
        const summary = input?.command ?? JSON.stringify(input ?? {});
        appendContent(message, `\n\n${header}\`\`\`command\n${name}: ${summary}\n\`\`\`\n\n`);
    }

    function parseResponseLine(line, message) {
        try {
            const dataJson = JSON.parse(line);

            if (dataJson.type === "system" && dataJson.subtype === "init") {
                message.cliSessionId = dataJson.session_id ?? "";
                return {};
            }

            // Live chunks; complete "assistant" snapshots are ignored to avoid duplication
            if (dataJson.type === "stream_event") {
                const event = dataJson.event ?? {};
                if (event.type === "content_block_start") {
                    const block = event.content_block ?? {};
                    if (block.type === "thinking") {
                        inThinkingBlock = true;
                        appendContent(message, "\n\n<think>\n");
                    } else if (block.type === "tool_use") {
                        currentToolId = block.id ?? "";
                        pendingTools[currentToolId] = { name: block.name ?? "", inputJson: "" };
                    }
                } else if (event.type === "content_block_delta") {
                    const delta = event.delta ?? {};
                    if (delta.type === "text_delta") {
                        appendContent(message, delta.text ?? "");
                    } else if (delta.type === "thinking_delta") {
                        appendContent(message, delta.thinking ?? "");
                    } else if (delta.type === "input_json_delta") {
                        const tool = pendingTools[currentToolId];
                        if (tool) tool.inputJson += delta.partial_json ?? "";
                    }
                } else if (event.type === "content_block_stop") {
                    if (inThinkingBlock) {
                        inThinkingBlock = false;
                        appendContent(message, "\n</think>\n\n");
                    } else {
                        const tool = pendingTools[currentToolId];
                        if (tool) {
                            try { tool.input = JSON.parse(tool.inputJson); } catch (e) {}
                        }
                        currentToolId = "";
                    }
                }
                return {};
            }

            // A tool result is the first sign an auto-approved call ran; gated calls
            // already rendered their fence with the permission request
            if (dataJson.type === "user") {
                const blocks = dataJson.message?.content;
                if (Array.isArray(blocks)) {
                    for (const block of blocks) {
                        if (block.type !== "tool_result") continue;
                        const tool = pendingTools[block.tool_use_id];
                        if (!tool) continue;
                        delete pendingTools[block.tool_use_id];
                        appendCommandFence(message, tool.name, tool.input, false);
                    }
                }
                return {};
            }

            if (dataJson.type === "control_request") {
                const request = dataJson.request ?? {};
                if (request.subtype === "can_use_tool") {
                    // This call's fence renders here; its tool result must not render another
                    delete pendingTools[request.tool_use_id];
                    appendCommandFence(message, request.tool_name ?? "", request.input ?? {}, true);
                    message.functionName = request.tool_name ?? "";
                    message.functionPending = true;
                    return { permissionRequest: { requestId: dataJson.request_id, input: request.input ?? {} } };
                }
                return {};
            }

            if (dataJson.type === "result") {
                // A self-requested interrupt also reports is_error (with an internal
                // diagnostic), but the session stays valid and resumable
                if (dataJson.is_error && !interruptRequested) {
                    // error_during_execution results carry errors[] instead of result
                    const errorText = dataJson.result ?? dataJson.errors?.join("\n") ?? "Unknown error";
                    appendContent(message, `**Error**: ${errorText}`);
                    // A failed session (e.g. an expired --resume target) must not be resumed
                    // again: dropping the ids makes the next request start fresh
                    message.cliSessionId = "";
                    pendingRequest?.messages?.forEach(m => { m.cliSessionId = "" });
                }
                const usage = dataJson.usage ?? {};
                const input = (usage.input_tokens ?? 0)
                    + (usage.cache_read_input_tokens ?? 0)
                    + (usage.cache_creation_input_tokens ?? 0);
                const output = usage.output_tokens ?? 0;
                return {
                    finished: true,
                    tokenUsage: { input: input, output: output, total: input + output }
                };
            }
        } catch (e) {
            // Non-JSON output is shown as-is
            appendContent(message, line);
        }
        return {};
    }

    function onRequestFinished(message: AiMessageData): var {
        // An interrupt can land mid-thinking; the dangling tag would swallow the rest of the message
        if (inThinkingBlock) {
            inThinkingBlock = false;
            appendContent(message, "\n</think>\n\n");
        }
        return {};
    }

    function reset() {
        pendingRequest = null;
        inThinkingBlock = false;
        currentToolId = "";
        pendingTools = ({});
        interruptRequested = false;
    }
}
