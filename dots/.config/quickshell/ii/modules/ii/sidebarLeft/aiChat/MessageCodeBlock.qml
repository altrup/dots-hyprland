pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import org.kde.syntaxhighlighting

ColumnLayout {
    id: root
    // These are needed on the parent loader
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var segmentLang: "txt"
    property var messageData: {}
    property bool isPendingCommand: false
    // Command fences carry tool name then state: command:Bash:running, command:Read:done...
    // Either segment can be absent on fences written outside the CLI path
    property var commandFlags: (segmentLang ?? "").split(":").slice(1).filter(s => s.length > 0)
    property bool isCommandRequest: (segmentLang ?? "").split(":")[0] === "command"
    property string commandState: isCommandRequest
        ? (commandFlags.filter(s => StringUtils.commandFenceStates.includes(s)).pop() ?? "")
        : ""
    property string commandToolName: isCommandRequest
        ? (commandFlags.find(s => !StringUtils.commandFenceStates.includes(s)) ?? "Bash")
        : ""
    // Unfinished states keep their token for good, so being live is checked against the message
    // rather than read off the fence. What is left over reads as denied: the command never ran
    readonly property string state: {
        if (commandState === "streaming") {
            return (messageData?.done ?? true) ? "denied" : "streaming";
        }
        if (commandState === "pending"
                && !(isPendingCommand && (messageData?.functionPending ?? false))) {
            return "denied";
        }
        return commandState;
    }
    // Spelled out because the translation extractor only sees literal keys. Streaming shows
    // nothing: there is no state to report yet, and the message has its own loading indicator
    readonly property var commandStateLabels: ({
        "streaming": "",
        "pending": Translation.tr("pending"),
        "running": Translation.tr("running"),
        "done": Translation.tr("done"),
        "failed": Translation.tr("failed"),
        // Labelled for the Reject button that produces it, as the rest of the copy already is
        "denied": Translation.tr("rejected"),
        "answered": Translation.tr("answered"),
    })
    readonly property string stateLabel: commandStateLabels[state] ?? state
    // Bash runs shell commands; every other tool takes JSON input
    property var displayLang: isCommandRequest
        ? (commandToolName === "Bash" ? "bash" : "json")
        : segmentLang

    property real codeBlockBackgroundRounding: Appearance.rounding.small
    property real codeBlockHeaderPadding: 3
    property real codeBlockComponentSpacing: 2

    spacing: codeBlockComponentSpacing

    Rectangle { // Code background
        Layout.fillWidth: true
        topLeftRadius: codeBlockBackgroundRounding
        topRightRadius: codeBlockBackgroundRounding
        bottomLeftRadius: Appearance.rounding.unsharpen
        bottomRightRadius: Appearance.rounding.unsharpen
        color: Appearance.colors.colSurfaceContainerHighest
        implicitHeight: codeBlockTitleBarRowLayout.implicitHeight + codeBlockHeaderPadding * 2

        RowLayout { // Language and buttons
            id: codeBlockTitleBarRowLayout
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: codeBlockHeaderPadding
            anchors.rightMargin: codeBlockHeaderPadding
            spacing: 5

            RowLayout {
                Layout.alignment: Qt.AlignLeft
                Layout.topMargin: 7
                Layout.bottomMargin: 7
                Layout.leftMargin: 10
                spacing: 6

                StyledText {
                    id: codeBlockLanguage
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                    text: root.isCommandRequest
                        ? root.commandToolName
                        : (root.displayLang ? Repository.definitionForName(root.displayLang).name : "plain")
                }
                Rectangle {
                    visible: root.stateLabel.length > 0
                    implicitWidth: 4
                    implicitHeight: 4
                    radius: implicitWidth / 2
                    color: Appearance.colors.colOnLayer1Inactive
                }
                StyledText {
                    visible: root.stateLabel.length > 0
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: ["denied", "failed"].includes(root.state)
                        ? Appearance.colors.colTertiary
                        : Appearance.colors.colSubtext
                    text: root.stateLabel
                }
            }

            Item { Layout.fillWidth: true }

            ButtonGroup {
                AiMessageControlButton {
                    id: copyCodeButton
                    buttonIcon: activated ? "inventory" : "content_copy"

                    onClicked: {
                        Quickshell.clipboardText = segmentContent
                        copyCodeButton.activated = true
                        copyIconTimer.restart()
                    }

                    Timer {
                        id: copyIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            copyCodeButton.activated = false
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Copy code")
                    }
                }
                AiMessageControlButton {
                    id: saveCodeButton
                    buttonIcon: activated ? "check" : "save"

                    onClicked: {
                        const downloadPath = FileUtils.trimFileProtocol(Directories.downloads)
                        Quickshell.execDetached(["bash", "-c",
                            `echo '${StringUtils.shellSingleQuoteEscape(segmentContent)}' > '${downloadPath}/code.${root.displayLang || "txt"}'`
                        ])
                        Quickshell.execDetached(["notify-send",
                            Translation.tr("Code saved to file"),
                            Translation.tr("Saved to %1").arg(`${downloadPath}/code.${root.displayLang || "txt"}`),
                            "-a", "Shell"
                        ])
                        saveCodeButton.activated = true
                        saveIconTimer.restart()
                    }

                    Timer {
                        id: saveIconTimer
                        interval: 1500
                        repeat: false
                        onTriggered: {
                            saveCodeButton.activated = false
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Save to Downloads")
                    }
                }
            }
        }
    }

    RowLayout { // Line numbers and code
        spacing: codeBlockComponentSpacing

        Rectangle { // Line numbers
            implicitWidth: 40
            Layout.fillHeight: true
            Layout.fillWidth: false
            topLeftRadius: Appearance.rounding.unsharpen
            bottomLeftRadius: codeBlockBackgroundRounding
            topRightRadius: Appearance.rounding.unsharpen
            bottomRightRadius: Appearance.rounding.unsharpen
            color: Appearance.colors.colLayer2

            Item {
                anchors.fill: parent
                anchors.rightMargin: 5

                Repeater {
                    // Char offset of each logical line's start; wrapped lines share one number
                    model: {
                        const lines = codeTextArea.text.split("\n");
                        let offset = 0;
                        return lines.map(line => {
                            const start = offset;
                            offset += line.length + 1;
                            return start;
                        });
                    }
                    Text {
                        required property int index
                        required property var modelData
                        anchors.right: parent.right
                        // Width referenced so rewrapping recomputes each line's y
                        y: (codeTextArea.width, codeTextArea.positionToRectangle(modelData).y)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignRight
                        text: index + 1
                    }
                }
            }
        }

        Rectangle { // Code background
            Layout.fillWidth: true
            topLeftRadius: Appearance.rounding.unsharpen
            bottomLeftRadius: Appearance.rounding.unsharpen
            topRightRadius: Appearance.rounding.unsharpen
            bottomRightRadius: codeBlockBackgroundRounding
            color: Appearance.colors.colLayer2
            implicitHeight: codeColumnLayout.implicitHeight

            ColumnLayout {
                id: codeColumnLayout
                anchors.fill: parent
                spacing: 0
                TextArea { // Code
                    id: codeTextArea
                    Layout.fillWidth: true
                    readOnly: !editing
                    selectByMouse: enableMouseSelection || editing
                    renderType: Text.NativeRendering
                    font.family: Appearance.font.family.monospace
                    font.hintingPreference: Font.PreferNoHinting // Prevent weird bold text
                    font.pixelSize: Appearance.font.pixelSize.small
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    wrapMode: TextEdit.Wrap
                    color: messageData.thinking ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1

                    text: segmentContent
                    onTextChanged: {
                        segmentContent = text
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            // Insert 4 spaces at cursor
                            const cursor = codeTextArea.cursorPosition;
                            codeTextArea.insert(cursor, "    ");
                            codeTextArea.cursorPosition = cursor + 4;
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_C) && event.modifiers == Qt.ControlModifier) {
                            codeTextArea.copy();
                            event.accepted = true;
                        }
                    }

                    SyntaxHighlighter {
                        id: highlighter
                        textEdit: codeTextArea
                        repository: Repository
                        definition: Repository.definitionForName(root.displayLang || "plaintext")
                        theme: Appearance.syntaxHighlightingTheme
                    }
                }
                Loader {
                    active: root.isCommandRequest && root.isPendingCommand && root.messageData.functionPending
                    visible: active
                    Layout.fillWidth: true
                    Layout.margins: 6
                    Layout.topMargin: 0
                    sourceComponent: RowLayout {
                        Item { Layout.fillWidth: true }
                        ButtonGroup {
                            GroupButton {
                                // The default hover (colLayer1Hover) is invisible on the
                                // block's colLayer2 background
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colBackgroundActive: Appearance.colors.colLayer2Active
                                contentItem: StyledText {
                                    text: Translation.tr("Reject")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                }
                                onClicked: Ai.rejectCommand(root.messageData)
                            }
                            GroupButton {
                                toggled: true
                                contentItem: StyledText {
                                    text: Translation.tr("Approve")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnPrimary
                                }
                                onClicked: Ai.approveCommand(root.messageData)
                            }
                        }
                    }
                }
            }

        }
    }
}