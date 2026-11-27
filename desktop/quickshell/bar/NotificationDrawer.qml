import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../shared" as Shared

PanelWindow {
    id: root
    property bool opened: false
    property var targetScreen: Shared.Screens.main
    screen: targetScreen || Shared.Screens.main
    visible: (opened || conceal.running) && (targetScreen !== null || Shared.Screens.main !== null)
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-notifications"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    function show() {
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        targetScreen = Quickshell.screens.find(s => s.name === focused) || Shared.Screens.main
        PopupState.close(); DesktopData.error = ""; opened = true
        DesktopData.refresh(); acknowledge.restart()
        Qt.callLater(() => content.forceActiveFocus())
    }
    function toggle() { if (opened) opened = false; else show() }
    onOpenedChanged: { DesktopData.notificationsOpen = opened; if (!opened) conceal.restart() }
    Timer { id: conceal; interval: Shared.DesktopStyle.slow }
    Timer { id: acknowledge; interval: 100; onTriggered: { if (DesktopData.busy) restart(); else if (root.opened) DesktopData.act("mark-seen") } }
    IpcHandler { target: "notifications"; function toggle(): void { root.toggle() } function close(): void { root.opened = false } }
    MouseArea { anchors.fill: parent; onClicked: root.opened = false }
    Rectangle {
        id: surface
        width: Math.min(Shared.DesktopStyle.px(440), root.width - Shared.DesktopStyle.px(24))
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right; rightMargin: Shared.DesktopStyle.spaceUnit * 2; topMargin: PanelStyle.barHeight + PanelStyle.outerGap + Shared.DesktopStyle.px(8); bottomMargin: PanelStyle.barHeight + PanelStyle.outerGap + Shared.DesktopStyle.px(8) }
        MouseArea { anchors.fill: parent }
        radius: Shared.DesktopStyle.radiusCard
        color: Colors.background; border.width: 1; border.color: Colors.selection
        opacity: root.opened ? 1 : 0
        transform: Translate { x: root.opened ? 0 : surface.width + Shared.DesktopStyle.px(12); Behavior on x { NumberAnimation { duration: Shared.DesktopStyle.slow; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
        FocusScope {
            id: content
            anchors.fill: parent
            Keys.onEscapePressed: root.opened = false
            ColumnLayout {
                anchors.fill: parent; anchors.margins: Shared.DesktopStyle.cardPadding; spacing: Shared.DesktopStyle.px(16)
                RowLayout {
                    UiLabel { text: "Notifications"; font.pixelSize: Shared.DesktopStyle.px(19); font.bold: true; Layout.fillWidth: true }
                    UiButton { glyph: "\u{F00D}"; Accessible.name: "Close notifications"; onClicked: root.opened = false }
                }
                ScrollView {
                    id: messages
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                    contentWidth: availableWidth; clip: true
                    NotificationCenter { width: messages.availableWidth; onActionInvoked: root.opened = false }
                }
            }
        }
    }
}
