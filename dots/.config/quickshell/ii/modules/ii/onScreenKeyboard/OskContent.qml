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

    property real baseX: (root.parent.width - root.width) / 2
    property real baseY: Appearance.sizes.elevationMargin
    property real targetX: baseX
    property real targetY: baseY // from bottom of screen
    x: Math.max(0, Math.min(root.parent.width - root.width, targetX))
    y: Math.max(0, Math.min(root.parent.height - root.height, root.parent.height - root.height - targetY))

    property int maxWidth: {
        return Math.max(Screen.width, Screen.height) * Config.options.osk.maxWidthFraction
    }
    property real aspectRatio: 0.35
    property real padding: 10
    implicitWidth: {
        return Math.min((parent.width || Screen.width) - 2 * Appearance.sizes.elevationMargin, maxWidth)
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
                rootXAtPress = root.x
                rootYAtPress = root.y
            }
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
