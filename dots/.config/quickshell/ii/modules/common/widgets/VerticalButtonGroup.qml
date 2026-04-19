import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * A container that supports GroupButton children for bounciness.
 * See https://m3.material.io/components/button-groups/overview
 */
Rectangle {
    id: root
    default property alias content: columnLayout.data
    property real spacing: 5
    property real padding: 0
    property int clickIndex: columnLayout.clickIndex

    property var visibleChildren: columnLayout.children.filter(c => c.visible)

    function calculateContentHeight() {
        let total = 0;
        for (let i = 0; i < root.visibleChildren.length; ++i) {
            const child = root.visibleChildren[i];
            total += child.baseHeight ?? child.implicitHeight ?? child.height;
        }
        return total + columnLayout.spacing * (root.visibleChildren.length - 1);
    }

    property real contentHeight: calculateContentHeight()

    onWidthChanged: {
        contentHeight = calculateContentHeight();
    }

    topLeftRadius: root.visibleChildren.length > 0 ? (root.visibleChildren[0].radius + padding) : 
        Appearance?.rounding?.small
    topRightRadius: topLeftRadius
    bottomLeftRadius: root.visibleChildren.length > 0 ? (root.visibleChildren[root.visibleChildren.length - 1].radius + padding) : 
        Appearance?.rounding?.small
    bottomRightRadius: bottomLeftRadius

    color: "transparent"
    height: root.contentHeight + padding * 2
    implicitWidth: columnLayout.implicitWidth + padding * 2
    implicitHeight: root.contentHeight + padding * 2
    
    children: [ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.spacing
        property int clickIndex: -1
    }]
}
