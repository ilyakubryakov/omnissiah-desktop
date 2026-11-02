pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SettingsCard {
    id: root
    property string deleting: ""
    UiLabel { text: "Saved looks"; font.pixelSize: 18 }
    UiLabel { text: "Save the palette, icons, panel layout, accents and window styling together. Wallpapers keep their own light/dark settings."; color: Colors.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap }
    RowLayout {
        Layout.fillWidth: true
        TextField {
            id: name; Layout.fillWidth: true; placeholderText: "Name this look"; maximumLength: 40
            color: Colors.foreground; placeholderTextColor: Colors.muted; selectByMouse: true
            background: Rectangle { radius: 8; color: Colors.background; border.color: name.activeFocus ? Colors.accent : Colors.selection }
            onAccepted: if (text.trim()) { ShellPrefs.send("look-save", text.trim()); clear() }
        }
        UiButton { text: ShellPrefs.looks.includes(name.text.trim()) ? "Update" : "Save"; enabled: !!name.text.trim() && !ShellPrefs.busy; onClicked: { ShellPrefs.send("look-save", name.text.trim()); name.clear() } }
    }
    Repeater {
        model: ShellPrefs.looks
        RowLayout {
            required property string modelData
            Layout.fillWidth: true
            UiLabel { text: modelData; Layout.fillWidth: true }
            UiButton { text: "Apply"; enabled: !ShellPrefs.busy; onClicked: ShellPrefs.send("look-apply", modelData) }
            UiButton { text: root.deleting === modelData ? "Confirm remove" : "Remove"; onClicked: { if (root.deleting === modelData) { ShellPrefs.send("look-delete", modelData); root.deleting = "" } else root.deleting = modelData } }
        }
    }
}
