import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
pragma ComponentBehavior: Bound

Scope { // Scope
    id: root
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false
    // we store screenHeight because Screen.height doesn't take exclusiveZones into effect
    property real screenHeight: oskContent.height + 2 * Appearance.sizes.elevationMargin
        
    PanelWindow { // Window
        id: oskRoot
        visible: GlobalStates.oskOpen && !GlobalStates.screenLocked
        onVisibleChanged: {
            if (!oskRoot.visible) {
                Ydotool.releaseAllKeys();
            }
        }

        anchors {
            top: !root.pinned
            bottom: true
            left: true
            right: true
        }

        function hide() {
            GlobalStates.oskOpen = false
        }
        exclusiveZone: root.pinned ? oskContent.height + 2 * Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut : 0
        onHeightChanged: {
            if (!root.pinned) screenHeight = oskRoot.height;
        }
        implicitHeight: root.screenHeight
        WlrLayershell.namespace: "quickshell:osk"
        WlrLayershell.layer: WlrLayer.Overlay
        // Hyprland 0.49: Focus is always exclusive and setting this breaks mouse focus grab
        // WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"

        mask: Region {
            item: oskContent
        }

        // Make it usable with other panels
        Component.onCompleted: {
            GlobalFocusGrab.addPersistent(oskRoot);
        }
        Component.onDestruction: {
            GlobalFocusGrab.removePersistent(oskRoot);
        }

        // Content
        StyledRectangularShadow {
            target: oskContent
        }
        Item {
            anchors {
                fill: parent
                margins: Appearance.sizes.elevationMargin
            }

            OskContent {
                id: oskContent
                pinned: root.pinned
                onHideRequested: oskRoot.hide()
                onPinRequested: (pinned) => {
                    root.pinned = pinned;
                }
            }
        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            GlobalStates.oskOpen = !GlobalStates.oskOpen;
        }

        function close(): void {
            GlobalStates.oskOpen = false
        }

        function open(): void {
            GlobalStates.oskOpen = true
        }
    }

    GlobalShortcut {
        name: "oskToggle"
        description: "Toggles on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = !GlobalStates.oskOpen;
        }
    }

    GlobalShortcut {
        name: "oskOpen"
        description: "Opens on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = true
        }
    }

    GlobalShortcut {
        name: "oskClose"
        description: "Closes on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = false
        }
    }

}
