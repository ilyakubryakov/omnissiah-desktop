pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({family: "papirus", icons: {}, families: []})
    readonly property var apps: {
        const out = {}
        for (const e of DesktopEntries.applications.values) if (!e.noDisplay) out[e.id] = e
        return out
    }
    function icon(entry) {
        if (!entry) return ""
        return data.icons[entry.icon || ""] || (Quickshell.iconPath(entry.icon || "", true) || Quickshell.iconPath("application-x-executable"))
    }
    function refresh() { delay.restart() }
    onAppsChanged: refresh()
    Component.onCompleted: refresh()
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/icon-theme"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); root.refresh() }
    }
    Timer { id: delay; interval: 150; onTriggered: {
        if (resolve.running) restart()
        else resolve.running = true
    } }
    Process {
        id: resolve
        command: [Quickshell.env("HOME") + "/.local/bin/theme", "icons-resolve"]
        stdinEnabled: true
        onStarted: { write(JSON.stringify(Object.values(root.apps).map(e => e.icon || ""))); stdinEnabled = false }
        onExited: stdinEnabled = true
        stdout: StdioCollector { onStreamFinished: {
            try { root.data = JSON.parse(text) } catch (e) { console.warn("Icon catalog:", e) }
        } }
    }
}
