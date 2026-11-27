import QtQuick
import "../shared" as Shared

Item {
    id: button
    required property string appId
    required property var host
    property bool pinned: true
    readonly property bool byClass: appId.startsWith("class:")
    readonly property var entry: AppIcons.apps[appId]
    readonly property string symbol: Hypr.icon(byClass ? appId.slice(6) : entry ? entry.startupClass || entry.name : appId)
    readonly property int running: Minimized.visibleOf(appId).length
    readonly property int minimized: Minimized.minimizedOf(appId).length
    readonly property bool attention: minimized > 0 && Minimized.isUrgent(appId)
    readonly property string name: entry ? entry.name : byClass ? appId.slice(6) : appId
    readonly property bool hovered: mouse.containsMouse
    readonly property color tone: ShellLayout.buttonColor(host.group)
    implicitWidth: Math.max(Shared.DesktopStyle.px(30), PanelStyle.barHeight + Shared.DesktopStyle.px(2))
    implicitHeight: PanelStyle.barHeight
    Component.onDestruction: host.forget(button)

    Rectangle {
        anchors.fill: parent; anchors.margins: Shared.DesktopStyle.px(3); radius: Shared.DesktopStyle.px(5)
        color: button.tone
        opacity: mouse.pressed ? 0.18 : mouse.containsMouse ? 0.10 : 0
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
    }
    Text {
        anchors.centerIn: parent; text: button.symbol
        font.family: Colors.iconFont; font.pixelSize: Math.max(Shared.DesktopStyle.px(16), Colors.fontSize + Shared.DesktopStyle.px(2))
        color: button.tone
    }
    readonly property string badge: Minimized.badge(appId)
    Rectangle {
        visible: button.badge !== ""
        anchors.right: parent.right; anchors.top: parent.top
        anchors.rightMargin: Shared.DesktopStyle.px(2); anchors.topMargin: Shared.DesktopStyle.px(2)
        height: button.badge === "dot" ? Shared.DesktopStyle.px(7) : Shared.DesktopStyle.px(13); radius: height / 2
        width: button.badge === "dot" ? Shared.DesktopStyle.px(7) : Math.max(height, badgeText.implicitWidth + Shared.DesktopStyle.px(6))
        color: Colors.red
        Text {
            id: badgeText
            visible: button.badge !== "dot"
            anchors.centerIn: parent; text: button.badge
            font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(9); font.bold: true
            color: Colors.background
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Shared.DesktopStyle.px(2)
        spacing: Shared.DesktopStyle.px(2)
        visible: button.running > 0 || button.minimized > 0
        Rectangle {
            visible: button.running > 0
            width: Shared.DesktopStyle.px(8); height: Shared.DesktopStyle.px(2); radius: Shared.DesktopStyle.px(1); anchors.verticalCenter: parent.verticalCenter
            color: button.tone; opacity: 0.75
        }
        Repeater {
            model: Math.min(3, button.minimized)
            Rectangle {
                width: Shared.DesktopStyle.px(3); height: Shared.DesktopStyle.px(3); radius: Shared.DesktopStyle.px(3) / 2; anchors.verticalCenter: parent.verticalCenter
                color: button.attention ? Colors.yellow : button.tone
            }
        }
    }
    BarToolTip {
        target: button; shown: mouse.containsMouse && !host.dragging && button.minimized === 0
        text: button.name + (button.pinned ? " · drag to move" : "") + " · right-click for windows and options"
    }
    MouseArea {
        id: mouse
        anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) host.hover(button)
        onClicked: m => {
            if (m.button === Qt.RightButton) host.menu(button)
            else if (button.pinned) PinnedApps.launch(button.appId)
            else Minimized.activate(button.appId)
        }
    }
}
