pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

SettingsGroup {
    id: root
    property string deleting: ""
    title: "Saved looks"
    footer: "A look saves the palette, icons, panel layout, accents and window styling together. Wallpapers keep their own light/dark settings."
    SettingsRow {
        title: "Save current look"
        TextField {
            id: name; Layout.preferredWidth: Shared.DesktopStyle.px(240); placeholderText: "Name this look"; maximumLength: 40
            color: Colors.foreground; placeholderTextColor: Colors.muted; selectByMouse: true
            background: Rectangle { radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.color: name.activeFocus ? Colors.accent : Colors.selection }
            onAccepted: if (text.trim()) { ShellPrefs.send("look-save", text.trim()); clear() }
        }
        UiButton { text: ShellPrefs.looks.includes(name.text.trim()) ? "Update" : "Save"; enabled: !!name.text.trim() && !ShellPrefs.busy; onClicked: { ShellPrefs.send("look-save", name.text.trim()); name.clear() } }
    }
    Repeater {
        model: ShellPrefs.looks
        SettingsRow {
            id: look
            required property string modelData
            title: modelData
            UiButton { text: "Apply"; enabled: !ShellPrefs.busy; onClicked: ShellPrefs.send("look-apply", look.modelData) }
            UiButton { text: root.deleting === look.modelData ? "Confirm remove" : "Remove"; danger: root.deleting === look.modelData; onClicked: { const chosen = look.modelData; if (root.deleting === chosen) { ShellPrefs.send("look-delete", chosen); root.deleting = "" } else root.deleting = chosen } }
        }
    }
}
