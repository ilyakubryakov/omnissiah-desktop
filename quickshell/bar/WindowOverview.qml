pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 14
    property string query: ""
    signal chosen()
    function found(c) { return ((c.title || "") + " " + (c.class || "")).toLowerCase().includes(query.toLowerCase()) }
    readonly property var clients: Hypr.clients.filter(c => c.workspace && c.workspace.id > 0 && found(c))
    readonly property var minimized: Minimized.windows.filter(c => found(c))
    readonly property var workspaces: [...new Set(Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id).concat(clients.map(c => c.workspace.id), [1,2,3,4,5,6,7,8,9,10], Shared.Screens.tv ? [11] : []))].sort((a,b) => a-b)
    property var draggedClient: null
    function moveWindow(client, workspace) {
        if (!client || !/^0x[0-9a-f]+$/i.test(client.address) || workspace < 1 || workspace > 11) return
        Hyprland.dispatch("hl.dsp.window.move({ window = " + JSON.stringify("address:" + client.address) + ", workspace = " + JSON.stringify(String(workspace)) + ", follow = false })")
        Hypr.refresh()
    }
    function focusWindow(client) {
        if (!/^0x[0-9a-f]+$/i.test(client.address)) return
        chosen()
        Qt.callLater(() => Minimized.show(client))
    }
    TextField {
        id: search
        Layout.fillWidth: true; padding: 12
        placeholderText: "Find an application or window…"
        color: Colors.foreground; placeholderTextColor: Colors.muted
        font.family: Colors.textFont; font.pixelSize: 16
        background: Rectangle { color: Colors.lightBackground; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
        onTextChanged: root.query = text
        onAccepted: if (root.clients.length || root.minimized.length) root.focusWindow(root.clients[0] || root.minimized[0])
        Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())
    }
    UiLabel { Layout.fillWidth: true; text: "Drag a window onto another workspace. Or select a window and use Move below."; color: Colors.muted; font.pixelSize: 13 }
    GridLayout {
        Layout.fillWidth: true
        columns: 2; columnSpacing: 14; rowSpacing: 14
        Repeater {
            id: workspaceRepeater
            model: root.workspaces
            ColumnLayout {
                id: workspace
                required property int modelData
                property alias dropTarget: map
                readonly property var windows: root.clients.filter(c => c.workspace.id === modelData)
                readonly property var monitor: Hypr.monitors.find(m => m.activeWorkspace && m.activeWorkspace.id === modelData)
                    || Hypr.monitors.find(m => windows.length && m.id === windows[0].monitor)
                    || Hypr.monitors.find(m => m.name === (modelData === 11 ? Shared.Screens.output("tv") : (Shared.Screens.main ? Shared.Screens.main.name : ""))) || ({x:0,y:0,width:1920,height:1080,scale:1})
                readonly property real minX: monitor.x
                readonly property real minY: monitor.y
                readonly property real spanX: monitor.width / monitor.scale
                readonly property real spanY: monitor.height / monitor.scale
                Layout.fillWidth: true
                UiButton {
                    text: "Workspace " + workspace.modelData + " · " + workspace.windows.length
                    selected: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspace.modelData
                    onClicked: { const id = String(workspace.modelData); root.chosen(); Qt.callLater(() => Hyprland.dispatch("hl.dsp.focus({ workspace = " + JSON.stringify(id) + " })")) }
                }
                Rectangle {
                    id: map
                    Layout.fillWidth: true; Layout.preferredHeight: Math.max(100, (width - 16) * workspace.spanY / workspace.spanX + 16)
                    color: Colors.darkBackground; border.width: 1
                    clip: false
                    border.color: drop.containsDrag ? Colors.accent : Colors.selection
                    DropArea {
                        id: drop
                        anchors.fill: parent
                        keys: ["station-window"]
                        onDropped: event => { root.moveWindow(root.draggedClient, workspace.modelData); event.acceptProposedAction() }
                    }
                    Repeater {
                        model: workspace.windows
                        Rectangle {
                            id: window
                            required property var modelData
                            x: 8 + (modelData.at[0] - workspace.minX) / workspace.spanX * (map.width - 16)
                            y: 8 + (modelData.at[1] - workspace.minY) / workspace.spanY * (map.height - 16)
                            width: Math.max(24, modelData.size[0] / workspace.spanX * (map.width - 16))
                            height: Math.max(24, modelData.size[1] / workspace.spanY * (map.height - 16))
                            color: hover.containsMouse || activeFocus ? Colors.selection : Colors.lightBackground
                            border.width: 1; border.color: Hypr.active.address === modelData.address ? Colors.accent : Colors.muted
                            activeFocusOnTab: true
                            Keys.onReturnPressed: root.focusWindow(modelData)
                            Accessible.role: Accessible.Button; Accessible.name: modelData.title || modelData.class
                            Accessible.onPressAction: root.focusWindow(modelData)
                            UiLabel { anchors.fill: parent; anchors.margins: 6; text: window.modelData.title || window.modelData.class; font.pixelSize: 11; elide: Text.ElideRight; maximumLineCount: 3; clip: true }
                            Drag.active: hover.drag.active
                            Drag.keys: ["station-window"]
                            Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2
                            MouseArea {
                                id: hover
                                anchors.fill: parent; hoverEnabled: true
                                drag.target: window
                                property bool moved: false
                                onPressed: { moved = false; root.draggedClient = window.modelData }
                                onPositionChanged: if (drag.active) moved = true
                                onReleased: mouse => {
                                    if (moved) {
                                        const accepted = window.Drag.drop()
                                        if (accepted === Qt.IgnoreAction) {
                                            for (let i = 0; i < workspaceRepeater.count; i++) {
                                                const target = workspaceRepeater.itemAt(i)
                                                const point = target.dropTarget.mapFromItem(window, mouse.x, mouse.y)
                                                if (point.x >= 0 && point.y >= 0 && point.x <= target.dropTarget.width && point.y <= target.dropTarget.height) {
                                                    root.moveWindow(window.modelData, target.modelData)
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    window.x = Qt.binding(() => 8 + (window.modelData.at[0] - workspace.minX) / workspace.spanX * (map.width - 16))
                                    window.y = Qt.binding(() => 8 + (window.modelData.at[1] - workspace.minY) / workspace.spanY * (map.height - 16))
                                }
                                onClicked: if (!moved) root.focusWindow(window.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: root.draggedClient ? "Move: " + root.draggedClient.class : "Select a window by dragging or using Select below"; Layout.fillWidth: true; elide: Text.ElideRight }
        ComboBox { id: destination; model: root.workspaces }
        UiButton { text: "Move"; enabled: !!root.draggedClient; onClicked: root.moveWindow(root.draggedClient, Number(destination.currentText)) }
    }
    Repeater {
        model: root.clients
        RowLayout {
            id: clientRow
            required property var modelData
            Layout.fillWidth: true
            UiButton { Layout.fillWidth: true; text: clientRow.modelData.workspace.id + " · " + clientRow.modelData.class + " · " + (clientRow.modelData.title || "").slice(0, 60); onClicked: root.focusWindow(clientRow.modelData) }
            UiButton { text: "Select"; selected: root.draggedClient && root.draggedClient.address === clientRow.modelData.address; onClicked: root.draggedClient = clientRow.modelData }
        }
    }

    Repeater {
        model: root.minimized
        UiButton {
            required property var modelData
            Layout.fillWidth: true
            text: "Minimized · " + modelData.class + " · " + (modelData.title || "").slice(0, 60)
            onClicked: root.focusWindow(modelData)
        }
    }
}
