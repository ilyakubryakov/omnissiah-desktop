pragma ComponentBehavior: Bound
import QtQuick
import "../shared" as Shared
import "DesktopCardGeometry.js" as Geometry

Item {
    id: root
    required property string cardId
    required property rect defaultGeometry
    required property size minimumSize
    required property size maximumSize
    required property size workArea
    property alias sourceComponent: body.sourceComponent
    property real aspectRatio: 0
    property int heightInset: 0
    signal activated()

    readonly property var stored: DesktopCardPrefs.cards[cardId] || ({})
    readonly property bool locked: stored.locked !== false
    readonly property var geometry: Geometry.fit(draft ?? (Geometry.valid(stored.geometry) ? stored.geometry : defaultGeometry),
        workArea, minimumSize, maximumSize, aspectRatio, heightInset)
    readonly property rect inputRect: visible ? Qt.rect(x, y, width, height) : Qt.rect(0, 0, 0, 0)
    property var draft: null
    property int gridStep: 0
    readonly property bool editing: draft !== null
    readonly property int controlSize: Shared.DesktopStyle.px(26)
    readonly property int controlMargin: Shared.DesktopStyle.px(9)
    readonly property int lockInset: controlSize + controlMargin

    x: geometry.x
    y: geometry.y
    width: geometry.width
    height: geometry.height

    Loader { id: body; anchors.fill: parent; active: root.visible }
    HoverHandler { id: hover }

    component EditArea: MouseArea {
        id: gesture
        required property int axes
        property point pressPoint
        property var startRect: null
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        function updateGeometry(mouseX: real, mouseY: real) {
            const point = mapToItem(root.parent, mouseX, mouseY)
            const dx = axes === 0 || axes & 1 ? point.x - pressPoint.x : 0
            const dy = axes === 0 || axes & 2 ? point.y - pressPoint.y : 0
            const resize = axes !== 0
            if (resize && root.aspectRatio > 0) {
                const horizontal = axes === 1 || (axes === 3 && Math.abs(dx) >= Math.abs(dy) * root.aspectRatio)
                root.draft = Geometry.resizeAspect(startRect, horizontal, horizontal ? dx : dy,
                    root.gridStep, root.workArea, root.minimumSize, root.maximumSize, root.aspectRatio, root.heightInset)
            } else {
                const rect = Geometry.edit(startRect, dx, dy, resize, root.workArea, root.minimumSize, root.maximumSize)
                root.draft = Geometry.snap(rect, root.gridStep, resize, root.workArea, root.minimumSize, root.maximumSize)
            }
        }
        onPressed: mouse => {
            startRect = root.geometry
            pressPoint = mapToItem(root.parent, mouse.x, mouse.y)
            root.activated()
        }
        onPositionChanged: mouse => {
            if (pressed && startRect) updateGeometry(mouse.x, mouse.y)
        }
        onReleased: mouse => {
            if (!startRect) return
            updateGeometry(mouse.x, mouse.y)
            const rect = root.geometry
            if (rect.width > 0 && rect.height > 0 && JSON.stringify(rect) !== JSON.stringify(startRect))
                DesktopCardPrefs.update(root.cardId, {geometry: rect})
            root.draft = null
            startRect = null
        }
        onCanceled: { root.draft = null; startRect = null }
    }

    EditArea {
        anchors.fill: parent
        visible: !root.locked
        axes: 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }

    readonly property int edgeBand: Shared.DesktopStyle.px(14)
    readonly property int cornerSize: Shared.DesktopStyle.px(44)
    EditArea {
        visible: !root.locked
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom
                  topMargin: root.lockInset + root.controlMargin; bottomMargin: root.cornerSize }
        width: root.edgeBand
        axes: 1
        cursorShape: Qt.SizeHorCursor
    }
    EditArea {
        visible: !root.locked
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: root.cornerSize }
        height: root.edgeBand
        axes: 2
        cursorShape: Qt.SizeVerCursor
    }

    Rectangle {
        visible: !root.locked
        anchors.fill: parent
        color: "transparent"
        radius: Shared.DesktopStyle.radiusCard
        border.width: 1
        border.color: Colors.accent
    }

    Rectangle {
        visible: hover.hovered || !root.locked
        anchors { top: parent.top; right: parent.right; margins: root.controlMargin }
        width: root.controlSize
        height: width
        radius: Shared.DesktopStyle.radiusControl
        color: lockMouse.containsMouse ? Colors.selection : Colors.lightBackground
        border.width: 1
        border.color: Colors.selection
        UiLabel {
            anchors.centerIn: parent
            text: root.locked ? "\u{F033E}" : "\u{F0340}"
            font.family: Colors.iconFont
            font.pixelSize: Shared.DesktopStyle.px(15)
            color: root.locked ? Colors.muted : Colors.accent
        }
        MouseArea {
            id: lockMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            Accessible.role: Accessible.Button
            Accessible.name: root.locked ? "Unlock card" : "Lock card"
            function toggleLock() {
                root.activated()
                DesktopCardPrefs.update(root.cardId, {locked: !root.locked})
            }
            Accessible.onPressAction: toggleLock()
            onClicked: toggleLock()
        }
    }

    Rectangle {
        visible: !root.locked
        anchors { right: parent.right; bottom: parent.bottom; margins: root.controlMargin }
        width: root.controlSize
        height: width
        radius: Shared.DesktopStyle.radiusControl
        color: grip.pressed ? Colors.selection : Colors.lightBackground
        border.width: 1
        border.color: Colors.selection
        UiLabel {
            anchors.centerIn: parent
            text: "↘"
            font.pixelSize: Shared.DesktopStyle.px(16)
            color: Colors.accent
        }
    }
    EditArea {
        id: grip
        visible: !root.locked
        anchors { right: parent.right; bottom: parent.bottom }
        width: root.cornerSize
        height: root.cornerSize
        axes: 3
        cursorShape: Qt.SizeFDiagCursor
    }
}
