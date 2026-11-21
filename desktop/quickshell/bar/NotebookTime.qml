pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    property bool visibleNow: false
    property double now: Date.now() / 1000
    property bool reminders: false
    property bool showDone: false
    spacing: 12
    function clock(seconds) {
        const value = Math.max(0, Math.ceil(seconds))
        const h = Math.floor(value / 3600), m = Math.floor(value / 60) % 60, s = value % 60
        return (h ? h + ":" : "") + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }
    Timer { interval: 1000; running: root.visibleNow; repeat: true; triggeredOnStart: true; onTriggered: root.now = Date.now() / 1000 }
    RowLayout {
        UiButton { text: "Timer"; selected: !root.reminders; onClicked: root.reminders = false }
        UiButton { text: "Reminder"; selected: root.reminders; onClicked: root.reminders = true }
        Item { Layout.fillWidth: true }
    }
    CalendarField { id: label; Layout.fillWidth: true; placeholderText: root.reminders ? "What should I remind you about?" : "Timer name (optional)"; maximumLength: 180 }
    RowLayout {
        visible: !root.reminders; Layout.fillWidth: true
        CalendarField { id: minutes; Layout.preferredWidth: 72; text: "25"; placeholderText: "min"; validator: IntValidator { bottom: 1; top: 1440 } }
        UiLabel { text: "min"; color: Colors.dim }
        Item { Layout.fillWidth: true }
        Repeater {
            model: [5, 15, 25]
            UiButton { required property int modelData; text: String(modelData); onClicked: minutes.text = String(modelData) }
        }
    }
    CalendarField {
        id: dateTime; visible: root.reminders; Layout.fillWidth: true
        text: Qt.formatDateTime(new Date(Date.now() + 3600000), "yyyy-MM-dd HH:mm")
        placeholderText: "YYYY-MM-DD HH:mm"
    }
    RowLayout {
        Layout.fillWidth: true
        UiButton {
            text: root.reminders ? "Add reminder" : "Start timer"; glyph: root.reminders ? "\u{F0F3}" : "\u{F04B}"; selected: true
            onClicked: {
                if (root.reminders) NotebookData.call({op:"add", kind:"reminder", label:label.text, when:dateTime.text})
                else NotebookData.call({op:"add", kind:"timer", label:label.text, seconds:Number(minutes.text) * 60})
            }
        }
        Item { Layout.fillWidth: true }
        UiButton { text: root.showDone ? "Active" : "History"; onClicked: root.showDone = !root.showDone }
    }
    ListView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 10
        model: NotebookData.jobs.filter(j => root.showDone || j.state !== "done").slice().sort((a,b) => a.due - b.due)
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property real remaining: modelData.state === "paused" ? modelData.remaining : modelData.due - root.now
            readonly property real progress: modelData.kind === "timer" && modelData.duration > 0 ? Math.max(0, Math.min(1, remaining / modelData.duration)) : 0
            width: ListView.view.width; height: contents.implicitHeight + 24
            radius: Shared.DesktopStyle.radiusSmall; color: Colors.lightBackground
            border.width: 1; border.color: modelData.state === "fired" ? Colors.accent : Colors.selection
            ColumnLayout {
                id: contents
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    UiLabel { text: card.modelData.kind === "timer" ? "\u{F017}" : "\u{F0F3}"; font.family: Colors.iconFont; color: Colors.accent }
                    UiLabel { text: card.modelData.label; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap }
                }
                UiLabel {
                    text: card.modelData.state === "done" ? "Completed" : card.modelData.state === "fired" ? "Time is up" : card.modelData.kind === "timer" ? root.clock(card.remaining) + (card.modelData.state === "paused" ? " · paused" : "") : Qt.formatDateTime(new Date(card.modelData.due * 1000), "ddd, dd MMM · HH:mm")
                    font.pixelSize: Shared.DesktopStyle.px(card.modelData.kind === "timer" ? 26 : 14)
                    color: card.modelData.state === "done" ? Colors.muted : Colors.accent
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                }
                Rectangle {
                    visible: card.modelData.kind === "timer" && ["running", "paused"].includes(card.modelData.state)
                    Layout.fillWidth: true; height: 4; radius: 2; color: Colors.selection
                    Rectangle { height: parent.height; radius: 2; width: parent.width * card.progress; color: Colors.accent; Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal } } }
                }
                RowLayout {
                    visible: card.modelData.state !== "done"
                    UiButton {
                        visible: card.modelData.kind === "timer" && ["running", "paused"].includes(card.modelData.state)
                        text: card.modelData.state === "paused" ? "Resume" : "Pause"
                        onClicked: NotebookData.call({op:card.modelData.state === "paused" ? "resume" : "pause", id:card.modelData.id})
                    }
                    UiButton { visible: card.modelData.state === "fired"; text: "+10 min"; onClicked: NotebookData.call({op:"snooze", id:card.modelData.id}) }
                    UiButton { text: card.modelData.state === "fired" ? "Done" : "Cancel"; onClicked: NotebookData.call({op:"done", id:card.modelData.id}) }
                    Item { Layout.fillWidth: true }
                }
            }
        }
        UiLabel { anchors.centerIn: parent; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; visible: !parent.count; text: "A gentle nudge when you need it.\nTimers keep running with the panel closed."; color: Colors.muted }
    }
}
