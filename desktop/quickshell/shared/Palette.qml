pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "PaletteDefaults.js" as Defaults

Singleton {
    id: root

    property color magenta: red
    property color cyan: blue
    property color background: Defaults.values.background
    property color windowBackground: background
    property color darkBackground: Defaults.values.darkBackground
    property color lightBackground: Defaults.values.lightBackground
    property color selection: Defaults.values.selection
    property color foreground: Defaults.values.foreground
    property color dim: Defaults.values.dim
    property color muted: Defaults.values.muted
    property color bright: Defaults.values.bright
    property color accent: Defaults.values.accent
    property color statusWarning: yellow
    property color statusAvailable: green
    property color statusUrgent: red
    property color red: Defaults.values.red
    property color green: Defaults.values.green
    property color yellow: Defaults.values.yellow
    property color blue: Defaults.values.blue

    property color shadow: Defaults.values.shadow
    property color claudeBrand: Defaults.values.claudeBrand

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
