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
    property bool preferBriefing: true
    onPlayerChanged: if (!player) preferBriefing = true
    function toggleView() { if (player) preferBriefing = !preferBriefing }
    readonly property bool active: player === null || preferBriefing
    property var usage: []
    property double clock: Date.now() / 1000
    readonly property var providers: [
        { id: 'codex', label: 'Codex', glyph: '\u{EC81}' },
        { id: 'claude', label: 'Claude', glyph: '\u{EC82}' },
        { id: 'opencode', label: 'OpenCode', glyph: '\u{F0121}' },
        { id: 'ollama', label: 'Ollama', glyph: '\u{F06A9}' },
        { id: 'google', label: 'Google agents', glyph: '\u{F0D5}' }
    ]
    readonly property var chipProviders: providers.slice(0, 2)
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
    function stale(data, seconds) { return !data.updatedAt || data.stale === true || clock - data.updatedAt > seconds }
    function stamp(data) { return data.updatedAt ? Qt.formatDateTime(new Date(data.updatedAt * 1000), 'dd MMM HH:mm') : 'Not checked yet' }
    function refresh() {
        if (!usageFetch.running) usageFetch.running = true
    }
    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (active) refresh()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.clock = Date.now() / 1000 }
    Timer { interval: 120000; running: root.active; repeat: true; onTriggered: if (!usageFetch.running) usageFetch.running = true }
    Process {
        id: usageFetch
        command: ['oninix-briefing', 'ai']
        stdout: StdioCollector { onStreamFinished: {
            try { root.usage = JSON.parse(text).providers || [] } catch (_) { root.usage = root.usage.map(p => Object.assign({}, p, { stale: true, error: 'Usage update unavailable' })) }
        } }
        onExited: code => { if (code !== 0) root.usage = root.usage.map(p => Object.assign({}, p, { stale: true, error: 'Usage update unavailable' })) }
    }
}
