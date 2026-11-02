pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: root
    spacing: 16
    property string selectedMode: "work"
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var bindings: ShellPrefs.devices[selectedMode] || ({})
    readonly property var definitions: [
        {id: "work", title: "Work", glyph: "\uf0b1", detail: "Notifications on. Your normal night light and audio defaults."},
        {id: "call", title: "Call", glyph: "\uf095", detail: "Do not disturb. Choose a microphone and output for meetings."},
        {id: "game", title: "Game", glyph: "\uf11b", detail: "Do not disturb and night light off. No changes to your window layout."},
        {id: "music", title: "Recording", glyph: "\uf001", detail: "Do not disturb and the low-latency Music audio profile."}
    ]
    PwObjectTracker { objects: root.nodes }
    SettingsCard {
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: "Current: " + (DesktopData.controls.mode || "normal"); font.pixelSize: 18; Layout.fillWidth: true }
            UiButton { text: "Restore Normal"; enabled: !DesktopData.busy && DesktopData.controls.mode !== "normal"; onClicked: DesktopData.act("mode", ["normal"]) }
        }
        UiLabel { Layout.fillWidth: true; text: "Normal restores the settings from before the mode. Changes you make manually while a mode is active are kept."; color: Colors.muted; wrapMode: Text.WordWrap }
    }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: root.definitions
            UiButton { required property var modelData; text: modelData.title; glyph: modelData.glyph; selected: root.selectedMode === modelData.id; onClicked: root.selectedMode = modelData.id }
        }
    }
    SettingsCard {
        UiLabel { text: root.definitions.find(d => d.id === root.selectedMode).detail; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Repeater {
            model: ["sink", "source"]
            ColumnLayout {
                id: deviceRow
                required property string modelData
                readonly property string saved: root.bindings[modelData] || ""
                readonly property var devices: root.nodes.filter(n => n.isSink === (modelData === "sink"))
                readonly property bool missing: saved !== "" && !devices.some(n => n.name === saved)
                readonly property var choices: [{name: "", label: "Use normal default"}].concat(devices.map(n => ({name: n.name, label: n.description || n.name}))).concat(missing ? [{name: saved, label: "Disconnected · " + saved}] : [])
                Layout.fillWidth: true
                UiLabel { text: deviceRow.modelData === "sink" ? "Audio output" : "Microphone"; color: Colors.muted }
                UiComboBox {
                    Layout.fillWidth: true
                    model: deviceRow.choices; textRole: "label"
                    currentIndex: Math.max(0, deviceRow.choices.findIndex(d => d.name === deviceRow.saved))
                    palette.button: Colors.selection; palette.buttonText: Colors.foreground
                    palette.base: Colors.background; palette.text: Colors.foreground
                    palette.highlight: Colors.accent; palette.highlightedText: Colors.background
                    onActivated: index => {
                        const value = Object.assign({mode: root.selectedMode, sink: "", source: ""}, root.bindings)
                        value[deviceRow.modelData] = deviceRow.choices[index].name
                        ShellPrefs.send("devices", value)
                    }
                }
                UiLabel { visible: deviceRow.missing; text: "Connect this device or select another before applying the mode."; color: Colors.yellow; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            }
        }
        UiLabel { text: "Device choices belong to this machine and are not included in portable appearance presets."; color: Colors.muted; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        UiButton { text: "Apply " + root.definitions.find(d => d.id === root.selectedMode).title; selected: true; enabled: !DesktopData.busy && !ShellPrefs.busy; onClicked: DesktopData.act("mode", [root.selectedMode]) }
    }
}
