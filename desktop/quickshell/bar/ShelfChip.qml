pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../shared" as Shared

StatusChip {
    id: root
    required property var barWindow
    readonly property string helper: "oninix-desktop"
    readonly property bool station: Quickshell.env("ONINIX_LAPTOP") !== "1"
    property var items: []
    readonly property var images: [".png", ".jpg", ".jpeg", ".webp", ".gif"]
    function act(args) { Quickshell.execDetached([helper].concat(args)) }
    function isImage(path) { return images.some(e => path.toLowerCase().endsWith(e)) }
    function fileName(path) { return path.split("/").pop() }
    function uri(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/") }

    Timer { interval: 2000; running: true; repeat: true; onTriggered: shelfFile.reload() }
    FileView {
        id: shelfFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/oninix-desktop/shelf/shelf.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text())
                root.items = Array.isArray(list) ? list.filter(e => e && typeof e.path === "string").map(e => e.path) : []
            } catch (_) { root.items = [] }
        }
        onLoadFailed: root.items = []
    }

    visible: items.length > 0
    glyph: "\u{F0C3F}"
    badge: Colors.accent
    Accessible.name: "Shelf, " + items.length + " files"
    onClicked: { shelfFile.reload(); if (shelfPopup.opened) shelfPopup.dismiss(); else shelfPopup.reveal(false) }

    BarPopup {
        id: shelfPopup
        anchorItem: root; barWindow: root.barWindow; above: root.barWindow.edge === "bottom"; cardWidth: Shared.DesktopStyle.px(420)
        triggerHovered: root.hovered
        CardHeader { glyph: "\u{F0C3F}"; title: "Shelf"; note: "Drag into any window" }
        Repeater {
            model: root.items
            Rectangle {
                id: tile
                required property string modelData
                readonly property bool picture: root.isImage(modelData)
                Layout.fillWidth: true
                implicitHeight: row.implicitHeight + Shared.DesktopStyle.px(16)
                radius: Shared.DesktopStyle.radiusControl
                color: dragArea.containsMouse ? Colors.selection : Colors.lightBackground
                border.width: 1; border.color: Colors.selection
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.mimeData: ({ "text/uri-list": root.uri(modelData) + "\r\n", "text/plain": modelData })
                Drag.imageSource: picture ? root.uri(modelData) : ""
                Drag.imageSourceSize: Qt.size(Shared.DesktopStyle.px(160), Shared.DesktopStyle.px(100))
                Drag.onDragFinished: { Drag.active = false; shelfPopup.holding = false }
                RowLayout {
                    id: row
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Shared.DesktopStyle.px(8) }
                    spacing: Shared.DesktopStyle.px(10)
                    Item {
                        implicitWidth: Shared.DesktopStyle.px(72); implicitHeight: Shared.DesktopStyle.px(48)
                        Image {
                            anchors.fill: parent; visible: tile.picture
                            source: tile.picture ? root.uri(tile.modelData) : ""
                            sourceSize: Qt.size(Shared.DesktopStyle.px(144), Shared.DesktopStyle.px(96))
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                        }
                        UiLabel {
                            anchors.centerIn: parent; visible: !tile.picture
                            text: "\u{F0214}"; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(26); color: Colors.accent
                        }
                    }
                    UiLabel { Layout.fillWidth: true; text: root.fileName(tile.modelData); elide: Text.ElideMiddle; font.pixelSize: Shared.DesktopStyle.px(12) }
                    UiButton { glyph: "\u{F018F}"; subtle: true; Accessible.name: "Copy " + root.fileName(tile.modelData); onClicked: root.act(["shelf-copy", tile.modelData]) }
                    UiButton { glyph: "\u{F0156}"; subtle: true; Accessible.name: "Remove from shelf"; onClicked: root.act(["shelf-remove", tile.modelData]) }
                }
                MouseArea {
                    id: dragArea
                    z: -1
                    anchors.fill: parent; hoverEnabled: true
                    drag.target: dragProxy
                    onDoubleClicked: Qt.openUrlExternally(root.uri(tile.modelData))
                    drag.onActiveChanged: if (drag.active) { shelfPopup.holding = true; tile.Drag.active = true }
                }
                Item { id: dragProxy }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            UiLabel { Layout.fillWidth: true; text: "Double-click opens. Empties on logout."; color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11) }
            UiButton { text: "Clear"; subtle: true; onClicked: { root.act(["shelf-remove", "*"]); shelfPopup.dismiss() } }
        }
    }
}
