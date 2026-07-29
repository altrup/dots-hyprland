pragma Singleton
import Quickshell

Singleton {
    id: root

    /**
     * Formats a string according to the args that are passed inc
     * @param { string } str
     * @param  {...any} args
     * @returns { string }
     */
    function format(str, ...args) {
        return str.replace(/{(\d+)}/g, (match, index) => typeof args[index] !== 'undefined' ? args[index] : match);
    }

    /**
     * Returns the domain of the passed in url or null
     * @param { string } url
     * @returns { string| null }
     */
    function getDomain(url) {
        const match = url.match(/^(?:https?:\/\/)?(?:www\.)?([^\/]+)/);
        return match ? match[1] : null;
    }

    /**
     * Returns the base url of the passed in url or null
     * @param { string } url
     * @returns { string | null }
     */
    function getBaseUrl(url) {
        const match = url.match(/^(https?:\/\/[^\/]+)(\/.*)?$/);
        return match ? match[1] : null;
    }

    /**
     * Escapes single quotes in shell commands
     * @param { string } str
     * @returns { string }
     */
    function shellSingleQuoteEscape(str) {
        return String(str)
        // .replace(/\\/g, '\\\\')
        .replace(/'/g, "'\\''");
    }

    /**
     * Applies a transform to the nth command fence. Empty-bodied fences are skipped so
     * the ordinal counts the same fences splitMarkdownBlocks emits.
     * @param { string } content
     * @param { number } ordinal
     * @param { (fence: string) => string } transform
     * @returns { string }
     */
    function editCommandFence(content, ordinal, transform) {
        if (ordinal < 0) return content;
        let seen = 0;
        return content.replace(/```command(?::[\w-]+)*\n([\s\S]*?)```/g,
            (fence, body) => body.trim().length === 0 ? fence
                : (seen++ === ordinal) ? transform(fence) : fence);
    }

    /**
     * Lifecycle states a command fence's info string can end with, as command:<name>:<state>.
     */
    readonly property var commandFenceStates: ["pending", "running", "done", "failed", "denied", "answered"]

    /**
     * Swaps a command fence's state token, keeping whatever tool name it already carries
     * so states replace each other instead of stacking.
     * @param { string } fence
     * @param { string } state
     * @returns { string }
     */
    function withCommandFenceState(fence, state) {
        return fence.replace(/^```command((?::[\w-]+)*)/, (full, flags) => {
            const name = flags.split(":").filter(s => s.length > 0)
                .find(s => !root.commandFenceStates.includes(s));
            return "```command" + (name ? ":" + name : "") + ":" + state;
        });
    }

    /**
     * Splits markdown blocks into three different types: text, think, and code.
     * @param { string } markdown
     * @returns {Array<{type: "text" | "think" | "code", content: string, lang?: string, completed?: boolean}>}
     */
    function splitMarkdownBlocks(markdown) {
        /**
         * @type {{type: "text" | "think" | "code"; content: string; lang: string | undefined; completed: boolean | undefined}[]}
         */
        const result = [];
        let pos = 0;
        let textStart = 0;
        const pushText = end => {
            const text = markdown.slice(textStart, end);
            if (text.trim()) result.push({ type: "text", content: text });
        };
        while (pos < markdown.length) {
            const think = markdown.indexOf("<think>", pos);
            const fence = markdown.indexOf("```", pos);
            if (think === -1 && fence === -1) break;
            // Whichever of the two opens first owns everything up to its own terminator, and
            // its body is never scanned. A construct with no terminator runs to the end and
            // is reported incomplete
            if (fence === -1 || (think !== -1 && think < fence)) {
                pushText(think);
                const close = markdown.indexOf("</think>", think + 7);
                const content = markdown.slice(think + 7, close === -1 ? markdown.length : close);
                if (content.trim()) {
                    result.push({ type: "think", content: content, completed: close !== -1 });
                }
                pos = close === -1 ? markdown.length : close + 8;
            } else {
                pushText(fence);
                const langMatch = markdown.slice(fence + 3).match(/^([\w:-]+)?\n/);
                const contentStart = fence + 3 + (langMatch?.[0].length ?? 0);
                const close = markdown.indexOf("```", contentStart);
                const content = markdown.slice(contentStart, close === -1 ? markdown.length : close);
                if (content.trim()) {
                    result.push({
                        type: "code",
                        lang: langMatch?.[1] ?? "",
                        content: content,
                        completed: close !== -1
                    });
                }
                pos = close === -1 ? markdown.length : close + 3;
            }
            textStart = pos;
        }
        pushText(markdown.length);
        return result;
    }

    /**
     * Returns the original string with backslashes escaped
     * @param { string } str
     * @returns { string }
     */
    function escapeBackslashes(str) {
        return str.replace(/\\/g, '\\\\');
    }

    /**
     * Wraps words to supplied maximum length
     * @param { string | null } str
     * @param { number } maxLen
     * @returns { string }
     */
    function wordWrap(str, maxLen) {
        if (!str)
            return "";
        let words = str.split(" ");
        let lines = [];
        let current = "";
        for (let i = 0; i < words.length; ++i) {
            if ((current + (current.length > 0 ? " " : "") + words[i]).length > maxLen) {
                if (current.length > 0)
                    lines.push(current);
                current = words[i];
            } else {
                current += (current.length > 0 ? " " : "") + words[i];
            }
        }
        if (current.length > 0)
            lines.push(current);
        return lines.join("\n");
    }

    /**
     * Cleans up a music title by removing bracketed and special characters.
     * @param { string } title
     * @returns { string }
     */
    function cleanMusicTitle(title) {
        if (!title)
            return "";
        // Brackets
        title = title.replace(/^ *\([^)]*\) */g, " "); // Round brackets
        title = title.replace(/^ *\[[^\]]*\] */g, " "); // Square brackets
        title = title.replace(/^ *\{[^\}]*\} */g, " "); // Curly brackets
        // Japenis brackets
        title = title.replace(/^ *【[^】]*】/, ""); // Touhou
        title = title.replace(/^ *《[^》]*》/, ""); // ??
        title = title.replace(/^ *「[^」]*」/, ""); // OP/ED thingie
        title = title.replace(/^ *『[^』]*』/, ""); // OP/ED thingie

        return title.trim();
    }

    /**
     * Converts seconds to a friendly time string (e.g. 1:23 or 1:02:03).
     * @param { number } seconds
     * @returns { string }
     */
    function friendlyTimeForSeconds(seconds) {
        if (isNaN(seconds) || seconds < 0)
            return "0:00";
        seconds = Math.floor(seconds);
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        if (h > 0) {
            return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
        } else {
            return `${m}:${s.toString().padStart(2, '0')}`;
        }
    }

    /**
     * Escapes HTML special characters in a string.
     * @param { string } str
     * @returns { string }
     */
    function escapeHtml(str) {
        if (typeof str !== 'string')
            return str;
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    /**
     * Cleans a cliphist entry by removing leading digits and tab.
     * @param { string } str
     * @returns { string }
     */
    function cleanCliphistEntry(str: string): string {
        return str.replace(/^\d+\t/, "");
    }

    /**
     * Checks if any substring in the list is contained in the string.
     * @param { string } str
     * @param { string[] } substrings
     * @returns { boolean }
     */
    function stringListContainsSubstring(str, substrings) {
        for (let i = 0; i < substrings.length; ++i) {
            if (str.includes(substrings[i])) {
                return true;
            }
        }
        return false;
    }

    /**
     * Removes the given prefix from the string if present.
     * @param { string } str
     * @param { string } prefix
     * @returns { string }
     */
    function cleanPrefix(str, prefix) {
        if (str.startsWith(prefix)) {
            return str.slice(prefix.length);
        }
        return str;
    }

    /**
     * Removes the first matching prefix from the string if present.
     * @param { string } str
     * @param { string[] } prefixes
     * @returns { string }
     */
    function cleanOnePrefix(str, prefixes) {
        for (let i = 0; i < prefixes.length; ++i) {
            if (str.startsWith(prefixes[i])) {
                return str.slice(prefixes[i].length);
            }
        }
        return str;
    }

    function toTitleCase(str) {
        // Replace "-" and "_" with space, then capitalize each word
        return str.replace(/[-_]/g, " ").replace(
            /\w\S*/g,
            function(txt) {
            return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
            }
        );
    }
}
