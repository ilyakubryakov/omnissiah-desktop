import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shared" as Shared

// Mako owns notification IDs and action callbacks. Only their presentation is
// delegated here: never guess an action or invoke one without a button click.
PanelWindow {
    id: root
    property var rows: []
    property string snapshot: ""
    screen: Shared.Screens.main
    visible: rows.length > 0 && Shared.Screens.main !== null && !DesktopData.notificationsOpen
    anchors { top: true; right: true }
    margins { top: PanelStyle.barHeight + PanelStyle.outerGap + 8; right: 8 }
    implicitWidth: 420
    implicitHeight: Math.min(cards.implicitHeight, screen ? screen.height - 100 : 700)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-action-notifications"
    // A popup must not take the keyboard when it appears (Hyprland focuses any
    // interactive layer on map): interactive only while the pointer is over it.
    WlrLayershell.keyboardFocus: hover.hovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function refresh() { if (!read.running) read.running = true }
    Component.onCompleted: refresh()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Connections { target: DesktopData; function onActionDone(name) { root.refresh() } }
    Process {
        id: read
        command: [DesktopData.helper, "data", "notification-popups"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    // Keep delegates (and a pressed button) alive between polls.
                    if (root.snapshot !== text) {
                        root.snapshot = text
                        root.rows = data.current || []
                    }
                } catch (e) { root.snapshot = ""; root.rows = [] }
            }
        }
    }
    HoverHandler { id: hover }
    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            id: cards
            width: parent.width
            spacing: 8
            Repeater {
                model: root.rows
                NotificationItem {
                    required property var modelData
                    notification: modelData
                    live: true
                    compact: true
                    buttonsOnly: true
                    onActionInvoked: root.refresh()
                }
            }
        }
    }
}
