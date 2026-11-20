pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool opened: false
    property bool ready: false
    property bool pending: false
    property string error: ""
    property var data: ({jobs:[], settings:{}, models:{}, devices:[], download:{}})
    property var detail: ({})
    property var settings: ({})
    property var devices: []
    property var queue: []
    readonly property var active: data.jobs.find(j => ["recording", "paused"].includes(j.state)) || null
    property int sequence: 0
    property var requests: ({})
    function call(value) {
        if (!ready) { error = "Meeting service is reconnecting. Try again in a moment."; return }
        if (pending) { if (value.op !== "status") queue = queue.concat([value]); return }
        value.requestId = ++sequence
        requests[value.requestId] = value
        pending = true
        backend.write(JSON.stringify(value) + "\n")
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
                const reply = JSON.parse(line), request = root.requests[reply.requestId]
                delete root.requests[reply.requestId]; root.pending = false
                if (root.queue.length) { const next = root.queue[0]; root.queue = root.queue.slice(1); Qt.callLater(() => root.call(next)) }
                if (!reply.ok) { root.error = reply.message; return }
                if (!request) return
                if (request.op !== "status") root.error = ""
                if (request.op === "detail") root.detail = reply.data
                else if (["publish", "tasks"].includes(request.op)) { root.error = "Saved in Obsidian"; root.refresh() }
                else {
                    root.data = reply.data
                    if (JSON.stringify(root.settings) !== JSON.stringify(reply.data.settings)) root.settings = reply.data.settings
                    if (JSON.stringify(root.devices) !== JSON.stringify(reply.data.devices)) root.devices = reply.data.devices
                }
            } catch (_) { root.pending = false; root.error = "Meeting response could not be read." }
        } }
        onExited: { root.ready = false; root.pending = false; root.requests = ({}); reconnect.restart() }
    }
    Timer { id: reconnect; interval: 2000; onTriggered: backend.running = true }
    Timer { interval: root.opened || root.active ? 1000 : 15000; repeat: true; running: root.ready; onTriggered: root.refresh() }
    onOpenedChanged: if (opened) refresh()
}
