import QtQuick
import "../shared" as Shared

Item {
    id: tile

    required property var pad
    required property string key
    property bool selected: false
    readonly property bool isFolder: key.startsWith("folder:")
    readonly property string itemId: key.slice(key.indexOf(":") + 1)
    readonly property var entry: isFolder ? null : pad.apps[itemId] || null
    readonly property var folder: isFolder ? pad.st.folders[itemId] || null : null
    readonly property bool hovered: pad.hover !== null && pad.hover.target === key
    readonly property bool dropInto: hovered && pad.hover.into

    width: pad.cellW
    height: pad.cellH
    opacity: pad.drag === key ? 0.25 : 1

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 18
        color: Colors.bright
        opacity: tile.selected ? 0.16 : mouse.containsMouse && pad.drag === "" ? 0.07 : 0
    }

    Rectangle {
        visible: tile.hovered && !tile.dropInto
        x: pad.hover && pad.hover.after ? parent.width - 3 : 0
        y: 14
        width: 3
        height: 72
        radius: 2
        color: Colors.accent
    }

    Item {
        id: art
        width: 72
        height: 72
        y: 14
        anchors.horizontalCenter: parent.horizontalCenter
        scale: tile.dropInto ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }

        Image {
            visible: !tile.isFolder
            anchors.fill: parent
            source: tile.entry ? pad.iconFor(tile.entry) : ""
            sourceSize.width: 128
            sourceSize.height: 128
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }
        Rectangle {
            visible: tile.isFolder
            anchors.fill: parent
            radius: 18
            color: Qt.rgba(Colors.lightBackground.r, Colors.lightBackground.g, Colors.lightBackground.b, 0.72)
            border.width: tile.dropInto ? 2 : 1
            border.color: tile.dropInto ? Colors.accent : Qt.rgba(Colors.bright.r, Colors.bright.g, Colors.bright.b, 0.14)

            Grid {
                anchors.centerIn: parent
                columns: 3
                spacing: 4
                Repeater {
                    model: tile.isFolder ? pad.folderApps(tile.itemId).slice(0, 9) : []
                    Image {
                        required property var modelData
                        width: 16
                        height: 16
                        source: pad.apps[modelData] ? pad.iconFor(pad.apps[modelData]) : ""
                        sourceSize.width: 32
                        sourceSize.height: 32
                        asynchronous: true
                        smooth: true
                    }
                }
            }
        }
        Rectangle {
            visible: !tile.isFolder && tile.dropInto
            anchors.fill: parent
            anchors.margins: -6
            radius: 20
            color: "transparent"
            border.width: 2
            border.color: Colors.accent
        }
    }

    Text {
        anchors.top: art.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: tile.isFolder ? (tile.folder ? tile.folder.name : "") : (tile.entry ? tile.entry.name : "")
        color: Colors.bright
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.35)
        font.family: Colors.textFont
        font.pixelSize: Colors.fontSize + 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        property point start
        property bool moved: false
        onPressed: m => { start = Qt.point(m.x, m.y); moved = false }
        onPositionChanged: m => {
            if (!pressed) return
            if (!moved && pad.canDrag && Math.hypot(m.x - start.x, m.y - start.y) > 8) {
                moved = true
                pad.beginDrag(tile.key)
            }
            if (moved) {
                const p = mapToItem(null, m.x, m.y)
                pad.moveDrag(p.x, p.y)
            }
        }
        onReleased: m => {
            if (!moved) return
            const p = mapToItem(null, m.x, m.y)
            pad.endDrag(p.x, p.y)
        }
        onClicked: if (!moved) pad.activate(tile.key)
    }
    Rectangle {
        visible: !tile.isFolder && (tile.selected || mouse.containsMouse || pinMouse.containsMouse || PinnedApps.contains(tile.itemId))
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 7
        width: 28; height: 28; radius: 14
        color: Colors.background
        Text { anchors.centerIn: parent; text: "\u{F0403}"; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(15); color: PinnedApps.contains(tile.itemId) ? Colors.accent : Colors.muted }
        MouseArea { id: pinMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: PinnedApps.toggle(tile.itemId) }
        BarToolTip { target: parent; shown: pinMouse.containsMouse; text: PinnedApps.contains(tile.itemId) ? "Unpin from panel" : "Pin to panel" }
    }

}
