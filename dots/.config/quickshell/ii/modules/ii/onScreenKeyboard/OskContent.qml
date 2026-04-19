import qs.modules.common
import qs.modules.common.widgets
import "layouts.js" as Layouts
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property bool pinned
    property bool allowDragging: true
    signal hideRequested()
    signal pinRequested(bool pinned)

    property real targetX: (root.parent.width - root.width) / 2
    property real targetY: 0 // from bottom of screen

    property bool dragging: false

    property real snapDistance: 40
    property real releaseDistance: 60
    property real snapResistance: 0.75

    property string snappedEdgeX: ""  // "", "left", "right"
    property string lastSnappedEdgeX: ""
    property real snapResistanceX: snappedEdgeX === "" ? 0 : (dragging ? snapResistance : 1)  
    property real maxX: root.parent.width - root.width
    property real snapOffsetX: lastSnappedEdgeX === "left" ? -targetX * snapResistanceX : 
        lastSnappedEdgeX === "right" ? (maxX - targetX) * snapResistanceX : 0
    function updateSnapOffsetX() {
        if (snappedEdgeX === "") {
            if (targetX < snapDistance) {
                snappedEdgeX = "left";
            } else if (targetX > maxX - snapDistance) {
                snappedEdgeX = "right";
            }
        } else if (snappedEdgeX === "left" && targetX > releaseDistance) {
            snappedEdgeX = "";
        } else if (snappedEdgeX === "right" && (maxX - targetX) > releaseDistance) {
            snappedEdgeX = "";
        }
    }
    onTargetXChanged: if (dragging) updateSnapOffsetX()
    onMaxXChanged: if (root.pinned) updateSnapOffsetX()
    onSnappedEdgeXChanged: {
        if (snappedEdgeX !== "") lastSnappedEdgeX = snappedEdgeX
    }
    Behavior on snapResistanceX {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    property string snappedEdgeY: "bottom"  // "", "top", "bottom"
    property string lastSnappedEdgeY: "bottom"
    property real snapResistanceY: snappedEdgeY === "" ? 0 : (dragging ? snapResistance : 1)  
    property real maxY: root.parent.height - root.height
    property real snapOffsetY: lastSnappedEdgeY === "bottom" ? -targetY * snapResistanceY : 
        lastSnappedEdgeY === "top" ? (maxY - targetY) * snapResistanceY : 0
    function updateSnapOffsetY() {
        if (snappedEdgeY === "") {
            if (targetY < snapDistance) {
                snappedEdgeY = "bottom"; // close to bottom
            } else if (targetY > maxY - snapDistance) {
                snappedEdgeY = "top";
            }
        } else if (snappedEdgeY === "bottom" && targetY > releaseDistance) {
            snappedEdgeY = "";
            if (root.pinned) root.pinRequested(false);
        } else if (snappedEdgeY === "top" && (maxY - targetY) > releaseDistance) {
            snappedEdgeY = "";
        }
    }
    onTargetYChanged: if (dragging) updateSnapOffsetY()
    onMaxYChanged: if (root.pinned) updateSnapOffsetY()
    onSnappedEdgeYChanged: {
        if (snappedEdgeY !== "") lastSnappedEdgeY = snappedEdgeY
    }
    Behavior on snapResistanceY {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    x: targetX + snapOffsetX
    // note that we do y from the bottom to fix animation issues when pinning
    y: root.parent.height - root.height - (targetY + snapOffsetY)

    property int maxWidth: {
        return Math.max(Screen.width, Screen.height) * Config.options.osk.maxWidthFraction
    }
    property real aspectRatio: 0.35
    property real padding: 10
    implicitWidth: {
        return Math.min(parent.width || (Screen.width - 2 * Appearance.sizes.elevationMargin), maxWidth)
    }
    implicitHeight: implicitWidth * aspectRatio + padding * 2
    color: Appearance.colors.colLayer0
    radius: Appearance.rounding.windowRounding

    Keys.onPressed: (event) => { // Esc to close
        if (event.key === Qt.Key_Escape) {
            root.hideRequested()
        }
    }

    component OskControlButton: GroupButton { // Pin button
        baseWidth: 40
        baseHeight: width
        clickedWidth: width
        clickedHeight: width + 10
        buttonRadius: Appearance.rounding.normal

        height: width

        Layout.fillWidth: true
        Layout.preferredWidth: baseWidth

        function calculateIconSize() {
            return height >= 50 ? Appearance.font.pixelSize.huge : Appearance.font.pixelSize.larger;
        }
    }

    component OskDragHandler: DragHandler {
        target: null
        enabled: root.allowDragging
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real rootXAtPress: 0
        property real rootYAtPress: 0

        onActiveChanged: {
            if (active) {
                rootXAtPress = root.x;
                rootYAtPress = root.y;
            }
            root.dragging = active;
        }

        onCentroidChanged: {
            if (!active) return;
            
            root.targetX = rootXAtPress + centroid.scenePosition.x - centroid.scenePressPosition.x;
            root.targetY = root.parent.height - root.height - (rootYAtPress + centroid.scenePosition.y - centroid.scenePressPosition.y);
        }
    }

    RowLayout {
        id: oskRowLayout
        anchors {
            fill: parent
            margins: root.padding
            leftMargin: 0
        }
        spacing: root.padding
        RowLayout {
            anchors {
                top: parent.top
                bottom: parent.bottom
                topMargin: -root.padding
                bottomMargin: -root.padding
            }
            
            VerticalButtonGroup {
                id: controlButtons
                Layout.fillWidth: true
                Layout.leftMargin: root.padding

                OskControlButton { // Pin button
                    toggled: root.pinned
                    downAction: () => {
                        if (!root.pinned) {
                            root.snappedEdgeY = "bottom";
                        }
                        root.pinRequested(!root.pinned);
                    }
                    contentItem: MaterialSymbol {
                        text: "keep"
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: parent.calculateIconSize()
                        color: root.pinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                    }
                    onHeightChanged: {
                        contentItem.iconSize = calculateIconSize()
                    }
                }
                OskControlButton {
                    visible: root.allowDragging
                    overrideDown: buttonDragHandler.active || down

                    mouseArea.cursorShape: Qt.SizeAllCursor
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        text: "drag_indicator"
                        iconSize: parent.calculateIconSize()
                    }
                    onHeightChanged: {
                        contentItem.iconSize = calculateIconSize()
                    }

                    OskDragHandler {
                        id: buttonDragHandler
                    }
                }
                OskControlButton {
                    onClicked: () => {
                        root.hideRequested()
                    }
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        text: "keyboard_hide"
                        iconSize: parent.calculateIconSize()
                    }
                    onHeightChanged: {
                        contentItem.iconSize = calculateIconSize()
                    }
                }
            }

            OskDragHandler {
                grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything
            }
        }
        Rectangle {
            Layout.topMargin: 20
            Layout.bottomMargin: 20
            Layout.fillHeight: true
            implicitWidth: 1
            color: Appearance.colors.colOutlineVariant
        }
        Item {
            id: keyboard    
            property var layouts: Layouts.byName
            property var activeLayoutName: (layouts.hasOwnProperty(Config.options?.osk.layout)) 
                ? Config.options?.osk.layout 
                : Layouts.defaultLayout
            property var currentLayout: layouts[activeLayoutName]

            implicitWidth: keyRows.implicitWidth
            implicitHeight: keyRows.implicitHeight
            
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: keyRows
                anchors.fill: parent
                spacing: 5

                Repeater {
                    model: keyboard.currentLayout.keys

                    delegate: RowLayout {
                        id: keyRow
                        required property var modelData
                        spacing: 5
                        
                        Repeater {
                            model: modelData
                            // A normal key looks like this: {label: "a", labelShift: "A", shape: "normal", keycode: 30, type: "normal"}
                            delegate: OskKey { 
                                required property var modelData
                                keyData: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
