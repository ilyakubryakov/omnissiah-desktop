pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var accounts: []
    property var providers: ({google: false, microsoft: false})
    property double lastSync: 0
    property string error: ""
    property string message: ""
    property string authUrl: ""
    property string operation: ""
    property string payload: ""
    property bool opened: false
    readonly property bool busy: action.running
    readonly property bool signingIn: busy && operation === "connect"
    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/station-calendar"
    signal operationFinished(string operation)
    onOpenedChanged: if (opened) refresh()
    function accept(snapshot) {
        accounts = snapshot.accounts || []
        providers = snapshot.providers || ({})
        lastSync = snapshot.ts || 0
    }
    function refresh() { if (!read.running && !busy) read.running = true }
    function request(value) {
        if (busy) return
        error = ""; message = ""; authUrl = ""; operation = value.op
        payload = JSON.stringify(value)
        action.stdinEnabled = true; action.running = true
    }
    function cancel() {
        if (!signingIn) return
        action.running = false; payload = ""; authUrl = ""
        message = "Sign-in cancelled. Existing accounts were kept."
    }
    function select(account, calendar, selected) {
        const ids = account.calendars.filter(c => c.id === calendar ? selected : c.selected).map(c => c.id)
        request({op: "select", id: account.id, calendars: ids})
    }
    Process {
        id: read
        command: [root.helper, "--status"]
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result = JSON.parse(text)
                if (result.type === "done") root.accept(result.data)
                else root.error = result.message || "Calendar settings could not be read."
            } catch (_) { root.error = "Calendar settings could not be read." }
        } }
    }
    Process {
        id: action
        command: [root.helper]
        onStarted: { write(root.payload); root.payload = ""; stdinEnabled = false; deadline.restart() }
        stdout: SplitParser { onRead: line => {
            try {
                const result = JSON.parse(line)
                if (result.type === "browser") {
                    root.authUrl = result.url
                    root.message = "Finish sign-in in your browser. You can close Control Station and return here afterwards."
                    Qt.openUrlExternally(result.url)
                } else if (result.type === "done") {
                    root.accept(result.data)
                    root.message = root.operation === "connect" ? "Account connected. Choose which calendars to show below."
                        : root.operation === "setup" ? "App setup saved. You can now sign in."
                        : root.operation === "sync" ? "Sync requested. Status will update when it finishes."
                        : root.operation === "remove" ? "Account removed from Station. Provider permissions can be revoked in your account settings."
                        : "Calendar settings saved."
                    root.operationFinished(root.operation)
                } else if (result.type === "error") root.error = result.message
            } catch (_) { root.error = "The calendar helper returned an invalid response." }
        } }
        onExited: { deadline.stop(); root.authUrl = ""; root.refresh() }
    }
    Timer {
        id: deadline
        interval: root.signingIn ? 360000 : 90000
        onTriggered: { action.running = false; root.authUrl = ""; root.error = "The calendar operation timed out. Refresh the list and try again." }
    }
    Timer { interval: 5000; running: root.opened && !root.busy; repeat: true; onTriggered: root.refresh() }
}
