import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// A System Settings style group: an optional title above, rows in one rounded
// box separated by hairlines (SettingsRow draws them), an optional footnote below.
ColumnLayout {
    id: root
    property string title: ""
    property string footer: ""
    default property alias rows: box.data
    Layout.fillWidth: true
    spacing: Shared.DesktopStyle.px(6)
    UiLabel {
        visible: root.title !== ""
        Layout.fillWidth: true; Layout.leftMargin: Shared.DesktopStyle.px(4)
        text: root.title; font.weight: Font.DemiBold; font.pixelSize: Shared.DesktopStyle.px(13)
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: box.implicitHeight
        radius: Shared.DesktopStyle.radiusCard
        color: Colors.lightBackground
        border.width: 1; border.color: Colors.selection
        ColumnLayout { id: box; anchors { left: parent.left; right: parent.right; top: parent.top } spacing: 0 }
    }
    UiLabel {
        visible: root.footer !== ""
        Layout.fillWidth: true; Layout.leftMargin: Shared.DesktopStyle.px(4); Layout.rightMargin: Shared.DesktopStyle.px(4)
        text: root.footer; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12)
    }
}
