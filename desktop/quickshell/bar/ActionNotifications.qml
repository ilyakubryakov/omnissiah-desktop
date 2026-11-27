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
    property bool refreshQueued: false
    property bool markerReady: false
    screen: Shared.Screens.main
    visible: rows.length > 0 && Shared.Screens.main !== null && !DesktopData.notificationsOpen
    anchors { top: true; right: true }
    margins { top: PanelStyle.barHeight + PanelStyle.outerGap + Shared.DesktopStyle.px(8); right: Shared.DesktopStyle.px(8) }
    implicitWidth: Shared.DesktopStyle.px(420)
    implicitHeight: Math.min(cards.implicitHeight, screen ? screen.height - Shared.DesktopStyle.px(100) : Shared.DesktopStyle.px(700))
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-action-notifications"
    WlrLayershell.keyboardFocus: hover.hovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function clear() {
        if (snapshot === "") return
        snapshot = ""
        rows = []
    }
    function hasAction(row) {
        return row && row.actions && Object.keys(row.actions).length > 0
    }
    function refresh() { if (!debounce.running) debounce.start() }
    Timer {
        id: debounce
        interval: 80
        onTriggered: {
            if (read.running) root.refreshQueued = true
            else if (probe.running) root.refreshQueued = true
            else probe.running = true
        }
    }
    FileView {
        id: marker
        path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/oninix-mako-notify" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); root.refresh() }
        onLoadFailed: root.markerReady = false
        onLoaded: {
            if (root.markerReady) return
            root.markerReady = true
            root.refresh()
        }
    }
    Component.onCompleted: refresh()
    Timer { interval: root.rows.length ? 2000 : root.markerReady ? 15000 : 3000; running: true; repeat: true; onTriggered: root.refresh() }
    Connections { target: DesktopData; function onActionDone(name) { root.refresh() } }
    Process {
        id: probe
        command: ["makoctl", "list", "-j"]
        onExited: if (!read.running && root.refreshQueued) {
            root.refreshQueued = false
            root.refresh()
        }
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
        onExited: {
            if (!marker.loaded) marker.reload()
            if (root.refreshQueued) {
                root.refreshQueued = false
                root.refresh()
            }
        }
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
            spacing: Shared.DesktopStyle.px(8)
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
