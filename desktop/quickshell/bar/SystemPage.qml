pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

// System: display set, time zone and night light (General); NixOS, AI / GPU and
// the system-management agent (Software).
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
    // Search targets on the second tab: switch first (see AppearancePanel.reveal).
    readonly property var targetTabs: ({ "NixOS": "software", "AI / GPU": "software", "System management": "software" })
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

    // ---- General ---------------------------------------------------------------
    SettingsGroup {
        visible: root.tab === "general" && !root.laptop
        title: "Displays"
        footer: "Xeneon is reserved for widgets. TV uses workspace 11; turning it off returns its windows to workspace 1. Audio stays on your selected device."
        SettingsRow {
            title: "Screens"
            Segmented {
                model: [{id: "desk", title: "LG + Xeneon"}, {id: "extended", title: "LG + Xeneon + TV"}]
                current: Shared.Screens.tv === null ? "desk" : "extended"
                enabled: !DesktopData.busy
                onChosen: id => DesktopData.act("display", [id])
            }
        }
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

    // ---- Software --------------------------------------------------------------
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

    Loader {
        Layout.fillWidth: true
        active: !root.laptop
        visible: root.tab === "software" && !root.laptop
        sourceComponent: SettingsGroup {
            title: "AI / GPU"
            SettingsRow {
                title: "Video memory"
                subtitle: Shared.StationStatus.gpu.available && Shared.StationStatus.gpu.vramUsed !== null && Shared.StationStatus.gpu.vramTotal > 0 ? "VRAM " + (Shared.StationStatus.gpu.vramUsed / 1073741824).toFixed(1) + " / " + (Shared.StationStatus.gpu.vramTotal / 1073741824).toFixed(0) + " GiB" : "GPU telemetry unavailable"
                UiButton {
                    text: "AI actions…"
                    onClicked: root.launch(["oninix-launcher", "--show-actions"])
                }
            }
        }
    }

    SettingsGroup {
        visible: root.tab === "software"
        title: "System management"
        SettingsRow {
            title: "Agent"
            subtitle: "The System management button opens a terminal in the personal configuration repository with the selected agent."
            Segmented {
                model: [{id: "claude", title: "Claude"}, {id: "codex", title: "Codex"}, {id: "opencode", title: "OpenCode"}, {id: "agy", title: "Antigravity"}]
                current: ((DesktopData.appearance || {}).desktop || {}).agent || ""
                enabled: !DesktopData.busy
                onChosen: id => DesktopData.act("appearance", ["desktop", "agent", id])
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
