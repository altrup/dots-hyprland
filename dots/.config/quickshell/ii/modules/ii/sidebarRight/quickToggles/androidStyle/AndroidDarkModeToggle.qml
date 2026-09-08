import qs.modules.common
import qs.modules.common.models.quickToggles
import qs.services
import QtQuick
import QtQuick.Controls as Controls

AndroidQuickToggleButton {
    id: root
    toggleModel: DarkModeToggle {}
    altAction: () => themeMenu.popup()
    onClicked: root.mainAction()

    Controls.Menu {
        id: themeMenu
        palette.window: Appearance.colors.colLayer1Base
        palette.windowText: Appearance.colors.colOnLayer1
        palette.text: Appearance.colors.colOnLayer1
        palette.highlight: Appearance.colors.colPrimary
        palette.highlightedText: Appearance.colors.colOnPrimary

        Controls.ButtonGroup { buttons: [lightItem, darkItem] }
        Controls.ButtonGroup { buttons: [standardItem, pureBlackItem] }
        Controls.MenuItem {
            id: lightItem
            text: Translation.tr("Light")
            checkable: true
            checked: !Appearance.m3colors.darkmode
            onTriggered: MaterialThemeLoader.setMode("light")
        }
        Controls.MenuItem {
            id: darkItem
            text: Translation.tr("Dark")
            checkable: true
            checked: Appearance.m3colors.darkmode
            onTriggered: MaterialThemeLoader.setMode("dark")
        }
        Controls.MenuSeparator {
            visible: Appearance.m3colors.darkmode
            height: visible ? implicitHeight : 0
        }
        Controls.MenuItem {
            text: Translation.tr("Dark style")
            enabled: false
            visible: Appearance.m3colors.darkmode
            height: visible ? implicitHeight : 0
        }
        Controls.MenuItem {
            id: standardItem
            text: Translation.tr("Standard")
            visible: Appearance.m3colors.darkmode
            height: visible ? implicitHeight : 0
            checkable: true
            checked: Config.options.appearance.darkStyle === "standard"
            onTriggered: MaterialThemeLoader.setDarkStyle("standard")
        }
        Controls.MenuItem {
            id: pureBlackItem
            text: Translation.tr("Pure black")
            visible: Appearance.m3colors.darkmode
            height: visible ? implicitHeight : 0
            checkable: true
            checked: Config.options.appearance.darkStyle === "pure-black"
            onTriggered: MaterialThemeLoader.setDarkStyle("pure-black")
        }
    }
}
