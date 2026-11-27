pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool recording: false
    property bool awake: false
    readonly property string scripts: Quickshell.env("ONINIX_SHARE") + "/hypr/scripts/"
    function toggleAwake() { if (!keepAwake.running) keepAwake.running = true }
    Process {
        id: keepAwake
        command: [root.scripts + "keep-awake.sh"]
        onExited: {
            awakeProbe.running = true
            DesktopData.refresh()
        }
    }
    Timer {
        interval: root.recording ? 2000 : 5000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!recorder.running) recorder.running = true
            if (!awakeProbe.running) awakeProbe.running = true
        }
    }
    Connections { target: DesktopData; function onActionDone(name) { if (!awakeProbe.running) awakeProbe.running = true } }
    Process {
        id: awakeProbe
        command: ["systemctl", "--user", "is-active", "--quiet", "oninix-keep-awake.service"]
        onExited: code => root.awake = code === 0
    }
    Process {
        id: recorder
        command: ["systemctl", "--user", "is-active", "--quiet", "oninix-screenrecord.service"]
        onExited: code => root.recording = code === 0
    }
}
