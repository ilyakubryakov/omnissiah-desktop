pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Daily update assessment (owner decision 2026-11-08). The hourly
// oninix-maintenance-reminder timer checks at most once a day; the panel
// only reads its cached answer: current, available (no rush) or due.
Singleton {
    id: root
    property var result: ({})
    property var maintenance: ({})
    property string error: ""
    readonly property string helper: "oninix-maintenance"
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
    readonly property bool checking: checkProcess.running || maintenance.checkRunning === true
    readonly property bool sessionOpen: maintenance.sessionOpen === true
    readonly property string agent: maintenance.agent || "claude"
    readonly property string agentLabel: agent === "codex" ? "Codex" : "Claude"
    property double clock: Date.now() / 1000
    readonly property var assessment: result.assessment || ({})
    readonly property var items: result.items || []
    // Older caches have no assessment; treat them as not yet checked.
    readonly property bool stale: !result.checkedAt || !result.assessment || clock - result.checkedAt > 2 * 86400
    readonly property string level: checking ? "checking" : error ? "error" : stale ? "stale" : assessment.level || "stale"
    readonly property int count: assessment.count || 0
    readonly property var reasons: assessment.reasons || []
    readonly property var unreachable: assessment.unreachable || []
    readonly property string blocker: assessment.blocker || ""
    readonly property var nix: items.find(i => i.kind === "nix") || ({})
    readonly property var available: items.filter(i => i.status === "available" && i.kind !== "nix" && i.kind !== "input")
    readonly property var packages: nix.changes || []
    readonly property string summary: level === "checking" ? "Checking for updates…"
        : level === "error" ? error : level === "stale" ? "Not checked yet" : assessment.summary || ""
    readonly property string stamp: result.checkedAt
        ? Qt.formatDateTime(new Date(result.checkedAt * 1000), "dd MMM HH:mm") : "Never"
    property double checkStarted: 0
    function check() {
        if (checking || sessionOpen) return
        error = ""
        checkStarted = Date.now() / 1000
        checkProcess.running = true
    }
    function launch() {
        if (checking || sessionOpen || launchProcess.running) return
        error = ""
        launchProcess.command = [helper, "launch", "auto"]
        launchProcess.running = true
    }
    FileView {
        id: cache
        path: root.stateHome + "/oninix/updates-check.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.result = JSON.parse(text()) } catch (_) { root.error = "Update check cache unreadable" } }
    }
    Timer {
        interval: root.checking ? 5000 : 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { root.clock = Date.now() / 1000; if (!statusProcess.running) statusProcess.running = true }
    }
    Process {
        id: statusProcess
        command: [root.helper, "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.maintenance = JSON.parse(text) } catch (_) {} } }
    }
    Process {
        id: checkProcess
        command: [root.helper, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text)
                    if (value.error) root.error = value.error
                    else root.result = value
                } catch (_) { root.error = "Update check failed; previous result retained" }
            }
        }
        onExited: code => {
            if (code !== 0 && !root.error) root.error = "Update check failed; previous result retained"
            root.clock = Date.now() / 1000
            cache.reload()
        }
    }
    Process {
        id: launchProcess
        stdout: StdioCollector { onStreamFinished: { try { root.error = JSON.parse(text).error || "" } catch (_) {} } }
        onExited: statusProcess.running = true
    }
}
