pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool opened: false
    property bool ready: false
    property var request: null
    readonly property bool busy: !!(request && request.op !== "status") || queue.length > 0
    property string error: ""
    property var data: ({jobs:[], settings:{}, models:{}, devices:[], download:{}})
    property var detail: ({})
    property var settings: ({})
    property var devices: []
    property var history: []
    property var queue: []
    readonly property var active: data.jobs.find(j => ["recording", "paused"].includes(j.state)) || null
    property int sequence: 0
    function send(value) {
        request = Object.assign({}, value, {requestId: ++sequence})
        backend.write(JSON.stringify(request) + "\n")
    }
    function pump() {
        if (!ready || request || !queue.length) return
        send(queue[0])
        queue = queue.slice(1)
    }
    function call(value) {
        if (!ready) { error = "Meeting service is reconnecting. Try again in a moment."; return }
        if (value.op === "status") {
            if (!request && !queue.length) send(value)
            return
        }
        queue = queue.concat([value])
        pump()
    }
    function refresh() { call({op:"status"}) }
    function setting(key, value) { const settings = {}; settings[key] = value; call({op:"settings", settings:settings}) }
    function clock(seconds) {
        const value = Math.max(0, Math.floor(seconds || 0))
        return String(Math.floor(value / 3600)).padStart(2,"0") + ":" + String(Math.floor(value / 60) % 60).padStart(2,"0") + ":" + String(value % 60).padStart(2,"0")
    }
    Process {
        id: backend
        running: true; stdinEnabled: true
        command: ["oninix-meetings"]
        onStarted: { root.ready = true; root.refresh() }
        stdout: SplitParser { onRead: line => {
            try {
                const reply = JSON.parse(line), request = root.request
                if (!request || request.requestId !== reply.requestId) return
                if (!reply.ok) {
                    root.error = reply.message
                } else {
                    if (request.op !== "status") root.error = ""
                    if (request.op === "detail") {
                        root.detail = reply.data
                    } else if (["publish", "tasks"].includes(request.op)) {
                        root.error = "Saved in Obsidian"
                        Qt.callLater(root.refresh)
                    } else {
                        const finished = reply.data.jobs.filter(j => !["recording", "paused"].includes(j.state))
                        if (JSON.stringify(root.data) !== JSON.stringify(reply.data)) root.data = reply.data
                        if (JSON.stringify(root.history) !== JSON.stringify(finished)) root.history = finished
                        if (JSON.stringify(root.settings) !== JSON.stringify(reply.data.settings)) root.settings = reply.data.settings
                        if (JSON.stringify(root.devices) !== JSON.stringify(reply.data.devices)) root.devices = reply.data.devices
                    }
                }
            } catch (_) { root.error = "Meeting response could not be read." }
            root.request = null
            root.pump()
        } }
        onExited: { root.ready = false; root.request = null; root.queue = []; reconnect.restart() }
    }
    Timer { id: reconnect; interval: 2000; onTriggered: backend.running = true }
    Timer { interval: root.opened || root.active ? 1000 : 15000; repeat: true; running: root.ready; onTriggered: root.refresh() }
    onOpenedChanged: if (opened) refresh()
}
