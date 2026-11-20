import QtQuick
import QtQuick.Layouts
import "../shared" as Shared
import "CalendarLogic.js" as Calendar

Rectangle {
    id: root
    required property var event
    property double now: Date.now()
    property bool showDate: false
    readonly property bool ongoing: Calendar.ongoing(event, now)
    readonly property color tint: (event.kind || event.c) === "work" ? Colors.cyan : (event.kind || event.c) === "personal" ? Colors.magenta : Colors.accent
    implicitHeight: content.implicitHeight + 24
    radius: Shared.DesktopStyle.radiusSmall
    color: ShellLayout.blend(Colors.lightBackground, tint, ongoing ? 0.12 : 0.04)
    border.width: ongoing ? 1 : 0
    border.color: ShellLayout.blend(Colors.lightBackground, tint, 0.45)
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 10 }
        width: 3; radius: 1.5; color: root.tint
    }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 24; rightMargin: 12; topMargin: 12 }
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            UiLabel {
                Layout.fillWidth: true
                text: (root.showDate ? Qt.formatDateTime(new Date(root.event.s), "ddd, d MMM") + " · " : "")
                    + (root.event.a ? "All day" : Qt.formatDateTime(new Date(root.event.s), "HH:mm")
                        + (Calendar.endTime(root.event) > Date.parse(root.event.s) ? " - " + Qt.formatDateTime(new Date(root.event.e), "HH:mm") : ""))
                color: root.tint; font.pixelSize: Shared.DesktopStyle.px(12); elide: Text.ElideRight
            }
            UiLabel { text: root.event.a ? "" : Calendar.duration(root.event); font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.muted }
        }
        UiLabel {
            Layout.fillWidth: true
            text: root.event.t || "Untitled event"; wrapMode: Text.Wrap; maximumLineCount: 3
            elide: Text.ElideRight; font.pixelSize: Shared.DesktopStyle.px(13); font.weight: Font.DemiBold
        }
        RowLayout {
            Layout.fillWidth: true
            UiLabel { Layout.fillWidth: true; text: root.event.cn || root.event.c || "Calendar"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11); elide: Text.ElideRight }
            UiLabel { text: Calendar.countdown(root.event, root.now); color: root.tint; font.pixelSize: Shared.DesktopStyle.px(11) }
        }
        Rectangle {
            visible: root.ongoing
            Layout.fillWidth: true; implicitHeight: 3; radius: 1.5; color: Colors.selection
            Rectangle {
                height: parent.height; radius: 1.5; color: root.tint
                width: parent.width * Math.max(0, Math.min(1, (root.now - Date.parse(root.event.s)) / (Calendar.endTime(root.event) - Date.parse(root.event.s))))
                Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal } }
            }
        }
    }
}
