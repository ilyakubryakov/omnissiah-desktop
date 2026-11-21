pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../shared" as Shared

ColumnLayout {
    id: root
    signal settingsRequested(string page)
    spacing: Shared.DesktopStyle.px(10)
    readonly property var player: Mpris.players.values.find(p => p.trackTitle && p.playbackState === MprisPlaybackState.Playing) || Mpris.players.values.find(p => p.trackTitle) || null
    readonly property var laptop: DesktopData.controls.laptop || ({})
    component Module: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 2 * Shared.DesktopStyle.px(12)
        radius: Shared.DesktopStyle.radiusCard
        color: Colors.lightBackground
        border.width: 1; border.color: Colors.selection
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.px(12) }
            spacing: Shared.DesktopStyle.px(8)
        }
    }

    FavoriteActions { Layout.fillWidth: true; compact: true; onSettingsRequested: page => root.settingsRequested(page) }

    Module {
        visible: root.laptop.brightness !== undefined && root.laptop.brightness !== null
        UiLabel { text: "Display"; font.weight: Font.DemiBold; font.pixelSize: Shared.DesktopStyle.px(13) }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "\u{F00DE}"; color: Colors.yellow; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(16) }
            UiSlider {
                id: brightness; Layout.fillWidth: true; from: 5; to: 100; stepSize: 1
                tint: Colors.yellow
                value: DesktopData.brightnessTarget >= 0 ? DesktopData.brightnessTarget : root.laptop.brightness ?? 50
                Accessible.name: "Brightness"
                onMoved: DesktopData.setBrightness(Math.round(value))
            }
        }
    }

    Module {
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: "Sound"; font.weight: Font.DemiBold; font.pixelSize: Shared.DesktopStyle.px(13); Layout.fillWidth: true }
            UiButton { subtle: true; glyph: ""; Accessible.name: "Sound settings"; onClicked: root.settingsRequested("audio") }
        }
        AudioChannel { Layout.fillWidth: true; title: "Output"; node: Shared.AudioState.sink }
        AudioChannel { Layout.fillWidth: true; title: "Microphone"; node: Shared.AudioState.source; microphone: true }
    }

    Module {
        visible: !!root.player
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                UiLabel { Layout.fillWidth: true; text: root.player?.trackTitle || ""; font.weight: Font.DemiBold; maximumLineCount: 1; elide: Text.ElideRight }
                UiLabel { Layout.fillWidth: true; text: root.player?.trackArtist || ""; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); maximumLineCount: 1; elide: Text.ElideRight }
            }
            UiButton { subtle: true; glyph: "\u{F04AE}"; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous(); Accessible.name: "Previous track" }
            UiButton { subtle: true; glyph: root.player?.playbackState === MprisPlaybackState.Playing ? "\u{F03E4}" : "\u{F040A}"; enabled: !!root.player?.canTogglePlaying; onClicked: root.player.togglePlaying(); Accessible.name: "Play or pause" }
            UiButton { subtle: true; glyph: "\u{F04AD}"; enabled: !!root.player?.canGoNext; onClicked: root.player.next(); Accessible.name: "Next track" }
        }
    }

    Module {
        UiLabel { text: "Desktop mode"; font.weight: Font.DemiBold; font.pixelSize: Shared.DesktopStyle.px(13) }
        Segmented {
            Layout.fillWidth: true
            model: (Quickshell.env("ONINIX_LAPTOP") === "1" ? ["normal", "work", "call"] : ["normal", "work", "call", "game", "music"])
                .map(id => ({id: id, title: id === "music" ? "Recording" : id.charAt(0).toUpperCase() + id.slice(1)}))
            current: DesktopData.controls.mode || "normal"
            enabled: !DesktopData.busy
            onChosen: id => DesktopData.act("mode", [id])
        }
    }

    RowLayout {
        Layout.fillWidth: true
        UiButton { text: "Settings…"; glyph: "\u{F0493}"; onClicked: root.settingsRequested("") }
        Item { Layout.fillWidth: true }
        UiButton { glyph: "\u{F033E}"; Accessible.name: "Lock"; onClicked: Qt.callLater(() => Quickshell.execDetached(["loginctl", "lock-session"])) }
        UiButton { glyph: "\u{F0425}"; Accessible.name: "Power"; onClicked: root.settingsRequested("power") }
    }
}
