pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var state: ({})
    property bool missing: true
    readonly property bool adaptivePanels: state.adaptivePanels !== false
    readonly property real panelOpacity: typeof state.panelOpacity === "number" ? Math.max(0.4, Math.min(1, state.panelOpacity / 100)) : 1
    readonly property string panelBackground: ["plain", "accent", "wallpaper"].includes(state.panelBackground) ? state.panelBackground : "plain"
    property string wallpaperPreview: ""
    readonly property color panelSurface: panelBackground === "wallpaper" && wallpaperColorsReady
        ? wallpaperSurface(wallpaperColors.colors, Colors.background, Colors.foreground, Colors.muted)
        : blend(Colors.background, Colors.accent, panelBackground === "accent" ? 0.06 : 0)
    readonly property bool wallpaperColorsReady: wallpaperPreview !== "" && wallpaperColors.colors.length > 0
    function luminance(c) {
        function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
    function contrast(a, b) {
        const x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }
    function wallpaperSurface(colors, base, foreground, muted) {
        if (!colors.length) return base
        // Favor the image's colored midtones over black borders/white highlights.
        let r = 0, g = 0, b = 0, total = 0
        for (const c of colors) {
            const hi = Math.max(c.r, c.g, c.b), lo = Math.min(c.r, c.g, c.b)
            const light = (hi + lo) / 2
            const weight = (0.15 + hi - lo) * Math.max(0.05, 1 - Math.abs(light - 0.5) * 2)
            r += c.r * weight; g += c.g * weight; b += c.b * weight; total += weight
        }
        // Use the image's hue, not a faint overlay on the theme's old hue.
        // Normalize brightness to the current light/dark theme before contrast checks.
        const hi = Math.max(r, g, b) / total
        const level = Math.max(base.r, base.g, base.b)
        const dark = luminance(base) < 0.5
        const brightness = Math.min(1, level + (dark ? 0.035 : 0))
        const tint = hi > 0.001
            ? Qt.rgba(r / total / hi * brightness, g / total / hi * brightness, b / total / hi * brightness, 1)
            : Qt.rgba(brightness, brightness, brightness, 1)
        const neutral = Qt.rgba(brightness, brightness, brightness, 1)
        const colored = blend(neutral, tint, dark ? 0.8 : 0.16)
        const foregroundFloor = Math.min(4.5, contrast(foreground, base))
        const mutedFloor = Math.min(3, contrast(muted, base))
        for (let amount = 1; amount > 0.01; amount -= 0.02) {
            const candidate = blend(base, colored, amount)
            if (contrast(foreground, candidate) >= foregroundFloor && contrast(muted, candidate) >= mutedFloor) return candidate
        }
        return base
    }
    ColorQuantizer {
        id: wallpaperColors
        source: root.wallpaperPreview
        depth: 3
        rescaleSize: 64
    }
    // One shared, event-driven extraction for all monitors. No polling or upload.
    function refreshWallpaper() { if (panelBackground === "wallpaper") wallpaperRefresh.restart() }
    onPanelBackgroundChanged: {
        if (panelBackground === "wallpaper") refreshWallpaper()
        else wallpaperPreview = ""
    }
    Component.onCompleted: refreshWallpaper()
    Timer {
        id: wallpaperRefresh
        interval: 120
        onTriggered: {
            if (wallpaperPath.running) restart()
            else wallpaperPath.running = true
        }
    }
    Process {
        id: wallpaperPath
        command: ["oninix-desktop", "wallpaper-preview"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (root.panelBackground === "wallpaper") root.wallpaperPreview = result.url || ""
                } catch (_) { root.wallpaperPreview = "" }
            }
        }
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/wallpapers.json"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); root.refreshWallpaper() }
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/name"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); root.refreshWallpaper() }
    }
    readonly property real groupStrength: typeof state.groupStrength === "number" ? Math.max(0, Math.min(0.3, state.groupStrength / 100)) : 0.12
    readonly property var groups: [
        { id: "launchers", name: "Launchers", tone: "neutral" },
        { id: "workspaces", name: "Workspaces", tone: "accent" },
        { id: "status", name: "Status & tray", tone: "cyan" },
        { id: "media", name: "Media & agenda", tone: "accent" },
        { id: "window", name: "Active window", tone: "accent" },
        { id: "metrics", name: "System & weather", tone: "green" }
    ]
    readonly property var tones: [
        {id:"none", name:"No tint"}, {id:"neutral", name:"Neutral"}, {id:"accent", name:"Theme accent"},
        {id:"warm", name:"Amber"}, {id:"green", name:"Sage"}, {id:"cyan", name:"Teal"},
        {id:"blue", name:"Slate"}, {id:"magenta", name:"Mauve"}
    ]
    function toneName(group) {
        const saved = (state.groupTones || {})[group]
        return tones.some(t => t.id === saved) ? saved : (groups.find(g => g.id === group) || {}).tone || "none"
    }
    function toneColor(name) {
        if (panelBackground === "wallpaper" && wallpaperColorsReady) {
            const index = Math.max(0, tones.findIndex(t => t.id === name)) % wallpaperColors.colors.length
            return wallpaperSurface([wallpaperColors.colors[index]], Colors.lightBackground, Colors.foreground, Colors.muted)
        }
        return ({none: Colors.background, neutral: Colors.foreground, accent: Colors.accent,
            warm: Colors.yellow, green: Colors.green, cyan: Colors.cyan, blue: Colors.blue, magenta: Colors.magenta})[name] || Colors.accent
    }
    readonly property string buttonMode: ["neutral", "theme", "groups"].includes(state.buttonMode) ? state.buttonMode : "groups"
    readonly property real buttonStrength: typeof state.buttonStrength === "number" ? Math.max(0, Math.min(1, state.buttonStrength / 100)) : 0.65
    function buttonTone(group) {
        const saved = (state.buttonTones || {})[group]
        return tones.some(t => t.id === saved) ? saved : (groups.find(g => g.id === group) || {}).tone || "neutral"
    }
    function paletteTone(name) {
        return ({none: Colors.foreground, neutral: Colors.foreground, accent: Colors.accent,
            warm: Colors.yellow, green: Colors.green, cyan: Colors.cyan, blue: Colors.blue, magenta: Colors.magenta})[name] || Colors.foreground
    }
    function buttonColor(group) {
        if (buttonMode === "neutral") return Colors.foreground
        const tone = paletteTone(buttonMode === "theme" ? "accent" : buttonTone(group))
        let candidate = blend(Colors.foreground, tone, buttonStrength)
        // Muted palette tones must stay legible on light and wallpaper surfaces.
        for (let amount = buttonStrength; amount > 0 && contrast(candidate, panelSurface) < 3; amount -= 0.05)
            candidate = blend(Colors.foreground, tone, amount)
        return candidate
    }
    function blend(a, b, amount) {
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1)
    }
    property var queue: []
    property string error: ""
    function change(args) {
        queue = queue.concat([args])
        pump()
    }
    function pump() {
        if (writer.running || !queue.length) return
        const args = queue[0]
        queue = queue.slice(1)
        writer.command = ["oninix-desktop", "appearance"].concat(args)
        writer.running = true
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: { try { const result = JSON.parse(text); if (result.error) root.error = result.error } catch (_) {} } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.error = text.trim() }
        onExited: (code, status) => {
            if (code === 0) root.error = ""
            else if (!root.error) root.error = "Could not save layout settings"
            store.reload()
            Qt.callLater(root.pump)
        }
    }
    Timer { interval: 2000; repeat: true; running: root.missing; onTriggered: store.reload() }
    FileView {
        id: store
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/shell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.missing = false
            try { root.state = JSON.parse(text()) || ({}) }
            catch (_) { root.error = "Invalid shell settings; using defaults"; root.state = ({}) }
        }
        onLoadFailed: { root.missing = true; root.state = ({}) }
    }
}
