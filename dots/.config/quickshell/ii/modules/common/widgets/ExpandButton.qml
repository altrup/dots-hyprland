import qs.modules.common
import qs.modules.common.functions
import QtQuick

/**
 * Chevron that points down when collapsed and up when expanded. Toggling is the caller's job,
 * so the same click can be handled by a surrounding header too.
 */
RippleButton {
    id: root
    property bool expanded: false
    // Set from the surrounding header's MouseArea so the whole bar lights up as one control
    property bool headerHovered: false

    implicitWidth: 22
    implicitHeight: 22
    colBackground: root.headerHovered ? Appearance.colors.colLayer2Hover
        : ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        text: "keyboard_arrow_down"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        iconSize: Appearance.font.pixelSize.normal
        color: Appearance.colors.colOnLayer2
        rotation: root.expanded ? 180 : 0
        Behavior on rotation {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }
}
