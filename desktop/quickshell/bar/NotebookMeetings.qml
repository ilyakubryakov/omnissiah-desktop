pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    property bool visibleNow: false
    property bool configure: false
    property bool reviewing: false
    property string outputName: ""
    property string micName: ""
    property bool withMic: true
    readonly property var outputs: MeetingsData.devices.filter(d => d.kind === "output")
    readonly property var microphones: MeetingsData.devices.filter(d => d.kind === "mic")
    readonly property var prefs: MeetingsData.settings
    readonly property var active: MeetingsData.active
    spacing: Shared.DesktopStyle.px(10)
    function chosen(nodes, name) { return nodes.find(n => n.name === name) || nodes.find(n => n.default) || nodes[0] || {} }
    onVisibleNowChanged: MeetingsData.opened = visibleNow
    Component.onCompleted: MeetingsData.opened = visibleNow
    Component.onDestruction: MeetingsData.opened = false
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: root.reviewing ? "Review meeting" : "Meeting recorder"; font.bold: true; Layout.fillWidth: true }
        UiButton { text: root.reviewing ? "Back" : root.configure ? "History" : "Setup"; onClicked: { if (root.reviewing) root.reviewing = false; else root.configure = !root.configure } }
    }
    UiLabel { visible: MeetingsData.error !== ""; text: MeetingsData.error; color: Colors.yellow; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12) }
    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: Shared.DesktopStyle.cardSpacing
            ColumnLayout {
                visible: root.configure && !root.reviewing
                Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
                UiLabel { text: "Local speech recognition"; font.bold: true }
                UiComboBox {
                    Layout.fillWidth: true; model: ["Whisper Turbo · best on GPU · 574 MB", "Whisper Base · laptop CPU · 148 MB"]
                    currentIndex: root.prefs.model === "base" ? 1 : 0
                    onActivated: MeetingsData.setting("model", currentIndex === 1 ? "base" : "turbo")
                }
                UiLabel { text: MeetingsData.data.models[root.prefs.model] ? "Model verified and ready offline" : "Download the model once before processing"; Layout.fillWidth: true; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
                UiButton {
                    text: MeetingsData.data.download.state === "downloading" ? "Downloading · " + MeetingsData.data.download.progress + "%" : "Download model"
                    enabled: MeetingsData.data.download.state !== "downloading" && !MeetingsData.busy
                    onClicked: MeetingsData.call({op:"download", model:root.prefs.model})
                }
                UiLabel { visible: MeetingsData.data.download.state === "error"; text: MeetingsData.data.download.message || ""; Layout.fillWidth: true; color: Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12) }
                UiLabel { visible: !MeetingsData.data.engine; text: "Whisper is not installed yet."; color: Colors.yellow }
                UiComboBox {
                    Layout.fillWidth: true; model: ["Detect English / Russian automatically", "English", "Russian"]
                    currentIndex: ["auto", "en", "ru"].indexOf(root.prefs.language)
                    onActivated: MeetingsData.setting("language", ["auto", "en", "ru"][currentIndex])
                }
                UiLabel { text: "Notes assistant"; font.bold: true }
                UiComboBox {
                    Layout.fillWidth: true; model: ["Claude · Haiku", "Codex · account default model", "Transcript only · fully local"]
                    currentIndex: ["claude", "codex", "none"].indexOf(root.prefs.provider)
                    onActivated: MeetingsData.setting("provider", ["claude", "codex", "none"][currentIndex])
                }
                UiLabel { Layout.fillWidth: true; text: "Only the transcript goes to your signed-in assistant. Audio stays on this device. Notes and tasks are drafts for review. Retrying uses these settings; existing exported notes stay unchanged."; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
                UiButton { text: root.prefs.translate ? "Russian translation: on" : "Russian translation: off"; selected: !!root.prefs.translate; enabled: root.prefs.provider !== "none"; onClicked: MeetingsData.setting("translate", !root.prefs.translate) }
                UiButton { text: root.prefs.autosave ? "Save draft to Obsidian: on" : "Save draft to Obsidian: off"; selected: !!root.prefs.autosave; onClicked: MeetingsData.setting("autosave", !root.prefs.autosave) }
                UiLabel { text: "Meeting folder inside your vault"; font.bold: true }
                CalendarField { id: folder; Layout.fillWidth: true; text: root.prefs.folder || ""; placeholderText: "Quick Notes/Meetings" }
                UiButton { text: "Save folder"; onClicked: MeetingsData.setting("folder", folder.text) }
                NotebookDictation { Layout.fillWidth: true; visibleNow: root.visibleNow && root.configure && !root.reviewing }
            }
            ColumnLayout {
                visible: !root.configure && !root.reviewing
                Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
                CalendarField { id: title; Layout.fillWidth: true; placeholderText: "Meeting title (optional)"; maximumLength: 180; enabled: !root.active }
                UiComboBox {
                    Layout.fillWidth: true; enabled: !root.active
                    model: root.outputs; textRole: "label"
                    currentIndex: root.outputs.findIndex(n => n.name === root.chosen(root.outputs, root.outputName).name)
                    onActivated: root.outputName = root.outputs[currentIndex].name
                }
                RowLayout {
                    Layout.fillWidth: true
                    UiButton { text: "Microphone"; selected: root.withMic; enabled: !root.active; onClicked: root.withMic = !root.withMic }
                    UiComboBox {
                        Layout.fillWidth: true; enabled: !root.active && root.withMic
                        model: root.microphones; textRole: "label"
                        currentIndex: root.microphones.findIndex(n => n.name === root.chosen(root.microphones, root.micName).name)
                        onActivated: root.micName = root.microphones[currentIndex].name
                    }
                }
                UiLabel { text: "Records the selected output and your microphone separately. Use headphones to avoid recording the speakers twice."; Layout.fillWidth: true; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
                Rectangle {
                    visible: !!root.active; Layout.fillWidth: true; implicitHeight: captureInfo.implicitHeight + Shared.DesktopStyle.px(24)
                    color: Colors.lightBackground; radius: Shared.DesktopStyle.radiusSmall; border.color: Colors.accent; border.width: 1
                    ColumnLayout {
                        id: captureInfo; anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.px(12) }
                        UiLabel { text: (root.active?.state === "paused" ? "Paused · " : "Recording · ") + MeetingsData.clock(root.active?.elapsed); color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(24); Layout.fillWidth: true }
                        Repeater {
                            model: ["output", "mic"]
                            RowLayout {
                                required property string modelData
                                visible: modelData === "output" || !!root.active?.sources?.mic
                                Layout.fillWidth: true
                                UiLabel { text: modelData === "output" ? "Meeting" : "You"; Layout.preferredWidth: Shared.DesktopStyle.px(64); font.pixelSize: Shared.DesktopStyle.px(12) }
                                Rectangle {
                                    Layout.fillWidth: true; height: Shared.DesktopStyle.px(5); radius: Shared.DesktopStyle.px(2); color: Colors.selection
                                    Rectangle { width: parent.width * (root.active?.levels?.[modelData] || 0); height: parent.height; radius: Shared.DesktopStyle.px(2); color: Colors.accent; Behavior on width { NumberAnimation { duration: 200 } } }
                                }
                            }
                        }
                        UiLabel { text: "You can close this drawer. Recording will continue."; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    UiButton {
                        text: !root.active ? "Record" : root.active.state === "paused" ? "Resume" : "Pause"
                        glyph: root.active?.state === "recording" ? "\u{F04C}" : "\u{F111}"
                        selected: true; enabled: !MeetingsData.busy && root.outputs.length > 0
                        onClicked: {
                            if (root.active) MeetingsData.call({op:root.active.state === "paused" ? "resume" : "pause", id:root.active.id})
                            else MeetingsData.call({op:"start", title:title.text, output:root.chosen(root.outputs, root.outputName).name, mic:root.withMic ? root.chosen(root.microphones, root.micName).name : ""})
                        }
                    }
                    UiButton { visible: !!root.active; text: "Stop & process"; enabled: !MeetingsData.busy; onClicked: MeetingsData.call({op:"stop", id:root.active.id}) }
                }
                UiLabel { text: "Recent recordings"; font.bold: true; Layout.topMargin: Shared.DesktopStyle.spaceUnit * 2 }
                UiLabel { visible: MeetingsData.history.length === 0; text: "Your recordings, transcripts and notes will appear here."; Layout.fillWidth: true; color: Colors.dim }
                Repeater {
                    model: MeetingsData.history
                    Rectangle {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: details.implicitHeight + Shared.DesktopStyle.px(24)
                        radius: Shared.DesktopStyle.radiusSmall; color: Colors.lightBackground
                        ColumnLayout {
                            id: details; anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.px(12) }
                            spacing: Shared.DesktopStyle.spaceUnit * 2
                            UiLabel { text: card.modelData.title; font.bold: true; Layout.fillWidth: true }
                            UiLabel { text: card.modelData.state + " · " + MeetingsData.clock(card.modelData.duration) + (card.modelData.progress ? "\n" + card.modelData.progress : ""); color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
                            UiLabel { visible: !!card.modelData.error; text: card.modelData.error || ""; color: Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
                            Flow {
                                Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(6)
                                UiButton { text: "Review"; visible: ["ready", "interrupted"].includes(card.modelData.state); onClicked: { MeetingsData.detail = ({}); MeetingsData.call({op:"detail", id:card.modelData.id}); root.reviewing = true } }
                                UiButton { text: "Retry"; visible: ["ready", "interrupted"].includes(card.modelData.state); onClicked: MeetingsData.call({op:"retry", id:card.modelData.id}) }
                                UiButton { text: "Cancel"; visible: ["queued", "transcribing", "summarizing"].includes(card.modelData.state); onClicked: MeetingsData.call({op:"cancel", id:card.modelData.id}) }
                                UiButton { text: "Files"; onClicked: Qt.openUrlExternally(card.modelData.url) }
                                UiButton {
                                    id: deleteButton
                                    property bool armed: false
                                    text: armed ? "Delete recording?" : "Delete"; glyph: "\u{F0A7A}"
                                    visible: !["queued", "transcribing", "summarizing"].includes(card.modelData.state)
                                    enabled: !MeetingsData.busy
                                    onClicked: { if (armed) MeetingsData.call({op:"delete", id:card.modelData.id}); else { armed = true; disarm.restart() } }
                                    Timer { id: disarm; interval: 4000; onTriggered: deleteButton.armed = false }
                                }
                                UiButton { text: "Open note"; visible: !!card.modelData.noteUrl; onClicked: Qt.openUrlExternally(card.modelData.noteUrl) }
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                visible: root.reviewing; Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
                UiLabel { text: MeetingsData.detail.title || "Loading…"; font.bold: true; Layout.fillWidth: true }
                UiLabel { text: MeetingsData.detail.summary?.summary || "Original transcript"; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(13) }
                Repeater {
                    model: MeetingsData.detail.summary?.decisions || []
                    UiLabel { required property string modelData; text: "• " + modelData; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(13) }
                }
                Repeater {
                    model: MeetingsData.detail.summary?.tasks || []
                    UiLabel { required property var modelData; text: "☐ " + modelData.text + (modelData.owner ? " · " + modelData.owner : "") + (modelData.due ? " · " + modelData.due : "") + "\n“" + modelData.evidence + "”"; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12); color: Colors.dim }
                }
                UiLabel { visible: !!MeetingsData.detail.summary?.translation; text: MeetingsData.detail.summary?.translation || ""; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(13) }
                RowLayout {
                    UiButton { text: "Save to Obsidian"; enabled: !!MeetingsData.detail.transcript && !MeetingsData.busy; onClicked: MeetingsData.call({op:"publish", id:MeetingsData.detail.id}) }
                    UiButton { text: "Tasks note"; enabled: (MeetingsData.detail.summary?.tasks?.length || 0) > 0 && !MeetingsData.busy; onClicked: MeetingsData.call({op:"tasks", id:MeetingsData.detail.id}) }
                }
                UiLabel { text: "Transcript · timestamps from recording start"; font.bold: true; Layout.fillWidth: true }
                TextEdit { text: MeetingsData.detail.transcript || "No transcript yet. Check the error and retry."; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; color: Colors.foreground; font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(12); textFormat: TextEdit.PlainText; Layout.fillWidth: true; Layout.preferredHeight: contentHeight }
            }
        }
    }
}
