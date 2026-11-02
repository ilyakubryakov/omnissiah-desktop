pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../shared" as Shared

Singleton {
    id: root
    readonly property int count: 14
    property var levels: []
    readonly property bool running: cava.running
    readonly property bool wanted: PanelBriefing.player !== null
        && PanelBriefing.player.playbackState === MprisPlaybackState.Playing
        && !PanelBriefing.preferBriefing && !Shared.DesktopStyle.fullscreen
    Process {
        id: cava
        running: root.wanted
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const values = line.split(";").filter(v => v !== "").map(v => Math.min(100, Math.max(0, parseInt(v) || 0)))
                if (values.length) root.levels = values
            }
        }
        onRunningChanged: if (!running) root.levels = []
    }
}
