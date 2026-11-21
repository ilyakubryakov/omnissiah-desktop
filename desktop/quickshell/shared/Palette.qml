pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property color magenta: red
    property color cyan: blue
    property color background: "#121010"
    property color windowBackground: background
    property color darkBackground: "#0a0909"
    property color lightBackground: "#1b1715"
    property color selection: "#3a2418"
    property color foreground: "#d9c4a3"
    property color dim: "#6e6052"
    property color muted: "#a68a6f"
    property color bright: "#f3cba2"
    property color accent: "#c1893e"
    property color statusWarning: yellow
    property color statusAvailable: green
    property color statusUrgent: red
    property color red: "#b8473a"
    property color green: "#8c9a62"
    property color yellow: "#c1893e"
    property color blue: "#7d93a1"

    readonly property string textFont: DesktopStyle.fontFamily
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int fontSize: DesktopStyle.metrics.caption_text_px

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/theme/name"
        printErrors: false
        watchChanges: true
        onFileChanged: { reload(); file.reload() }
    }

    IpcHandler {
        target: "colors"
        function reload(): void { file.reload() }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/theme/current/quickshell-colors.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const body = file.text().split("\n").filter(l => !l.startsWith("//")).join("\n")
            try {
                const p = JSON.parse(body)
                root.windowBackground = p.windowBackground || p.background || root.background
                for (const key in p)
                    if (key in root) root[key] = p[key]
            } catch (e) {
                console.warn("bar: bad palette file", e)
            }
        }
    }
}
