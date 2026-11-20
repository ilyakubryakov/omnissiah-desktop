pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../shared" as Shared

// Sound: output, microphone, per-application streams and studio tools.
ColumnLayout {
    id: root
    property bool studioExpanded: false
    spacing: Shared.DesktopStyle.px(20)
    readonly property int sliderWidth: Shared.DesktopStyle.px(300)
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    PwObjectTracker {
        objects: root.nodes
    }
    function deviceName(node) {
        return (node.description || node.name || "Audio device").replace(/^.* HD Audio /, "");
    }
    component DevicePicker: UiComboBox {
        id: picker
        required property bool input
        readonly property var devices: root.nodes.filter(n => !n.isStream && n.isSink !== input)
        Layout.preferredWidth: Shared.DesktopStyle.px(300)
        model: devices.map(n => root.deviceName(n))
        currentIndex: devices.indexOf(input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink)
        Accessible.name: input ? "Input device" : "Output device"
        onActivated: index => {
            if (input)
                Pipewire.preferredDefaultAudioSource = devices[index];
            else
                Pipewire.preferredDefaultAudioSink = devices[index];
        }
        palette.button: Colors.selection
        palette.buttonText: Colors.foreground
        palette.base: Colors.background
        palette.text: Colors.foreground
        palette.highlight: Colors.accent
        palette.highlightedText: Colors.background
    }
    // Volume slider plus Mute for one node; a row control of a SettingsRow.
    component VolumeControl: RowLayout {
        id: volume
        required property var node
        spacing: Shared.DesktopStyle.px(8)
        UiSlider {
            Layout.preferredWidth: root.sliderWidth - Shared.DesktopStyle.px(52)
            from: 0; to: 1; stepSize: 0.01
            value: volume.node.audio.volume
            tint: volume.node.audio.muted ? Colors.muted : Colors.accent
            onMoved: volume.node.audio.volume = value
            Accessible.name: "Volume " + volume.node.description
        }
        UiLabel {
            Layout.preferredWidth: Shared.DesktopStyle.px(46)
            horizontalAlignment: Text.AlignRight
            text: Math.round(volume.node.audio.volume * 100) + "%"
            color: Colors.muted
        }
        UiButton {
            text: volume.node.audio.muted ? "Muted" : "Mute"
            selected: volume.node.audio.muted
            onClicked: volume.node.audio.muted = !volume.node.audio.muted
        }
    }

    SettingsGroup {
        title: "Output"
        SettingsRow {
            title: "Output device"
            DevicePicker { input: false }
        }
        SettingsRow {
            visible: !!Pipewire.defaultAudioSink
            title: "Volume"
            Loader {
                active: !!Pipewire.defaultAudioSink
                sourceComponent: VolumeControl { node: Pipewire.defaultAudioSink }
            }
        }
    }

    SettingsGroup {
        title: "Microphone"
        SettingsRow {
            title: "Input device"
            subtitle: Pipewire.defaultAudioSource ? "" : "No input device"
            DevicePicker { input: true }
        }
        SettingsRow {
            visible: !!Pipewire.defaultAudioSource
            title: "Input volume"
            Loader {
                active: !!Pipewire.defaultAudioSource
                sourceComponent: VolumeControl { node: Pipewire.defaultAudioSource }
            }
        }
    }

    SettingsGroup {
        title: "Applications"
        SettingsRow {
            visible: !root.nodes.some(n => n.isStream)
            subtitle: "No applications playing or recording audio"
        }
        Repeater {
            model: root.nodes.filter(n => n.isStream)
            SettingsRow {
                id: stream
                required property var modelData
                title: root.deviceName(modelData)
                VolumeControl { node: stream.modelData }
            }
        }
    }

    SettingsGroup {
        title: "Music / recording"
        SettingsRow {
            title: "Studio tools"
            UiButton {
                glyph: "\u{F001}"
                text: root.studioExpanded ? "Collapse" : "Show"
                selected: root.studioExpanded
                onClicked: root.studioExpanded = !root.studioExpanded
            }
        }
        SettingsRow {
            visible: root.studioExpanded
            stacked: true
            Loader {
                Layout.fillWidth: true
                active: root.studioExpanded
                sourceComponent: Shared.MusicControls {}
            }
        }
    }
}
