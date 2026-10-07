pragma Singleton

import qs.modules.common
import Quickshell

Singleton {
    id: root
    property int shiftMode: 0 // 0: off, 1: on, 2: lock
    property list<int> shiftKeys: [42, 54] // Keycodes for Shift keys (left and right)
    // Armed modkeys are never held in uinput on their own; they wrap the next key press
    // so compositor mouse binds (e.g. SUPER+click) cannot swallow OSK clicks.
    property list<int> armedMods: []

    function activeMods() {
        return (root.shiftMode ? [root.shiftKeys[0]] : []).concat(root.armedMods);
    }

    function toggleMod(keycode) {
        root.armedMods = root.armedMods.includes(keycode)
            ? root.armedMods.filter(k => k !== keycode)
            : [...root.armedMods, keycode];
    }

    function releaseAllKeys() {
        const keycodes = Array.from(Array(249).keys());
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            ...keycodes.map(keycode => `${keycode}:0`)
        ])
        root.shiftMode = 0;
        root.armedMods = [];
    }

    function press(keycode) {
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            ...activeMods().map(k => `${k}:1`),
            `${keycode}:1`
        ]);
    }

    function release(keycode) {
        Quickshell.execDetached([
            "ydotool",
            "key", "--key-delay", "0",
            `${keycode}:0`,
            ...activeMods().reverse().map(k => `${k}:0`)
        ]);
    }
}
