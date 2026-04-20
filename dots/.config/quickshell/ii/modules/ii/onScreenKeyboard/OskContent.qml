import qs.modules.common
import qs.modules.common.widgets
import "layouts.js" as Layouts
import QtQuick
import QtQuick.Layouts
pragma ComponentBehavior: Bound

Rectangle {
    id: root
    property bool pinned: false
    property bool allowDragging: true
    property bool allowPinning: true
    signal hideRequested()
    signal pinRequested(bool pinned)

    property real snapDistance: 0.02 * Math.min(root.parent.width, root.parent.height)
    property real releaseDistance: 1.5 * snapDistance
    property real snapResistance: 0.8
    property real sampleBlend: 0.5 // how much of velocity to blend from sample
    property real friction: 150 // how many pixels/second to decrease velocity by per second

    property real targetX: (root.parent.width - root.width) / 2
    property real targetY: (root.parent.height - root.height)

    property bool dragging: false

    component SnapEdge: Item {
        required property real coordinate
        required property real edgeCoordinate
        // lowerSide: true if snapping towards x < snapCoordinate, false if snapping towards x > snapCoordinate
        required property string side // which side to snap to: "lower", "center", "upper" 
        required property bool enabled

        property bool snapped: false
        property real snapResistance: !snapped ? 0 : (root.dragging ? root.snapResistance : 1)
        property real snapOffset: (edgeCoordinate - coordinate) * snapResistance
        function updateSnapOffset() {
            if (!enabled) {
                snapped = false;
                return;
            }

            if (!snapped && (
                side === "center" ? Math.abs(coordinate - edgeCoordinate) < root.snapDistance :
                (side === "lower" ? 1 : -1) * (coordinate - edgeCoordinate) < root.snapDistance
            )) {
                snapped = true;
            } else if (snapped && (
                side === "center" ? Math.abs(coordinate - edgeCoordinate) > root.releaseDistance :
                (side === "lower" ? 1 : -1) * (coordinate - edgeCoordinate) > root.releaseDistance
            )) {
                snapped = false;
            }
        }
        onCoordinateChanged: updateSnapOffset()
        onEdgeCoordinateChanged: updateSnapOffset()
        onSideChanged: updateSnapOffset()
        onEnabledChanged: updateSnapOffset()
        Behavior on snapResistance {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    property real maxX: root.parent.width - root.width
    SnapEdge {
        id: leftEdge
        enabled: root.parent.width > 0 && root.width > 0 && !verticalCenter.snapped
        coordinate: root.targetX
        edgeCoordinate: 0
        side: "lower"
    }
    SnapEdge {
        id: verticalCenter
        enabled: root.parent.width > 0 && root.width > 0
        coordinate: root.targetX
        edgeCoordinate: root.maxX/2
        side: "center"
    }
    SnapEdge {
        id: rightEdge
        enabled: root.parent.width > 0 && root.width > 0 && !leftEdge.snapped && !verticalCenter.snapped
        coordinate: root.targetX
        edgeCoordinate: root.maxX
        side: "upper"
    }

    property real maxY: root.parent.height - root.height
    SnapEdge {
        id: topEdge
        enabled: root.parent.height > 0 && root.height > 0
        coordinate: root.targetY
        edgeCoordinate: 0
        side: "lower"
    }
    SnapEdge {
        id: bottomEdge
        enabled: root.parent.height > 0 && root.height > 0 && !(topEdge.enabled && topEdge.snapped)
        coordinate: root.targetY
        edgeCoordinate: root.maxY
        side: "upper"

        onSnappedChanged: {
            if (!snapped && root.pinned && root.dragging) root.pinRequested(false);
        }
    }

    x: targetX + leftEdge.snapOffset + verticalCenter.snapOffset + rightEdge.snapOffset
    y: targetY + topEdge.snapOffset + bottomEdge.snapOffset

    property real lastTime: 0
    property real lastX: 0
    property real lastY: 0
    property real velocityX: 0
    property real velocityY: 0
    // sample velocity while dragging
    function sampleVelocity() {
        if (!dragging) return;

        const now = Date.now();
        const dt = (now - lastTime) / 1000;
        if (dt > 1 / 60) {
            velocityX = (targetX - lastX) / dt;
            velocityY = (targetY - lastY) / dt;
            lastX = targetX;
            lastY = targetY;
            lastTime = now;
        }
    }
    onDraggingChanged: {
        momentumTimer.running = !dragging;
        if (dragging) {
            lastTime = Date.now();
            lastX = x;
            lastY = y;
            velocityX = 0;
            velocityY = 0;
        }
    }
    onXChanged: sampleVelocity();
    onYChanged: sampleVelocity();
    Timer {
        id: momentumTimer
        interval: 1000 / 60
        repeat: true
        running: false
        
        onTriggered: {
            // sample velocity
            const dt = interval / 1000;
            root.velocityX = (1 - root.sampleBlend) * root.velocityX + root.sampleBlend * (root.x - root.lastX) / dt;
            root.velocityY = (1 - root.sampleBlend) * root.velocityY + root.sampleBlend * (root.y - root.lastY) / dt;
            root.lastX = root.x;
            root.lastY = root.y;

            // momentum calculations
            const speed = Math.hypot(root.velocityX, root.velocityY);
            if (speed > 0) {
                const newSpeed = Math.max(0, speed - root.friction * dt);
                const scale = newSpeed / speed;
                root.velocityX *= scale;
                root.velocityY *= scale;
            }
            root.targetX += root.velocityX * dt;
            root.targetY += root.velocityY * dt;
            
            if (speed < 5) {  // px/sec threshold
                running = false;
                root.velocityX = 0;
                root.velocityY = 0;
            }
        }
    }

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
        dragThreshold: 0
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
            root.targetY = rootYAtPress + centroid.scenePosition.y - centroid.scenePressPosition.y;
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
                    visible: root.allowPinning
                    toggled: root.pinned
                    downAction: () => {
                        if (!root.pinned) {
                            topEdge.snapped = false;
                            bottomEdge.snapped = true;
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
                    overrideDown: buttonDragHandler.active || leftBarDragHandler.active || pressHandler.pressed || down

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

            TapHandler {
                id: pressHandler
                acceptedButtons: leftBarDragHandler.acceptedButtons
            }
            OskDragHandler {
                id: leftBarDragHandler
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
