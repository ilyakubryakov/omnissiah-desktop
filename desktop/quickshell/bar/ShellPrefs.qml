pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "BarItemsLogic.js" as Items

Singleton {
    id: root
    property var favorites: ["network", "bluetooth", "dnd", "awake", "nightlight", "microphone"]
    property var layouts: ({primary: {top: ["launchers", "workspaces", "status"], bottom: ["media", "window", "metrics"], hidden: []}, secondary: {top: ["launchers", "workspaces", "status"], bottom: ["media", "window", "metrics"], hidden: []}})
    property var ui: ({last: "network", scroll: {}})
    property var items: Items.DEFAULTS
    readonly property var placed: Items.resolve(items, PinnedApps.visibleIds)
    property var looks: []
    property var devices: ({})
    property bool undoAvailable: false
    property string undoLabel: ""
    property string error: ""
    property bool loaded: false
    property bool editingPanels: false
    property string editRole: "primary"
    property string draggedGroup: ""
    property var queue: []
    readonly property bool busy: worker.running || queue.length > 0
    signal ready()
    signal changed()
    function accept(data) {
        if (data.error) { error = data.error; return }
        if (!data.prefs) return
        for (const key of ["favorites", "layouts", "ui", "items"])
            if (JSON.stringify(root[key]) !== JSON.stringify(data.prefs[key])) root[key] = data.prefs[key]
        for (const key of ["looks", "devices"])
            if (JSON.stringify(root[key]) !== JSON.stringify(data[key])) root[key] = data[key]
        undoAvailable = !!data.undo; undoLabel = data.undoLabel || ""
        if (!loaded) { loaded = true; ready() }
        changed()
    }
    function send(action, value) {
        const next = queue.slice()
        if (action === "ui") for (let i = next.length - 1; i >= 0; i--) if (next[i][0] === "ui") next.splice(i, 1)
        next.push([action, value]); queue = next; pump()
    }
    function refresh() { if (!busy) send("data", undefined) }
    function pump() {
        if (worker.running || !queue.length) return
        const next = queue.slice(), task = next.shift(); queue = next
        worker.command = [DesktopData.helper, "shell", task[0]]
        if (task[1] !== undefined) worker.command = worker.command.concat([JSON.stringify(task[1])])
        error = ""; worker.running = true
    }
    function moveFavorite(item, before) {
        const items = favorites.filter(i => i !== item), pos = items.indexOf(before)
        items.splice(pos < 0 ? items.length : pos, 0, item)
        send("favorites", items)
    }
    function toggleFavorite(item) {
        send("favorites", favorites.includes(item) ? favorites.filter(i => i !== item) : favorites.concat([item]))
    }
    function moveItem(token, group, before) {
        const next = Items.move(items, PinnedApps.visibleIds, token, group, before)
        if (Items.same(next, placed)) return
        items = next
        send("items", next)
    }
    function moveGroup(role, item, bar, before) {
        const layout = JSON.parse(JSON.stringify(layouts[role]))
        for (const edge of ["top", "bottom", "hidden"]) layout[edge] = layout[edge].filter(i => i !== item)
        const pos = layout[bar].indexOf(before)
        layout[bar].splice(pos < 0 ? layout[bar].length : pos, 0, item)
        send("layout", {role: role, layout: layout})
    }
    Component.onCompleted: refresh()
    Connections { target: DesktopData; function onActionDone(name) { if (name === "appearance") root.refresh() } }
    Process {
        id: worker
        stdout: StdioCollector { onStreamFinished: { try { root.accept(JSON.parse(text)) } catch (_) { root.error = "Could not read shell settings" } } }
        onExited: Qt.callLater(root.pump)
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/control-center.json"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); refreshDelay.restart() }
    }
    Timer { id: refreshDelay; interval: 150; onTriggered: root.refresh() }
}
