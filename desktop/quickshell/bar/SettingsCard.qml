import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    default property alias content: contents.data
    Layout.fillWidth: true
    implicitHeight: contents.implicitHeight + 2 * Shared.DesktopStyle.cardPadding
    radius: Shared.DesktopStyle.radiusCard
    color: Colors.lightBackground
    border.color: Colors.selection
    border.width: 1
    ColumnLayout {
        id: contents
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.cardPadding }
        spacing: Shared.DesktopStyle.cardSpacing
    }
}
