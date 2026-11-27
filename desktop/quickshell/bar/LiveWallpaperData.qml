pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "LiveWallpaper.js" as Live

Singleton {
    id: root
    property bool open: false
    property bool serviceChecked: false
    property bool servicePresent: false
    property bool serviceRunning: false
    property string customizeId: ""
    property var status: ({})
    property string statusError: ""
    property string actionError: ""
    readonly property string statusText: statusError || Live.statusText(status)
    readonly property bool busy: action.pending
    readonly property var properties: status.mode === "live" && Array.isArray(status.item?.properties)
        ? status.item.properties : []
    readonly property bool customizing: !!customizeId && status.item?.id === customizeId && properties.length > 0
    property int revision: 0
    signal libraryChanged()

    onOpenChanged: if (!open) customizeId = ""
    onServicePresentChanged: if (!servicePresent) open = false
    onStatusChanged: {
        if (customizeId && (status.mode !== "live" || status.item?.id !== customizeId
            || !status.item?.properties?.length))
            customizeId = ""
    }

    function openCustomize() {
        if (!properties.length) return
        customizeId = status.item.id
        open = true
    }

    function refresh() {
        if (!service.running) service.running = true
        if (statusRead.pending || busy) return
        statusRead.revision = revision
        statusRead.run(["status"])
    }

    function run(args, itemId = args[1] || "") {
        if (busy) return
        actionError = ""
        if (args[0] === "set" && args[1] === "live" && !serviceRunning) {
            actionError = "The live wallpaper service is unavailable."
            return
        }
        if (["set", "place", "prop", "mark"].includes(args[0])) revision++
        action.itemId = itemId
        action.run(args)
    }

    function place(itemId, options) {
        if (itemId && status.mode === "live" && status.item?.id === itemId)
            run(["place", itemId].concat(options))
    }

    function customize(key, value) {
        if (customizing)
            run(Live.propertyArgs(customizeId, key, value), customizeId)
    }

    Process {
        id: service
        command: ["systemctl", "--user", "show", "--property=LoadState,ActiveState", "oninix-livewall.service"]
        stdout: StdioCollector {
            onStreamFinished: {
                const states = text.trim().split("\n")
                root.serviceRunning = states.includes("ActiveState=active")
                root.servicePresent = states.includes("LoadState=loaded")
                root.serviceChecked = states.some(state => state.startsWith("LoadState="))
            }
        }
    }

    LiveWallpaperRequest {
        id: statusRead
        property int revision: 0
        onFinished: raw => {
            const result = Live.plain(raw)
            if (revision !== root.revision) {
                Qt.callLater(root.refresh)
                return
            }
            if (result.mode === "static" || result.mode === "live") {
                root.status = result
                root.statusError = ""
            } else {
                root.statusError = result.error || "Invalid live wallpaper status"
            }
        }
    }

    LiveWallpaperRequest {
        id: action
        property string itemId: ""
        onFinished: raw => {
            const result = Live.plain(raw)
            root.actionError = result.error || ""
            const verb = command[1]
            const field = {place: "placement", prop: "properties", mark: "broken"}[verb]
            if (field) {
                if (result.error) return
                const valid = verb === "place" ? !!result.placement
                    : verb === "prop" ? Array.isArray(result.properties) : typeof result.broken === "boolean"
                if (result.id !== itemId || !valid) {
                    root.actionError = "Invalid live wallpaper " + field
                    root.refresh()
                } else if (root.status.item?.id === result.id) {
                    const item = Object.assign({}, root.status.item, {[field]: result[field]})
                    root.status = Object.assign({}, root.status, {item: item})
                }
                if (verb === "mark") root.libraryChanged()
                return
            }
            if (verb !== "set") return
            if (result.mode === "static" || result.mode === "live") {
                root.actionError = ""
                root.status = result
                root.statusError = ""
            } else {
                root.actionError = result.error || "Invalid live wallpaper status"
                root.refresh()
            }
        }
    }
}
