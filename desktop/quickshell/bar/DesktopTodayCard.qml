pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    id: root
    required property var feed
    required property bool actionsEnabled
    required property bool calendarReady
    required property bool calendarStale
    required property int lockInset
    readonly property var current: feed?.next ?? null
    readonly property bool happening: current?.state === "now"
    readonly property string joinUrl: current?.join || ""
    readonly property string error: calendarStale ? "Calendar is out of date" : ""
    readonly property var agenda: (feed?.allday ?? []).concat(feed?.events ?? [])

    radius: Shared.DesktopStyle.radiusCard
    color: Colors.background
    border.width: 1
    border.color: Colors.selection
    clip: true

    function time(iso: string): string {
        const date = new Date(iso)
        return isNaN(date.getTime()) ? "" : Qt.formatTime(date, "HH:mm")
    }
    function countdown(): string {
        if (!current) return ""
        if (happening) {
            const minutes = Math.ceil((Date.parse(current.end) - feed.now) / 60000)
            return minutes > 0 ? "Now · " + minutes + " min left" : "Now"
        }
        return current.minutes > 0 ? "Next · In " + current.minutes + " min" : "Next · Starts shortly"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Shared.DesktopStyle.px(16)
        spacing: Shared.DesktopStyle.px(10)

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: root.lockInset
            spacing: Shared.DesktopStyle.px(8)
            UiLabel {
                text: "\u{F00ED}"
                color: Colors.accent
                font.family: Colors.iconFont
                font.pixelSize: Shared.DesktopStyle.px(18)
            }
            UiLabel {
                text: "Today"
                font.pixelSize: Shared.DesktopStyle.px(21)
                font.weight: Font.DemiBold
            }
            UiLabel {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: Qt.formatDate(root.feed.date, "ddd, d MMM")
                color: Colors.muted
                font.pixelSize: Shared.DesktopStyle.px(12)
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: spotlight.implicitHeight + Shared.DesktopStyle.px(24)
            radius: Shared.DesktopStyle.radiusControl
            color: Colors.lightBackground
            border.color: Colors.selection
            border.width: 1

            RowLayout {
                id: spotlight
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: Shared.DesktopStyle.px(12)
                anchors.rightMargin: anchors.leftMargin
                spacing: Shared.DesktopStyle.px(10)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Shared.DesktopStyle.px(4)
                    UiLabel {
                        visible: !!root.current
                        Layout.fillWidth: true
                        text: root.countdown()
                        color: root.happening ? Colors.statusAvailable : Colors.accent
                        font.pixelSize: Shared.DesktopStyle.px(12)
                        font.weight: Font.DemiBold
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: root.current ? root.current.title || "Untitled event"
                            : root.feed?.done ? "You're done for today"
                            : !root.calendarReady ? "Calendar unavailable"
                            : root.agenda.length ? "No timed events today" : "No events today"
                        font.pixelSize: Shared.DesktopStyle.px(18)
                        font.weight: Font.DemiBold
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
                UiButton {
                    visible: /^https:\/\//i.test(root.joinUrl)
                    enabled: root.actionsEnabled
                    text: "Join"
                    glyph: "↗"
                    selected: true
                    activeFocusOnTab: false
                    onClicked: Qt.openUrlExternally(root.joinUrl)
                }
            }
        }

        Flickable {
            id: timeline
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: events.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            acceptedButtons: Qt.NoButton
            interactive: root.actionsEnabled
            ScrollBar.vertical: ScrollBar { interactive: false; policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: events
                width: Math.max(0, timeline.width - Shared.DesktopStyle.px(8))
                spacing: 0
                Repeater {
                    model: root.agenda
                    RowLayout {
                        id: eventRow
                        required property var modelData
                        readonly property bool past: modelData.state === "past"
                        readonly property bool live: modelData.state === "now"
                        readonly property bool next: modelData.state === "next"
                        Layout.fillWidth: true
                        Layout.preferredHeight: Shared.DesktopStyle.px(27)
                        spacing: Shared.DesktopStyle.px(8)
                        UiLabel {
                            Layout.preferredWidth: Shared.DesktopStyle.px(48)
                            text: eventRow.modelData.start ? root.time(eventRow.modelData.start) : "All day"
                            color: Colors.muted
                            font.pixelSize: Shared.DesktopStyle.px(12)
                            wrapMode: Text.NoWrap
                        }
                        Rectangle {
                            readonly property int size: Shared.DesktopStyle.px(6)
                            Layout.preferredWidth: size
                            Layout.preferredHeight: size
                            radius: size / 2
                            color: eventRow.live ? Colors.statusAvailable : eventRow.next ? Colors.accent
                                : eventRow.past ? Colors.dim : Colors.muted
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            text: eventRow.modelData.title || "Untitled event"
                            color: eventRow.past ? Colors.muted : Colors.foreground
                            font.pixelSize: Shared.DesktopStyle.px(13)
                            font.weight: eventRow.live || eventRow.next ? Font.DemiBold : Font.Normal
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        UiLabel {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.error
            color: Colors.muted
            font.pixelSize: Shared.DesktopStyle.px(11)
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
    }
}
