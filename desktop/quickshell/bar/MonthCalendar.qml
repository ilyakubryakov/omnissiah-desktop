import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

PanelWindow {
    id: root
    property bool opened: false
    property var cal: null
    signal accountsRequested()
    screen: Shared.Screens.main
    visible: (opened || conceal.running) && Shared.Screens.main !== null
    anchors { top: true; right: true }
    margins { top: 42; right: 20 }
    implicitWidth: 396
    implicitHeight: calendar.implicitHeight + 36
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-calendar"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    function toggle() {
        opened = !opened
        if (opened) { PopupState.close(); calendar.reset(); Qt.callLater(() => { if (root.opened) calendar.forceActiveFocus() }) }
    }
    onOpenedChanged: if (!opened) conceal.restart()
    Timer { id: conceal; interval: Shared.DesktopStyle.normal }
    Shared.ClickCatcher { active: root.opened; onClicked: root.opened = false }
    Rectangle {
        anchors.fill: parent
        radius: Shared.DesktopStyle.radiusPanel
        color: Colors.background
        border.color: Colors.selection; border.width: 1
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.normal } }
        transform: Translate { y: root.opened ? 0 : -12; Behavior on y { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } } }
        CalendarCard {
            id: calendar
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 18 }
            cal: root.cal
            onAccountsRequested: { root.opened = false; root.accountsRequested() }
            Keys.onEscapePressed: root.opened = false
        }
    }
}
