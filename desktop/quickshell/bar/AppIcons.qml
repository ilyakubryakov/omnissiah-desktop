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
        return data.icons[entry.icon || ""] || Quickshell.iconPath(entry.icon || "", "application-x-executable")
    }
    function windowEntry(cls) {
        const key = (cls || "").toLowerCase()
        if (!key.startsWith("chrome-") && !key.startsWith("crx_")) return null
        return Object.values(apps).find(e => e.startupClass && e.startupClass.toLowerCase() === key) || null
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
        command: ["oninix-theme", "icons-resolve"]
        stdinEnabled: true
        onStarted: { write(JSON.stringify(Object.values(root.apps).map(e => e.icon || ""))); stdinEnabled = false }
        onExited: stdinEnabled = true
        stdout: StdioCollector { onStreamFinished: {
            try { root.data = JSON.parse(text) } catch (e) { console.warn("Icon catalog:", e) }
        } }
    }
}
