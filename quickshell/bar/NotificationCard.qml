pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "NotificationLogic.js" as Logic

ColumnLayout {
    id: root
    signal detailsRequested()
    spacing: 10

    readonly property var rows: Logic.groups(DesktopData.notifications.current, DesktopData.notifications.history)
        .filter(g => g.notification.tier !== "quiet").slice(0, 4)
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "NOTIFICATIONS"; font.pixelSize: 11; color: Colors.accent; font.letterSpacing: 1 }
        Item { Layout.fillWidth: true }
        UiButton { text: "Clear"; enabled: !DesktopData.busy && root.rows.length > 0; onClicked: DesktopData.act("clear") }
        UiButton { text: "All"; onClicked: root.detailsRequested() }
    }
    UiLabel {
        visible: !!DesktopData.notifications.error || root.rows.length === 0
        text: DesktopData.notifications.error || "All quiet. No recent notifications."
        Layout.fillWidth: true; font.pixelSize: 13; color: Colors.muted
    }
    Repeater {
        model: root.rows
        NotificationItem { required property var modelData; notification: modelData.notification; ids: modelData.ids; count: modelData.count; compact: true; live: modelData.live; onActionInvoked: PopupState.close() }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: DesktopData.unreadCount + " unread"; color: Colors.muted; font.pixelSize: 12; Layout.fillWidth: true }
        UiButton { text: "Do not disturb"; selected: !!DesktopData.controls.dnd; enabled: !DesktopData.busy; onClicked: DesktopData.act("dnd") }
    }
}
