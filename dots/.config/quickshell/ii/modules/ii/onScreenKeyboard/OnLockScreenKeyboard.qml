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
    anchors.fill : parent
    active: GlobalStates.oskOpen
    onActiveChanged: {     
        if (!oskLoader.active) {
            Ydotool.releaseAllKeys();
        }
    }
    
    sourceComponent: Rectangle { // Window
        id: oskRoot
        visible: oskLoader.active

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        function hide() {
            GlobalStates.oskOpen = false
        }
        // exclusiveZone: oskLoader.pinned ? implicitHeight - Appearance.sizes.hyprlandGapsOut : 0
        implicitHeight: oskContent.height + Appearance.sizes.elevationMargin * 2
        color: "green"

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

