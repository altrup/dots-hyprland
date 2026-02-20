pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: bar
    property bool showBarBackground: Config.options.bar.showBackground

    Variants {
        // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData

                property var hyprlandDataMonitor: HyprlandData.monitors.find(m => m.name === screen.name)
                property var currentWorkspaceID: hyprlandDataMonitor?.specialWorkspace.id || hyprlandDataMonitor?.activeWorkspace.id
                property var biggestWindow: HyprlandData.biggestWindowForWorkspace(currentWorkspaceID)
                property var window: HyprlandData.activeWindow?.workspace?.id === currentWorkspaceID ? HyprlandData.activeWindow : biggestWindow

                property bool autoHideEnable: window?.fullscreen === 2 || Config?.options.bar.autoHide.enable

                Timer {
                    id: showBarTimer
                    interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: {
                        barRoot.superShow = true
                    }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else {
                            showBarTimer.stop();
                            barRoot.superShow = false;
                        }
                    }
                }
                property bool superShow: false
                property bool mustShow: (hoverRegion.containsMouse || superShow) && (Config?.options.bar.autoHide.enableOnFullscreen || window?.fullscreen !== 2)
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: (barRoot.autoHideEnable && (!mustShow || (window?.fullscreen !== 2 && !Config?.options.bar.autoHide.pushWindows))) ? 0 :
                    Appearance.sizes.baseBarHeight + (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                Behavior on exclusiveZone {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                WlrLayershell.namespace: "quickshell:bar"
                WlrLayershell.layer: WlrLayer.Overlay
                implicitHeight: Appearance.sizes.barHeight + Appearance.rounding.screenRounding
                mask: Region {
                    item: hoverMaskRegion
                }
                color: "transparent"

                // Positioning
                anchors {
                    top: !Config.options.bar.bottom
                    bottom: Config.options.bar.bottom
                    left: true
                    right: true
                }

                margins {
                    right: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                    bottom: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
                }

                // Include in focus grab
                Component.onCompleted: {
                    GlobalFocusGrab.addPersistent(barRoot);
                }
                Component.onDestruction: {
                    GlobalFocusGrab.removePersistent(barRoot);
                }

                MouseArea  {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors {
                        fill: parent
                        rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * 1
                        bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * 1
                    }

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            topMargin: -Config.options.bar.autoHide.hoverRegionWidth
                            bottomMargin: -Config.options.bar.autoHide.hoverRegionWidth
                        }
                    }

                    BarContent {
                        id: barContent
                        
                        implicitHeight: Appearance.sizes.barHeight
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: (barRoot.autoHideEnable && !mustShow) ? -Appearance.sizes.barHeight : 0
                            bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
                            rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                        }
                        Behavior on anchors.topMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "bottom"
                            when: Config.options.bar.bottom
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: parent.bottom
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.bottomMargin: (barRoot.autoHideEnable && !mustShow) ? -Appearance.sizes.barHeight : 0
                            }
                        }
                    }

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: barContent.bottom
                            bottom: undefined
                        }
                        height: mustShow || barRoot.window?.fullscreen !== 2 || Config.options.appearance.fakeScreenRounding === 1 ? Appearance.rounding.screenRounding : 0
                        active: showBarBackground && Config.options.bar.cornerStyle === 0 // Hug

                        Behavior on height {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "bottom"
                            when: Config.options.bar.bottom
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: barContent.top
                                }
                            }
                        }

                        sourceComponent: Item {
                            implicitHeight: roundDecorators.height
                            RoundCorner {
                                id: leftCorner
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                }

                                implicitSize: roundDecorators.height
                                color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: Config.options.bar.bottom
                                    PropertyChanges {
                                        leftCorner.corner: RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                            RoundCorner {
                                id: rightCorner
                                anchors {
                                    right: parent.right
                                    top: !Config.options.bar.bottom ? parent.top : undefined
                                    bottom: Config.options.bar.bottom ? parent.bottom : undefined
                                }
                                implicitSize: roundDecorators.height
                                color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"

                                corner: RoundCorner.CornerEnum.TopRight
                                states: State {
                                    name: "bottom"
                                    when: Config.options.bar.bottom
                                    PropertyChanges {
                                        rightCorner.corner: RoundCorner.CornerEnum.BottomRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    GlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"

        onPressed: {
            GlobalStates.barOpen = !GlobalStates.barOpen;
        }
    }

    GlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"

        onPressed: {
            GlobalStates.barOpen = true;
        }
    }

    GlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"

        onPressed: {
            GlobalStates.barOpen = false;
        }
    }
}
