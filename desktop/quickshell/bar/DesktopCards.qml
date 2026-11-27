pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared
import "CalendarLogic.js" as Calendar

PanelWindow {
    id: root
    required property var screenTarget
    required property var cal
    signal menuRequested(point position)
    readonly property rect todayRect: visible ? today.inputRect : Qt.rect(0, 0, 0, 0)
    readonly property bool editing: visible && !today.locked
    property var placedOn: null

    readonly property int inset: Shared.DesktopStyle.px(24)
    readonly property int gridStep: Shared.DesktopStyle.px(24)
    readonly property size workArea: Qt.size(width, height)
    readonly property bool shown: DesktopCardPrefs.loaded && DesktopCardPrefs.cards.today?.enabled !== false

    screen: screenTarget
    visible: shown && screenTarget !== null && placedOn === screenTarget
    onScreenTargetChanged: Qt.callLater(() => { placedOn = screenTarget })
    Component.onCompleted: Qt.callLater(() => { placedOn = screenTarget })

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "oninix-desktop-cards"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        Region { item: root.editing ? editArea : null }
        Region { item: root.visible && !root.editing ? today : null }
    }

    Item { id: editArea; anchors.fill: parent }
    Item {
        id: grid
        anchors.fill: parent
        visible: opacity > 0
        opacity: today.editing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
        Repeater {
            model: grid.visible ? Math.floor(root.width / root.gridStep) : 0
            Rectangle {
                required property int index
                x: (index + 1) * root.gridStep; width: 1; height: grid.height
                color: Colors.foreground; opacity: (index + 1) % 4 === 0 ? 0.16 : 0.06
            }
        }
        Repeater {
            model: grid.visible ? Math.floor(root.height / root.gridStep) : 0
            Rectangle {
                required property int index
                y: (index + 1) * root.gridStep; height: 1; width: grid.width
                color: Colors.foreground; opacity: (index + 1) % 4 === 0 ? 0.16 : 0.06
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: mouse => root.menuRequested(Qt.point(mouse.x, mouse.y))
    }

    DesktopCardFrame {
        id: today
        visible: root.visible
        cardId: "today"
        gridStep: root.gridStep
        workArea: root.workArea
        minimumSize: Qt.size(Shared.DesktopStyle.px(304), Shared.DesktopStyle.px(256))
        maximumSize: Qt.size(Shared.DesktopStyle.px(880), Shared.DesktopStyle.px(960))
        defaultGeometry: {
            const w = Math.min(Shared.DesktopStyle.px(392), Math.max(0, root.width - 2 * root.inset))
            const h = Math.min(Shared.DesktopStyle.px(384), Math.max(0, root.height - 2 * root.inset))
            return Qt.rect(root.width - root.inset - w, root.inset, w, h)
        }
        sourceComponent: DesktopTodayCard {
            feed: Calendar.today(root.cal.events, root.cal.now * 1000)
            calendarReady: root.cal.ready
            calendarStale: root.cal.stale
            actionsEnabled: today.locked
            lockInset: today.lockInset
        }
    }
}
