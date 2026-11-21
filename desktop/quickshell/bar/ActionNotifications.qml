import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shared" as Shared

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
    WlrLayershell.keyboardFocus: hover.hovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function refresh() { if (!probe.running && !read.running) probe.running = true }
    function clear() {
        if (snapshot === "") return
        snapshot = ""
        rows = []
    }
    function hasAction(row) {
        return row && row.actions && Object.keys(row.actions).length > 0
    }
    Component.onCompleted: refresh()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Connections { target: DesktopData; function onActionDone(name) { root.refresh() } }
    Process {
        id: probe
        command: ["makoctl", "list", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const rows = Array.isArray(data) ? data : data.data || []
                    if (rows.some(row => (Array.isArray(row) ? row : [row]).some(root.hasAction))) {
                        read.running = true
                        return
                    }
                } catch (e) {}
                root.clear()
            }
        }
    }
    Process {
        id: read
        command: [DesktopData.helper, "data", "notification-popups"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    if (root.snapshot !== text) {
                        root.snapshot = text
                        root.rows = data.current || []
                    }
                } catch (e) { root.clear() }
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
