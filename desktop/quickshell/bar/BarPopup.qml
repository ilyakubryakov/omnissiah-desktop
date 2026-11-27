import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

PanelWindow {
    id: root
    required property Item anchorItem
    required property var barWindow
    property bool triggerHovered: false
    property bool above: barWindow && barWindow.edge === "bottom"
    property int cardWidth: Shared.DesktopStyle.px(420)
    property bool opened: false
    property bool pinned: false
    property bool suppressed: false
    property bool holding: false
    onHoldingChanged: if (!holding && !engaged && !pinned) leave.restart()
    property color tone: Colors.accent
    default property alias content: column.data
    readonly property bool engaged: triggerHovered || hover.hovered
    property real anchorX: 0
    function place() {
        if (!anchorItem || !barWindow || !barWindow.contentItem) return false
        anchorX = anchorItem.mapToItem(barWindow.contentItem, 0, 0).x + anchorItem.width / 2
        return true
    }
    readonly property int fittedWidth: Math.min(cardWidth, Math.max(Shared.DesktopStyle.px(200), (screen ? screen.width : Shared.DesktopStyle.px(1920)) - Shared.DesktopStyle.px(16)))
    screen: barWindow.screen
    anchors { left: true; top: !root.above; bottom: root.above }
    margins {
        left: Math.max(Shared.DesktopStyle.px(8), Math.min((root.screen ? root.screen.width : Shared.DesktopStyle.px(1920)) - root.fittedWidth - Shared.DesktopStyle.px(8),
            root.barWindow.margins.left + root.anchorX - root.fittedWidth / 2))
        top: root.above ? 0 : root.barWindow.height + PanelStyle.outerGap + Shared.DesktopStyle.px(6)
        bottom: root.above ? root.barWindow.height + PanelStyle.outerGap + Shared.DesktopStyle.px(6) : 0
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-card"
    WlrLayershell.keyboardFocus: pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    implicitWidth: fittedWidth
    implicitHeight: column.implicitHeight + Shared.DesktopStyle.px(36)
    color: "transparent"
    visible: opened || conceal.running

    function reveal(pin) {
        if (Shared.DesktopStyle.fullscreen || !place() || !PopupState.claim(root, pin)) return
        enter.stop()
        leave.stop()
        conceal.stop()
        pinned = pin
        opened = true
        if (pin) Qt.callLater(() => {
            if (column.children.length) column.children[0].forceActiveFocus()
            else body.forceActiveFocus()
        })
    }
    function dismiss() {
        enter.stop()
        leave.stop()
        pinned = false
        holding = false
        opened = false
        suppressed = triggerHovered
    }
    function retire() {
        dismiss()
        conceal.stop()
    }
    Component.onDestruction: if (PopupState.current === root) PopupState.current = null
    function togglePinned() { if (pinned) dismiss(); else reveal(true) }
    onOpenedChanged: if (!opened) conceal.restart()
    onEngagedChanged: {
        if (engaged) {
            leave.stop()
            if (!opened && !suppressed) enter.restart()
        } else {
            enter.stop()
            suppressed = false
            if (!pinned) leave.restart()
        }
    }
    Connections { target: Shared.DesktopStyle; function onFullscreenChanged() { if (Shared.DesktopStyle.fullscreen) root.dismiss() } }
    Timer { id: enter; interval: 180; onTriggered: if (root.engaged && !root.opened && !root.suppressed) root.reveal(false) }
    Timer { id: leave; interval: 260; onTriggered: if (!root.engaged && !root.pinned && !root.holding) root.dismiss() }
    Timer { id: conceal; interval: Shared.DesktopStyle.slow }
    Shared.ClickCatcher {
        active: root.pinned && !root.holding
        topInset: PanelStyle.barHeight + PanelStyle.outerGap
        bottomInset: PanelStyle.barHeight + PanelStyle.outerGap
        onClicked: root.dismiss()
    }
    Rectangle {
        id: body
        anchors.fill: parent
        radius: Shared.DesktopStyle.radiusPanel
        color: ShellLayout.blend(Colors.background, root.tone, 0.035)
        border.width: 1
        border.color: ShellLayout.blend(Colors.background, root.tone, 0.25)
        opacity: root.opened ? 1 : 0
        transform: Translate {
            y: root.opened ? 0 : (root.above ? Shared.DesktopStyle.px(12) : -Shared.DesktopStyle.px(12))
            Behavior on y { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
        HoverHandler { id: hover }
        Keys.onEscapePressed: root.dismiss()
        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.px(18) }
            spacing: Shared.DesktopStyle.cardSpacing
        }
    }
}
