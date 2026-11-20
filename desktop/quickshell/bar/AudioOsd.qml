import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

PanelWindow {
    id: root
    screen: Shared.Screens.main
    visible: hide.running && Shared.Screens.main !== null
    anchors { bottom: true }
    margins.bottom: 72
    implicitWidth: 360
    implicitHeight: 94
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
    Connections {
        target: Shared.AudioState
        function onChanged(kind, device, volume, muted) {
            root.kind = kind; root.device = device; root.volume = volume; root.muted = muted
            hide.restart()
        }
    }
    Timer { id: hide; interval: 1200 }
    Rectangle {
        anchors.fill: parent
        color: Colors.background
        border.color: root.muted ? Colors.red : Colors.accent
        border.width: 1
        Column {
            anchors.fill: parent; anchors.margins: 14
            spacing: 6
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
                width: parent.width; height: 3; color: Colors.lightBackground
                Rectangle {
                    width: parent.width * (root.muted ? 0 : Math.min(1, Math.max(0, root.volume)))
                    height: parent.height; color: Colors.accent
                }
            }
        }
    }
}
