import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../shared" as Shared

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
    anchor.margins.top: Shared.DesktopStyle.px(4)
    implicitWidth: cardWidth
    implicitHeight: column.implicitHeight + Shared.DesktopStyle.px(16)
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
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.spaceUnit * 2 }
            spacing: Shared.DesktopStyle.px(2)
        }
    }
}
