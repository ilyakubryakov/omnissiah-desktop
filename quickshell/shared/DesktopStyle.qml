pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var preferences: ({})
    readonly property bool comfortable: preferences.density === "comfortable"
    property bool fullscreen: false
    readonly property bool motion: ["subtle", "smooth"].includes(preferences.motion) && !fullscreen

    readonly property int radiusSmall: 10
    readonly property int radiusCard: 16
    readonly property int radiusPanel: 22
    readonly property int spacing: comfortable ? 16 : 12
    readonly property bool smooth: preferences.motion === "smooth"
    readonly property int fast: motion ? (smooth ? 160 : 120) : 0
    readonly property int normal: motion ? (smooth ? 300 : 220) : 0
    readonly property int slow: motion ? (smooth ? 400 : 320) : 0
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/desktop.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const next = {}
            for (const line of text().split("\n")) {
                const pair = line.split("=")
                if (pair.length === 2) next[pair[0]] = pair[1]
            }
            root.preferences = next
        }
        onLoadFailed: root.preferences = ({})
    }
}
