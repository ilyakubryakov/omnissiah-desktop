pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    readonly property var s: DesktopData.settings || ({})
    readonly property var workspaceNumbers: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    UiLabel { visible: !root.s.autostart; text: "Loading…"; color: Colors.muted }

    SettingsGroup {
        visible: !!root.s.autostart
        title: "Autostart"
        footer: "Changes apply at the next login. Always started by the session: " + (root.s.sessionApps || []).join(", ") + "."
        Repeater {
            model: root.s.autostart || []
            SettingsRow {
                id: auto
                required property var modelData
                title: modelData.name
                subtitle: modelData.applies ? "" : "Not for Hyprland"
                Segmented {
                    model: [{id: "on", title: "On"}, {id: "off", title: "Off"}]
                    current: auto.modelData.enabled ? "on" : "off"
                    enabled: !DesktopData.busy
                    onChosen: id => DesktopData.act("autostart-set", [auto.modelData.id, id])
                }
                UiButton {
                    visible: !auto.modelData.system
                    text: "Remove"
                    danger: true
                    enabled: !DesktopData.busy
                    onClicked: DesktopData.act("autostart-remove", [auto.modelData.id])
                }
            }
        }
        SettingsRow {
            title: "Add an app"
            SettingCombo {
                id: addApp
                Layout.preferredWidth: Shared.DesktopStyle.px(240)
                model: root.s.apps || []
                textRole: "name"
            }
            UiButton {
                text: "Add"
                enabled: !DesktopData.busy && addApp.currentIndex >= 0
                onClicked: DesktopData.act("autostart-add", [root.s.apps[addApp.currentIndex].id])
            }
        }
    }

    SettingsGroup {
        id: wsGroup
        readonly property var w: root.s.workspaces || ({ rules: [], running: [], fixed: [] })
        visible: !!root.s.workspaces
        title: "Apps on workspaces"
        footer: "Pick an open window's class or type one. New windows of that app open on its workspace."
        Repeater {
            model: wsGroup.w.fixed
            SettingsRow {
                id: fixedRule
                required property var modelData
                title: modelData.class
                subtitle: "Fixed"
                UiLabel { text: "Workspace " + fixedRule.modelData.workspace; color: Colors.muted }
            }
        }
        Repeater {
            model: wsGroup.w.rules
            SettingsRow {
                id: rule
                required property var modelData
                title: modelData.class
                SettingCombo {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Shared.DesktopStyle.px(90)
                    model: root.workspaceNumbers
                    currentIndex: rule.modelData.workspace - 1
                    onActivated: i => DesktopData.act("workspace-set", [rule.modelData.class, String(i + 1)])
                }
                UiButton {
                    text: "Remove"
                    danger: true
                    enabled: !DesktopData.busy
                    onClicked: DesktopData.act("workspace-set", [rule.modelData.class, "0"])
                }
            }
        }
        SettingsRow {
            title: "Add a rule"
            SettingCombo {
                id: wsClass
                Layout.preferredWidth: Shared.DesktopStyle.px(220)
                editable: true
                model: wsGroup.w.running
            }
            SettingCombo {
                id: wsNumber
                Layout.fillWidth: false
                Layout.preferredWidth: Shared.DesktopStyle.px(90)
                model: root.workspaceNumbers
            }
            UiButton {
                text: "Add"
                enabled: !DesktopData.busy && wsClass.editText.trim() !== ""
                onClicked: DesktopData.act("workspace-set", [wsClass.editText.trim(), String(wsNumber.currentIndex + 1)])
            }
        }
    }

    SettingsGroup {
        visible: !!root.s.defaults
        title: "Default apps"
        Repeater {
            model: root.s.defaults || []
            SettingsRow {
                id: def
                required property var modelData
                readonly property int choice: modelData.choices.findIndex(c => c.id === modelData.current)
                title: modelData.label
                SettingCombo {
                    Layout.preferredWidth: Shared.DesktopStyle.px(240)
                    model: def.modelData.choices
                    textRole: "name"
                    currentIndex: def.choice
                    displayText: def.choice >= 0 ? currentText : (def.modelData.current || "Not set")
                    enabled: def.modelData.choices.length > 0 && !DesktopData.busy
                    onActivated: i => DesktopData.act("default-app", [def.modelData.key, def.modelData.choices[i].id])
                }
            }
        }
    }

    SettingsGroup {
        id: capture
        readonly property var cap: root.s.capture || null
        readonly property var keys: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".split("").concat(
            ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "Print", "space"])
        visible: cap !== null
        title: "Capture shortcuts"
        footer: "The camera menu on the bar picks what the capture key does: an area or window, the whole screen, or a video (press again to stop). Screenshots are saved to ~/Pictures/Screenshots, videos to ~/Videos/Screencasts."
        Repeater {
            model: [["key", "Capture (bar mode)"], ["key_save", "Capture and save"]]
            SettingsRow {
                id: shortcut
                required property var modelData
                readonly property string combo: capture.cap ? capture.cap[modelData[0]] : ""
                property var mods: combo.split("+").slice(0, -1)
                onComboChanged: mods = combo.split("+").slice(0, -1)
                title: modelData[1]
                Repeater {
                    model: [["SUPER", "Win"], ["CTRL", "Ctrl"], ["ALT", "Alt"], ["SHIFT", "Shift"]]
                    UiButton {
                        required property var modelData
                        text: modelData[1]
                        selected: shortcut.mods.includes(modelData[0])
                        onClicked: shortcut.mods = selected ? shortcut.mods.filter(m => m !== modelData[0]) : shortcut.mods.concat([modelData[0]])
                    }
                }
                SettingCombo {
                    id: keyPick
                    Layout.fillWidth: false
                    Layout.preferredWidth: Shared.DesktopStyle.px(90)
                    model: capture.keys
                    currentIndex: capture.keys.indexOf(shortcut.combo.split("+").slice(-1)[0])
                }
                UiButton {
                    readonly property string next: ["SUPER", "CTRL", "ALT", "SHIFT"].filter(m => shortcut.mods.includes(m)).concat([keyPick.currentText]).join("+")
                    text: "Apply"
                    enabled: !DesktopData.busy && shortcut.mods.length > 0 && next !== shortcut.combo
                    onClicked: DesktopData.act("capture-set", [shortcut.modelData[0], next])
                }
            }
        }
    }
}
