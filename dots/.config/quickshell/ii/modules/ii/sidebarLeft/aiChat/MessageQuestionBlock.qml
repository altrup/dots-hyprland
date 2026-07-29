pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * Renders an AskUserQuestion command fence as one box for the whole question set:
 * a command-block style title bar, then per question its text, option pills and
 * a free-text pill, and a Submit/Dismiss pair modeled after command
 * approval. Submit sends one permission response; questions with no selection
 * are skipped. Dismiss denies the request. The fence body is the tool's JSON
 * input; once submitted it is rewritten to {questions, answers} with an
 * :answered flag and renders statically.
 */
ColumnLayout {
    id: root
    property var segmentContent: ({})
    property var segmentLang: ""
    property var messageData: {}
    property bool isPendingCommand: false

    property bool submitted: (segmentLang ?? "").split(":").includes("answered")
    property bool dismissed: (segmentLang ?? "").split(":").includes("denied")
    // Parsed tolerantly while the tool input streams, so the box renders progressively;
    // the last good parse is kept when a prefix is momentarily unparseable
    property var parsed: null
    property var questions: parsed?.questions ?? []
    property bool interactive: isPendingCommand && (messageData?.functionPending ?? false) && !submitted && !dismissed
    // While the tool input is still streaming (before the permission handshake), the
    // controls render disabled so the box has its final geometry from the start
    property bool streamingPreview: !submitted && !dismissed && !interactive && !(messageData?.done ?? true)
    onSegmentContentChanged: reparse()
    Component.onCompleted: reparse()

    function reparse() {
        const result = parsePartialJson(String(segmentContent ?? ""));
        if (result !== null) parsed = result;
    }

    // Closes open strings and brackets of truncated JSON; null means cut mid-escape
    function closeJson(s) {
        let stack = [];
        let inStr = false;
        for (let i = 0; i < s.length; i++) {
            const c = s[i];
            if (inStr) {
                if (c === '\\') {
                    if (i + 1 >= s.length) return null;
                    i++;
                    continue;
                }
                if (c === '"') inStr = false;
                continue;
            }
            if (c === '"') inStr = true;
            else if (c === '{' || c === '[') stack.push(c);
            else if (c === '}' || c === ']') stack.pop();
        }
        let out = s;
        if (inStr) out += '"';
        out = out.replace(/,\s*$/, "");
        for (let i = stack.length - 1; i >= 0; i--) {
            out += stack[i] === '{' ? '}' : ']';
        }
        return out;
    }

    // Chops back past dangling keys/colons/partial literals until a close succeeds
    function parsePartialJson(s) {
        for (let end = s.length; end > 0 && end > s.length - 64; end--) {
            const closed = closeJson(s.slice(0, end));
            if (closed === null) continue;
            try { return JSON.parse(closed); } catch (e) {}
        }
        return null;
    }

    function chosenLabels(question) {
        if (root.interactive) return Ai.questionSelections[question] ?? [];
        const answer = root.parsed?.answers?.[question];
        return typeof answer === "string" ? answer.split(", ") : [];
    }

    // Committed answer parts that match no option label (free-text answers)
    function freeTextOf(question, options) {
        const labels = (options ?? []).map(opt => opt.label);
        return chosenLabels(question).filter(part => !labels.includes(part)).join(", ");
    }

    spacing: 2

    // Animated slot for the multiSelect checkmark: its width changes continuously,
    // so the pill and text stay in step instead of the icon popping in a single frame
    component CheckSlot: Item {
        id: slot
        required property bool checked
        implicitHeight: checkIcon.implicitHeight
        implicitWidth: checked ? checkIcon.implicitWidth + 4 : 0
        clip: true
        Behavior on implicitWidth {
            animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
        }
        MaterialSymbol {
            id: checkIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnPrimary
            text: "check"
            opacity: slot.checked ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    StyledText { // Input still streaming, nothing parseable yet
        visible: root.parsed === null
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
        text: Translation.tr("Preparing question...")
    }

    Rectangle { // Title bar, mirrors the command block header
        visible: root.parsed !== null
        Layout.fillWidth: true
        topLeftRadius: Appearance.rounding.small
        topRightRadius: Appearance.rounding.small
        bottomLeftRadius: Appearance.rounding.unsharpen
        bottomRightRadius: Appearance.rounding.unsharpen
        color: Appearance.colors.colSurfaceContainerHighest
        implicitHeight: titleRowLayout.implicitHeight + 10 * 2

        RowLayout {
            id: titleRowLayout
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 13
            spacing: 6

            MaterialSymbol {
                color: Appearance.colors.colOnLayer2
                text: "question_exchange"
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer2
                text: root.questions.length > 1 ? Translation.tr("Questions") : Translation.tr("Question")
            }
            Rectangle {
                visible: root.dismissed
                implicitWidth: 4
                implicitHeight: 4
                radius: implicitWidth / 2
                color: Appearance.colors.colOnLayer1Inactive
            }
            StyledText {
                visible: root.dismissed
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colError
                text: Translation.tr("dismissed")
            }
        }
    }

    Rectangle { // Questions, option pills, and the Submit/Dismiss pair
        visible: root.parsed !== null
        Layout.fillWidth: true
        topLeftRadius: Appearance.rounding.unsharpen
        topRightRadius: Appearance.rounding.unsharpen
        bottomLeftRadius: Appearance.rounding.small
        bottomRightRadius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        implicitHeight: questionContentColumn.implicitHeight + 10 * 2

        MouseArea { // Click on box dead space to unfocus the text pill
            anchors.fill: parent
            onPressed: root.forceActiveFocus()
        }

        ColumnLayout {
            id: questionContentColumn
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            Repeater {
                model: ScriptModel {
                    values: root.questions
                }
                delegate: ColumnLayout { // One section per question
                    id: questionSection
                    required property var modelData
                    required property int index
                    property string question: modelData.question ?? ""
                    property bool multiSelect: modelData.multiSelect ?? false

                    Layout.fillWidth: true
                    Layout.topMargin: index > 0 ? 6 : 0
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colOnLayer1
                        text: questionSection.question
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: ScriptModel {
                                values: questionSection.modelData.options ?? []
                            }
                            delegate: GroupButton { // Styled like the command suggestion pills
                                id: optionPill
                                required property var modelData
                                property string label: modelData.label ?? ""
                                enabled: root.interactive
                                bounce: false
                                // The checkmark slot animates its own width; the pill follows it
                                // rigidly so the size change is animated exactly once
                                enableImplicitWidthAnimation: false
                                buttonRadius: optionPill.down ? Appearance.rounding.verysmall : Appearance.rounding.small
                                horizontalPadding: 8
                                verticalPadding: 6
                                toggled: root.chosenLabels(questionSection.question).includes(label)
                                // colBackground carries the toggled fill so the chosen pill
                                // stays highlighted in the submitted (disabled) transcript
                                colBackground: toggled ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                                contentItem: RowLayout {
                                    spacing: 0
                                    CheckSlot {
                                        checked: questionSection.multiSelect && optionPill.toggled
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        horizontalAlignment: Text.AlignHCenter
                                        color: optionPill.toggled ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                                        text: optionPill.label
                                    }
                                }
                                onClicked: {
                                    if (questionSection.multiSelect) {
                                        Ai.toggleQuestionOption(questionSection.question, optionPill.label);
                                    } else {
                                        Ai.setQuestionSelection(questionSection.question,
                                            optionPill.toggled ? [] : [optionPill.label]);
                                    }
                                }
                                StyledToolTip {
                                    text: optionPill.modelData.description ?? ""
                                }
                            }
                        }

                        Rectangle { // Free-text pill, expands with its content
                            id: freeTextPill
                            // Renders selected exactly like an option pill: lit when its
                            // text is among the question's current picks
                            property bool committed: freeTextInput.text.trim().length > 0
                                && root.chosenLabels(questionSection.question).includes(freeTextInput.text.trim())
                            // In the submitted transcript the pill stays, showing the custom answer
                            property string historyFreeText: root.interactive || root.streamingPreview
                                ? "" : root.freeTextOf(questionSection.question, questionSection.modelData.options ?? [])
                            visible: root.interactive || root.streamingPreview || historyFreeText.length > 0
                            radius: Appearance.rounding.small
                            color: committed ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                            border.width: freeTextInput.activeFocus && !committed ? 1 : 0
                            border.color: Appearance.colors.colPrimary
                            implicitHeight: freeTextInput.implicitHeight + 6 * 2
                            // Empty keeps room for the placeholder; typed text sizes the pill exactly
                            implicitWidth: freeTextInput.text.length > 0
                                ? freeTextInput.contentWidth + 8 * 2 + freeCheckSlot.width
                                : 120

                            CheckSlot {
                                id: freeCheckSlot
                                checked: questionSection.multiSelect && freeTextPill.committed
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextInput {
                                id: freeTextInput
                                enabled: root.interactive
                                // Interactive typing replaces this binding; for a loaded
                                // transcript it fills in the submitted custom answer
                                text: freeTextPill.historyFreeText
                                anchors.fill: parent
                                anchors.leftMargin: 8 + freeCheckSlot.width
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: freeTextPill.committed ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                                selectByMouse: true
                                // Editing only happens uncommitted (focus un-commits), so the
                                // background is always colSecondaryContainer; primary stands out
                                selectedTextColor: Appearance.colors.colOnPrimary
                                selectionColor: Appearance.colors.colPrimary

                                property string placeholder: Translation.tr("Other...")
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: freeTextInput.text.length === 0 && !freeTextInput.activeFocus
                                    font: freeTextInput.font
                                    color: Appearance.colors.colSubtext
                                    text: freeTextInput.placeholder
                                }

                                MouseArea { // Owns the drag so the list view can't steal it and
                                    // scroll mid-selection; drives cursor/selection itself
                                    anchors.fill: parent
                                    enabled: root.interactive
                                    cursorShape: Qt.IBeamCursor
                                    preventStealing: true
                                    onPressed: mouse => {
                                        freeTextInput.forceActiveFocus();
                                        freeTextInput.cursorPosition = freeTextInput.positionAt(mouse.x, mouse.y);
                                    }
                                    onPositionChanged: mouse => {
                                        freeTextInput.moveCursorSelection(freeTextInput.positionAt(mouse.x, mouse.y));
                                    }
                                    onDoubleClicked: freeTextInput.selectWord()
                                }

                                // The one custom entry this pill has contributed; edits replace it
                                property string committedText: ""

                                // Single-select: text becomes the answer. multiSelect: text joins
                                // the picks like a toggled chip
                                function commitFreeText() {
                                    const answer = text.trim();
                                    if (questionSection.multiSelect) {
                                        if (committedText.length > 0 && committedText !== answer
                                                && root.chosenLabels(questionSection.question).includes(committedText)) {
                                            Ai.toggleQuestionOption(questionSection.question, committedText);
                                        }
                                        if (answer.length > 0
                                                && !root.chosenLabels(questionSection.question).includes(answer)) {
                                            Ai.toggleQuestionOption(questionSection.question, answer);
                                        }
                                        committedText = answer;
                                    } else if (answer.length > 0) {
                                        // Don't clobber an option picked while this field kept focus
                                        const current = root.chosenLabels(questionSection.question);
                                        if (current.length === 0 || current.includes(committedText)) {
                                            Ai.setQuestionSelection(questionSection.question, [answer]);
                                            committedText = answer;
                                        }
                                    }
                                }

                                // Focus un-commits this pill's entry (single-select: the whole
                                // selection) so it drops back to the typing look; leaving
                                // with text commits — Enter also commits, but isn't required
                                onActiveFocusChanged: {
                                    if (!root.interactive) return;
                                    if (activeFocus) {
                                        if (questionSection.multiSelect) {
                                            if (committedText.length > 0
                                                    && root.chosenLabels(questionSection.question).includes(committedText)) {
                                                Ai.toggleQuestionOption(questionSection.question, committedText);
                                            }
                                        } else {
                                            Ai.setQuestionSelection(questionSection.question, []);
                                        }
                                    } else {
                                        commitFreeText();
                                    }
                                }

                                // Blur commits, so Enter just drops focus
                                onAccepted: root.forceActiveFocus()
                            }
                        }

                    }
                }
            }

            RowLayout { // Submit/Dismiss pair, mirrors command approval
                visible: root.interactive || root.streamingPreview
                Layout.fillWidth: true
                Layout.topMargin: 2

                Item { Layout.fillWidth: true }
                ButtonGroup {
                    GroupButton {
                        enabled: root.interactive
                        // The default hover (colLayer1Hover) is invisible on this
                        // box's colLayer2 background
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colBackgroundActive: Appearance.colors.colLayer2Active
                        contentItem: StyledText {
                            text: Translation.tr("Dismiss")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                        }
                        onClicked: Ai.dismissQuestions(root.messageData)
                    }
                    GroupButton {
                        enabled: root.interactive
                        toggled: true
                        // colBackground carries the fill so it survives the disabled state
                        colBackground: Appearance.colors.colPrimary
                        contentItem: StyledText {
                            text: Translation.tr("Submit")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimary
                        }
                        onClicked: {
                            // Commit free text still sitting in a focused pill first
                            root.forceActiveFocus();
                            Ai.submitQuestions(root.messageData);
                        }
                    }
                }
            }
        }
    }
}
