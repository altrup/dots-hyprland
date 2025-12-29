import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Rectangle {
    id: root
    property string subtitle: ""
    signal hideRequested()

    anchors.fill: parent
    color: ColorUtils.transparentize(Appearance.m3colors.m3background, Appearance.m3colors.darkmode ? 0.05 : 0.12)
    
    component ScreenCorner: RoundCorner {
        visible: (Config.options.appearance.fakeScreenRounding === 1 || (Config.options.appearance.fakeScreenRounding === 2 && !fullscreen))
        
        anchors {
            top: isTopLeft || isTopRight ? parent.top : undefined
            left: isBottomLeft || isTopLeft ? parent.left : undefined
            bottom: isBottomLeft || isBottomRight ? parent.bottom: undefined
            right: isTopRight || isBottomRight ? parent.right: undefined
        }

        rightVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && (isTopRight || isBottomRight)) * 1
        bottomVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && (isBottomLeft || isBottomRight)) * 1

        implicitSize: Appearance.rounding.screenRounding
        implicitHeight: implicitSize
        implicitWidth: implicitSize
    }
    ScreenCorner {
        corner: RoundCorner.CornerEnum.TopLeft
    }
    ScreenCorner {
        corner: RoundCorner.CornerEnum.TopRight
    }
    ScreenCorner {
        corner: RoundCorner.CornerEnum.BottomLeft
    }
    ScreenCorner {
        corner: RoundCorner.CornerEnum.BottomRight
    }

    MouseArea {
        id: sessionMouseArea
        anchors.fill: parent
        onClicked: {
            root.hideRequested();
        }
    }

    ColumnLayout { // Content column
        id: contentColumn
        anchors.centerIn: parent
        spacing: 15

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.hideRequested();
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            StyledText {
                // Title
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
                text: Translation.tr("Session")
            }

            StyledText {
                // Small instruction
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                text: Translation.tr("Arrow keys to navigate, Enter to select\nEsc or click anywhere to cancel")
            }
        }

        GridLayout {
            columns: 4
            columnSpacing: 15
            rowSpacing: 15

            SessionActionButton {
                id: sessionLock
                focus: root.visible
                buttonIcon: "lock"
                buttonText: Translation.tr("Lock")
                onClicked: {
                    Session.lock();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.right: sessionSleep
                KeyNavigation.down: sessionHibernate
            }
            SessionActionButton {
                id: sessionSleep
                buttonIcon: "dark_mode"
                buttonText: Translation.tr("Sleep")
                onClicked: {
                    Session.suspend();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.left: sessionLock
                KeyNavigation.right: sessionLogout
                KeyNavigation.down: sessionShutdown
            }
            SessionActionButton {
                id: sessionLogout
                buttonIcon: "logout"
                buttonText: Translation.tr("Logout")
                onClicked: {
                    Session.logout();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.left: sessionSleep
                KeyNavigation.right: sessionTaskManager
                KeyNavigation.down: sessionReboot
            }
            SessionActionButton {
                id: sessionTaskManager
                buttonIcon: "browse_activity"
                buttonText: Translation.tr("Task Manager")
                onClicked: {
                    Session.launchTaskManager();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.left: sessionLogout
                KeyNavigation.down: sessionFirmwareReboot
            }

            SessionActionButton {
                id: sessionHibernate
                buttonIcon: "downloading"
                buttonText: Translation.tr("Hibernate")
                onClicked: {
                    Session.hibernate();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.up: sessionLock
                KeyNavigation.right: sessionShutdown
            }
            SessionActionButton {
                id: sessionShutdown
                buttonIcon: "power_settings_new"
                buttonText: Translation.tr("Shutdown")
                onClicked: {
                    Session.poweroff();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.left: sessionHibernate
                KeyNavigation.right: sessionReboot
                KeyNavigation.up: sessionSleep
            }
            SessionActionButton {
                id: sessionReboot
                buttonIcon: "restart_alt"
                buttonText: Translation.tr("Reboot")
                onClicked: {
                    Session.reboot();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.left: sessionShutdown
                KeyNavigation.right: sessionFirmwareReboot
                KeyNavigation.up: sessionLogout
            }
            SessionActionButton {
                id: sessionFirmwareReboot
                buttonIcon: "settings_applications"
                buttonText: Translation.tr("Reboot to firmware settings")
                onClicked: {
                    Session.rebootToFirmware();
                    root.hideRequested();
                }
                onFocusChanged: {
                    if (focus)
                        root.subtitle = buttonText;
                }
                KeyNavigation.up: sessionTaskManager
                KeyNavigation.left: sessionReboot
            }
        }

        DescriptionLabel {
            Layout.alignment: Qt.AlignHCenter
            text: root.subtitle
        }
    }

    RowLayout {
        anchors {
            top: contentColumn.bottom
            topMargin: 10
            horizontalCenter: contentColumn.horizontalCenter
        }
        spacing: 10

        Loader {
            active: SessionWarnings.packageManagerRunning
            visible: active
            sourceComponent: DescriptionLabel {
                text: Translation.tr("Your package manager is running")
                textColor: Appearance.m3colors.m3onErrorContainer
                color: Appearance.m3colors.m3errorContainer
            }
        }
        Loader {
            active: SessionWarnings.downloadRunning
            visible: active
            sourceComponent: DescriptionLabel {
                text: Translation.tr("There might be a download in progress")
                textColor: Appearance.m3colors.m3onErrorContainer
                color: Appearance.m3colors.m3errorContainer
            }
        }
    }

    component DescriptionLabel: Rectangle {
        id: descriptionLabel
        property string text
        property color textColor: Appearance.colors.colOnTooltip
        color: Appearance.colors.colTooltip
        clip: true
        radius: Appearance.rounding.normal
        implicitHeight: descriptionLabelText.implicitHeight + 10 * 2
        implicitWidth: descriptionLabelText.implicitWidth + 15 * 2

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        StyledText {
            id: descriptionLabelText
            anchors.centerIn: parent
            color: descriptionLabel.textColor
            text: descriptionLabel.text
        }
    }
}
