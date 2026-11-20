import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../shared" as Shared

ColumnLayout {
    id: root
    required property var player
    property bool active: false
    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing
    readonly property real duration: player && player.lengthSupported ? player.length : 0
    spacing: 14
    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }
    Timer {
        interval: 1000; running: root.active && root.playing && root.player.positionSupported; repeat: true
        onTriggered: root.player.positionChanged()
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ClippingRectangle {
            Layout.preferredWidth: 116; Layout.preferredHeight: 116
            radius: 16
            color: Colors.lightBackground
            Image {
                id: art
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.slow } }
            }
            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "\u{F075A}"; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(42); color: Colors.accent
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            UiLabel { text: root.playing ? "NOW PLAYING" : "PAUSED"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(10); font.letterSpacing: 2 }
            UiLabel {
                Layout.fillWidth: true
                text: root.player ? root.player.trackTitle || "Unknown track" : "No player"
                font.pixelSize: Shared.DesktopStyle.px(17); font.weight: Font.DemiBold
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText
            }
            UiLabel { Layout.fillWidth: true; text: root.player ? root.player.trackArtist : ""; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(13); elide: Text.ElideRight; textFormat: Text.PlainText }
            UiLabel { Layout.fillWidth: true; text: root.player ? root.player.trackAlbum : ""; visible: text !== ""; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11); elide: Text.ElideRight; textFormat: Text.PlainText }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 0
        visible: root.duration > 0
        UiSlider {
            id: seek
            Layout.fillWidth: true
            from: 0; to: Math.max(1, root.duration)
            value: root.player ? root.player.position : 0
            enabled: root.player && root.player.canSeek && root.player.positionSupported
            Accessible.name: "Playback position"
            onMoved: if (root.player && !pressed) root.player.position = value
            onPressedChanged: if (!pressed && root.player && enabled) root.player.position = value
        }
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: root.time(seek.value); color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
            Item { Layout.fillWidth: true }
            UiLabel { text: root.time(root.duration); color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
        }
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 12
        UiButton { glyph: "\u{F04AE}"; Accessible.name: "Previous track"; enabled: root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
        UiButton { glyph: root.playing ? "\u{F03E4}" : "\u{F040A}"; text: root.playing ? "Pause" : "Play"; selected: true; enabled: root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
        UiButton { glyph: "\u{F04AD}"; Accessible.name: "Next track"; enabled: root.player && root.player.canGoNext; onClicked: root.player.next() }
    }
    Keys.onSpacePressed: if (player && player.canTogglePlaying) player.togglePlaying()
}
