pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string page: ""
    property string controlTab: "quick"
    property bool open: false
    property bool notificationsOpen: false
    signal notificationsRequested()
    onOpenChanged: open ? markSeen() : cleanupDelay.restart()
    onPageChanged: markSeen()

    function markSeen() { if (open && page === "notifications") act("mark-seen") }
    property var appearance: ({ palettes: [], wallpaper: {}, schedule: {} })
    property bool wallpapersOpen: false
    property string wallpaperSlot: "shared"
    signal wallpapersRequested()
    function showWallpapers(slot) {
        wallpaperSlot = slot; wallpapersOpen = true; wallpapersRequested()
    }
    function readAppearance() { if (!appearanceRead.running) appearanceRead.running = true }
    property bool choosingFile: false
    property var controls: ({})
    readonly property var vpnProfiles: controls.vpns || []
    readonly property var activeVpns: vpnProfiles.filter(c => c.active === "yes")
    readonly property string vpnStatus: controls.vpns === null ? "Unavailable" : activeVpns.length ? activeVpns.map(c => c.name).join(", ") : vpnProfiles.length ? "Disconnected" : "No profiles"
    readonly property var tailscale: controls.tailscale || ({ state: "Loading", online: false, ips: [] })
    readonly property string tailscaleStatus: tailscale.online ? "Connected · " + (tailscale.ips || []).filter(ip => !ip.includes(":")).join(", ") : ({Loading:"Loading", NeedsLogin:"Sign-in required", NeedsMachineAuth:"Device approval required", Stopped:"Disconnected", Starting:"Connecting", Running:"Offline", NoState:"Starting", Unavailable:"Service unavailable"})[tailscale.state] || "Unavailable"
    property var notifications: ({ current: [], history: [] })
    property var clips: []
    property string error: ""
    readonly property bool busy: action.running
    readonly property int notificationCount: notifications.current.length
    readonly property int unreadCount: notifications.unread || 0
    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/station-desktop"
    signal actionDone(string name)

    property int brightnessTarget: -1
    property int brightnessQueued: -1
    function setBrightness(amount) {
        brightnessTarget = Math.max(5, Math.min(100, amount))
        brightnessQueued = brightnessTarget
        brightnessDelay.restart()
    }
    function flushBrightness() {
        if (brightnessWrite.running || brightnessQueued < 0) return
        brightnessWrite.command = [helper, "brightness", String(brightnessQueued)]
        brightnessQueued = -1
        brightnessWrite.running = true
    }
    Timer { id: brightnessDelay; interval: 80; onTriggered: root.flushBrightness() }
    Process {
        id: brightnessWrite
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (d.error) { root.error = d.error; root.brightnessTarget = -1 }
        } }
        onExited: {
            if (root.brightnessQueued >= 0) Qt.callLater(root.flushBrightness)
            else root.refresh()
        }
    }

    property var wifi: ({ device: null, enabled: false, networks: [] })
    property string wifiError: ""
    property bool scanning: false
    property string askSsid: ""
    readonly property bool networkOpen: open && page === "controls" && controlTab === "network"
    readonly property string joining: wifiJoin.running ? wifiJoin.ssid : ""
    onNetworkOpenChanged: {
        askSsid = ""; wifiError = ""
        if (networkOpen) { readWifi(); if (wifi.enabled) scanWifi() }
    }
    function readWifi() { if (!wifiRead.running) wifiRead.running = true }
    function scanWifi() { scanning = true; act("wifi-scan"); scanDone.restart() }

    function connectWifi(ssid, password) {
        if (wifiJoin.running) return
        wifiError = ""; askSsid = ""
        wifiJoin.ssid = ssid; wifiJoin.password = password
        wifiJoin.command = [helper, "wifi-connect", ssid]
        wifiJoin.running = true
    }

    Timer { interval: 5000; running: root.networkOpen && root.askSsid === ""; repeat: true; onTriggered: root.readWifi() }
    Timer { id: scanDone; interval: 6000; onTriggered: { root.scanning = false; root.readWifi() } }
    Process {
        id: wifiRead; command: [root.helper, "data", "wifi"]
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (!d.error) root.wifi = d
        } }
    }
    Process {
        id: wifiJoin
        property string ssid: ""
        property string password: ""
        stdinEnabled: true
        onStarted: { write(password + "\n"); password = ""; stdinEnabled = false }
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (d.error) root.wifiError = d.error
        } }
        onExited: { stdinEnabled = true; root.readWifi(); root.refresh() }
    }

    property var settings: ({})
    readonly property bool settingsOpen: open && page === "controls" && ["devices", "session", "system", "power"].includes(controlTab)
    onSettingsOpenChanged: if (settingsOpen) readSettings()
    function readSettings() { if (!settingsRead.running) settingsRead.running = true }
    Timer { interval: 15000; running: root.settingsOpen; repeat: true; onTriggered: root.readSettings() }
    Process {
        id: settingsRead; command: [root.helper, "data", "settings"]
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (!d.error) root.settings = d
        } }
    }

    property var displays: ({ displays: [], pending: null })
    property string displayError: ""
    readonly property string displayHelper: Quickshell.env("HOME") + "/.local/bin/station-display"
    readonly property bool displaysOpen: open && page === "controls" && controlTab === "displays"
    readonly property bool displayPending: displays.pending !== null && displays.pending !== undefined
    readonly property bool displayBusy: displayAct.running
    signal displaysApplied()
    onDisplaysOpenChanged: if (displaysOpen) readDisplays()
    function readDisplays() { if (!displayRead.running) displayRead.running = true }

    function displayCommand(args, input) {
        if (displayAct.running) return
        displayError = ""
        displayAct.input = input || ""
        displayAct.stdinEnabled = displayAct.input !== ""
        displayAct.command = [displayHelper].concat(args)
        displayAct.running = true
    }
    Timer { interval: 3000; running: root.displaysOpen || root.displayPending; repeat: true; onTriggered: root.readDisplays() }
    Process {
        id: displayRead; command: [root.displayHelper, "data"]
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (d.error) root.displayError = d.error
            else root.displays = d
        } }
    }
    Process {
        id: displayAct
        property string input: ""
        onStarted: if (input !== "") { write(input); input = ""; stdinEnabled = false }
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (d.error) root.displayError = d.error
            else root.displaysApplied()
        } }
        onExited: root.readDisplays()
    }

    function readNotifications() { if (!notificationRead.running) notificationRead.running = true }
    function refresh() {
        if (networkOpen) readWifi()
        if (settingsOpen) readSettings()
        if (wallpapersOpen || open && page === "appearance") readAppearance()
        if (!controlRead.running) controlRead.running = true
        if (!notificationRead.running) notificationRead.running = true
        if (open && page === "clipboard" && !clipRead.running) clipRead.running = true
    }
    function act(name, args) {
        if (action.running) return
        error = ""; action.name = name
        action.command = [helper, name].concat(args || [])
        action.running = true
    }
    function parse(text) {
        try { return JSON.parse(text) } catch (e) { return { error: "Service unavailable" } }
    }
    Component.onCompleted: refresh()
    Timer { interval: root.open || root.notificationsOpen ? 5000 : 15000; running: true; repeat: true; onTriggered: {
        if (!notificationRead.running) notificationRead.running = true
    } }
    Timer { interval: root.open || root.notificationsOpen ? 5000 : 15000; running: true; repeat: true; onTriggered: {
        if (!controlRead.running) controlRead.running = true
    } }
    Process {
        id: appearanceRead; command: [root.helper, "data", "appearance"]
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (d.error) root.error = d.error
            else root.appearance = d
        } }
    }
    Process {
        id: controlRead; command: [root.helper, "data", "controls"]
        property int brightnessAtStart: -1
        onStarted: brightnessAtStart = !brightnessWrite.running && root.brightnessQueued < 0 && !brightnessDelay.running ? root.brightnessTarget : -1
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text); root.controls = d.error ? ({}) : d
            if (controlRead.brightnessAtStart >= 0 && controlRead.brightnessAtStart === root.brightnessTarget && !brightnessWrite.running && root.brightnessQueued < 0 && !brightnessDelay.running) root.brightnessTarget = -1
        } }
    }
    Process {
        id: notificationRead; command: [root.helper, "data", "notifications"]
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            root.notifications = d.error ? { current: [], history: [], error: d.error } : d
        } }
    }
    Process {
        id: clipRead; command: [root.helper, "data", "clipboard"]
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text); root.clips = root.open && root.page === "clipboard" && Array.isArray(d) ? d : []
            if (d.error) root.error = d.error
        } }
    }
    Timer {
        id: cleanupDelay; interval: 1000
        onTriggered: {
            if (root.open) return
            if (clipRead.running) restart()
            else cleanup.running = true
        }
    }
    Process { id: cleanup; command: [root.helper, "clear-previews"] }
    Process {
        id: action
        property string name: ""
        stdout: StdioCollector { onStreamFinished: {
            const d = root.parse(text)
            if (d.error) root.error = d.error
            else root.actionDone(action.name)
        } }
        onExited: root.refresh()
    }
}
