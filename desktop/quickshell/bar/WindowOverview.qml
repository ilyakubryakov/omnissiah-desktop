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
        if (!client || !/^0x[0-9a-f]+$/i.test(client.address) || workspace < 1 || workspace > 12) return
        Hyprland.dispatch("hl.dsp.window.move({ window = " + JSON.stringify("address:" + client.address) + ", workspace = " + JSON.stringify(String(workspace)) + ", follow = false })")
        Hypr.refresh()
    }
    function closeWindow(client) {
        if (!client || !/^0x[0-9a-f]+$/i.test(client.address)) return
        if (root.draggedClient && root.draggedClient.address === client.address) root.draggedClient = null
        Hyprland.dispatch("hl.dsp.window.close({ window = " + JSON.stringify("address:" + client.address) + " })")
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
        font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.px(16)
        background: Rectangle { color: Colors.lightBackground; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
        onTextChanged: root.query = text
        onAccepted: if (root.clients.length || root.minimized.length) root.focusWindow(root.clients[0] || root.minimized[0])
        Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())
    }
    UiLabel { Layout.fillWidth: true; text: "Click to focus, drag onto another workspace, right-click to select for Move, middle-click to close."; wrapMode: Text.Wrap; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(13) }
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
                        keys: ["oninix-window"]
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
                            readonly property bool picked: !!root.draggedClient && root.draggedClient.address === modelData.address
                            border.width: picked ? 2 : 1; border.color: picked || Hypr.active.address === modelData.address ? Colors.accent : Colors.muted
                            activeFocusOnTab: true
                            Keys.onReturnPressed: root.focusWindow(modelData)
                            Accessible.role: Accessible.Button; Accessible.name: modelData.title || modelData.class
                            Accessible.onPressAction: root.focusWindow(modelData)
                            readonly property bool roomy: height >= Shared.DesktopStyle.px(64) && width >= Shared.DesktopStyle.px(64)
                            ApplicationIcon {
                                visible: window.roomy
                                anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: Shared.DesktopStyle.px(8)
                                appClass: window.modelData.class
                                iconSize: Math.min(Shared.DesktopStyle.px(34), window.height / 3)
                                glyphColor: Colors.accent
                            }
                            UiLabel {
                                anchors { fill: parent; margins: Shared.DesktopStyle.px(6); topMargin: window.roomy ? Shared.DesktopStyle.px(14) + Math.min(Shared.DesktopStyle.px(34), window.height / 3) : Shared.DesktopStyle.px(6) }
                                text: window.modelData.title || window.modelData.class; font.pixelSize: Shared.DesktopStyle.px(11)
                                elide: Text.ElideRight; maximumLineCount: 3; clip: true; wrapMode: Text.Wrap
                                horizontalAlignment: window.roomy ? Text.AlignHCenter : Text.AlignLeft
                            }
                            Drag.active: hover.drag.active
                            Drag.keys: ["oninix-window"]
                            Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2
                            MouseArea {
                                id: hover
                                anchors.fill: parent; hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                drag.target: pressedButtons & Qt.LeftButton ? window : null
                                property bool moved: false
                                onPressed: mouse => { moved = false; if (mouse.button === Qt.LeftButton) root.draggedClient = window.modelData }
                                onPositionChanged: if (drag.active) moved = true
                                onReleased: mouse => {
                                    if (mouse.button !== Qt.LeftButton) return
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
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) root.closeWindow(window.modelData)
                                    else if (mouse.button === Qt.RightButton) root.draggedClient = window.picked ? null : window.modelData
                                    else if (!moved) root.focusWindow(window.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !!root.draggedClient
        UiLabel { text: root.draggedClient ? "Move " + (root.draggedClient.title || root.draggedClient.class) : ""; Layout.fillWidth: true; elide: Text.ElideRight }
        ComboBox { id: destination; model: root.workspaces }
        UiButton { text: "Move"; enabled: !!root.draggedClient; onClicked: root.moveWindow(root.draggedClient, Number(destination.currentText)) }
        UiButton { glyph: "\uf00d"; Accessible.name: "Clear selection"; subtle: true; onClicked: root.draggedClient = null }
    }
    UiLabel { visible: root.minimized.length > 0; text: "Minimized"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
    Flow {
        visible: root.minimized.length > 0
        Layout.fillWidth: true; spacing: Shared.DesktopStyle.px(8)
        Repeater {
            model: root.minimized
            Rectangle {
                id: tile
                required property var modelData
                width: Shared.DesktopStyle.px(180); height: Shared.DesktopStyle.px(44)
                radius: Shared.DesktopStyle.radiusControl
                color: tileMouse.containsMouse ? Colors.selection : Colors.lightBackground
                border.width: 1; border.color: Colors.selection
                Accessible.role: Accessible.Button; Accessible.name: "Restore " + (modelData.title || modelData.class)
                RowLayout {
                    anchors { fill: parent; leftMargin: Shared.DesktopStyle.px(10); rightMargin: Shared.DesktopStyle.px(10) }
                    spacing: Shared.DesktopStyle.px(8)
                    ApplicationIcon { appClass: tile.modelData.class; iconSize: Shared.DesktopStyle.px(20); glyphColor: Colors.accent }
                    UiLabel { Layout.fillWidth: true; text: tile.modelData.title || tile.modelData.class; elide: Text.ElideRight; font.pixelSize: Shared.DesktopStyle.px(12) }
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => mouse.button === Qt.MiddleButton ? root.closeWindow(tile.modelData) : root.focusWindow(tile.modelData)
                }
            }
        }
    }
}
