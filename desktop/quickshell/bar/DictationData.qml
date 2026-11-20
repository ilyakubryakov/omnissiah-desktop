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
    property var data: ({phase:"idle", settings:{}, devices:[], download:{}, text:"", message:""})
    property var settings: ({})
    property var devices: []
    property var queue: []
    readonly property bool active: ["recording", "transcribing", "cancelling"].includes(data.phase)
    property int sequence: 0
    property var requests: ({})
    function call(value) {
        if (!ready) { error = "Dictation service is reconnecting. Try again in a moment."; return }
        if (pending) { if (value.op !== "status") queue = queue.concat([value]); return }
        value.requestId = ++sequence
        requests[value.requestId] = value
        pending = true
        backend.write(JSON.stringify(value) + "\n")
    }
    function refresh() { call({op:"status"}) }
    function setting(key, value) { const settings = {}; settings[key] = value; call({op:"settings", settings:settings}) }
    Process {
        id: backend
        running: true; stdinEnabled: true
        command: ["oninix-dictation"]
        onStarted: { root.ready = true; root.refresh() }
        stdout: SplitParser { onRead: line => {
            try {
                const reply = JSON.parse(line), request = root.requests[reply.requestId]
                delete root.requests[reply.requestId]; root.pending = false
                if (root.queue.length) { const next = root.queue[0]; root.queue = root.queue.slice(1); Qt.callLater(() => root.call(next)) }
                if (!reply.ok) { root.error = reply.message; return }
                if (!request) return
                if (request.op !== "status") root.error = ""
                {
                    root.data = reply.data
                    if (JSON.stringify(root.settings) !== JSON.stringify(reply.data.settings)) root.settings = reply.data.settings
                    if (JSON.stringify(root.devices) !== JSON.stringify(reply.data.devices)) root.devices = reply.data.devices
                }
            } catch (_) { root.pending = false; root.error = "Dictation response could not be read." }
        } }
        onExited: { root.ready = false; root.pending = false; root.requests = ({}); reconnect.restart() }
    }
    Timer { id: reconnect; interval: 2000; onTriggered: backend.running = true }
    Timer { interval: root.active ? 250 : 500; repeat: true; running: root.ready; onTriggered: root.refresh() }
    onOpenedChanged: if (opened) refresh()
}
