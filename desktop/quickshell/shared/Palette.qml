pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared palette from the theme engine (themes/templates/quickshell.tpl). Watching the
// file means `theme set` recolours the bars without a restart.
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

    // Watch the stable selection file as well as the symlink target. This also
    // covers a theme applied over SSH without the session's Wayland environment.
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/theme/name"
        watchChanges: true
        onFileChanged: { reload(); file.reload() }
    }

    // `theme set` repoints the current/ symlink, which the file watch does not
    // see (it holds the old target), so `theme` also pushes: ipc call colors reload.
    IpcHandler {
        target: "colors"
        function reload(): void { file.reload() }
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/theme/current/quickshell-colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // The generated file opens with a // header that JSON does not allow.
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
