pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import "../shared" as Shared

ColumnLayout {
    id: root
    property var cal: null
    signal appearanceRequested()
    signal notificationsRequested()
    signal calendarRequested()
    signal launchRequested(var command)
    spacing: Shared.DesktopStyle.spacing
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var player: Mpris.players.values.find(p => p.trackTitle && p.playbackState === MprisPlaybackState.Playing) || Mpris.players.values.find(p => p.trackTitle) || null
    readonly property var battery: (DesktopData.controls.laptop || {}).battery
    component Card: SettingsCard {}
    RowLayout {
        spacing: 20
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            UiLabel { text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); font.pixelSize: 22 }
            UiLabel { text: "CPU " + (Sys.cpu < 0 ? "--" : Sys.cpu + "%") + "  ·  RAM " + (Sys.mem < 0 ? "--" : Sys.mem + "%") + (root.battery ? "  ·  Battery " + root.battery.percent + "%" : ""); color: Colors.muted; font.pixelSize: 12 }
        }
        UiLabel { text: Qt.formatDateTime(clock.date, "HH:mm"); font.pixelSize: 30; color: Colors.accent }
        UiButton { glyph: "\u{F00ED}"; Accessible.name: "Calendar"; onClicked: root.calendarRequested() }
    }
    FavoriteActions { Layout.fillWidth: true }
    GridLayout {
        Layout.fillWidth: true
        columns: root.width >= 640 ? 2 : 1
        columnSpacing: Shared.DesktopStyle.spacing; rowSpacing: Shared.DesktopStyle.spacing
        Card {
            Layout.preferredWidth: 1; Layout.minimumWidth: 0; Layout.fillHeight: true
            RowLayout {
                Layout.fillWidth: true
                UiLabel { text: "Sound"; Layout.fillWidth: true; font.weight: Font.DemiBold }
                UiButton { text: "Devices ›"; onClicked: DesktopData.controlTab = "audio" }
            }
            AudioChannel { Layout.fillWidth: true; title: "Output"; node: Shared.AudioState.sink }
            AudioChannel { Layout.fillWidth: true; title: "Microphone"; node: Shared.AudioState.source; microphone: true }
        }
        Card {
            Layout.preferredWidth: 1; Layout.minimumWidth: 0; Layout.fillHeight: true
            AgendaCard { Layout.fillWidth: true; cal: root.cal; limit: 2; onCalendarRequested: root.calendarRequested() }
        }
    }
    Card {
        visible: (DesktopData.controls.laptop || {}).brightness !== undefined && (DesktopData.controls.laptop || {}).brightness !== null
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: "Brightness"; color: Colors.yellow; font.pixelSize: 13 }
            UiSlider {
                id: brightness; Layout.fillWidth: true; from: 5; to: 100; stepSize: 1
                tint: Colors.yellow
                value: DesktopData.brightnessTarget >= 0 ? DesktopData.brightnessTarget : (DesktopData.controls.laptop || {}).brightness ?? 50
                Accessible.name: "Brightness"
                onMoved: DesktopData.setBrightness(Math.round(value))
            }
            UiLabel { text: Math.round(brightness.value) + "%"; font.pixelSize: 12; Layout.preferredWidth: 40 }
        }
    }
    Card {
        visible: DesktopData.notificationCount > 0
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                UiLabel { text: "Notifications · " + DesktopData.notificationCount; color: Colors.accent; font.pixelSize: 12 }
                UiLabel { Layout.fillWidth: true; text: DesktopData.notifications.current[0]?.summary || ""; maximumLineCount: 1; elide: Text.ElideRight; font.pixelSize: 13 }
            }
            UiButton { text: "Open ›"; onClicked: root.notificationsRequested() }
        }
    }
    Card {
        visible: !!root.player
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                UiLabel { Layout.fillWidth: true; text: root.player?.trackTitle || ""; font.weight: Font.DemiBold; maximumLineCount: 1; elide: Text.ElideRight }
                UiLabel { Layout.fillWidth: true; text: root.player?.trackArtist || ""; color: Colors.muted; font.pixelSize: 12; maximumLineCount: 1; elide: Text.ElideRight }
            }
            UiButton { glyph: "\u{F04AE}"; enabled: !!root.player?.canGoPrevious; onClicked: root.player.previous(); Accessible.name: "Previous track" }
            UiButton { glyph: root.player?.playbackState === MprisPlaybackState.Playing ? "\u{F03E4}" : "\u{F040A}"; enabled: !!root.player?.canTogglePlaying; onClicked: root.player.togglePlaying(); Accessible.name: "Play or pause" }
            UiButton { glyph: "\u{F04AD}"; enabled: !!root.player?.canGoNext; onClicked: root.player.next(); Accessible.name: "Next track" }
        }
    }
    Card {
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: "Desktop mode"; Layout.fillWidth: true; color: Colors.muted; font.pixelSize: 12 }
            Repeater {
                model: ["normal", "work", "call", "game", "music"]
                UiButton { required property string modelData; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); selected: (DesktopData.controls.mode || "normal") === modelData; enabled: !DesktopData.busy; onClicked: DesktopData.act("mode", [modelData]) }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        UiButton { text: "Lock"; glyph: "\u{F033E}"; onClicked: root.launchRequested(["loginctl", "lock-session"]) }
        UiButton { text: "Power"; glyph: "\u{F0425}"; onClicked: DesktopData.controlTab = "power" }
    }
    Timer { id: refreshAwake; interval: 500; onTriggered: DesktopData.refresh() }
}
