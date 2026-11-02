pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property var ids: []
    property bool loaded: false
    property string pending: ""
    signal settingsRequested()
    readonly property var visibleIds: ids.filter(id => !!AppIcons.apps[id])
    function contains(id) { return ids.includes(id) }
    function save() { pending = JSON.stringify({ids: ids}); delay.restart() }
    function toggle(id) {
        if (!loaded || (!contains(id) && !AppIcons.apps[id])) return
        if (!contains(id) && ids.length >= 100) { DesktopData.error = "The panel supports up to 100 pinned apps."; return }
        ids = contains(id) ? ids.filter(i => i !== id) : ids.concat([id]); save()
    }
    function move(id, target, after) {
        if (id === target || !ids.includes(id) || !ids.includes(target)) return
        const next = ids.filter(i => i !== id)
        next.splice(next.indexOf(target) + (after ? 1 : 0), 0, id)
        ids = next; save()
    }
    function launch(id) {
        if (!Minimized.activate(id)) start(id)
    }
    function start(id) {
        const e = AppIcons.apps[id]
        if (!e) return
        if (e.runInTerminal)
            Hypr.exec("kitty -e " + e.command.map(a => "'" + a.replace(/'/g, "'\\''") + "'").join(" "))
        else
            Hypr.exec("'" + (id + ".desktop").replace(/'/g, "'\\''") + "'")
    }
    function seed() {
        const defaults = ["kitty", "org.kde.dolphin", "firefox", "org.mozilla.firefox", "org.kde.kate"]
        ids = defaults.map(wanted => Object.keys(AppIcons.apps).find(id => id === wanted)).filter(Boolean)
        if (!ids.length) { seedDelay.restart(); return }
        loaded = true; save()
    }
    Timer { id: seedDelay; interval: 500; onTriggered: root.seed() }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/launchers.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                if (!Array.isArray(d.ids)) throw new Error("Invalid launchers")
                root.ids = [...new Set(d.ids.filter(i => typeof i === "string"))]; root.loaded = true
            } catch (_) { DesktopData.error = "Could not read pinned apps. Existing preferences were kept." }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) seedDelay.start()
            else DesktopData.error = "Could not read pinned apps. Check access to your settings."
        }
    }
    Timer { id: delay; interval: 120; onTriggered: {
        if (writer.running) { restart(); return }
        writer.command = [DesktopData.helper, "appearance", "launchers", root.pending]
        root.pending = ""; writer.running = true
    } }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: {
            try { const d = JSON.parse(text); if (d.error) DesktopData.error = d.error } catch (_) {}
        } }
        onExited: (code, status) => {
            if (code !== 0) DesktopData.error = "Could not save pinned apps. Try moving an icon again."
            if (root.pending) delay.restart()
        }
    }
}
