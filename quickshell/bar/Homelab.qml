pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string url: Integrations.prometheus + "/api/v1/query?query="
        + encodeURIComponent('ALERTS{alertstate="firing"}')
    property bool reachable: false
    property var alerts: []

    property var host: ({})
    property string hostError: ""
    property double now: Date.now()
    property double attemptedAt: 0
    readonly property bool hostLoading: snapshot.running
    readonly property bool hostFresh: !!host.updatedAt && !host.stale && hostError === "" && now - host.updatedAt < 60000
    function readHost(force) {
        now = Date.now()
        if (!Integrations.telemetry || snapshot.running || (!force && now - attemptedAt < 15000)) return
        attemptedAt = now
        snapshot.running = true
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.now = Date.now() }

    Timer { interval: 60000; running: root.reachable; repeat: true; triggeredOnStart: true; onTriggered: root.readHost(false) }
    readonly property var fullestPool: (host.disks || []).filter(d => d.pool).reduce((m, d) => !m || d.pct > m.pct ? d : m, null)

    readonly property string level: {
        if (!hostFresh) return reachable && alerts.length ? "warn" : ""
        const disks = host.disks || [], drives = host.drives || []
        if (host.up === false || alerts.some(a => a.severity === "critical")
            || disks.some(d => d.health && d.health !== "online") || drives.some(d => d.ok === false)) return "bad"
        if (alerts.length || disks.some(d => d.pct >= 85) || host.ups?.onBattery
            || drives.some(d => d.tempC >= (d.kind === "hdd" ? 55 : 75)) || host.temp >= 85) return "warn"
        return "ok"
    }
    property bool timedOut: false
    Timer { id: deadline; interval: 15000; onTriggered: { root.timedOut = true; snapshot.running = false; root.hostError = "Server request timed out" } }
    Process {
        id: snapshot
        command: ["curl", "-fsS", "--max-time", "10", Integrations.telemetry]
        onStarted: { root.timedOut = false; deadline.restart() }
        stdout: StdioCollector { onStreamFinished: {
            try {
                const value = JSON.parse(text)
                if (value.error) root.hostError = value.error
                else { root.host = value; root.hostError = ""; root.now = Date.now() }
            } catch (_) { if (!root.timedOut) root.hostError = "Homeserver telemetry unavailable" }
        } }
        onExited: (code, status) => { deadline.stop(); if (code !== 0 && !root.timedOut) root.hostError = "Homeserver telemetry unavailable" }
    }

    property var request: null
    Timer { id: alertDeadline; interval: 6000; onTriggered: { if (root.request) root.request.abort(); root.request = null; root.reachable = false; root.alerts = [] } }
    function poll() {
        if (!Integrations.prometheus || request) return
        const xhr = new XMLHttpRequest()
        request = xhr
        alertDeadline.restart()
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            alertDeadline.stop()
            root.request = null
            try {
                if (xhr.status !== 200) throw new Error("Unavailable")
                const rows = JSON.parse(xhr.responseText).data.result
                root.alerts = rows.map(r => ({
                    name: r.metric.alertname || "alert",
                    severity: r.metric.severity || "",
                    target: r.metric.instance || r.metric.pod || r.metric.job || ""
                }))
                root.reachable = true
            } catch (e) {
                root.reachable = false
                root.alerts = []
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    Timer {
        interval: 60000
        running: Integrations.prometheus !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
