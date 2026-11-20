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
    // The briefing is the default; right-click on the lower-left group shows the player.
    property bool preferBriefing: true
    onPlayerChanged: if (!player) preferBriefing = true
    function toggleView() { if (player) preferBriefing = !preferBriefing }
    readonly property bool active: player === null || preferBriefing
    property var usage: []
    property var clusters: []
    property double clock: Date.now() / 1000
    readonly property var providers: [
        { id: 'codex', label: 'Codex', glyph: '\u{EC81}' },
        { id: 'claude', label: 'Claude', glyph: '\u{EC82}' },
        { id: 'opencode', label: 'OpenCode', glyph: '\u{F0121}' },
        { id: 'ollama', label: 'Ollama', glyph: '\u{F06A9}' },
        { id: 'google', label: 'Google agents', glyph: '\u{F0D5}' }
    ]
    readonly property var chipProviders: providers.slice(0, 2)
    readonly property var targets: [{ id: 'home', label: 'Home K8s' }, { id: 'prod', label: 'Balancy Prod' }]
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
    property var laptopBackup: ({})
    property var vmBackup: ({})
    property var collectedBackups: []
    readonly property var backupRows: {
        const rows = collectedBackups.map(row => row.id === 'vms' && vmBackup.kind === 'vms'
            ? Object.assign({}, row, {result: vmBackup.result, guests: vmBackup.guests, lastSuccess: vmBackup.lastSuccess}) : row)
        if (laptopBackup.lastSuccess || laptopBackup.lastFailure)
            rows.push(Object.assign({id: 'laptop', label: 'System and home', source: 'Laptop',
                note: 'Hourly on AC, unmetered network and reachable homelab. Keeps 24 hourly, 14 daily, 8 weekly and 6 monthly versions.'}, laptopBackup))
        return rows
    }
    function backupRowLevel(row) {
        if (row.result === 'failed') return 'bad'
        if (row.result === 'partial') return 'late'
        if (row.stale || row.result === 'unknown' || !row.lastSuccess
            || (row.metricsAt && clock - row.metricsAt > 7200)) return 'unknown'
        if (clock - row.lastSuccess > 3 * 86400) return 'bad'
        if (clock - row.lastSuccess > 26 * 3600) return 'late'
        return 'ok'
    }
    readonly property bool backupKnown: backupRows.length > 0
    readonly property bool backupPartial: backupRows.some(row => row.result === 'partial')
    readonly property bool backupFailed: backupRows.some(row => row.result === 'failed')
    readonly property bool backupUnknown: backupRows.some(row => backupRowLevel(row) === 'unknown')
    readonly property real backupAge: backupRows.reduce((age, row) => Math.max(age,
        row.lastSuccess ? clock - row.lastSuccess : Infinity), 0)
    readonly property string backupLevel: backupRows.some(row => backupRowLevel(row) === 'bad') ? 'bad'
        : backupRows.some(row => backupRowLevel(row) !== 'ok') ? 'late' : 'ok'
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
        if (!backupFetch.running) backupFetch.running = true
    }
    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (active) refresh()
    // watchChanges cannot see a status file created after startup; re-read it with the clock.
    Timer { interval: 30000; running: true; repeat: true; onTriggered: { root.clock = Date.now() / 1000; backupFile.reload(); vmBackupFile.reload(); if (root.active && !backupFetch.running) backupFetch.running = true } }
    // One collector shared by both monitors. The helper caches and rate-limits requests.
    Timer { interval: 120000; running: root.active; repeat: true; onTriggered: if (!usageFetch.running) usageFetch.running = true }
    Timer { interval: 120000; running: root.active; repeat: true; onTriggered: if (!clusterFetch.running) clusterFetch.running = true }
    FileView {
        id: backupFile
        path: '/var/lib/laptop-backup-status/status.json'
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); root.laptopBackup = d && typeof d === 'object' ? d : {} } catch (_) {} }
    }
    FileView {
        id: vmBackupFile
        path: '/var/lib/oninix-backup-status/vms.json'
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.vmBackup = JSON.parse(text()) } catch (_) {} }
    }
    Process {
        id: backupFetch
        command: ['oninix-briefing', 'backups']
        stdout: StdioCollector { onStreamFinished: {
            try { root.collectedBackups = JSON.parse(text).backups || [] } catch (_) {
                root.collectedBackups = root.collectedBackups.map(row => Object.assign({}, row, {stale: true}))
            }
        } }
        onExited: code => { if (code !== 0) root.collectedBackups = root.collectedBackups.map(row => Object.assign({}, row, {stale: true})) }
    }
    Process {
        id: usageFetch
        command: ['oninix-briefing', 'ai']
        stdout: StdioCollector { onStreamFinished: {
            try { root.usage = JSON.parse(text).providers || [] } catch (_) { root.usage = root.usage.map(p => Object.assign({}, p, { stale: true, error: 'Usage update unavailable' })) }
        } }
        onExited: code => { if (code !== 0) root.usage = root.usage.map(p => Object.assign({}, p, { stale: true, error: 'Usage update unavailable' })) }
    }
    Process {
        id: clusterFetch
        command: ['oninix-briefing', 'clusters']
        stdout: StdioCollector { onStreamFinished: {
            try { root.clusters = JSON.parse(text).clusters || [] } catch (_) { root.clusters = root.clusters.map(c => Object.assign({}, c, { stale: true, error: 'Status update unavailable' })) }
        } }
        onExited: code => { if (code !== 0) root.clusters = root.clusters.map(c => Object.assign({}, c, { stale: true, error: 'Status update unavailable' })) }
    }
}
