import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../shared" as Shared
import "CalendarLogic.js" as Logic

RowLayout {
    id: bar
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true
    property real availableWidth: 1920
    property var cal: null
    required property var barWindow
    signal openCalendar()
    readonly property var player: PanelBriefing.player
    readonly property bool playing: player !== null
    readonly property bool showMedia: playing && !PanelBriefing.preferBriefing
    onShowMediaChanged: if (!showMedia) playerPopup.dismiss()
    onPlayerChanged: if (!player) playerPopup.dismiss()

    property double now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: bar.now = Date.now() }

    // Only today's timed events: tomorrow's standup is not worth bar space tonight.
    readonly property var meeting: {
        if (!cal || !cal.ready || cal.stale) return null
        const today = Logic.onDay(cal.events, new Date(now)).filter(event => !event.a)
        return Logic.upcoming(today, now, 1)[0] || null
    }
    readonly property int meetingIn: meeting ? Math.ceil((Date.parse(meeting.s) - now) / 60000) : 0


        spacing: 8

        // Right-click anywhere in the group swaps the player and the briefing.
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: PanelBriefing.toggleView() }

        BarSystem { barWindow: bar.barWindow }

        // Two dots tell which view is shown while both exist.
        Item {
            visible: bar.playing
            implicitWidth: 14; implicitHeight: PanelStyle.barHeight
            Layout.fillHeight: true
            Column {
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [true, false]
                    Rectangle {
                        required property bool modelData
                        width: 5; height: 5; radius: 2.5
                        color: ShellLayout.buttonColor("media")
                        opacity: modelData === bar.showMedia ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
                    }
                }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PanelBriefing.toggleView() }
            BarToolTip { target: parent; shown: pagerHover.hovered; text: bar.showMedia ? "Show briefing · right-click" : "Show the player · right-click" }
            HoverHandler { id: pagerHover }
        }

        IdleBriefing {
            visible: !bar.showMedia
            barWindow: bar.barWindow
            availableWidth: bar.availableWidth
        }

        Seg {
            id: track
            visible: bar.showMedia
            maximumLabelWidth: Math.max(100, bar.availableWidth * 0.2)
            readonly property bool paused: bar.player && bar.player.playbackState === MprisPlaybackState.Paused
            glyph: paused ? "\u{F03E4}" : "\u{F075A}"
            tint: paused ? Colors.muted : Colors.foreground
            label: bar.player ? [bar.player.trackArtist, bar.player.trackTitle].filter(s => s).join(" - ") : ""
            onClicked: playerPopup.togglePinned()
            onRightClicked: PanelBriefing.toggleView()
            onMiddleClicked: if (bar.player && bar.player.canTogglePlaying) bar.player.togglePlaying()
            BarPopup {
                id: playerPopup
                anchorItem: track
                barWindow: bar.barWindow
                triggerHovered: track.hovered
                above: bar.barWindow.edge === "bottom"
                tone: ShellLayout.toneColor(ShellLayout.toneName("media"))
                MediaCard { Layout.fillWidth: true; player: bar.player; active: playerPopup.opened }
            }
        }

        SpectrumBars {
            visible: bar.showMedia
            tone: ShellLayout.buttonColor("media")
            Layout.rightMargin: 4
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: playerPopup.togglePinned() }
        }

        // While music plays the meeting shrinks to its countdown; the full agenda stays in its hover card.
        Seg {
            id: meetingSegment
            readonly property string when: bar.meetingIn <= 0 ? "Now"
                : bar.meetingIn <= 60 ? "in " + bar.meetingIn + " min"
                : bar.meeting ? Qt.formatTime(new Date(Date.parse(bar.meeting.s)), "HH:mm") : ""
            visible: bar.meeting !== null
            sep: track.visible
            maximumLabelWidth: Math.max(120, bar.availableWidth * 0.16)
            glyph: "\u{F00F0}"
            label: !bar.meeting ? "" : when
            tint: bar.meetingIn <= 0 && bar.meetingIn > -5 ? Colors.red
                : bar.meetingIn > 0 && bar.meetingIn <= 10 ? Colors.accent
                : bar.meetingIn <= 0 ? Colors.dim : Colors.foreground
            onClicked: meetingPopup.togglePinned()
            onRightClicked: PanelBriefing.toggleView()
            BarPopup {
                id: meetingPopup
                anchorItem: meetingSegment
                barWindow: bar.barWindow
                triggerHovered: meetingSegment.hovered
                above: bar.barWindow.edge === "bottom"
                cardWidth: Shared.DesktopStyle.px(440)
                tone: Colors.cyan
                AgendaCard { Layout.fillWidth: true; cal: bar.cal; onCalendarRequested: { meetingPopup.dismiss(); bar.openCalendar() } }
            }
        }
    }
