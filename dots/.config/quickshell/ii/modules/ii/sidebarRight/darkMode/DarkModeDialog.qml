import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

WindowDialog {
    id: root
    backgroundHeight: 360

    WindowDialogTitle {
        text: Translation.tr("Appearance")
    }

    WindowDialogSectionHeader {
        text: Translation.tr("Mode")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    ConfigSelectionArray {
        currentValue: Appearance.m3colors.darkmode ? "dark" : "light"
        onSelected: newValue => MaterialThemeLoader.setMode(newValue)
        options: [
            { value: "light", displayName: Translation.tr("Light") },
            { value: "dark", displayName: Translation.tr("Dark") }
        ]
    }

    ColumnLayout {
        visible: Appearance.m3colors.darkmode
        Layout.fillWidth: true
        spacing: 16

        WindowDialogSectionHeader {
            text: Translation.tr("Dark style")
        }

        WindowDialogSeparator {
            Layout.topMargin: -22
            Layout.leftMargin: 0
            Layout.rightMargin: 0
        }

        ConfigSelectionArray {
            currentValue: Config.options.appearance.darkStyle
            onSelected: newValue => MaterialThemeLoader.setDarkStyle(newValue)
            options: [
                { value: "standard", displayName: Translation.tr("Standard") },
                { value: "pure-black", displayName: Translation.tr("Pure black") }
            ]
        }
    }

    WindowDialogButtonRow {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
