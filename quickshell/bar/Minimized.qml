pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "MinimizedLogic.js" as Logic

Singleton {
    id: root
    property var order: ({})
    property int sequence: 0
    property var urgent: ({})
    property var unread: ({})
    readonly property var windows: Hypr.clients.filter(c => Logic.isMinimized(c))
    readonly property var extraIds: Logic.extraIds(windows, PinnedApps.visibleIds, AppIcons.apps, order)

    function valid(c) { return !!c && /^0x[0-9a-f]+$/i.test(c.address) }
    function isMinimized(c) { return Logic.isMinimized(c) }
    function windowsOf(id) {
        return Hypr.clients.filter(c => valid(c) && c.mapped !== false && Logic.matches(id, c, AppIcons.apps)
            && (Logic.isMinimized(c) || Logic.isVisible(c)))
    }
    function minimizedOf(id) { return windowsOf(id).filter(Logic.isMinimized) }
    function visibleOf(id) { return windowsOf(id).filter(Logic.isVisible) }

    function listOf(id) {
        const all = windowsOf(id)
        return all.filter(Logic.isVisible).sort((a, b) => a.focusHistoryID - b.focusHistoryID)
            .concat(all.filter(Logic.isMinimized).sort((a, b) => Logic.rank(a, order) - Logic.rank(b, order)))
    }
    function isUrgent(id) { return minimizedOf(id).some(c => urgent[c.address]) }
    function badge(id) { return Logic.badge(id, unread) }
    function title(c) { return c.title || c["class"] || "Window" }

    function lua(call, address) {
        if (!/^0x[0-9a-f]+$/i.test(address)) return
        Quickshell.execDetached(["hyprctl", "eval", "require(\"minimize\")." + call + "(\"address:" + address + "\")"])
        Hypr.refresh()
    }
    function minimize(c) { if (valid(c)) lua("minimize", c.address) }
    function close(c) { if (valid(c)) lua("close", c.address) }
    function show(c) {
        if (!valid(c)) return
        if (urgent[c.address]) { const u = Object.assign({}, urgent); delete u[c.address]; urgent = u }
        lua("show", c.address)
    }
    function minimizeApp(id) { const v = visibleOf(id); if (v.length) lua("minimize_app", v[0].address) }
    function closeApp(id) { for (const c of windowsOf(id)) close(c) }

    function activate(id) {
        const c = Logic.pick(windowsOf(id), order)
        if (c) show(c)
        return !!c
    }

    onWindowsChanged: {
        const next = Logic.updateOrder(order, sequence, windows)
        sequence = next.sequence; order = next.order
        const u = {}
        for (const c of windows) if (urgent[c.address]) u[c.address] = true
        if (Object.keys(u).length !== Object.keys(urgent).length) urgent = u
    }

    FileView {
        id: unreadFile
        property bool ok: false
        path: Quickshell.env("HOME") + "/.cache/comms-unread.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.unread = JSON.parse(text()); ok = true } catch (_) {} }
        onLoadFailed: { root.unread = ({}); ok = false }
    }
    Timer { interval: 30000; repeat: true; running: !unreadFile.ok; onTriggered: unreadFile.reload() }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "minimized") {
                const [raw, state] = event.data.split(",")
                const address = "0x" + raw.replace(/^0x/, "")
                if (state === "1") root.lua("minimize", address)
                else if (state === "0" && root.windows.some(c => c.address === address)) root.lua("show", address)
            } else if (event.name === "urgent") {
                const address = "0x" + event.data.replace(/^0x/, "")
                if (root.windows.some(c => c.address === address)) {
                    const u = Object.assign({}, root.urgent); u[address] = true; root.urgent = u
                }
            }
        }
    }
}
