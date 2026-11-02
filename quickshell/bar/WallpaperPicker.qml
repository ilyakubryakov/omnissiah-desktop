pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Wallpaper gallery"
    visible: DesktopData.wallpapersOpen
    implicitWidth: 1040
    implicitHeight: 780
    minimumSize: Qt.size(760, 560)
    color: Colors.background
    onClosed: DesktopData.wallpapersOpen = false
    readonly property var wallpaper: DesktopData.appearance.wallpaper || ({})
    readonly property string slot: wallpaper.mode !== "variant" ? "shared" : DesktopData.wallpaperSlot === "shared" ? activeVariant : DesktopData.wallpaperSlot
    readonly property string selected: wallpaper[slot] || wallpaper.shared || ""
    readonly property string activeVariant: (DesktopData.appearance.palettes.find(p => p.id === DesktopData.appearance.schedule.palette) || {}).mode || "dark"
    readonly property string directory: wallpaper.directory || ""
    property int generation: 0
    property var images: []
    property var thumbnails: ({})
    property string error: ""
    readonly property var filtered: images.filter(image => image.name.toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase()))
    readonly property int columns: Math.max(2, Math.floor(grid.width / 260))
    onDirectoryChanged: if (visible) refresh()
    onVisibleChanged: {
        if (visible) { DesktopData.readAppearance(); refresh(); body.forceActiveFocus() }
        else { generation++; images = []; thumbnails = {}; search.clear(); error = "" }
    }
    function refresh() {
        if (listing.running) { refreshDelay.restart(); return }
        generation++; images = []; thumbnails = {}; error = ""; grid.contentY = 0
        listing.generation = generation
        listing.running = true
    }
    function act(args) { DesktopData.act("appearance", args) }
    function nextThumbnail() {
        if (!visible || thumbnail.running || grid.moving) return

        const first = Math.max(0, Math.floor(grid.contentY / grid.cellHeight)) * columns
        const end = Math.min(filtered.length, (Math.ceil((grid.contentY + grid.height) / grid.cellHeight) + 1) * columns)
        for (let i = first; i < end; i++) {
            const path = filtered[i].path
            if (thumbnails[path] !== undefined) continue
            thumbnail.generation = generation
            thumbnail.path = path
            thumbnail.command = [DesktopData.helper, "wallpaper-preview", path]
            thumbnail.running = true
            return
        }
    }
    Timer { id: refreshDelay; interval: 100; onTriggered: if (root.visible) root.refresh() }
    Timer { id: previewDelay; interval: 80; onTriggered: root.nextThumbnail() }
    Process {
        id: listing
        property int generation: 0
        command: [DesktopData.helper, "data", "wallpapers"]
        stdout: StdioCollector { onStreamFinished: {
            if (!root.visible || listing.generation !== root.generation) return
            const result = DesktopData.parse(text)
            root.error = result.error || ""
            root.images = result.images || []
            previewDelay.restart()
        } }
    }
    Process {
        id: thumbnail
        property string path: ""
        property int generation: 0
        stdout: StdioCollector { onStreamFinished: {
            if (!root.visible || thumbnail.generation !== root.generation) return
            const result = DesktopData.parse(text)
            root.thumbnails = Object.assign({}, root.thumbnails, {[thumbnail.path]: result.url || ""})
        } }
        onExited: previewDelay.restart()
    }
    FocusScope {
        id: body
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: DesktopData.wallpapersOpen = false
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24; spacing: 14
            RowLayout {
                Layout.fillWidth: true
                UiLabel {
                    text: "WALLPAPERS"; font.pixelSize: 13; font.letterSpacing: 3; color: Colors.accent; Layout.fillWidth: true
                    MouseArea { anchors.fill: parent; onPressed: root.startSystemMove() }
                }
                UiLabel { text: root.filtered.length + " images"; font.pixelSize: 12; color: Colors.muted }
                UiButton { text: "Close · Esc"; onClicked: DesktopData.wallpapersOpen = false }
            }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: directoryField
                    Layout.fillWidth: true
                    text: root.directory
                    placeholderText: "Wallpaper folder"
                    color: Colors.foreground; selectionColor: Colors.accent
                    background: Rectangle { color: Colors.lightBackground; radius: 6; border.width: 1; border.color: directoryField.activeFocus ? Colors.accent : Colors.selection }
                    enabled: !DesktopData.busy
                    onAccepted: if (text.trim()) root.act(["wallpaper-directory", text])
                }
                UiButton { text: "Save folder"; enabled: !DesktopData.busy && !!directoryField.text.trim(); onClicked: root.act(["wallpaper-directory", directoryField.text]) }
                UiButton { text: "Browse…"; enabled: !DesktopData.busy; onClicked: folderPicker.open() }
                UiButton { text: "Refresh"; enabled: !listing.running; onClicked: root.refresh() }
            }
            RowLayout {
                Layout.fillWidth: true
                UiButton { text: "All themes"; selected: root.wallpaper.mode !== "variant"; enabled: !DesktopData.busy; onClicked: root.act(["wallpaper-mode", "shared"]) }
                UiButton {
                    text: "Light"; selected: root.wallpaper.mode === "variant" && root.slot === "light"; enabled: !DesktopData.busy
                    onClicked: { DesktopData.wallpaperSlot = "light"; if (root.wallpaper.mode !== "variant") root.act(["wallpaper-mode", "variant"]) }
                }
                UiButton {
                    text: "Dark"; selected: root.wallpaper.mode === "variant" && root.slot === "dark"; enabled: !DesktopData.busy
                    onClicked: { DesktopData.wallpaperSlot = "dark"; if (root.wallpaper.mode !== "variant") root.act(["wallpaper-mode", "variant"]) }
                }
                Item { Layout.fillWidth: true }
                TextField {
                    id: search
                    Layout.preferredWidth: 240
                    placeholderText: "Search collection…"
                    color: Colors.foreground; selectionColor: Colors.accent
                    background: Rectangle { color: Colors.lightBackground; radius: 6; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
                    onTextChanged: { grid.contentY = 0; previewDelay.restart() }
                }
            }
            UiLabel {
                Layout.fillWidth: true; elide: Text.ElideMiddle; font.pixelSize: 12; color: Colors.muted
                text: root.selected ? "Selected · " + root.selected : "No wallpaper selected for this variant"
            }
            UiLabel {
                visible: !!root.error || !!DesktopData.error
                text: root.error || DesktopData.error; color: Colors.red; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            GridView {
                id: grid
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; reuseItems: true; cacheBuffer: 0
                cellWidth: width / root.columns; cellHeight: cellWidth * 0.625 + 44
                model: root.visible ? root.filtered : []
                onContentYChanged: previewDelay.restart()
                onHeightChanged: previewDelay.restart()
                onWidthChanged: previewDelay.restart()
                onMovingChanged: if (!moving) previewDelay.restart()
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property string preview: root.thumbnails[modelData.path] || ""
                    width: grid.cellWidth; height: grid.cellHeight
                    function choose() { if (!DesktopData.busy) root.act(["wallpaper", root.slot, modelData.path]) }
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: choose()
                    Keys.onReturnPressed: choose()
                    Keys.onSpacePressed: choose()
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 6; radius: 8
                        color: Colors.lightBackground
                        border.width: root.selected === card.modelData.path || card.activeFocus ? 2 : 1
                        border.color: root.selected === card.modelData.path || card.activeFocus ? Colors.accent : Colors.selection
                        Image {
                            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
                            height: parent.height - 40
                            source: card.preview; asynchronous: true; cache: false
                            sourceSize: Qt.size(512, 320)
                            fillMode: Image.PreserveAspectFit
                        }
                        UiLabel {
                            anchors.centerIn: parent; color: Colors.muted; font.pixelSize: 12
                            visible: !card.preview
                            text: root.thumbnails[card.modelData.path] === "" ? "Preview unavailable" : "Loading preview…"
                        }
                        UiLabel {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 12 }
                            text: (root.selected === card.modelData.path ? "✓  " : "") + card.modelData.name
                            font.pixelSize: 12; elide: Text.ElideRight
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.choose() }
                    }
                }
                UiLabel {
                    anchors.centerIn: parent; color: Colors.muted
                    visible: listing.running || root.filtered.length === 0 && !root.error
                    text: listing.running ? "Reading collection…" : root.images.length ? "No matching images" : "No images in this folder"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                UiButton { text: "Choose another file…"; enabled: !DesktopData.busy; onClicked: filePicker.open() }
                UiButton { text: "Open folder"; enabled: !!root.wallpaper.directoryUrl; onClicked: Qt.openUrlExternally(root.wallpaper.directoryUrl) }
                Item { Layout.fillWidth: true }
                UiLabel { text: DesktopData.busy ? "Saving…" : root.slot !== "shared" && root.slot !== root.activeVariant ? "Saving for " + root.slot + " themes · current theme is " + root.activeVariant : "Click an image to apply"; color: Colors.muted; font.pixelSize: 12 }
            }
        }
    }
    FolderDialog {
        id: folderPicker; title: "Wallpaper collection"
        currentFolder: root.wallpaper.directoryUrl || "file:///"
        onAccepted: root.act(["wallpaper-directory", selectedFolder.toString()])
    }
    FileDialog {
        id: filePicker; title: "Wallpaper for " + root.slot
        currentFolder: root.wallpaper.directoryUrl || "file:///"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        fileMode: FileDialog.OpenFile
        onAccepted: root.act(["wallpaper", root.slot, selectedFile.toString()])
    }
}
