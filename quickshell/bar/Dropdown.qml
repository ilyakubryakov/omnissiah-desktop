import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: drop

    required property Item anchorItem
    required property var barWindow
    property bool open: false
    property int cardWidth: 320
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
