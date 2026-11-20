import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// Shared by Quick settings and the bar preview. PipeWire remains the source of
// truth; moving a microphone slider must never unmute it as a side effect.
ColumnLayout {
    id: root
    required property string title
    required property var node
    property bool microphone: false
    readonly property var audio: node ? node.audio : null
    readonly property color tint: audio && audio.muted ? Colors.muted : microphone ? Colors.green : Colors.accent
    spacing: 2
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: root.title; font.pixelSize: Shared.DesktopStyle.px(12); color: root.tint }
        UiLabel {
            Layout.fillWidth: true
            text: root.node ? root.node.nickname || root.node.description || root.node.name : "No device connected"
            font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.muted; elide: Text.ElideRight; maximumLineCount: 1
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        UiButton {
            glyph: root.microphone ? (root.audio?.muted ? "\u{F036D}" : "\u{F036C}") : (root.audio?.muted ? "\u{F0581}" : "\u{F057E}")
            selected: !!root.audio?.muted
            enabled: !!root.audio
            Accessible.name: (root.audio?.muted ? "Unmute " : "Mute ") + root.title
            onClicked: root.audio.muted = !root.audio.muted
        }
        UiSlider {
            id: level
            objectName: root.microphone ? "microphoneLevel" : "outputLevel"
            Layout.fillWidth: true
            from: 0; to: 1; stepSize: 0.01
            enabled: !!root.audio
            tint: root.tint
            value: root.audio ? root.audio.volume : 0
            Accessible.name: root.title + " volume"
            onMoved: if (root.audio) root.audio.volume = value
        }
        UiLabel {
            Layout.preferredWidth: 66
            horizontalAlignment: Text.AlignRight
            text: !root.audio ? "--" : Math.round(root.audio.volume * 100) + "%" + (root.audio.muted ? " · off" : "")
            font.pixelSize: Shared.DesktopStyle.px(12); color: root.audio?.muted ? Colors.muted : Colors.foreground
        }
    }
}
