import QtQuick
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

// The DBus menu of a tray item, drawn as a bar Dropdown. Platform (QMenu)
// popups never appear from the layer-shell bar on Hyprland, hence our own.
// Submenus open in place, with a back row on top.
Dropdown {
    id: menu

    property var item: null
    property var stack: []
    cardWidth: Shared.DesktopStyle.px(260)

    function show(trayItem, anchor) {
        if (open && item === trayItem) { open = false; return }
        item = trayItem
        anchorItem = anchor
        stack = [trayItem.menu]
        open = true
    }

    // DBus menu labels mark mnemonics with "_" and escape a literal one as "__".
    function plain(text) {
        return (text || "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
    }

    onOpenChanged: if (!open) stack = []

    QsMenuOpener {
        id: opener
        menu: menu.stack.length ? menu.stack[menu.stack.length - 1] : null
    }

    DropdownRow {
        visible: menu.stack.length > 1
        glyph: "\u{F0141}"
        label: "Back"
        onClicked: menu.stack = menu.stack.slice(0, -1)
    }

    Repeater {
        model: opener.children

        Item {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData.isSeparator ? 9 : row.implicitHeight

            Rectangle {
                visible: entry.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Colors.lightBackground
            }

            DropdownRow {
                id: row
                visible: !entry.modelData.isSeparator
                width: parent.width
                enabled: entry.modelData.enabled
                opacity: enabled ? 1 : 0.45
                label: menu.plain(entry.modelData.text)
                current: entry.modelData.checkState === Qt.Checked
                glyph: entry.modelData.buttonType === QsMenuButtonType.CheckBox
                    ? (current ? "\u{F0132}" : "\u{F0131}")
                    : entry.modelData.buttonType === QsMenuButtonType.RadioButton
                    ? (current ? "\u{F043E}" : "\u{F043D}")
                    : ""
                detail: entry.modelData.hasChildren ? "\u{F0142}" : ""
                onClicked: {
                    if (entry.modelData.hasChildren) {
                        menu.stack = menu.stack.concat([entry.modelData])
                        return
                    }
                    entry.modelData.triggered()
                    menu.open = false
                }
            }
        }
    }
}
