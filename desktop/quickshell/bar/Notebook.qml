pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../shared" as Shared

PanelWindow {
    id: root
    property bool opened: false
    property bool pinned: true
    property string page: "notes"
    property bool editing: false
    property bool settings: false
    property var targetScreen: Shared.Screens.main
    screen: targetScreen || Shared.Screens.main
    visible: (opened || conceal.running) && (targetScreen !== null || Shared.Screens.main !== null)
    anchors { top: true; bottom: true; left: true }
    margins { top: PanelStyle.barHeight + PanelStyle.outerGap + 8; bottom: PanelStyle.barHeight + PanelStyle.outerGap + 8; left: 8 }
    implicitWidth: Math.min(420, screen ? screen.width - 24 : 420)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-notebook"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onOpenedChanged: {
        NotebookData.opened = opened
        if (!opened) conceal.restart()
    }
    function toggle() {
        if (opened) { opened = false; return }
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        targetScreen = Quickshell.screens.find(s => s.name === focused && s.name !== Shared.Screens.output("edge")) || Shared.Screens.main
        PopupState.close(); opened = true
        if (NotebookData.dirty) editing = true
        Qt.callLater(() => content.forceActiveFocus())
    }
    IpcHandler {
        target: "notebook"
        function toggle(): void { root.toggle() }
        function close(): void { root.opened = false }
        // Meta+Shift+N: the primary selection goes into the open note (or a new one).
        function capture(): void { selection.running = true }
        function meetings(): void { NotebookData.save(false); root.page = "meetings"; root.settings = false; if (!root.opened) root.toggle() }
    }
    Timer { id: conceal; interval: Shared.DesktopStyle.slow }
    property string captureNote: ""
    Timer { id: captureNoteClear; interval: 4000; onTriggered: root.captureNote = "" }
    Connections { target: NotebookData; function onCaptureFailed(message) { root.captureNote = message; captureNoteClear.restart() } }
    Process {
        id: selection
        command: ["wl-paste", "--primary", "--no-newline", "--type", "text/plain;charset=utf-8"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.opened) root.toggle()
                root.page = "notes"; root.settings = false
                if (NotebookData.capture(text.slice(0, 64 * 1024))) {
                    root.editing = true; root.captureNote = "Selection added"; captureNoteClear.restart()
                }
            }
        }
    }
    // Pinned mode leaves other applications usable while the note stays visible.
    Shared.ClickCatcher { active: root.opened && !root.pinned; onClicked: root.opened = false }
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Shared.DesktopStyle.radiusCard
        color: Colors.background
        border.width: 1; border.color: Colors.selection
        opacity: root.opened ? 1 : 0
        transform: Translate { x: root.opened ? 0 : -root.width - 12; Behavior on x { NumberAnimation { duration: Shared.DesktopStyle.slow; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
        FocusScope {
            id: content
            anchors.fill: parent
            Keys.onEscapePressed: root.opened = false
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                RowLayout {
                    UiLabel { text: "\u{F044}"; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(19); color: Colors.accent }
                    UiLabel { text: "Notebook"; font.pixelSize: Shared.DesktopStyle.px(18); font.bold: true; Layout.fillWidth: true }
                    UiButton { text: root.pinned ? "Pinned" : "Pin"; selected: root.pinned; onClicked: root.pinned = !root.pinned }
                    UiButton { glyph: "\u{F00D}"; onClicked: root.opened = false; Accessible.name: "Close notebook" }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [{id:"notes",name:"Notes",icon:"\u{F249}"},{id:"calculate",name:"Calc",icon:"\u{F1EC}"},{id:"time",name:"Time",icon:"\u{F017}"},{id:"meetings",name:"Meet",icon:"\u{F130}"}]
                        UiButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.name; glyph: modelData.icon; selected: root.page === modelData.id
                            onClicked: { NotebookData.save(false); root.page = modelData.id; root.settings = false }
                        }
                    }
                }
                UiLabel { visible: root.captureNote !== ""; text: root.captureNote; color: Colors.muted; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12) }
                UiLabel { visible: NotebookData.error !== ""; text: NotebookData.error; color: Colors.red; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12) }
                Loader {
                    Layout.fillHeight: true; Layout.fillWidth: true; Layout.minimumHeight: 0
                    sourceComponent: root.settings ? settingsPage : root.page === "notes" ? notesPage : root.page === "calculate" ? calculatorPage : root.page === "meetings" ? meetingsPage : timePage
                }
                RowLayout {
                    Layout.fillWidth: true
                    UiLabel { Layout.fillWidth: true; text: root.page === "notes" ? "Obsidian · Quick Notes" : "Private · saved on this device"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
                    UiButton { glyph: "\u{F013}"; selected: root.settings; onClicked: root.settings = !root.settings; Accessible.name: "Notebook settings" }
                }
            }
        }
    }
    Component {
        id: meetingsPage
        NotebookMeetings { visibleNow: root.opened && root.page === "meetings" }
    }
    Component {
        id: settingsPage
        ColumnLayout {
            spacing: 12
            UiLabel { text: "Obsidian vault"; font.bold: true }
            UiLabel { Layout.fillWidth: true; text: "Notes are saved as Markdown in Quick Notes. Obsidian Sync handles the other devices."; wrapMode: Text.Wrap; color: Colors.dim }
            CalendarField { id: vaultPath; Layout.fillWidth: true; text: NotebookData.vault; placeholderText: "~/Projects/k3lmiir-vault-sync" }
            UiButton { text: "Use this vault"; enabled: !NotebookData.dirty && !NotebookData.saving; onClicked: NotebookData.call({op:"vault", path:vaultPath.text}) }
            UiLabel { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Reminders and timers run even with this panel closed. Missed alerts appear after you wake the laptop or sign in again."; color: Colors.dim }
            Item { Layout.fillHeight: true }
        }
    }
    Component {
        id: notesPage
        ColumnLayout {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                CalendarField { Layout.fillWidth: true; visible: !root.editing; placeholderText: "Search notes…"; text: NotebookData.query; onTextEdited: NotebookData.query = text }
                UiButton { text: root.editing ? "All notes" : "New note"; glyph: root.editing ? "\u{F060}" : "\u{F067}"; onClicked: {
                    if (root.editing) { NotebookData.save(false); root.editing = false }
                    else { NotebookData.select("new"); root.editing = true }
                } }
                UiButton { visible: root.editing; glyph: "\u{F0EA}"; enabled: !selection.running; onClicked: selection.running = true; Accessible.name: "Add selected text (Meta+Shift+N)" }
                UiButton { visible: root.editing && !!NotebookData.note.url; glyph: "\u{F08E}"; onClicked: { NotebookData.save(false); Qt.openUrlExternally(NotebookData.note.url) } Accessible.name: "Open in Obsidian" }
            }
            ColumnLayout {
                visible: root.editing
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                CalendarField {
                    id: titleField
                    Layout.fillWidth: true; placeholderText: "Note title"; maximumLength: 180
                    enabled: !NotebookData.loading
                    text: NotebookData.title
                    onTextEdited: NotebookData.edit(text, editor.text)
                }
                // Clickable checklist: toggles "- [ ]" lines through the normal save path,
                // so a note changed elsewhere still ends in the conflict prompt.
                ScrollView {
                    visible: NotebookData.tasks.length > 0
                    Layout.fillWidth: true; Layout.maximumHeight: Shared.DesktopStyle.px(170)
                    Layout.preferredHeight: taskColumn.implicitHeight
                    clip: true; contentWidth: availableWidth
                    ColumnLayout {
                        id: taskColumn
                        width: parent.width; spacing: 2
                        Repeater {
                            model: NotebookData.tasks
                            CheckBox {
                                required property var modelData
                                Layout.fillWidth: true
                                checked: modelData.done
                                enabled: !NotebookData.conflict && !NotebookData.loading
                                text: modelData.text
                                font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(13)
                                font.strikeout: modelData.done
                                onClicked: NotebookData.toggleTask(modelData.line)
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Colors.lightBackground; radius: Shared.DesktopStyle.radiusSmall
                    border.width: 1; border.color: editor.activeFocus ? Colors.accent : Colors.selection
                    ScrollView {
                        id: noteScroll
                        anchors.fill: parent; anchors.margins: 3; clip: true
                        contentWidth: availableWidth
                        TextArea {
                            id: editor
                            height: Math.max(contentHeight + topPadding + bottomPadding, noteScroll.availableHeight)
                            enabled: !NotebookData.loading
                            text: NotebookData.body
                            placeholderText: "Write something…\n\nMarkdown works here:\n- [ ] A small task"
                            textFormat: TextEdit.PlainText
                            wrapMode: TextEdit.Wrap
                            color: Colors.foreground; placeholderTextColor: Colors.muted
                            selectionColor: Colors.selection; selectedTextColor: Colors.foreground
                            font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(14)
                            padding: 12; selectByMouse: true; background: null
                            onTextChanged: { if (activeFocus && text !== NotebookData.body) NotebookData.edit(titleField.text, text) }
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_S && event.modifiers & Qt.ControlModifier) { NotebookData.save(false); event.accepted = true }
                                // Ctrl+Enter toggles the task on the cursor's line.
                                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.modifiers & Qt.ControlModifier) {
                                    const line = text.slice(0, cursorPosition).split("\n").length - 1
                                    const position = cursorPosition
                                    NotebookData.toggleTask(line); cursorPosition = Math.min(position, length)
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
                Connections {
                    target: NotebookData
                    function onNoteLoaded() { titleField.text = NotebookData.title; editor.text = NotebookData.body }
                }
                UiLabel { text: NotebookData.saveState; color: NotebookData.conflict ? Colors.yellow : Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
                RowLayout {
                    visible: NotebookData.conflict
                    UiButton { text: "Save a copy"; onClicked: NotebookData.save(true) }
                    UiButton { text: "Reload original"; enabled: !!NotebookData.note.id; onClicked: NotebookData.reloadNote() }
                }
            }
            ListView {
                visible: !root.editing
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 10
                model: NotebookData.notes
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width; height: noteCard.implicitHeight + 24
                    radius: Shared.DesktopStyle.radiusSmall
                    color: cardMouse.containsMouse ? Colors.selection : Colors.lightBackground
                    border.width: 1; border.color: cardMouse.containsMouse ? Colors.accent : Colors.selection
                    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                    ColumnLayout {
                        id: noteCard; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6
                        UiLabel { Layout.fillWidth: true; text: modelData.title; font.bold: true; elide: Text.ElideRight }
                        UiLabel { Layout.fillWidth: true; text: modelData.preview || "Empty note"; color: Colors.dim; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; font.pixelSize: Shared.DesktopStyle.px(12) }
                        RowLayout {
                            Layout.fillWidth: true
                            UiLabel { text: Qt.formatDateTime(new Date(modelData.modified * 1000), "dd MMM · HH:mm"); color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11); Layout.fillWidth: true }
                            UiLabel { visible: modelData.total > 0; text: modelData.done + "/" + modelData.total; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11) }
                        }
                    }
                    MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { NotebookData.select(modelData.id); root.editing = true } }
                }
                UiLabel { anchors.centerIn: parent; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; visible: !NotebookData.notes.length; text: NotebookData.available ? "A small thought, a checklist, a draft.\nCreate your first quick note." : "Choose your Obsidian vault in Settings."; color: Colors.muted }
            }
        }
    }
    Component {
        id: calculatorPage
        ColumnLayout {
            spacing: 14
            UiLabel { text: "A little room to think"; color: Colors.dim }
            CalendarField { id: expression; Layout.fillWidth: true; placeholderText: "(125 + 75) * 1.21"; text: NotebookData.expression; onTextEdited: NotebookData.expression = text; onAccepted: NotebookData.calculate() }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: answer.implicitHeight + 32
                color: Colors.lightBackground; radius: Shared.DesktopStyle.radiusCard
                UiLabel { id: answer; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 } text: NotebookData.result || "="; font.pixelSize: Shared.DesktopStyle.px(28); color: Colors.accent; wrapMode: Text.WrapAnywhere }
            }
            UiLabel { visible: NotebookData.calcError !== ""; text: NotebookData.calcError; Layout.fillWidth: true; wrapMode: Text.Wrap; color: Colors.red; font.pixelSize: Shared.DesktopStyle.px(12) }
            RowLayout {
                UiButton { text: "Calculate"; glyph: "\u{F1EC}"; selected: true; onClicked: NotebookData.calculate() }
                UiButton { text: "Copy"; enabled: NotebookData.result !== ""; onClicked: NotebookData.call({op:"copy",text:NotebookData.result}) }
            }
            UiLabel { text: "+  −  ×  ÷  %  ^  ·  sqrt()  abs()  pi  e"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                model: NotebookData.history
                delegate: UiButton {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.expression + " = " + modelData.result
                    onClicked: { expression.text = modelData.expression; NotebookData.expression = modelData.expression; NotebookData.result = modelData.result }
                }
            }
        }
    }
    Component { id: timePage; NotebookTime { visibleNow: root.opened && root.page === "time" } }
}
