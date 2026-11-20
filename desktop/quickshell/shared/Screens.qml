pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var roles: ({})
    // Primary chosen in Control Center > Displays; port as last written by oninix-display.
    property string primaryOutput: ""
    function output(role) { return roles[role] || "" }
    function screen(role) {
        const name = output(role)
        return name ? Quickshell.screens.find(s => s.name === name) || null : null
    }
    // A docked laptop keeps the desktop on an external display (same rule as outputs.lua).
    readonly property var docked: {
        if (Quickshell.env("ONINIX_LAPTOP") !== "1") return null
        const outside = Quickshell.screens.filter(s => s.name !== output("main"))
            .sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0)
        return outside.find(s => s.name === primaryOutput) || outside[0] || null
    }
    readonly property var main: docked || (primaryOutput ? Quickshell.screens.find(s => s.name === primaryOutput) || null : null)
        || screen("main") || screen("vm")
        || Quickshell.screens.find(s => s.name !== output("edge") && s.name !== output("tv")) || null
    readonly property var edge: screen("edge")
    readonly property var tv: screen("tv")
    FileView {
        id: file
        path: Quickshell.env("ONINIX_LAPTOP") === "1" ? "/etc/oninix/monitors.conf" : Quickshell.env("HOME") + "/.config/oninix/monitors.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const next = {}; let role = ""
            for (const raw of text().split("\n")) {
                const line = raw.trim()
                const section = line.match(/^\[([\w_]+)\]$/)
                const field = line.match(/^output\s*=\s*(.*?)\s*$/)
                if (section) role = section[1]
                else if (field && role) next[role] = field[1]
            }
            root.roles = next
        }
    }
    // A file created after start is not watched yet; poll only while it is missing.
    property bool primaryMissing: false
    Timer { interval: 5000; running: root.primaryMissing; repeat: true; onTriggered: saved.reload() }
    FileView {
        id: saved
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/oninix/monitors.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: { root.primaryOutput = ""; root.primaryMissing = true }
        onLoaded: {
            let section = "", primary = ""
            for (const raw of text().split("\n")) {
                const line = raw.trim()
                const head = line.match(/^\[(.+)\]$/)
                const field = line.match(/^output\s*=\s*(.*?)\s*$/)
                if (head) section = head[1]
                else if (field && section === "primary") primary = field[1]
            }
            root.primaryOutput = primary; root.primaryMissing = false
        }
    }
}
