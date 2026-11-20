pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var report: ({})
    property real clock: Date.now() / 1000
    readonly property bool running: fullCheck.running
    readonly property bool known: (report.results || []).length > 0
    readonly property bool stale: known && clock - (report.checked || 0) > 45 * 60
    readonly property string level: !known ? 'unknown' : stale ? 'stale' : report.level
    readonly property var issues: (report.results || []).filter(r => r.level !== 'ok')
    readonly property var rows: (report.results || []).slice().sort((a, b) => rank(b.level) - rank(a.level))
    readonly property var rebuild: report.rebuild || null
    readonly property var events: report.events || []

    function rank(level) { return { fail: 2, warn: 1 }[level] || 0 }
    function ago(seconds) {
        if (seconds < 90) return 'just now'
        if (seconds < 5400) return Math.round(seconds / 60) + ' min ago'
        if (seconds < 172800) return Math.round(seconds / 3600) + ' h ago'
        return Math.round(seconds / 86400) + ' d ago'
    }
    function runFull() { if (!fullCheck.running) fullCheck.running = true }

    property var fix: ({ status: 'idle' })
    readonly property string fixStatus: fix.status || 'idle'
    readonly property bool fixBusy: fixStatus === 'diagnosing' || fixStatus === 'fixing' || fixAction.running
    property string fixError: ''
    function fixRun(verb) {
        if (fixAction.running) return
        root.fixError = ''
        fixAction.command = ['oninix-doctor-fix', verb]
        fixAction.running = true
    }

    Timer { interval: 60000; running: true; repeat: true; onTriggered: { root.clock = Date.now() / 1000; cache.reload(); if (!fixStatusProcess.running) fixStatusProcess.running = true } }
    FileView {
        id: fixCache
        path: Quickshell.env('HOME') + '/.cache/oninix/doctor-fix.json'
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); if (d && typeof d === 'object') root.fix = d } catch (_) {} }
    }
    Process {
        id: fixStatusProcess
        running: true
        command: ['oninix-doctor-fix', 'status']
        stdout: StdioCollector { onStreamFinished: { try { const d = JSON.parse(text); if (d && typeof d === 'object') root.fix = d } catch (_) {} } }
    }
    Process {
        id: fixAction
        stderr: StdioCollector { onStreamFinished: root.fixError = text.trim() }
        onExited: { fixCache.reload(); fixStatusProcess.running = true }
    }
    FileView {
        id: cache
        path: Quickshell.env('HOME') + '/.cache/oninix/doctor.json'
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); if (d && typeof d === 'object') root.report = d } catch (_) {} }
    }
    Process {
        id: fullCheck
        command: ['oninix-doctor', '--cache']
        onExited: { root.clock = Date.now() / 1000; cache.reload() }
    }
}
