import qs.modules.common
import QtQuick
import QtQuick.Layouts

/**
 * Clipping window for content that collapses to nothing.
 *
 * Anchor the content to this item's bottom, so collapsing slides it out of view instead of
 * squashing it, which would re-wrap text on the way. Set contentHeight to the content's own
 * natural height; measuring it here would fight the anchor.
 */
Item {
    id: root
    property bool collapsed: false
    property real contentHeight: 0
    property var animation: Appearance?.animation.elementMoveFast
    // Off while content is still arriving, so growth isn't animated as a collapse
    property bool animated: true

    Layout.fillWidth: true
    clip: true
    implicitHeight: root.collapsed ? 0 : root.contentHeight

    Behavior on implicitHeight {
        enabled: root.animated
        NumberAnimation {
            duration: root.animation.duration
            easing.type: root.animation.type
            easing.bezierCurve: root.animation.bezierCurve
        }
    }
}
