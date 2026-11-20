pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../shared" as Shared

// Super+/: one page with the shortcuts used every day, read live from
// `hyprctl binds` by description so it never goes stale. The full guide
// (every bind, with search) stays on Super+Shift+H.
ToolOverlay {
    id: root
    title: "Shortcuts"
    cardWidth: Shared.DesktopStyle.px(1000)
    cardHeight: Shared.DesktopStyle.px(760)
    property var binds: []
    readonly property var groups: [
        {title: "Apps", items: ["terminal", "launcher: apps, projects, files", "files", "Chrome (focus or start)", "Telegram", "Slack", "Claude", "1Password quick access"]},
        {title: "Windows", items: ["close window", "maximize", "fullscreen", "float / tile window", "minimize window to the panel", "group into tabs / ungroup", "switch between all application windows", "window and workspace overview"]},
        {title: "Desktops", items: ["go to workspace (1..0)", "send window to workspace (1..0)", "show desktop / bring windows back", "go to the Citrix desk (12)", "send terminal/Kate/VS Code to the Citrix desk (12)"]},
        {title: "System", items: ["control center: quick toggles and sliders", "settings (Control Station)", "clipboard with previews", "notification history", "screenshot to clipboard", "capture: area / screen / video (bar menu), to clipboard", "lock", "dictation: hold Right Alt to speak, release to insert", "Vika: type a message (clipboard picture can be attached)", "this cheatsheet"]}
    ]
    function find(description) { return binds.find(b => b.description === description) || null }
    function keys(bind) {
        const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]].filter(m => bind.modmask & m[0]).map(m => m[1])
        const names = {Return: "Enter", space: "Space", comma: ",", minus: "-", slash: "/", Print: "PrtSc", Escape: "Esc", Tab: "Tab",
                       Alt_R: "Right Alt", Control_R: "Right Ctrl", up: "Arrows"}
        let key = names[bind.key] || bind.key
        if (bind.description.endsWith("(1..0)")) key = "1…0"
        return mods.concat([key.length === 1 ? key.toUpperCase() : key])
    }
    function label(description) {
        const text = description === "this cheatsheet" ? "all shortcuts, with search" : description.replace(/ \(1\.\.0\)$/, "")
        return text.charAt(0).toUpperCase() + text.slice(1)
    }
    onOpenedChanged: if (opened) read.running = true
    Process {
        id: read
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.binds = JSON.parse(text) } catch (_) { root.binds = [] } } }
    }
    component KeyCap: Rectangle {
        property string text: ""
        implicitWidth: Math.max(implicitHeight, cap.implicitWidth + Shared.DesktopStyle.px(14))
        implicitHeight: Shared.DesktopStyle.px(24)
        radius: Shared.DesktopStyle.px(6)
        color: Colors.background
        border.width: 1; border.color: Colors.selection
        Text { id: cap; anchors.centerIn: parent; text: parent.text; color: Colors.foreground; font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(12) }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width >= Shared.DesktopStyle.px(860) ? 2 : 1
        columnSpacing: Shared.DesktopStyle.px(16); rowSpacing: Shared.DesktopStyle.px(16)
        Repeater {
            model: root.groups
            SettingsGroup {
                id: group
                required property var modelData
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 1
                title: modelData.title
                Repeater {
                    model: group.modelData.items.map(d => root.find(d)).filter(b => b)
                    SettingsRow {
                        id: shortcut
                        required property var modelData
                        title: root.label(modelData.description)
                        Repeater {
                            model: root.keys(shortcut.modelData)
                            KeyCap { required property string modelData; text: modelData }
                        }
                    }
                }
            }
        }
    }
    UiLabel {
        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
        text: "Super+Shift+H lists every shortcut. Esc closes."
        color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12)
    }
}
