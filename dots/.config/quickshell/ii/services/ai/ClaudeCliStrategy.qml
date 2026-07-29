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
    // Command fences render at content_block_start and are rewritten in place while the
    // input streams; the open fence is always the message tail, so a rewrite is just a
    // slice at the recorded offsets. Entries stay registered after the block stops
    // because the permission request refers back to them (and can even beat the stop)
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

    function buildPermissionResponse(permissionRequest, allow, updatedInput): string {
        // A denial still comes back as an error tool_result; recording the decision here
        // stops that result from relabelling the fence as failed
        const tool = pendingTools[permissionRequest.toolUseId];
        if (tool) tool.state = allow ? "running" : "denied";
        return JSON.stringify({
            type: "control_response",
            response: {
                subtype: "success",
                request_id: permissionRequest.requestId,
                response: allow
                    ? { behavior: "allow", updatedInput: updatedInput ?? permissionRequest.input }
                    : { behavior: "deny", message: "User rejected this command" }
            }
        });
    }

    // Encodes the AskUserQuestion answer contract for updatedInput: {questions, answers}
    // keyed by question text, multiSelect labels joined with ", ", skipped questions
    // (no selection) omitted
    function buildQuestionAnswers(questions, selections): var {
        const answers = {};
        for (const q of questions) {
            const answer = (selections[q.question] ?? []).join(", ");
            if (answer.length > 0) answers[q.question] = answer;
        }
        return { questions: questions, answers: answers };
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

    // The same splitter the renderer uses, so ordinals can't desync from it
    function commandFenceCount(content) {
        return CF.StringUtils.splitMarkdownBlocks(content)
            .filter(b => b.type === "code" && b.lang?.split(":")[0] === "command").length;
    }

    function registerTool(id, name, message) {
        const tool = {
            name: name,
            inputJson: "",
            open: true,
            state: "running",
            ordinal: commandFenceCount(message.content),
            fenceStart: message.content.length,
            rawFenceStart: message.rawContent.length,
        };
        pendingTools[id] = tool;
        rewriteFence(message, tool);
        return tool;
    }

    // Valid only while the fence is the message tail: from registerTool until the
    // block's stop event (tool.open), plus the stop event's own final rewrite
    function rewriteFence(message, tool) {
        const fence = `\n\n\`\`\`command:${tool.name}:${tool.state}\n${commandSummary(tool)}\n\`\`\`\n\n`;
        message.content = message.content.slice(0, tool.fenceStart) + fence;
        message.rawContent = message.rawContent.slice(0, tool.rawFenceStart) + fence;
    }

    // Results land after the block's stop event, by which point the fence is no longer
    // the message tail, so the state token is swapped in place by ordinal instead
    function setFenceState(message, tool) {
        const swap = fence => CF.StringUtils.withCommandFenceState(fence, tool.state);
        message.content = CF.StringUtils.editCommandFence(message.content, tool.ordinal, swap);
        message.rawContent = CF.StringUtils.editCommandFence(message.rawContent, tool.ordinal, swap);
    }

    function commandSummary(tool) {
        if (tool.input !== undefined) return tool.input?.command ?? JSON.stringify(tool.input ?? {});
        return partialStringField(tool.inputJson, "command") ?? tool.inputJson;
    }

    // Value of a string field in incomplete JSON, tolerating a cut mid-escape
    function partialStringField(json, field) {
        const start = json.match(new RegExp(`"${field}"\\s*:\\s*"`));
        if (!start) return null;
        let out = "";
        for (let i = start.index + start[0].length; i < json.length; i++) {
            const c = json[i];
            if (c === '"') break;
            if (c !== '\\') { out += c; continue; }
            const esc = json[++i];
            if (esc === undefined) break;
            if (esc === 'n') out += '\n';
            else if (esc === 't') out += '\t';
            else if (esc === 'u') {
                const hex = json.slice(i + 1, i + 5);
                if (hex.length < 4) break;
                out += String.fromCharCode(parseInt(hex, 16));
                i += 4;
            } else out += esc;
        }
        return out;
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
                        registerTool(currentToolId, block.name ?? "", message);
                    }
                } else if (event.type === "content_block_delta") {
                    const delta = event.delta ?? {};
                    if (delta.type === "text_delta") {
                        appendContent(message, delta.text ?? "");
                    } else if (delta.type === "thinking_delta") {
                        appendContent(message, delta.thinking ?? "");
                    } else if (delta.type === "input_json_delta") {
                        const tool = pendingTools[currentToolId];
                        if (tool) {
                            tool.inputJson += delta.partial_json ?? "";
                            rewriteFence(message, tool);
                        }
                    }
                } else if (event.type === "content_block_stop") {
                    if (inThinkingBlock) {
                        inThinkingBlock = false;
                        appendContent(message, "\n</think>\n\n");
                    } else {
                        const tool = pendingTools[currentToolId];
                        if (tool) {
                            if (tool.input === undefined) {
                                try { tool.input = JSON.parse(tool.inputJson); } catch (e) {}
                            }
                            rewriteFence(message, tool);
                            tool.open = false;
                        }
                        currentToolId = "";
                    }
                }
                return {};
            }

            // Tool results ride on "user" lines and settle the fence's state
            if (dataJson.type === "user") {
                const blocks = dataJson.message?.content;
                if (Array.isArray(blocks)) {
                    for (const block of blocks) {
                        if (block.type !== "tool_result") continue;
                        const tool = pendingTools[block.tool_use_id];
                        // AskUserQuestion keeps its own delegate and :answered end state
                        if (!tool || tool.state !== "running" || tool.name === "AskUserQuestion") continue;
                        tool.state = block.is_error ? "failed" : "done";
                        setFenceState(message, tool);
                    }
                }
                return {};
            }

            if (dataJson.type === "control_request") {
                const request = dataJson.request ?? {};
                if (request.subtype === "can_use_tool") {
                    let tool = pendingTools[request.tool_use_id];
                    if (!tool) tool = registerTool(request.tool_use_id, request.tool_name ?? "", message);
                    // Nothing runs until the user decides; tools that need no approval
                    // never reach here and stay "running"
                    tool.state = "pending";
                    if (tool.open) {
                        // The request can beat the block's stop event; its input is authoritative
                        tool.input = request.input ?? {};
                        rewriteFence(message, tool);
                    } else {
                        setFenceState(message, tool);
                    }
                    message.pendingCommandIndex = tool.ordinal;
                    message.functionName = request.tool_name ?? "";
                    message.functionPending = true;
                    return { permissionRequest: {
                        requestId: dataJson.request_id,
                        toolUseId: request.tool_use_id ?? "",
                        input: request.input ?? {}
                    } };
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
