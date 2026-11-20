pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({})
    property double now: Date.now() / 1000
    readonly property bool fresh: data.ts !== undefined && now - data.ts >= -5 && now - data.ts < 25
    readonly property var local: fresh ? (data.local || {}) : ({})
    readonly property var gpu: local.gpu || ({})
    readonly property var ollama: fresh ? (data.ollama || {}) : ({})
    readonly property var comfy: fresh ? (data.comfy || {}) : ({})
    readonly property var vms: fresh ? (data.vms || {}) : ({})
    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/oninix-status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()) } catch (e) {} }
    }
    Timer {
        interval: 5000; running: Quickshell.env("ONINIX_LAPTOP") !== "1"; repeat: true; triggeredOnStart: true
        onTriggered: { root.now = Date.now() / 1000; file.reload() }
    }
}
