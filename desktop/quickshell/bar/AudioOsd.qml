import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../shared" as Shared

PanelWindow {
    id: root
    screen: Shared.Screens.main
    visible: hide.running && Shared.Screens.main !== null
    anchors { bottom: true }
    margins.bottom: Shared.DesktopStyle.px(72)
    implicitWidth: Shared.DesktopStyle.px(360)
    implicitHeight: Shared.DesktopStyle.px(94)
    exclusiveZone: 0
    color: "transparent"
    focusable: false
    mask: Region { }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-audio-osd"
    property string kind: ""
    property string device: ""
    property real volume: 0
    property bool muted: false
    property real quietUntil: 0
    property real quietVolume: -1
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/oninix-duck-quiet" : ""
        watchChanges: true
        printErrors: false
        onLoaded: {
            const parts = text().trim().split(/\s+/)
            root.quietUntil = Number(parts[0]) || 0
            root.quietVolume = parts.length > 1 ? Number(parts[1]) : -1
        }
        onLoadFailed: { root.quietUntil = 0; root.quietVolume = -1 }
        onFileChanged: reload()
    }
    Connections {
        target: Shared.AudioState
        function onChanged(kind, device, volume, muted) {
            root.kind = kind; root.device = device; root.volume = volume; root.muted = muted
            show.restart()
        }
    }
    Timer {
        id: show; interval: 150
        onTriggered: {
            const ducking = root.kind === "Output" && Date.now() / 1000 < root.quietUntil
                && (root.quietVolume < 0 || Math.abs(root.volume - root.quietVolume) < 0.02)
            if (!ducking) hide.restart()
        }
    }
    Timer { id: hide; interval: 1200 }
    Rectangle {
        anchors.fill: parent
        color: Colors.background
        border.color: root.muted ? Colors.red : Colors.accent
        border.width: 1
        Column {
            anchors.fill: parent; anchors.margins: Shared.DesktopStyle.px(14)
            spacing: Shared.DesktopStyle.px(6)
            Text {
                width: parent.width
                text: root.kind + "  " + (root.muted ? "MUTED" : Math.round(root.volume * 100) + "%")
                color: root.muted ? Colors.red : Colors.foreground
                font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(16)
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: root.device; color: Colors.muted
                font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(12)
            }
            Rectangle {
                width: parent.width; height: Shared.DesktopStyle.px(3); color: Colors.lightBackground
                Rectangle {
                    width: parent.width * (root.muted ? 0 : Math.min(1, Math.max(0, root.volume)))
                    height: parent.height; color: Colors.accent
                }
            }
        }
    }
}
