import QtQuick
import QtQuick.Layouts
import "../shared" as Shared
import "BarItemsLogic.js" as Items

Item {
    id: root
    required property var bar
    required property string group
    property var tokens: []
    readonly property var placed: ShellPrefs.placed[group] || []
    onPlacedChanged: if (!Items.same(placed, tokens)) tokens = placed
    Component.onCompleted: tokens = placed
    readonly property var extras: group === "launchers" ? Minimized.extraIds : []
    readonly property bool dragging: bar.dragToken !== ""
    readonly property int gap: 6
    readonly property var drop: insertion(bar.dragPoint)
    implicitWidth: row.width
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true

    function insertion(scene) {
        if (!dragging) return null
        const p = row.mapFromItem(null, scene.x, scene.y)
        if (p.y < 0 || p.y > root.height || p.x < -14 || p.x > tokensEnd() + 14) return null
        for (let i = 0; i < cells.count; i++) {
            const c = cells.itemAt(i)
            if (c && c.visible && p.x < c.x + c.contentWidth / 2) return { before: c.modelData, x: c.x }
        }
        return { before: "", x: tokensEnd() }
    }
    function tokensEnd() {
        let end = 0
        for (let i = 0; i < cells.count; i++) {
            const c = cells.itemAt(i)
            if (c && c.visible) end = c.x + c.contentWidth
        }
        return end
    }
    Connections {
        target: root.bar
        function onIconDropped(token) {
            if (!root.drop) return
            const before = root.drop.before, group = root.group
            Qt.callLater(() => ShellPrefs.moveItem(token, group, before))
        }
    }

    Row {
        id: row
        height: parent.height
        Repeater {
            id: cells
            model: root.tokens
            Item {
                id: cell
                required property string modelData
                required property int index
                readonly property bool app: Items.isApp(modelData)
                readonly property Item content: app ? appLoader.item : appletLoader.item
                readonly property real contentWidth: content ? content.implicitWidth : 0
                readonly property bool tight: app && index + 1 < root.tokens.length && Items.isApp(root.tokens[index + 1])
                visible: app || (appletLoader.item ? appletLoader.item.shown : false)
                width: visible ? contentWidth + (tight || index === root.tokens.length - 1 ? 0 : root.gap) : 0
                height: row.height
                opacity: root.bar.dragToken === modelData ? 0.35 : 1
                Loader {
                    id: appletLoader
                    active: !cell.app
                    height: parent.height
                    sourceComponent: Component { BarApplet { token: cell.modelData; bar: root.bar } }
                }
                Loader {
                    id: appLoader
                    active: cell.app
                    height: parent.height
                    sourceComponent: Component { AppButton { appId: cell.modelData.slice(4); host: root } }
                }
                DragHandler {
                    target: null
                    dragThreshold: 6
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.ClosedHandCursor
                    onActiveChanged: active ? root.bar.beginIconDrag(cell.modelData) : root.bar.endIconDrag()
                    onCentroidChanged: if (active) root.bar.dragPoint = centroid.scenePosition
                }
            }
        }
        Item {
            visible: root.extras.length > 0
            width: root.gap * 2 + 1; height: row.height
            Rectangle {
                anchors.centerIn: parent
                width: 1; height: parent.height - 14
                color: ShellLayout.buttonColor(root.group); opacity: 0.35
            }
        }
        Repeater {
            model: root.extras
            AppButton {
                required property string modelData
                appId: modelData; host: root; pinned: false
            }
        }
    }
    Rectangle {
        visible: root.drop !== null
        x: root.drop ? Math.max(0, root.drop.x - 2) : 0
        y: 4; z: 2; width: 2; height: root.height - 8; radius: 1
        color: Colors.accent
    }

    property string popupApp: ""
    property string popupName: ""
    property bool popupPinned: false
    property bool popupEntry: false
    property Item popupAnchor: null
    function target(button) {
        popupApp = button.appId; popupName = button.name
        popupPinned = button.pinned; popupEntry = !!button.entry; popupAnchor = button
    }
    function hover(button) { if (!windowsPopup.pinned) target(button) }
    function menu(button) {
        if (windowsPopup.pinned && popupApp === button.appId) windowsPopup.dismiss()
        else { target(button); windowsPopup.reveal(true) }
    }
    function forget(button) { if (popupAnchor === button) { popupAnchor = null; windowsPopup.dismiss() } }
    BarPopup {
        id: windowsPopup
        readonly property var windows: root.popupApp ? Minimized.listOf(root.popupApp) : []
        function run(action) { dismiss(); action() }
        anchorItem: root.popupAnchor || root
        barWindow: root.bar
        cardWidth: Shared.DesktopStyle.px(360)
        triggerHovered: !!root.popupAnchor && root.popupAnchor.minimized > 0 && root.popupAnchor.hovered && !root.dragging
        onAnchorItemChanged: if (opened && anchorItem) place()
        UiLabel {
            Layout.fillWidth: true
            text: root.popupName
            color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); elide: Text.ElideRight
        }
        UiLabel {
            visible: !windowsPopup.windows.length
            Layout.fillWidth: true
            text: "No open windows"
            color: Colors.muted
        }
        Repeater {
            model: windowsPopup.windows
            RowLayout {
                id: windowRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                UiButton {
                    Layout.fillWidth: true
                    text: Minimized.title(windowRow.modelData) + (Minimized.isMinimized(windowRow.modelData) ? "  · minimized" : "")
                    onClicked: windowsPopup.run(() => Minimized.show(windowRow.modelData))
                }
                UiButton {
                    glyph: "\u{F00D}"
                    Accessible.name: "Close " + Minimized.title(windowRow.modelData)
                    onClicked: Minimized.close(windowRow.modelData)
                }
            }
        }
        GridLayout {
            visible: windowsPopup.pinned
            Layout.fillWidth: true
            columns: 2; columnSpacing: 6; rowSpacing: 6
            UiButton {
                visible: root.popupEntry; Layout.fillWidth: true; text: "New window"
                onClicked: windowsPopup.run(() => PinnedApps.start(root.popupApp))
            }
            UiButton {
                visible: windowsPopup.windows.some(c => !Minimized.isMinimized(c)); Layout.fillWidth: true; text: "Minimize all"
                onClicked: windowsPopup.run(() => Minimized.minimizeApp(root.popupApp))
            }
            UiButton {
                visible: root.popupEntry; Layout.fillWidth: true
                text: root.popupPinned ? "Remove from panel" : "Keep in panel"
                onClicked: windowsPopup.run(() => PinnedApps.toggle(root.popupApp))
            }
            UiButton {
                visible: windowsPopup.windows.length > 0; Layout.fillWidth: true; text: "Close all"; danger: true
                onClicked: windowsPopup.run(() => Minimized.closeApp(root.popupApp))
            }
            UiButton {
                Layout.fillWidth: true; text: "Apps & icons"
                onClicked: windowsPopup.run(() => PinnedApps.settingsRequested())
            }
        }
    }
}
