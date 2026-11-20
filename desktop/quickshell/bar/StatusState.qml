pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Recording and keep-awake, polled once for every panel that shows their icons.
Singleton {
    id: root
    property bool recording: false
    property bool awake: false
    readonly property string scripts: Quickshell.env("ONINIX_SHARE") + "/hypr/scripts/"
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!states.running) states.running = true }
    }
    Process {
        id: states
        command: ["sh", "-c", "pgrep -f '(^|/)gpu-screen-recorder( |$)' >/dev/null && echo rec; systemctl --user is-active --quiet oninix-keep-awake.service && echo awake"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recording = text.indexOf("rec") >= 0
                root.awake = text.indexOf("awake") >= 0
            }
        }
    }
}
