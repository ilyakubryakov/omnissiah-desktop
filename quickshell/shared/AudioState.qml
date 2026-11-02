pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var output: sink ? sink.audio : null
    readonly property var input: source ? source.audio : null
    property bool settled: false
    signal changed(string kind, string device, real volume, bool muted)

    PwObjectTracker { objects: [root.sink, root.source].filter(n => n !== null) }
    function reset() { settled = false; settle.restart() }
    function announce(kind, node, audio) {
        if (settled && Pipewire.ready && node && audio)
            changed(kind, node.nickname || node.description || node.name, audio.volume, audio.muted)
    }
    onSinkChanged: reset()
    onSourceChanged: reset()
    Component.onCompleted: reset()
    Timer { id: settle; interval: 300; onTriggered: root.settled = true }
    Connections {
        target: root.output
        function onVolumeChanged() { root.announce("Output", root.sink, root.output) }
        function onMutedChanged() { root.announce("Output", root.sink, root.output) }
    }
    Connections {
        target: root.input
        function onVolumeChanged() { root.announce("Microphone", root.source, root.input) }
        function onMutedChanged() { root.announce("Microphone", root.source, root.input) }
    }
}
