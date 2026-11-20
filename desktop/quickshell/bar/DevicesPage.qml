pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

// Devices: keyboard, mouse, touchpad, battery, printers and scanners.
ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    readonly property var s: DesktopData.settings || ({})
    readonly property var input: s.input || ({ layouts: "us" })
    readonly property int sliderWidth: Shared.DesktopStyle.px(300)
    readonly property var layoutChoices: [["us", "English"], ["ru", "Russian"], ["ua", "Ukrainian"], ["lt", "Lithuanian"], ["de", "German"], ["pl", "Polish"], ["fr", "French"], ["es", "Spanish"]]
    readonly property var onOff: [{id: "yes", title: "On"}, {id: "no", title: "Off"}]
    function setInput(key, value) { DesktopData.act("input-set", [key, String(value)]) }
    function launch(command) { Qt.callLater(() => Quickshell.execDetached(command)) }

    UiLabel { visible: !root.s.input; text: "Loading…"; color: Colors.muted }

    SettingsGroup {
        visible: !!root.s.input
        title: "Keyboard"
        footer: "CapsLock switches between layouts (Shift+CapsLock for Caps Lock); the first one selected is the default."
        SettingsRow {
            title: "Layouts"
            stacked: true
            Flow {
                Layout.fillWidth: true
                spacing: Shared.DesktopStyle.px(6)
                Repeater {
                    model: root.layoutChoices
                    UiButton {
                        required property var modelData
                        readonly property var current: root.input.layouts.split(",")
                        text: modelData[1]
                        selected: current.includes(modelData[0])
                        enabled: !DesktopData.busy
                        onClicked: {
                            const next = selected ? current.filter(l => l !== modelData[0]) : current.concat([modelData[0]])
                            if (next.length > 0 && next.length <= 4)
                                root.setInput("layouts", next.join(","))
                        }
                    }
                }
            }
        }
        SettingsRow {
            title: "Repeat rate"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 10; to: 80; stepSize: 5; value: Number(root.input.repeat_rate); format: v => Math.round(v) + "/s"; onCommitted: v => root.setInput("repeat_rate", Math.round(v)) }
        }
        SettingsRow {
            title: "Repeat delay"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 150; to: 1000; stepSize: 50; value: Number(root.input.repeat_delay); format: v => Math.round(v) + " ms"; onCommitted: v => root.setInput("repeat_delay", Math.round(v)) }
        }
    }

    SettingsGroup {
        visible: !!root.s.input
        title: "Mouse"
        SettingsRow {
            title: "Pointer speed"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: -1; to: 1; stepSize: 0.05; value: Number(root.input.mouse_speed); format: v => (v > 0 ? "+" : "") + v.toFixed(2); onCommitted: v => root.setInput("mouse_speed", v.toFixed(2)) }
        }
        SettingsRow {
            title: "Natural scrolling"
            subtitle: "Content follows the wheel, as on a touch screen"
            Segmented {
                model: root.onOff
                current: root.input.mouse_natural === "yes" ? "yes" : "no"
                enabled: !DesktopData.busy
                onChosen: id => root.setInput("mouse_natural", id)
            }
        }
    }

    SettingsGroup {
        visible: !!root.s.touchpad
        title: "Touchpad"
        footer: "A two-finger press is the right click. Three fingers switch workspaces, up opens the Launchpad."
        SettingsRow {
            title: "Scroll speed"
            SettingSlider { Layout.preferredWidth: root.sliderWidth; from: 0.1; to: 2; stepSize: 0.05; value: Number(root.input.scroll); format: v => v.toFixed(2) + "×"; onCommitted: v => root.setInput("scroll", v.toFixed(2)) }
        }
        SettingsRow {
            title: "Natural scrolling"
            Segmented {
                model: root.onOff
                current: root.input.natural === "yes" ? "yes" : "no"
                enabled: !DesktopData.busy
                onChosen: id => root.setInput("natural", id)
            }
        }
        SettingsRow {
            title: "Tap to click"
            Segmented {
                model: root.onOff
                current: root.input.tap === "yes" ? "yes" : "no"
                enabled: !DesktopData.busy
                onChosen: id => root.setInput("tap", id)
            }
        }
    }

    SettingsGroup {
        visible: !!root.s.battery
        title: "Battery"
        SettingsRow {
            title: {
                const b = root.s.battery || {}
                return b.health !== null && b.health !== undefined ? "Health " + b.health + "% of design capacity" : "Health unknown"
            }
            subtitle: {
                const b = root.s.battery || {}
                return (b.cycles !== null && b.cycles !== undefined ? b.cycles + " cycles · " : "")
                    + (b.limit ? "Charging stops at " + b.limit + "%." : "This laptop's firmware does not offer a charge limit to Linux.")
            }
        }
    }

    SettingsGroup {
        id: printers
        readonly property var p: root.s.printers
        visible: !!root.s.input
        title: "Printers"
        SettingsRow {
            visible: printers.p === null || (!!printers.p && printers.p.queues.length === 0)
            title: printers.p === null ? "Printing turns on after the next system rebuild." : "No printers yet"
            subtitle: printers.p === null ? "" : "Network printers usually appear by themselves."
        }
        Repeater {
            model: printers.p ? printers.p.queues : []
            SettingsRow {
                id: queue
                required property string modelData
                readonly property bool isDefault: printers.p.default === modelData
                title: modelData
                subtitle: isDefault ? "Default printer" : ""
                UiButton {
                    text: queue.isDefault ? "Default" : "Make default"
                    selected: queue.isDefault
                    enabled: !DesktopData.busy
                    onClicked: DesktopData.act("printer-default", [queue.modelData])
                }
            }
        }
        SettingsRow {
            visible: !!printers.p && printers.p.jobs > 0
            title: printers.p ? printers.p.jobs + " job(s) waiting" : ""
            UiButton { text: "Cancel all"; danger: true; enabled: !DesktopData.busy; onClicked: DesktopData.act("print-cancel") }
        }
        SettingsRow {
            visible: printers.p !== null
            title: "Printer settings"
            subtitle: "Add, share or configure printers"
            UiButton { glyph: "\u{F0493}"; text: "Printer settings…"; onClicked: root.launch(["system-config-printer"]) }
        }
    }

    SettingsGroup {
        id: scanners
        readonly property var sc: root.s.scanners
        visible: !!root.s.input
        title: "Scanners"
        SettingsRow {
            visible: scanners.sc === null || (!!scanners.sc && scanners.sc.devices.length === 0)
            title: scanners.sc === null ? "Scanning turns on after the next system rebuild."
                : scanners.sc && scanners.sc.searching ? "Looking for scanners on the network…" : "No scanners found."
        }
        Repeater {
            model: scanners.sc ? scanners.sc.devices : []
            SettingsRow {
                required property var modelData
                title: modelData.name
            }
        }
        SettingsRow {
            visible: scanners.sc !== null
            title: "Scan a document"
            UiButton { glyph: "\u{F06AB}"; text: "Scan a document…"; onClicked: root.launch(["skanpage"]) }
        }
    }
}
