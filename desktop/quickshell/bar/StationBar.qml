pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

PanelWindow {
    id: shellWindow
    required property var modelData
    property var cal: null
    property string edge: "top"
    signal openPanel(string page)
    signal openCalendar()
    property string dragToken: ""
    property point dragPoint: Qt.point(-1e6, -1e6)
    signal iconDropped(string token)
    function beginIconDrag(token) { PopupState.close(); dragToken = token }
    function endIconDrag() {
        if (!dragToken) return
        const token = dragToken
        iconDropped(token)
        dragToken = ""; dragPoint = Qt.point(-1e6, -1e6)
    }
    readonly property string role: Shared.Screens.main && modelData.name === Shared.Screens.main.name ? "primary" : "secondary"
    readonly property var groups: ShellPrefs.layouts[role][edge]
    readonly property bool editing: ShellPrefs.editingPanels && ShellPrefs.editRole === role
    readonly property var weights: ({launchers: 1, workspaces: 0.9, status: 1.4, media: 1.1, window: 0.8, metrics: 1.5})
    readonly property real weightSum: groups.reduce((sum, name) => sum + weights[name], 0)
    screen: modelData
    visible: groups.length > 0 || editing
    anchors { top: shellWindow.edge === "top"; bottom: shellWindow.edge === "bottom"; left: true; right: true }
    implicitHeight: PanelStyle.barHeight
    margins.top: edge === "top" ? PanelStyle.outerGap : 0
    margins.bottom: edge === "bottom" ? PanelStyle.outerGap : 0
    WlrLayershell.namespace: "oninix-panel"
    color: "transparent"
    mask: Region { item: panelContent }
    PanelContext { id: panelContext; screenName: shellWindow.screen ? shellWindow.screen.name : "" }
    function parts() { const items = []; for (let i = 0; i < groupRepeater.count; i++) if (groupRepeater.itemAt(i)) items.push(groupRepeater.itemAt(i)); return items }
    function arrange() {
        const items = parts(), total = items.reduce((n, i) => n + i.width, 0), gap = Math.max(0, (panelContent.width - total) / Math.max(1, items.length - 1))
        let x = 0
        items.forEach((item, index) => {
            item.x = items.length === 1 ? (panelContent.width - item.width) / 2 : x
            if (items.length === 3 && index === 1) item.x = Math.max(items[0].width + Shared.DesktopStyle.px(8), Math.min((panelContent.width - item.width) / 2, panelContent.width - items[2].width - item.width - Shared.DesktopStyle.px(8)))
            x += item.width + gap
        })
        if (backdrop.groups.length !== items.length || items.some((item, i) => item !== backdrop.groups[i])) backdrop.groups = items
    }
    PanelBackdrop {
        id: backdrop; anchors.fill: parent; context: panelContext; groups: []
        sideInset: panelContent.x
        pixelScale: (Hypr.monitors.find(m => m.name === panelContext.screenName) || {}).scale || 1
    }
    Item {
        id: panelContent; z: 1
        x: panelContext.sideGapFor(shellWindow.width); width: Math.max(0, shellWindow.width - 2 * x); height: shellWindow.height
        onWidthChanged: Qt.callLater(shellWindow.arrange)
        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.RightButton
            onClicked: { ShellPrefs.editRole = shellWindow.role; ShellPrefs.editingPanels = true; shellWindow.openPanel("panels") }
        }
        Repeater {
            id: groupRepeater; model: shellWindow.groups
            onItemAdded: Qt.callLater(shellWindow.arrange)
            onItemRemoved: Qt.callLater(shellWindow.arrange)
            Item {
                id: slot
                required property string modelData
                required property int index
                readonly property real budget: Math.max(Shared.DesktopStyle.px(48), (panelContent.width - Shared.DesktopStyle.px(12) * Math.max(0, shellWindow.groups.length - 1)) * shellWindow.weights[modelData] / Math.max(1, shellWindow.weightSum))
                readonly property color tone: ShellLayout.toneColor(ShellLayout.toneName(modelData))
                readonly property real strength: ShellLayout.toneName(modelData) === "none" ? 0 : ShellLayout.groupStrength
                readonly property real hoverTint: content.item ? content.item.hoverTint : 0
                width: Math.min(content.item ? content.item.implicitWidth : budget, budget)
                height: panelContent.height
                onWidthChanged: Qt.callLater(shellWindow.arrange)
                Flickable {
                    id: viewport
                    anchors.fill: parent; clip: true; boundsBehavior: Flickable.StopAtBounds
                    interactive: false
                    contentWidth: content.width; contentHeight: height
                    onContentWidthChanged: if (slot.modelData === "status") contentX = Math.max(0, contentWidth - width)
                    onWidthChanged: if (slot.modelData === "status") contentX = Math.max(0, contentWidth - width)
                    onContentXChanged: {
                        const bounded = Math.max(0, Math.min(contentX, Math.max(0, contentWidth - width)))
                        if (contentX !== bounded) contentX = bounded
                    }
                    WheelHandler { enabled: viewport.contentWidth > viewport.width; property: "contentX"; orientation: Qt.Horizontal; rotationScale: -28 }
                    WheelHandler { enabled: viewport.contentWidth > viewport.width; property: "contentX"; orientation: Qt.Vertical; rotationScale: -28 }
                    Loader {
                        id: content
                        width: item ? item.implicitWidth : 0; height: parent.height
                        sourceComponent: ({launchers: launchers, workspaces: workspaces, status: status, media: media, window: window, metrics: metrics})[slot.modelData]
                        Component { id: launchers; BarGroup { group: "launchers"; BarItems { bar: shellWindow; group: "launchers" } } }
                        Component { id: workspaces; BarWorkspaces { bar: shellWindow; budget: slot.budget } }
                        Component { id: status; BarGroup { group: "status"; BarItems { bar: shellWindow; group: "status" } } }
                        Component { id: media; BarGroup { group: "media"; BarMedia { barWindow: shellWindow; availableWidth: Math.min(panelContent.width, slot.budget * 2.8); cal: shellWindow.cal; onOpenCalendar: shellWindow.openCalendar() } } }
                        Component { id: window; BarGroup { group: "window"; BarWindow { barWindow: shellWindow; availableWidth: Math.max(0, slot.budget - Shared.DesktopStyle.px(230)); compact: slot.budget < Shared.DesktopStyle.px(245) } } }
                        Component { id: metrics; BarGroup { group: "metrics"; BarMetrics { barWindow: shellWindow; availableWidth: panelContent.width } } }
                    }
                }
                Rectangle {
                    id: handle; visible: shellWindow.editing; anchors.fill: parent; radius: PanelStyle.cornerRadius
                    color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.94)
                    border.color: Colors.accent; border.width: 1
                    UiLabel { anchors.centerIn: parent; text: "⠿  " + slot.modelData; color: Colors.accent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.OpenHandCursor
                        onClicked: shellWindow.openPanel("panels")
                    }
                }
            }
        }
    }
}
