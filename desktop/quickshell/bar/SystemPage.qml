pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    property string tab: "general"
    readonly property bool laptop: Quickshell.env("ONINIX_LAPTOP") === "1"
    readonly property int sliderWidth: Shared.DesktopStyle.px(300)
    function launch(command) {
        Qt.callLater(() => Quickshell.execDetached(command));
    }
    function gib(bytes) {
        return (bytes / 1073741824).toFixed(0);
    }
    readonly property var targetTabs: ({ "NixOS": "software", "Local AI": "software", "Voice and machine spirit": "software" })
    function reveal(target) {
        const next = targetTabs[target]
        if (!next || root.tab === next) return false
        root.tab = next
        return true
    }
    component TimeField: TextField {
        Layout.preferredWidth: Shared.DesktopStyle.px(80)
        inputMask: "99:99"
        color: Colors.foreground
        background: Rectangle { radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.width: 1; border.color: Colors.selection }
    }

    Segmented {
        Layout.alignment: Qt.AlignHCenter
        model: [{id: "general", title: "General"}, {id: "software", title: "Software"}]
        current: root.tab
        onChosen: id => root.tab = id
    }

    SettingsGroup {
        id: tzGroup
        readonly property var tz: (DesktopData.settings || {}).timezone || null
        visible: root.tab === "general" && tz !== null
        title: "Time zone"
        footer: !tz ? "" : tz.auto && !tz.service ? "Automatic: waiting for a location fix (or the next system rebuild)."
            : tz.auto ? "Follows your location. Picking a zone by hand turns Automatic off." : "Set by hand."
        SettingsRow {
            title: "Set automatically"
            subtitle: tzGroup.tz ? tzGroup.tz.zone : ""
            UiButton {
                glyph: tzGroup.tz && tzGroup.tz.auto ? "\u{F0132}" : "\u{F0131}"
                text: tzGroup.tz && tzGroup.tz.auto ? "On" : "Off"
                selected: !!tzGroup.tz && tzGroup.tz.auto
                enabled: !DesktopData.busy
                onClicked: DesktopData.act("tz-auto", [tzGroup.tz.auto ? "off" : "on"])
            }
        }
        SettingsRow {
            title: "Time zone"
            SettingCombo {
                id: zonePick
                Layout.preferredWidth: Shared.DesktopStyle.px(260)
                editable: true
                model: tzGroup.tz ? tzGroup.tz.zones : []
                currentIndex: tzGroup.tz ? tzGroup.tz.zones.indexOf(tzGroup.tz.zone) : -1
            }
            UiButton {
                text: "Set"
                enabled: !DesktopData.busy && !!tzGroup.tz && tzGroup.tz.zones.includes(zonePick.editText)
                onClicked: DesktopData.act("tz-set", [zonePick.editText])
            }
        }
    }

    SettingsGroup {
        id: nightGroup
        readonly property var nl: (DesktopData.settings || {}).nightlight || null
        property bool custom: !!nl && nl.from !== ""
        visible: root.tab === "general" && nl !== null
        title: "Night light"
        SettingsRow {
            title: "Night light"
            UiButton {
                glyph: "\u{F0EB}"
                text: DesktopData.controls.nightlight ? "On" : "Off"
                selected: !!DesktopData.controls.nightlight
                enabled: !DesktopData.busy
                onClicked: DesktopData.act("nightlight")
            }
        }
        SettingsRow {
            title: "Schedule"
            Segmented {
                model: [{id: "sun", title: "Sunset to sunrise"}, {id: "custom", title: "Custom hours"}]
                current: nightGroup.custom ? "custom" : "sun"
                enabled: !DesktopData.busy
                onChosen: id => {
                    if (id === "custom") nightGroup.custom = true;
                    else { nightGroup.custom = false; DesktopData.act("nightlight-set", [String(nightGroup.nl.kelvin), "", ""]); }
                }
            }
        }
        SettingsRow {
            visible: nightGroup.custom
            title: "Hours"
            UiLabel { text: "From" }
            TimeField { id: nightFrom; text: nightGroup.nl && nightGroup.nl.from ? nightGroup.nl.from : "22:00" }
            UiLabel { text: "to" }
            TimeField { id: nightTo; text: nightGroup.nl && nightGroup.nl.to ? nightGroup.nl.to : "07:00" }
            UiButton {
                text: "Apply"
                enabled: !DesktopData.busy
                onClicked: DesktopData.act("nightlight-set", [String(nightGroup.nl.kelvin), nightFrom.text, nightTo.text])
            }
        }
        SettingsRow {
            title: "Warmth"
            SettingSlider {
                Layout.preferredWidth: root.sliderWidth
                from: 2500; to: 6000; stepSize: 100
                value: nightGroup.nl ? nightGroup.nl.kelvin : 4000
                format: v => Math.round(v) + " K"
                onCommitted: v => DesktopData.act("nightlight-set", [String(Math.round(v)), nightGroup.nl.from, nightGroup.nl.to])
            }
        }
    }

    SettingsGroup {
        id: nixGroup
        readonly property var sys: (DesktopData.settings || {}).system || null
        visible: root.tab === "software" && sys !== null
        title: "NixOS"
        footer: "Removes generations older than 14 days (the weekly automatic run keeps 30). Boot menu entries shrink on the next rebuild."
        SettingsRow {
            title: nixGroup.sys ? nixGroup.sys.version : ""
            subtitle: nixGroup.sys ? "Generation " + nixGroup.sys.generation + " of " + nixGroup.sys.generations
                + " · built " + Qt.formatDateTime(new Date(nixGroup.sys.built * 1000), "d MMM, HH:mm") : ""
            UiButton {
                glyph: "\u{F1C0}"
                text: "Clean old generations…"
                onClicked: root.launch(["kitty", "--title", "Nix cleanup", "sh", "-c",
                    "sudo nix-collect-garbage --delete-older-than 14d; echo; read -r -p 'Done. Press Enter to close. ' _"])
            }
        }
        Repeater {
            model: nixGroup.sys ? nixGroup.sys.disks : []
            SettingsRow {
                id: disk
                required property var modelData
                title: modelData.mount
                Rectangle {
                    Layout.preferredWidth: Shared.DesktopStyle.px(200)
                    implicitHeight: Shared.DesktopStyle.px(6)
                    radius: height / 2
                    color: Colors.selection
                    Rectangle {
                        width: parent.width * disk.modelData.used / Math.max(1, disk.modelData.size)
                        height: parent.height
                        radius: height / 2
                        color: disk.modelData.used / disk.modelData.size > 0.9 ? Colors.red : Colors.accent
                    }
                }
                UiLabel {
                    Layout.preferredWidth: Shared.DesktopStyle.px(100)
                    horizontalAlignment: Text.AlignRight
                    color: Colors.muted
                    text: root.gib(disk.modelData.used) + " / " + root.gib(disk.modelData.size) + " GiB"
                }
            }
        }
    }

    SettingsGroup {
        id: voiceGroup
        property var voice: ({})
        visible: root.tab === "software"
        title: "Voice and machine spirit"
        footer: "Hold Right Alt to dictate, hold Right Ctrl or press Super+A to ask the machine spirit. Whisper runs on this computer; requests to the spirit go to the agent you signed in to."
        FileView {
            path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/oninix/voice.json"
            watchChanges: true; printErrors: false
            onFileChanged: reload()
            onLoaded: { try { voiceGroup.voice = JSON.parse(text()) } catch (_) { voiceGroup.voice = {} } }
            onLoadFailed: voiceGroup.voice = {}
        }
        SettingsRow {
            title: voiceGroup.voice.checkedAt ? (voiceGroup.voice.enabled ? "Voice is on" : "Voice is off") : "Voice not checked yet"
            subtitle: voiceGroup.voice.checkedAt
                ? "Whisper " + voiceGroup.voice.model + " on " + String(voiceGroup.voice.backend || "cpu").toUpperCase() + " · " + (voiceGroup.voice.reason || "")
                : "The first login measures what this computer can run."
            UiButton {
                text: "Check again"
                onClicked: root.launch(["kitty", "--title", "Voice check", "sh", "-c", "oninix-voice-profile; read -r -p 'Press Enter to close ' _"])
            }
            UiButton {
                visible: voiceGroup.voice.checkedAt !== undefined && !voiceGroup.voice.enabled
                text: "Turn on anyway"
                onClicked: root.launch(["kitty", "--title", "Voice check", "sh", "-c", "oninix-voice-profile --force; read -r -p 'Press Enter to close ' _"])
            }
        }
        SettingsRow {
            title: "Machine spirit"
            subtitle: "Ask for a change, see the diff, apply or undo."
            UiButton {
                glyph: "\u{F0A8D}"
                text: "Ask…"
                onClicked: root.launch(["kitty", "--hold", "--class", "oninix-spirit", "--title", "Machine spirit", "oninix-spirit"])
            }
            UiButton {
                text: "Undo last change"
                onClicked: root.launch(["kitty", "--class", "oninix-spirit", "--title", "Machine spirit", "sh", "-c", "oninix-spirit undo; read -r -p 'Press Enter to close ' _"])
            }
        }
        Process {
            id: agentStatus
            property var state: ({})
            command: ["oninix-spirit", "status"]
            running: root.tab === "software"
            stdout: StdioCollector { onStreamFinished: { try { agentStatus.state = JSON.parse(text) } catch (_) {} } }
        }
        Timer { interval: 5000; repeat: true; running: root.tab === "software"; onTriggered: if (!agentStatus.running) agentStatus.running = true }
        Repeater {
            model: [{id: "claude", title: "Claude Code", login: "claude auth login"}, {id: "codex", title: "Codex", login: "codex login"}]
            SettingsRow {
                id: agentRow
                required property var modelData
                readonly property var info: agentStatus.state[modelData.id] || ({})
                title: modelData.title
                subtitle: !info.installed ? "Not installed. Tick the AI set or ask for it."
                    : info.signedIn ? "Signed in" + (agentStatus.state.agent === modelData.id ? " · the machine spirit uses it" : "")
                    : "Not signed in. Your own account, your own subscription."
                UiButton {
                    visible: !!agentRow.info.installed
                    text: agentRow.info.signedIn ? "Sign in again" : "Sign in…"
                    onClicked: root.launch(["kitty", "--title", agentRow.modelData.title + " sign in", "sh", "-c", agentRow.modelData.login + "; read -r -p 'Press Enter to close ' _"])
                }
                UiButton {
                    visible: !!agentRow.info.installed && !!agentRow.info.signedIn
                    text: agentStatus.state.agent === agentRow.modelData.id ? "In use" : "Use for the spirit"
                    selected: agentStatus.state.agent === agentRow.modelData.id
                    onClicked: { Quickshell.execDetached(["oninix-spirit", "use", agentRow.modelData.id]); agentStatus.running = true }
                }
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        active: !root.laptop
        visible: root.tab === "software" && !root.laptop
        sourceComponent: SettingsGroup {
            title: "Local AI"
            SettingsRow {
                title: "Ollama"
                UiButton {
                    text: "AI actions…"
                    onClicked: root.launch(["oninix-launcher", "--show-actions"])
                }
            }
        }
    }

    UiLabel {
        visible: root.tab === "general" && root.laptop
        Layout.fillWidth: true
        color: Colors.muted
        font.pixelSize: Shared.DesktopStyle.px(13)
        text: "Balanced is the everyday profile. Use Performance for demanding work, or Power saver to extend battery life. Closing the lid suspends the laptop."
    }
}
