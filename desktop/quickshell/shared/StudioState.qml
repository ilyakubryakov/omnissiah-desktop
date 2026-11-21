pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property int users: 0
    property var data: ({settings:{}, nodes:[], midi:[]})
    property string error: ""
    readonly property bool busy: action.running
    readonly property string helper: "oninix-audio"
    function refresh() { if (!read.running) read.running = true }
    function setQuantum(value) {
        if (busy) return
        error = ""
        action.command = [helper, "quantum", String(value)]
        action.running = true
    }
    onUsersChanged: if (users > 0) refresh()
    Timer { interval: 5000; repeat: true; running: root.users > 0; onTriggered: root.refresh() }
    Process {
        id: read; command: [root.helper, "status"]
        stdout: StdioCollector { onStreamFinished: {
            try { const next = JSON.parse(text); if (next.error) { root.error = next.error; root.data = ({settings:{},nodes:[],midi:[]}) } else { root.data = next; root.error = "" } }
            catch (_) { root.error = "Audio telemetry unavailable"; root.data = ({settings:{},nodes:[],midi:[]}) }
        } }
    }
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: { try { const next = JSON.parse(text); if (next.error) root.error = next.error } catch (_) { root.error = "Audio action failed" } } }
        onExited: if (exitCode === 0) root.refresh()
    }
}
