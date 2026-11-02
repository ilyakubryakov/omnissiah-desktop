import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../bar" as Bar

ColumnLayout {
    id: root
    spacing: 12
    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var clock: StudioState.data.settings || ({})
    Component.onCompleted: StudioState.users++
    Component.onDestruction: StudioState.users--
    Bar.UiLabel { Layout.fillWidth: true; text: "Audio buffer"; color: Bar.Colors.accent }
    Bar.UiLabel { Layout.fillWidth: true; visible: !!StudioState.data.music_requested && !StudioState.data.music; text: "Music buffer is no longer active. Select Music mode again to reapply it."; color: Bar.Colors.red }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Repeater {
            model: [0,128,256,512]
            Bar.UiButton {
                required property int modelData
                text: modelData === 0 ? "Auto" : modelData + " frames"
                selected: root.clock["clock.force-quantum"] === modelData
                enabled: !StudioState.busy && StudioState.error === ""
                onClicked: StudioState.setQuantum(modelData)
            }
        }
    }
    Bar.UiLabel { Layout.fillWidth: true; text: "Requested: " + (root.clock["clock.force-quantum"] || "Auto") + " · default quantum: " + (root.clock["clock.quantum"] || "unknown") + " · " + (root.clock["clock.rate"] ? root.clock["clock.rate"] / 1000 + " kHz" : "rate unknown") }
    Bar.UiLabel { Layout.fillWidth: true; color: Bar.Colors.muted; font.pixelSize: 12; text: "Change buffers between takes. 128 frames at 48 kHz = 2.67 ms per quantum, not round-trip latency. Sample rate is left to the DAW." }
    Bar.UiLabel { visible: StudioState.error !== ""; text: StudioState.error; color: Bar.Colors.red; Layout.fillWidth: true }
    Bar.UiLabel { visible: !root.devices.length; text: "No audio devices connected"; color: Bar.Colors.muted }
    Repeater {
        model: root.devices
        Bar.UiButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.description + " · " + (modelData.isSink ? "output" : "input")
            selected: modelData === Pipewire.defaultAudioSink || modelData === Pipewire.defaultAudioSource
            onClicked: { if (modelData.isSink) Pipewire.preferredDefaultAudioSink = modelData; else Pipewire.preferredDefaultAudioSource = modelData }
        }
    }
    Bar.UiLabel { Layout.fillWidth: true; text: "MIDI · " + ((StudioState.data.midi || []).join(", ") || "No MIDI nodes reported"); color: Bar.Colors.muted }
    Repeater {
        model: (StudioState.data.nodes || []).filter(n => n.state === "R" || n.errors > 0)
        Bar.UiLabel {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.name + " · " + modelData.quantum + " / " + modelData.rate + " · ERR " + modelData.errors
            color: modelData.errors > 0 ? Bar.Colors.red : Bar.Colors.muted
        }
    }
    Bar.UiLabel { Layout.fillWidth: true; font.pixelSize: 12; color: Bar.Colors.muted; text: "ERR is PipeWire's cumulative node error counter; it can reset when a node restarts. No running nodes means no live latency test." }
    Flow {
        Layout.fillWidth: true; spacing: 8
        Bar.UiButton { text: "Live audio stats"; onClicked: Quickshell.execDetached(["uwsm", "app", "--", "kitty", "--title", "PipeWire monitor", "pw-top"]) }
    }
}
