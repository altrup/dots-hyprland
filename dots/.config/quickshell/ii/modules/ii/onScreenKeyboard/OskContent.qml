import qs.modules.common
import qs.modules.common.widgets
import "layouts.js" as Layouts
import QtQuick
import QtQuick.Layouts
pragma ComponentBehavior: Bound

Item {
    id: root
    property string pinEdge: "" // "top" or "bottom"
    property bool allowDragging: true
    property bool allowPinning: true
    signal hideRequested()
    signal pinEdgeRequested(string pinEdge)

    property real snapDistance: 0.02 * Math.min(root.parent.width, root.parent.height)
    property real releaseDistance: 1.5 * snapDistance
    property real snapResistance: 0.8
    property real sampleSmoothingTime: 0.03 // time constant of blending velocity with sampled data
    property real friction: 150 // how many pixels/second to decrease velocity by per second

    property list<var> dragHandlers: []
    property bool dragging: dragHandlers.some(h => h.active)

    property real maxX: root.parent.width - root.width
    property real maxY: root.parent.height - root.height

    property real targetX: root.maxX / 2
    property real targetY: root.maxY

    Connections {
        target: root.parent
        property real lastRootWidth: root.width
        property real lastRootHeight: root.height
        property real lastWidth: root.parent.width
        property real lastHeight: root.parent.height
        function onWidthChanged() {
            if (lastWidth <= 0 || root.parent.width <= 0) return;
            // set targetX to same relative location
            if (lastWidth - lastRootWidth > 0) {
                root.targetX *= (root.parent.width - root.width) / (lastWidth - lastRootWidth);
            } else {
                root.targetX = (root.parent.width - root.width) / 2; // default value
            }
            lastRootWidth = root.width;
            lastWidth = root.parent.width;
        }
        function onHeightChanged() {
            if (lastHeight <= 0 || root.parent.height <= 0) return;
            // set targetY to same relative location
            if (lastHeight - lastRootHeight > 0) {
                root.targetY *= (root.parent.height - root.height) / (lastHeight - lastRootHeight);
            } else {
                root.targetY = (root.parent.height - root.height); // default value
            }
            lastRootHeight = root.height;
            lastHeight = root.parent.height;
        }
    }

    component SnapEdge: Item {
        required property real coordinate
        required property real edgeCoordinate
        // lowerSide: true if snapping towards x < snapCoordinate, false if snapping towards x > snapCoordinate
        required property string side // which side to snap to: "lower", "center", "upper" 
        required property bool enabled
        property bool requireManualUnsnap: false // if true, user must be dragging to unsnap (as opposed to momentum)

        property bool snapped: false
        property real snapResistance: !snapped ? 0 : (root.dragging ? root.snapResistance : 1)
        property real snapOffset: (edgeCoordinate - coordinate) * snapResistance
        function updateSnapOffset() {
            if (!enabled) {
                snapped = false;
                return;
            }
            if (requireManualUnsnap && !root.dragging) return;

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

    SnapEdge {
        id: topEdge
        enabled: root.parent.height > 0 && root.height > 0
        coordinate: root.targetY
        edgeCoordinate: 0
        side: "lower"
        requireManualUnsnap: root.pinEdge === "top"

        onSnappedChanged: {
            if (!snapped && root.pinEdge === "top" && root.dragging) root.pinEdgeRequested("");
        }
    }
    SnapEdge {
        id: bottomEdge
        enabled: root.parent.height > 0 && root.height > 0 && !(topEdge.enabled && topEdge.snapped)
        coordinate: root.targetY
        edgeCoordinate: root.maxY
        side: "upper"
        requireManualUnsnap: root.pinEdge === "bottom"

        onSnappedChanged: {
            if (!snapped && root.pinEdge === "bottom" && root.dragging) root.pinEdgeRequested("");
        }
    }

    x: targetX + leftEdge.snapOffset + verticalCenter.snapOffset + rightEdge.snapOffset
    y: targetY + topEdge.snapOffset + bottomEdge.snapOffset

    Timer {
        id: momentumTimer
        interval: 1000 / 60
        repeat: true
        running: root.dragging || !(velocityX === 0 && velocityY === 0)

        property real lastX: 0
        property real lastY: 0
        property real velocityX: 0
        property real velocityY: 0

        onRunningChanged: {
            if (!running) return;

            // initialize values
            lastX = root.dragging ? root.targetX : root.x;
            lastY = root.dragging ? root.targetY : root.y;
        }
        
        onTriggered: {
            if (root.dragging) {
                const dt = interval / 1000;
                velocityX = (root.targetX - lastX) / dt;
                velocityY = (root.targetY - lastY) / dt;
                lastX = root.targetX;
                lastY = root.targetY;
            } else {
                // sample velocity
                const dt = interval / 1000;
                const retention = Math.exp(-dt / root.sampleSmoothingTime);
                velocityX = retention * velocityX + (1 - retention) * (root.x - lastX) / dt;
                velocityY = retention * velocityY + (1 - retention) * (root.y - lastY) / dt;
                lastX = root.x;
                lastY = root.y;

                // momentum calculations
                const speed = Math.hypot(velocityX, velocityY);
                if (speed > 0) {
                    const newSpeed = Math.max(0, speed - root.friction * dt);
                    const scale = newSpeed / speed;
                    velocityX *= scale;
                    velocityY *= scale;
                }
                root.targetX += velocityX * dt;
                root.targetY += velocityY * dt;
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
        dragThreshold: 2
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real rootXAtPress: 0
        property real rootYAtPress: 0

        Component.onCompleted: root.dragHandlers.push(this)
        Component.onDestruction: root.dragHandlers.splice(root.dragHandlers.indexOf(this), 1)

        onActiveChanged: {
            if (active) {
                rootXAtPress = root.x;
                rootYAtPress = root.y;
            }
        }

        onCentroidChanged: {
            if (!active) return;

            root.targetX = rootXAtPress + centroid.scenePosition.x - centroid.scenePressPosition.x;
            root.targetY = rootYAtPress + centroid.scenePosition.y - centroid.scenePressPosition.y;
        }
    }

    StyledRectangularShadow {
        target: oskBackground
    }
    Rectangle {
        id: oskBackground
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding

        TapHandler {
            id: pressHandler
            acceptedButtons: leftBarDragHandler.acceptedButtons
        }
        OskDragHandler {
            id: leftBarDragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.ApprovesTakeOverByAnything
        }
        RowLayout {
            id: oskRowLayout
            anchors {
                fill: parent
                margins: root.padding
            }
            spacing: root.padding
            RowLayout {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                }

                VerticalButtonGroup {
                    id: controlButtons
                    Layout.fillWidth: true

                    OskControlButton { // Pin button
                        visible: root.allowPinning
                        toggled: root.pinEdge.length > 0
                        downAction: () => {
                            const nextPinEdge = root.pinEdge.length > 0 ? "" : 
                                                momentumTimer.running ? (momentumTimer.velocityY >= 0 ? "bottom": "top") :
                                                oskContent.y + root.height / 2 >= root.parent.height / 2 ? "bottom" : "top";
                            if (nextPinEdge.length > 0) {
                                topEdge.snapped = nextPinEdge === "top";
                                bottomEdge.snapped = nextPinEdge === "bottom";

                                momentumTimer.velocityY = 0;
                            }
                            root.pinEdgeRequested(nextPinEdge);
                        }
                        contentItem: MaterialSymbol {
                            text: "keep"
                            horizontalAlignment: Text.AlignHCenter
                            iconSize: parent.calculateIconSize()
                            color: root.pinEdge.length > 0 ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
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
}
