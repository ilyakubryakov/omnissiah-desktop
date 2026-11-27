pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../shared" as Shared
import "Holidays.js" as Holidays
import "CalendarLogic.js" as Calendar

ColumnLayout {
    id: root
    property var cal: null
    signal accountsRequested()
    property int offset: 0
    property date selectedDate: clock.date
    readonly property date today: clock.date
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int firstDay: (month.getDay() + 6) % 7
    readonly property var holidays: Object.assign({}, Holidays.forYear(month.getFullYear() - 1),
        Holidays.forYear(month.getFullYear()), Holidays.forYear(month.getFullYear() + 1))
    readonly property var selectedHolidays: holidays[Holidays.key(selectedDate)] || []
    readonly property var events: cal && cal.ready && cal.configured ? cal.events : []
    readonly property var selectedEvents: Calendar.onDay(events, selectedDate)
    onSelectedDateChanged: if (eventScroll) eventScroll.ScrollBar.vertical.position = 0
    spacing: Shared.DesktopStyle.cardSpacing
    SystemClock { id: clock; precision: SystemClock.Minutes }
    function reset() { offset = 0; selectedDate = today }
    onOffsetChanged: { flip.from = (offset < previousOffset ? -1 : 1) * Shared.DesktopStyle.px(10); previousOffset = offset; flip.restart(); fade.restart() }
    property int previousOffset: 0
    Keys.onLeftPressed: offset--
    Keys.onRightPressed: offset++
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: Shared.DesktopStyle.spaceUnit
            UiLabel { text: "CALENDAR"; font.pixelSize: Shared.DesktopStyle.px(10); font.letterSpacing: Shared.DesktopStyle.px(2); color: Colors.accent }
            UiLabel { text: Qt.formatDateTime(root.month, "MMMM yyyy"); font.pixelSize: Shared.DesktopStyle.px(20); font.weight: Font.DemiBold }
        }
        UiButton { text: "‹"; Accessible.name: "Previous month"; onClicked: root.offset-- }
        UiButton { text: "›"; Accessible.name: "Next month"; onClicked: root.offset++ }
    }
    GridLayout {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: Shared.DesktopStyle.px(276)
        columns: 7; rowSpacing: Shared.DesktopStyle.spaceUnit; columnSpacing: Shared.DesktopStyle.spaceUnit
        transform: Translate { id: slide }
        NumberAnimation { id: flip; target: slide; property: "x"; to: 0; duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic }
        NumberAnimation { id: fade; target: grid; property: "opacity"; from: 0.4; to: 1; duration: Shared.DesktopStyle.normal }
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            UiLabel { required property string modelData; Layout.fillWidth: true; text: modelData; horizontalAlignment: Text.AlignHCenter; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
        }
        Repeater {
            model: 42
            Rectangle {
                id: day
                required property int index
                readonly property date date: new Date(root.month.getFullYear(), root.month.getMonth(), index - root.firstDay + 1)
                readonly property bool current: date.getMonth() === root.month.getMonth()
                readonly property bool selected: date.toDateString() === root.selectedDate.toDateString()
                readonly property bool today: date.toDateString() === root.today.toDateString()
                readonly property var holidays: root.holidays[Holidays.key(date)] || []
                readonly property int eventCount: Calendar.onDay(root.events, date).length
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: Shared.DesktopStyle.radiusSmall
                color: selected ? Colors.accent : hover.hovered ? Colors.selection : "transparent"
                border.width: today && !selected ? 1 : 0
                border.color: Colors.accent
                Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                HoverHandler { id: hover }
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: Qt.formatDate(day.date, "dddd d MMMM yyyy") + ", " + day.eventCount + " events"
                Accessible.onPressAction: root.selectedDate = day.date
                Keys.onReturnPressed: root.selectedDate = day.date
                Keys.onSpacePressed: root.selectedDate = day.date
                UiLabel {
                    anchors.centerIn: parent
                    text: day.date.getDate()
                    color: day.selected ? Colors.background : !day.current ? Colors.dim
                        : day.holidays.length ? Colors.yellow : (day.date.getDay() === 0 || day.date.getDay() === 6) ? Colors.muted : Colors.foreground
                    font.pixelSize: Shared.DesktopStyle.px(13)
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: Shared.DesktopStyle.spaceUnit
                    width: Shared.DesktopStyle.px(3); height: Shared.DesktopStyle.px(3); radius: Shared.DesktopStyle.px(3) / 2
                    visible: day.holidays.length > 0 || day.eventCount > 0
                    color: day.selected ? Colors.background : day.eventCount > 0 ? Colors.cyan : Colors.yellow
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedDate = day.date }
            }
        }
    }
    UiButton { text: "Manage calendars"; glyph: "\u{F073}"; Layout.fillWidth: true; onClicked: root.accountsRequested() }
    Rectangle { Layout.fillWidth: true; height: 1; color: Colors.selection }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { Layout.fillWidth: true; text: Qt.formatDate(root.selectedDate, "ddd, d MMM"); font.pixelSize: Shared.DesktopStyle.px(14); font.weight: Font.DemiBold }
        UiButton { text: "Today"; onClicked: root.reset() }
    }
    UiLabel {
        Layout.fillWidth: true
        visible: root.selectedHolidays.length > 0
        text: root.selectedHolidays.map(h => h.country + " · " + h.name).join("\n")
        wrapMode: Text.WordWrap; font.pixelSize: Shared.DesktopStyle.px(12); color: Colors.yellow; textFormat: Text.PlainText
    }
    ScrollView {
        id: eventScroll
        visible: root.selectedEvents.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(eventList.implicitHeight, Shared.DesktopStyle.px(240))
        contentWidth: availableWidth
        contentHeight: eventList.implicitHeight
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            id: eventList
            width: eventScroll.availableWidth - Shared.DesktopStyle.px(10)
            spacing: Shared.DesktopStyle.spaceUnit * 2
            Repeater {
                model: root.selectedEvents
                EventCard { required property var modelData; Layout.fillWidth: true; event: modelData; now: root.today.getTime() }
            }
        }
    }
    UiLabel {
        Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Shared.DesktopStyle.px(12); color: Colors.muted
        visible: root.selectedEvents.length === 0 || !root.cal || root.cal.stale || root.cal.broken.length > 0
        text: !root.cal || !root.cal.ready ? "Calendar sync is unavailable" : !root.cal.configured ? "No calendars connected"
            : root.cal.stale ? "Sync is overdue · showing saved events"
            : root.cal.broken.length ? "Some calendars failed to sync · showing saved events" : "No synced events for this day"
    }
}
