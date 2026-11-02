import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../shared" as Shared

Flickable {
    id: root
    property var barWindow: null
    property real maximumWidth: 420
    readonly property int cell: Math.max(30, PanelStyle.barHeight + 2)
    property string dragging: ""
    property real pointerX: 0
    property int insertion: -1
    readonly property var entries: PinnedApps.visibleIds
    readonly property var extras: Minimized.extraIds
    readonly property int gap: extras.length ? 9 : 0
    property string popupApp: ""
    property string popupName: ""
    property bool popupPinned: false
    property bool popupEntry: false
    property Item popupAnchor: null
    function target(button) {
        popupApp = button.modelData; popupName = button.name
        popupPinned = button.pinned; popupEntry = !!button.entry; popupAnchor = button
    }
    implicitWidth: Math.min(contentWidth, maximumWidth)
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true
    contentWidth: (entries.length + extras.length) * cell + gap
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    function track(x) {
        pointerX = x
        insertion = Math.max(0, Math.min(entries.length, Math.round((x + contentX) / cell)))
    }
    function finish() {
        if (dragging && entries.length) {
            const index = Math.min(entries.length - 1, insertion)
            PinnedApps.move(dragging, entries[index], insertion >= entries.length)
        }
        dragging = ""; insertion = -1
    }
    Timer {
        interval: 35; repeat: true; running: root.dragging !== ""
        onTriggered: {
            if (root.pointerX < 18) root.contentX = Math.max(0, root.contentX - 8)
            else if (root.pointerX > root.width - 18) root.contentX = Math.min(Math.max(0, root.contentWidth - root.width), root.contentX + 8)
            root.track(root.pointerX)
        }
    }
    Repeater {
        model: root.entries.concat(root.extras)
        Item {
            id: button
            required property string modelData
            required property int index
            readonly property bool pinned: index < root.entries.length
            readonly property bool byClass: modelData.startsWith("class:")
            readonly property var entry: AppIcons.apps[modelData]
            readonly property string symbol: Hypr.icon(byClass ? modelData.slice(6) : modelData)
            readonly property bool hasSymbol: byClass || symbol !== "\u{F05AF}"
            readonly property int running: Minimized.visibleOf(modelData).length
            readonly property int minimized: Minimized.minimizedOf(modelData).length
            readonly property bool attention: minimized > 0 && Minimized.isUrgent(modelData)
            readonly property string name: entry ? entry.name : byClass ? modelData.slice(6) : modelData
            x: index * root.cell + (pinned ? 0 : root.gap); width: root.cell; height: root.height
            readonly property bool hovered: mouse.containsMouse
            Component.onDestruction: if (root.popupAnchor === button) { root.popupAnchor = null; windowsPopup.dismiss() }
            opacity: root.dragging === modelData ? 0.35 : 1
            Rectangle {
                anchors.fill: parent; anchors.margins: 3; radius: 5
                color: ShellLayout.buttonColor("launchers")
                opacity: mouse.pressed ? 0.18 : mouse.containsMouse ? 0.10 : 0
                Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.fast } }
            }
            Text {
                visible: button.hasSymbol
                anchors.centerIn: parent; text: button.symbol
                font.family: Colors.iconFont; font.pixelSize: Math.max(16, Colors.fontSize + 2)
                color: ShellLayout.buttonColor("launchers")
            }
            Image {
                id: appIcon
                visible: !button.hasSymbol
                anchors.centerIn: parent
                width: Math.min(20, root.height - 8); height: width
                source: button.hasSymbol ? "" : AppIcons.icon(button.entry)
                sourceSize: Qt.size(64, 64); fillMode: Image.PreserveAspectFit; mipmap: true
                layer.enabled: true
                layer.effect: MultiEffect { colorization: 1; colorizationColor: ShellLayout.buttonColor("launchers") }
            }
            readonly property string badge: Minimized.badge(modelData)

            Rectangle {
                visible: button.badge !== ""
                anchors.right: parent.right; anchors.top: parent.top
                anchors.rightMargin: 2; anchors.topMargin: 2
                height: button.badge === "dot" ? 7 : 13; radius: height / 2
                width: button.badge === "dot" ? 7 : Math.max(height, badgeText.implicitWidth + 6)
                color: Colors.red
                Text {
                    id: badgeText
                    visible: button.badge !== "dot"
                    anchors.centerIn: parent; text: button.badge
                    font.family: Colors.textFont; font.pixelSize: 9; font.bold: true
                    color: Colors.background
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                spacing: 2
                visible: button.running > 0 || button.minimized > 0
                Rectangle {
                    visible: button.running > 0
                    width: 8; height: 2; radius: 1; anchors.verticalCenter: parent.verticalCenter
                    color: ShellLayout.buttonColor("launchers"); opacity: 0.75
                }
                Repeater {
                    model: Math.min(3, button.minimized)
                    Rectangle {
                        width: 3; height: 3; radius: 1.5; anchors.verticalCenter: parent.verticalCenter
                        color: button.attention ? Colors.yellow : ShellLayout.buttonColor("launchers")
                    }
                }
            }
            BarToolTip {
                target: button; shown: mouse.containsMouse && !root.dragging && button.minimized === 0
                text: button.name + (button.pinned ? " · drag to reorder" : "") + " · right-click for windows and options"
            }
            MouseArea {
                id: mouse
                anchors.fill: parent; hoverEnabled: true; preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                property point start
                property bool moved: false
                onPressed: m => { start = Qt.point(m.x, m.y); moved = false }
                onContainsMouseChanged: if (containsMouse && !windowsPopup.pinned) root.target(button)
                onPositionChanged: m => {
                    if (!(pressedButtons & Qt.LeftButton) || !button.pinned) return
                    if (!moved && Math.hypot(m.x - start.x, m.y - start.y) > 6) {
                        moved = true; root.dragging = button.modelData
                    }
                    if (moved) root.track(mapToItem(root, m.x, m.y).x)
                }
                onReleased: if (moved) root.finish()
                onCanceled: { root.dragging = ""; root.insertion = -1 }
                onClicked: m => {
                    if (moved) return
                    if (m.button === Qt.RightButton) {
                        if (windowsPopup.pinned && root.popupApp === button.modelData) windowsPopup.dismiss()
                        else { root.target(button); windowsPopup.reveal(true) }
                    } else if (button.pinned) PinnedApps.launch(button.modelData)
                    else Minimized.activate(button.modelData)
                }
                onWheel: w => {
                    root.contentX = Math.max(0, Math.min(Math.max(0, root.contentWidth - root.width), root.contentX - (w.angleDelta.y || w.angleDelta.x)))
                    w.accepted = true
                }
            }
        }
    }
    Rectangle {
        parent: root
        visible: root.extras.length > 0
        x: root.entries.length * root.cell + root.gap / 2 - root.contentX
        y: 7; width: 1; height: root.height - 14
        color: ShellLayout.buttonColor("launchers"); opacity: 0.35
    }

    BarPopup {
        id: windowsPopup
        readonly property var windows: root.popupApp ? Minimized.listOf(root.popupApp) : []
        function run(action) { dismiss(); action() }
        anchorItem: root.popupAnchor || root
        barWindow: root.barWindow
        cardWidth: 360
        triggerHovered: !!root.popupAnchor && root.popupAnchor.minimized > 0 && root.popupAnchor.hovered && !root.dragging
        onAnchorItemChanged: if (opened && anchorItem) place()
        UiLabel {
            Layout.fillWidth: true
            text: root.popupName
            color: Colors.muted; font.pixelSize: 12; elide: Text.ElideRight
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
    Rectangle {
        parent: root
        visible: root.dragging !== ""
        x: Math.max(0, Math.min(root.width - 2, root.insertion * root.cell - root.contentX))
        y: 4; width: 2; height: root.height - 8; radius: 1; color: Colors.accent
    }
    Rectangle {
        parent: root
        visible: root.contentWidth > root.width
        x: root.contentWidth ? root.contentX / root.contentWidth * root.width : 0
        y: root.height - 2; height: 2; radius: 1
        width: Math.max(12, root.width * root.width / Math.max(1, root.contentWidth))
        color: Colors.muted; opacity: root.dragging ? 0.65 : 0.3
    }
}
