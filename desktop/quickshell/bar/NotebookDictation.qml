pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    property bool visibleNow: false
    readonly property var prefs: DictationData.settings
    spacing: 10
    onVisibleNowChanged: if (visibleNow) DictationData.call({op:"devices"})
    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.selection; Layout.topMargin: 10 }
    UiLabel { text: "Hold-to-talk dictation"; font.bold: true }
    UiLabel { text: "Hold Right Alt, speak, then release it. Text goes into the focused field. Win+Alt+Esc cancels. Up to 90 seconds per phrase. No Enter is sent and your clipboard stays unchanged."; Layout.fillWidth: true; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
    UiComboBox {
        Layout.fillWidth: true; model: ["Whisper Base · laptop CPU", "Whisper Turbo · best on GPU"]
        currentIndex: root.prefs.model === "turbo" ? 1 : 0
        onActivated: DictationData.setting("model", currentIndex === 1 ? "turbo" : "base")
    }
    UiComboBox {
        Layout.fillWidth: true; model: ["Detect English / Russian", "English", "Russian"]
        currentIndex: ["auto", "en", "ru"].indexOf(root.prefs.language)
        onActivated: DictationData.setting("language", ["auto", "en", "ru"][currentIndex])
    }
    UiComboBox {
        id: mic
        Layout.fillWidth: true; textRole: "label"
        model: [{name:"default",label:"Follow the default microphone"}].concat(DictationData.devices)
        currentIndex: Math.max(0, model.findIndex(n => n.name === DictationData.data.microphone))
        onActivated: DictationData.call({op:"microphone",name:model[currentIndex].name})
    }
    UiLabel { text: "Vocabulary"; font.bold: true }
    CalendarField {
        id: vocabulary
        Layout.fillWidth: true; maximumLength: 600
        text: root.prefs.vocabulary || ""
        placeholderText: "Names and terms, comma separated: Balancy, Quickshell, REAPER"
        onEditingFinished: if (text !== (root.prefs.vocabulary || "")) DictationData.setting("vocabulary", text)
    }
    UiLabel { text: "Improves spelling of names and jargon in dictation and meeting transcripts. Stays on this computer."; Layout.fillWidth: true; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
    UiButton {
        text: DictationData.data.download.state === "downloading" ? "Downloading models…" : "Download / verify models"
        enabled: DictationData.data.download.state !== "downloading"
        onClicked: DictationData.call({op:"download"})
    }
    UiLabel { text: DictationData.data.ready ? "Whisper + speech filter ready offline. No AI service is used for dictation." : DictationData.data.download.message || "Download the speech filter before the first dictation."; Layout.fillWidth: true; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(12) }
    UiLabel { visible: DictationData.error !== ""; text: DictationData.error; Layout.fillWidth: true; color: Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12) }
}
