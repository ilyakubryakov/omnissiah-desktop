import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    default property alias content: contents.data
    Layout.fillWidth: true
    implicitHeight: contents.implicitHeight + 32
    radius: Shared.DesktopStyle.radiusCard
    color: Colors.lightBackground
    border.color: Colors.selection
    border.width: 1
    ColumnLayout {
        id: contents
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 12
    }
}
