pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

SettingsCard {
    id: root
    readonly property var titles: ({launchers: "Applications", workspaces: "Workspaces", status: "Tray & controls", media: "Media & agenda", window: "Window & tiling", metrics: "Resources & home"})
    property string dragging: ""
    property point dragPoint: Qt.point(0, 0)
    function finish(group, point) {
        for (let i = 0; i < lanes.count; i++) {
            const lane = lanes.itemAt(i), box = lane.dropBox, pos = box.mapToItem(root, 0, 0)
            if (point.y < pos.y || point.y > pos.y + box.height || point.x < pos.x || point.x > pos.x + box.width) continue
            if (lane.modelData === "hidden" && group === "status") break
            let before = ""
            for (let j = 0; j < lane.entries.count; j++) {
                const row = lane.entries.itemAt(j), y = row.mapToItem(root, 0, 0).y
                if (row.modelData !== group && point.y < y + row.height / 2) { before = row.modelData; break }
            }
            ShellPrefs.moveGroup(ShellPrefs.editRole, group, lane.modelData, before)
            break
        }
        dragging = ""
    }
    readonly property var layout: ShellPrefs.layouts[ShellPrefs.editRole]
    RowLayout {
        Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(10)
        UiLabel { text: "Panel layout"; font.weight: Font.DemiBold; font.pixelSize: Shared.DesktopStyle.px(15); Layout.fillWidth: true }
        Segmented {
            model: [{id: "primary", title: "Main screen"}, {id: "secondary", title: "Other screens"}]
            current: ShellPrefs.editRole
            onChosen: id => ShellPrefs.editRole = id
        }
        UiButton { text: ShellPrefs.editingPanels ? "Finish editing" : "Highlight groups"; selected: ShellPrefs.editingPanels; onClicked: ShellPrefs.editingPanels = !ShellPrefs.editingPanels }
    }
    UiLabel { Layout.fillWidth: true; text: "Drag groups between the rows or onto another group to change their order. The tray and Control Station always remain available."; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); wrapMode: Text.WordWrap }
    Repeater {
        id: lanes
        model: ["top", "bottom", "hidden"]
        ColumnLayout {
            id: lane
            required property string modelData
            property alias dropBox: laneBox
            property alias entries: entries
            Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(6)
            UiLabel { text: ({top: "Top panel", bottom: "Bottom panel", hidden: "Hidden"})[lane.modelData]; color: Colors.muted }
            Rectangle {
                id: laneBox
                Layout.fillWidth: true; implicitHeight: tiles.implicitHeight + Shared.DesktopStyle.px(16)
                radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.color: root.dragging ? Colors.accent : Colors.selection
                ColumnLayout {
                    id: tiles; anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.spaceUnit * 2 } spacing: Shared.DesktopStyle.px(5)
                    UiLabel { visible: root.layout[lane.modelData].length === 0; text: "Drop a group here"; color: Colors.muted; Layout.fillWidth: true; Layout.preferredHeight: Shared.DesktopStyle.px(32) }
                    Repeater {
                        id: entries
                        model: root.layout[lane.modelData]
                        Item {
                            id: slot; required property string modelData; required property int index
                            Layout.fillWidth: true; implicitHeight: Shared.DesktopStyle.px(42); z: root.dragging === modelData ? 20 : 1
                            Rectangle {
                                id: tile; property string groupId: slot.modelData
                                width: slot.width; height: slot.height; radius: Shared.DesktopStyle.px(8)
                                color: root.dragging === slot.modelData ? Colors.selection : Colors.lightBackground
                                border.color: root.dragging === slot.modelData ? Colors.accent : Colors.selection; border.width: 1
                                MouseArea {
                                    id: dragger; width: parent.width - actions.width - Shared.DesktopStyle.px(12); height: parent.height
                                    preventStealing: true; cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property point start
                                    onPressed: m => { start = mapToItem(root, m.x, m.y) }
                                    onPositionChanged: m => {
                                        if (!pressed) return
                                        const point = mapToItem(root, m.x, m.y)
                                        if (Math.hypot(point.x - start.x, point.y - start.y) > Shared.DesktopStyle.px(6)) root.dragging = slot.modelData
                                        root.dragPoint = point
                                    }
                                    onReleased: m => { if (root.dragging) root.finish(slot.modelData, mapToItem(root, m.x, m.y)) }
                                    onCanceled: root.dragging = ""
                                    UiLabel { anchors { left: parent.left; leftMargin: Shared.DesktopStyle.px(12); verticalCenter: parent.verticalCenter } text: "⠿   " + root.titles[slot.modelData] }
                                }
                                RowLayout {
                                    id: actions; anchors { right: parent.right; rightMargin: Shared.DesktopStyle.spaceUnit; verticalCenter: parent.verticalCenter } spacing: Shared.DesktopStyle.px(2)
                                    UiButton { glyph: "\uf062"; Accessible.name: "Move up"; enabled: slot.index > 0; onClicked: ShellPrefs.moveGroup(ShellPrefs.editRole, slot.modelData, lane.modelData, root.layout[lane.modelData][slot.index - 1]) }
                                    UiButton { glyph: "\uf063"; Accessible.name: "Move down"; enabled: slot.index < root.layout[lane.modelData].length - 1; onClicked: ShellPrefs.moveGroup(ShellPrefs.editRole, slot.modelData, lane.modelData, root.layout[lane.modelData][slot.index + 2] || "") }
                                    UiComboBox {
                                        implicitWidth: Shared.DesktopStyle.px(110); implicitHeight: Shared.DesktopStyle.px(32)
                                        model: slot.modelData === "status" ? ["top", "bottom"] : ["top", "bottom", "hidden"]
                                        currentIndex: model.indexOf(lane.modelData)
                                        palette.button: Colors.selection; palette.buttonText: Colors.foreground
                                        palette.base: Colors.background; palette.text: Colors.foreground
                                        onActivated: index => ShellPrefs.moveGroup(ShellPrefs.editRole, slot.modelData, model[index], "")
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
    }
    UiButton { text: "Restore default arrangement"; onClicked: ShellPrefs.send("layout", {role: ShellPrefs.editRole, layout: {top: ["launchers", "workspaces", "status"], bottom: ["media", "window", "metrics"], hidden: []}}) }
    Rectangle {
        parent: root; z: 99; visible: root.dragging !== ""
        x: root.dragPoint.x + Shared.DesktopStyle.px(14); y: root.dragPoint.y - Shared.DesktopStyle.px(16)
        width: dragLabel.implicitWidth + Shared.DesktopStyle.px(24); height: Shared.DesktopStyle.px(34); radius: Shared.DesktopStyle.px(8)
        color: Colors.selection; border.color: Colors.accent
        UiLabel { id: dragLabel; anchors.centerIn: parent; text: root.titles[root.dragging] || ""; color: Colors.accent }
    }

}
