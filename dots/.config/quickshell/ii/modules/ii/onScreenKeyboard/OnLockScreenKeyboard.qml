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

Loader {
    id: oskLoader
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false
    active: GlobalStates.oskOpen
    onActiveChanged: {     
        if (!oskLoader.active) {
            Ydotool.releaseAllKeys();
        }
    }

    anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
    }
    
    sourceComponent: Rectangle { // Window
        id: oskRoot
        visible: oskLoader.active

        function hide() {
            GlobalStates.oskOpen = false
        }
        implicitHeight: oskContent.height + Appearance.sizes.elevationMargin * 2
        color: "transparent"

        // Content
        StyledRectangularShadow {
            target: oskContent
        }
        OskContent {
            id: oskContent
            pinned: oskLoader.pinned
            onHideRequested: oskRoot.hide()
            onPinRequested: (pinned) => {
                oskLoader.pinned = pinned;
            }
        }
    }
}

