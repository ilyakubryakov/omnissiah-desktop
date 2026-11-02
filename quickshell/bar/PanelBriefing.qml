pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => p.trackTitle)
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing)
            || ps.find(p => p.playbackState === MprisPlaybackState.Paused) || null
    }

    property bool preferBriefing: false
    onPlayerChanged: if (!player) preferBriefing = false
    function toggleView() { if (player) preferBriefing = !preferBriefing }
    readonly property bool active: player === null || preferBriefing
    property var usage: []
    property var clusters: []
    property double clock: Date.now() / 1000
    readonly property var providers: [
        { id: 'codex', label: 'Codex', glyph: '\u{EC81}' },
        { id: 'claude', label: 'Claude', glyph: '\u{EC82}' }
    ].filter(p => Integrations.ai.includes(p.id))
    readonly property var targets: Integrations.clusters
    function provider(id) { return usage.find(p => p.id === id) || {} }
    function tightest(data) {
        return (data.windows || []).reduce((best, w) => !best || w.usedPercent > best.usedPercent ? w : best, null)
    }
    function period(minutes) {
        if (!minutes) return 'Quota'
        if (minutes % 1440 === 0) return (minutes / 1440) + 'd'
        if (minutes % 60 === 0) return (minutes / 60) + 'h'
        return minutes + 'm'
    }
    function usageStale(data) {
        return stale(data, 300) || (data.windows || []).some(w => w.resetsAt && w.resetsAt <= clock)
    }
    function resetText(window) {
        if (!window.resetsAt) return 'Reset time unavailable'
        const mins = Math.ceil((window.resetsAt - clock) / 60)
        if (mins <= 0) return 'Reset due · waiting for an update'
        const left = mins >= 1440 ? Math.floor(mins / 1440) + 'd ' + Math.floor(mins % 1440 / 60) + 'h'
            : mins >= 60 ? Math.floor(mins / 60) + 'h ' + mins % 60 + 'm' : mins + 'm'
        return 'Resets in ' + left + ' · ' + Qt.formatDateTime(new Date(window.resetsAt * 1000), 'ddd HH:mm')
    }
    function cluster(id) { return clusters.find(c => c.id === id) || {} }

    property var backup: ({})
    readonly property bool backupKnown: !!(backup.lastSuccess || backup.lastFailure)
    readonly property bool backupFailed: backup.result === 'failed' && (backup.lastFailure || 0) > (backup.lastSuccess || 0)
    readonly property real backupAge: backup.lastSuccess ? clock - backup.lastSuccess : Infinity
    readonly property string backupLevel: !backupKnown ? '' : backupFailed || backupAge > 3 * 86400 ? 'bad'
        : backupAge > 26 * 3600 ? 'late' : 'ok'
    function ago(seconds) {
        if (!isFinite(seconds)) return 'never'
        if (seconds < 3600) return Math.max(1, Math.round(seconds / 60)) + 'm'
        if (seconds < 172800) return Math.round(seconds / 3600) + 'h'
        return Math.round(seconds / 86400) + 'd'
    }
    function when(epoch) { return epoch ? Qt.formatDateTime(new Date(epoch * 1000), 'ddd dd MMM HH:mm') : 'never' }
    function stale(data, seconds) { return !data.updatedAt || data.stale === true || clock - data.updatedAt > seconds }
    function stamp(data) { return data.updatedAt ? Qt.formatDateTime(new Date(data.updatedAt * 1000), 'dd MMM HH:mm') : 'Not checked yet' }
    function refresh() {
        if (!usageFetch.running) usageFetch.running = true
        if (!clusterFetch.running) clusterFetch.running = true
    }
    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (active) refresh()

    Timer { interval: 30000; running: true; repeat: true; onTriggered: { root.clock = Date.now() / 1000; backupFile.reload() } }

    Timer { interval: 120000; running: root.active; repeat: true; onTriggered: if (!usageFetch.running) usageFetch.running = true }
    Timer { interval: 120000; running: root.active; repeat: true; onTriggered: if (!clusterFetch.running) clusterFetch.running = true }
    FileView {
        id: backupFile
        path: '/var/lib/laptop-backup-status/status.json'
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); root.backup = d && typeof d === 'object' ? d : {} } catch (_) {} }
    }
    Process {
        id: usageFetch
        command: [Quickshell.env('HOME') + '/.local/bin/station-briefing', 'ai']
        stdout: StdioCollector { onStreamFinished: {
            try { root.usage = JSON.parse(text).providers || [] } catch (_) { root.usage = root.usage.map(p => Object.assign({}, p, { stale: true, error: 'Usage update unavailable' })) }
        } }
        onExited: code => { if (code !== 0) root.usage = root.usage.map(p => Object.assign({}, p, { stale: true, error: 'Usage update unavailable' })) }
    }
    Process {
        id: clusterFetch
        command: [Quickshell.env('HOME') + '/.local/bin/station-briefing', 'clusters']
        stdout: StdioCollector { onStreamFinished: {
            try { root.clusters = JSON.parse(text).clusters || [] } catch (_) { root.clusters = root.clusters.map(c => Object.assign({}, c, { stale: true, error: 'Status update unavailable' })) }
        } }
        onExited: code => { if (code !== 0) root.clusters = root.clusters.map(c => Object.assign({}, c, { stale: true, error: 'Status update unavailable' })) }
    }
}
