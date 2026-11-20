pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    property string selectedMode: "work"
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var bindings: ShellPrefs.devices[selectedMode] || ({})
    readonly property var definitions: [
        {id: "work", title: "Work", glyph: "\uf0b1", detail: "Notifications on. Your normal night light and audio defaults."},
        {id: "call", title: "Call", glyph: "\uf095", detail: "Do not disturb. Choose a microphone and output for meetings."},
        {id: "game", title: "Game", glyph: "\uf11b", detail: "Use performance scheduling, pause local AI and notifications, disable night light and fullscreen Steam games. Normal restores the previous state."},
        {id: "music", title: "Recording", glyph: "\uf001", detail: "Do not disturb and the low-latency Music audio profile."}
    ].filter(d => Quickshell.env("ONINIX_LAPTOP") !== "1" || !["game", "music"].includes(d.id))
    PwObjectTracker { objects: root.nodes }
    readonly property var selectedDefinition: root.definitions.find(d => d.id === root.selectedMode) || root.definitions[0]

    SettingsGroup {
        title: "Current mode"
        footer: "Normal restores the settings from before the mode. Changes you make manually while a mode is active are kept."
        SettingsRow {
            title: "Current: " + (DesktopData.controls.mode || "normal")
            UiButton { text: "Restore Normal"; enabled: !DesktopData.busy && DesktopData.controls.mode !== "normal"; onClicked: DesktopData.act("mode", ["normal"]) }
        }
    }

    SettingsGroup {
        title: "Modes"
        Repeater {
            model: root.definitions
            SettingsRow {
                id: modeRow
                required property var modelData
                readonly property bool chosen: root.selectedMode === modelData.id
                readonly property bool running: DesktopData.controls.mode === modelData.id
                title: modelData.title + (running ? " · active" : "")
                subtitle: modelData.detail
                Rectangle {
                    implicitWidth: Shared.DesktopStyle.px(28); implicitHeight: implicitWidth
                    radius: Shared.DesktopStyle.px(7)
                    color: modeRow.running ? Colors.accent : Colors.selection
                    Text { anchors.centerIn: parent; text: modeRow.modelData.glyph; color: modeRow.running ? Colors.background : Colors.foreground; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(14) }
                }
                UiButton { text: modeRow.chosen ? "Selected" : "Edit"; selected: modeRow.chosen; onClicked: root.selectedMode = modeRow.modelData.id }
            }
        }
    }

    SettingsGroup {
        title: root.selectedDefinition.title + " devices"
        footer: "Device choices are saved separately on each computer."
        Repeater {
            model: ["sink", "source"]
            SettingsRow {
                id: deviceRow
                required property string modelData
                readonly property string saved: root.bindings[modelData] || ""
                readonly property var devices: root.nodes.filter(n => n.isSink === (modelData === "sink"))
                readonly property bool missing: saved !== "" && !devices.some(n => n.name === saved)
                readonly property var choices: [{name: "", label: "Use normal default"}].concat(devices.map(n => ({name: n.name, label: n.description || n.name}))).concat(missing ? [{name: saved, label: "Disconnected · " + saved}] : [])
                title: modelData === "sink" ? "Audio output" : "Microphone"
                subtitle: missing ? "Connect this device or select another before applying the mode." : ""
                UiComboBox {
                    Layout.preferredWidth: Shared.DesktopStyle.px(300)
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
            }
        }
        SettingsRow {
            title: "Turn on " + root.selectedDefinition.title
            UiButton { text: "Apply " + root.selectedDefinition.title; selected: true; enabled: !DesktopData.busy && !ShellPrefs.busy; onClicked: DesktopData.act("mode", [root.selectedMode]) }
        }
    }
}
