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

Rectangle { // Window
    id: oskRoot
    property bool open: GlobalStates.oskOpen
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false

    onOpenChanged: {
        if (!open) {
            Ydotool.releaseAllKeys();
        }
    }

    anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
    }

    function hide() {
        open = false
    }
    implicitHeight: oskContent.height + Appearance.sizes.elevationMargin * 2
    color: "transparent"

    state: open ? "open" : "closed" 
    
    states: [
        State {
            name: "closed"
            PropertyChanges { target: oskRoot; anchors.bottomMargin: -oskRoot.implicitHeight; } 
        },
        State {
            name: "open"
            PropertyChanges { target: oskRoot; anchors.bottomMargin: 0; }
        }
    ]
    Behavior on anchors.bottomMargin {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    // Content
    StyledRectangularShadow {
        target: oskContent
    }
    OskContent {
        id: oskContent
        pinned: oskRoot.pinned
        onHideRequested: oskRoot.hide()
        onPinRequested: (pinned) => {
            oskRoot.pinned = pinned;
        }
    }
}
