pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    readonly property bool laptop: Quickshell.env("ONINIX_LAPTOP") === "1"
    readonly property var brightness: (DesktopData.controls.laptop || {}).brightness
    readonly property var idleChoices: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
    function idleLabel(m) {
        return m === 0 ? "Never" : m < 60 ? m + " min" : (m / 60) + " h";
    }
    function launch(command) {
        Qt.callLater(() => Quickshell.execDetached(command));
    }

    SettingsGroup {
        title: "Power and idle"
        footer: DesktopData.controls.awake ? "Keep awake is active: automatic lock, screen off and sleep are paused."
            : "Screen off keeps apps running. Move the mouse or press a key to wake the displays."
        SettingsRow {
            title: "Keep awake"
            subtitle: "Pauses automatic lock, screen off and sleep"
            UiButton {
                text: DesktopData.controls.awake ? "On" : "Off"
                selected: !!DesktopData.controls.awake
                onClicked: StatusState.toggleAwake()
            }
        }
        SettingsRow {
            title: "Lock screen"
            UiButton {
                text: "Lock now"
                onClicked: root.launch(["loginctl", "lock-session"])
            }
        }
        SettingsRow {
            title: "Screen off"
            UiButton {
                text: "Turn off displays"
                onClicked: root.launch(["sh", "-c", "sleep 1; hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = \"disable\" }))'"])
            }
        }
        SettingsRow {
            title: "Power menu"
            subtitle: "Log out, restart or shut down"
            UiButton {
                text: "Open…"
                onClicked: root.launch([Quickshell.env("ONINIX_SHARE") + "/hypr/scripts/power-menu.sh"])
            }
        }
    }

    SettingsGroup {
        visible: !!DesktopData.settings.idle
        title: "Lock and sleep"
        footer: "Timeouts count from your last activity and are saved for this machine. Never disables only that timer. Keep awake pauses all three. Meta+L, closing the lid and sleep still lock at once."
        Repeater {
            model: [["lock", "Lock screen after"], ["screen", "Turn off display after"], ["suspend", "Suspend after"]]
            SettingsRow {
                id: idle
                required property var modelData
                title: modelData[1]
                SettingCombo {
                    Layout.preferredWidth: Shared.DesktopStyle.px(160)
                    readonly property int minutes: (DesktopData.settings.idle || {})[idle.modelData[0]] ?? 0
                    readonly property var choices: Array.from(new Set(root.idleChoices.concat([minutes]))).sort((a, b) => a - b)
                    model: choices.map(m => root.idleLabel(m))
                    currentIndex: choices.indexOf(minutes)
                    enabled: !DesktopData.busy
                    onActivated: i => DesktopData.act("idle-set", [idle.modelData[0], String(choices[i])])
                }
            }
        }
    }

    SettingsGroup {
        visible: root.laptop
        title: "Battery"
        footer: "Balanced is the everyday profile. Use Performance for demanding work, or Power saver to extend battery life. Closing the lid suspends the laptop."
        SettingsRow {
            title: "Battery"
            UiLabel {
                color: Colors.muted
                text: {
                    const b = (DesktopData.controls.laptop || {}).battery;
                    return b ? b.percent + "% · " + b.status : "Unavailable";
                }
            }
        }
        SettingsRow {
            title: "Power profile"
            Segmented {
                model: ((DesktopData.controls.laptop || {}).profiles || []).map(p => ({
                    id: p,
                    title: ({ "power-saver": "Power saver", balanced: "Balanced", performance: "Performance" })[p] || p
                }))
                current: (DesktopData.controls.laptop || {}).profile || ""
                enabled: !DesktopData.busy
                onChosen: id => DesktopData.act("power-profile", [id])
            }
        }
        SettingsRow {
            title: "Brightness"
            RowLayout {
                spacing: Shared.DesktopStyle.px(8)
                UiSlider {
                    id: powerBrightness
                    Layout.preferredWidth: Shared.DesktopStyle.px(250)
                    from: 5; to: 100; stepSize: 1
                    tint: Colors.yellow
                    value: DesktopData.brightnessTarget >= 0 ? DesktopData.brightnessTarget : root.brightness ?? 5
                    visible: root.brightness != null
                    Accessible.name: "Display brightness"
                    onMoved: DesktopData.setBrightness(Math.round(value))
                }
                UiLabel {
                    Layout.preferredWidth: root.brightness == null ? implicitWidth : Shared.DesktopStyle.px(46)
                    horizontalAlignment: Text.AlignRight
                    color: Colors.muted
                    text: root.brightness == null ? "Unavailable" : Math.round(powerBrightness.value) + "%"
                }
            }
        }
    }
}
