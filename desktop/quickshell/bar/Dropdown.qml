import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../shared" as Shared

// A menu that drops from a bar item, in the bar's flat style. A click anywhere
// outside it and the bar closes it (Hyprland focus grab); the bar stays in the
// grab so clicking the same item again toggles instead of reopening.
PopupWindow {
    id: drop

    required property Item anchorItem
    required property var barWindow
    property bool open: false
    property int cardWidth: Shared.DesktopStyle.px(320)
    default property alias content: column.data

    anchor.item: anchorItem
    anchor.edges: barWindow.edge === "bottom" ? Edges.Top : Edges.Bottom
    anchor.gravity: barWindow.edge === "bottom" ? Edges.Top : Edges.Bottom
    anchor.margins.top: 4
    implicitWidth: cardWidth
    implicitHeight: column.implicitHeight + 16
    visible: open
    color: "transparent"

    HyprlandFocusGrab {
        windows: [drop, drop.barWindow]
        active: drop.open
        onCleared: drop.open = false
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        border.width: 1
        border.color: Colors.lightBackground

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 2
        }
    }
}
