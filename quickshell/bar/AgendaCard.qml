pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "CalendarLogic.js" as Calendar

ColumnLayout {
    id: root
    property var cal: null
    property int limit: 3
    signal calendarRequested()
    readonly property double now: clock.date.getTime()
    readonly property var events: cal && cal.ready && cal.configured ? Calendar.upcoming(cal.events, now, limit) : []
    readonly property string status: !cal || !cal.ready ? "Calendar sync is unavailable"
        : !cal.configured ? "No calendars connected"
        : cal.stale ? "Sync is overdue · showing saved events"
        : cal.broken.length ? "Sync failed: " + cal.broken.join(", ") + " · saved events"
        : ""
    spacing: 10
    SystemClock { id: clock; precision: SystemClock.Minutes }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "UP NEXT"; color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 2; Layout.fillWidth: true }
        UiButton { text: "Calendar ›"; onClicked: root.calendarRequested() }
    }
    UiLabel {
        visible: root.status !== ""; text: root.status; color: Colors.yellow
        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12
    }
    Repeater {
        model: root.events
        EventCard { required property var modelData; Layout.fillWidth: true; event: modelData; now: root.now; showDate: true }
    }
    UiLabel {
        visible: !root.events.length && root.status === ""
        text: "No upcoming events in the synced period"
        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Colors.muted; font.pixelSize: 12
    }
}
