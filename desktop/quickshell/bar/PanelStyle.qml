pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../shared" as Shared

Singleton {
    id: root
    property string style: "flat"
    readonly property var presets: [
        { id: "flat", name: "Full panel", detail: "Continuous · edge to edge" },
        { id: "islands", name: "Islands", detail: "Separate groups · clear backdrop" }
    ]
    readonly property int barHeight: typeof ShellLayout.state.panelHeight === "number" ? Math.max(28, Math.min(56, ShellLayout.state.panelHeight)) : 36 + (Shared.DesktopStyle.comfortable ? 4 : 0)
    readonly property int widthPercent: typeof ShellLayout.state.panelWidth === "number" ? Math.max(60, Math.min(100, ShellLayout.state.panelWidth)) : 100
    function sideGapFor(screenWidth) {
        const width = Math.max(Math.min(screenWidth, 1100), screenWidth * widthPercent / 100)
        return Math.round((screenWidth - width) / 2)
    }
    readonly property int outerGap: 0
    readonly property bool customCorners: typeof ShellLayout.state.panelRadius === "number"
    // A file created after start is not watched yet; poll only while it is missing.
    property bool missing: false
    Timer { interval: 2000; running: root.missing; repeat: true; onTriggered: store.reload() }
    readonly property int cornerRadius: Math.min(barHeight / 2, customCorners ? Math.max(0, Math.min(24, ShellLayout.state.panelRadius)) : style === "islands" ? 12 : 0)
    FileView {
        id: store
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/theme/panels.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.missing = false
            try {
                const next = JSON.parse(text()).style
                root.style = root.presets.some(p => p.id === next) ? next : "flat"
            } catch (_) { root.style = "flat" }
        }
        onLoadFailed: { root.missing = true; root.style = "flat" }
    }
}
