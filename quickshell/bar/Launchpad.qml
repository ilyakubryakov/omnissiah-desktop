import QtQuick
import "../shared" as Shared
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root

    property bool opened: false
    property bool presented: false
    property var target: null
    property string query: ""
    property string openFolder: ""
    property int selected: 0
    property var st: ({ root: [], folders: {} })
    property bool loaded: false
    property bool seeding: false
    property string drag: ""
    property point dragPos: Qt.point(0, 0)
    property var hover: null

    readonly property int cellW: 136
    readonly property int cellH: 136
    readonly property int columns: Math.max(4, Math.min(8, Math.floor((width - 160) / cellW)))
    readonly property bool canDrag: query === ""

    readonly property var rules: [
        { name: "Gaming", cats: ["Game"] },
        { name: "Coding", cats: ["Development", "IDE", "TextEditor", "TerminalEmulator"] },
        { name: "Music", cats: ["Audio", "Music", "Midi", "AudioVideo", "Video", "Player"] },
        { name: "Office", cats: ["Office", "WordProcessor", "Spreadsheet", "Presentation"] },
        { name: "Design", cats: ["Graphics", "3DGraphics", "Engineering"] },
        { name: "Internet", cats: ["Network", "WebBrowser", "Chat", "InstantMessaging", "Email", "RemoteAccess"] },
        { name: "System", cats: ["System", "Settings", "Monitor", "Security", "Utility", "FileManager", "HardwareSettings"] }
    ]

    readonly property var apps: {
        const m = {}
        for (const e of DesktopEntries.applications.values)
            if (!e.noDisplay) m[e.id] = e
        return m
    }
    readonly property var rootItems: st.root.filter(k => k.startsWith("folder:")
        ? !!st.folders[k.slice(7)] : !!apps[k.slice(4)])
    readonly property var results: {
        const q = query.trim().toLowerCase()
        if (q === "") return []
        const score = e => {
            const n = (e.name || "").toLowerCase()
            if (n.startsWith(q)) return 0
            if (n.includes(q)) return 1
            const extra = [e.genericName, e.comment, e.id].concat(e.keywords || []).join(" ").toLowerCase()
            return extra.includes(q) ? 2 : -1
        }
        return Object.values(apps).map(e => ({ e: e, s: score(e) })).filter(r => r.s >= 0)
            .sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name)).map(r => "app:" + r.e.id)
    }

    function folderApps(fid) {
        const f = st.folders[fid]
        return f ? f.apps.filter(a => !!apps[a]) : []
    }
    function iconFor(e) { return AppIcons.icon(e) }
    function clone() { return JSON.parse(JSON.stringify(st)) }
    function newId() { return "f" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36) }
    function category(e) {
        const cats = e.categories || []
        const r = rules.find(r => r.cats.some(c => cats.includes(c)))
        return r ? r.name : ""
    }
    function insertNear(list, item, target, after) {
        const out = list.filter(x => x !== item)
        const i = target ? out.indexOf(target) : -1
        if (i < 0) out.push(item)
        else out.splice(i + (after ? 1 : 0), 0, item)
        return out
    }

    function save() { store.setText(JSON.stringify(st, null, 1)) }

    function reconcile() {
        if (!loaded) return
        const s = clone()
        const placed = new Set(s.root.filter(k => k.startsWith("app:")).map(k => k.slice(4)))
        for (const f of Object.values(s.folders)) for (const a of f.apps) placed.add(a)
        if (seeding) {
            for (const r of rules) {
                const fid = newId() + r.name.toLowerCase()
                s.folders[fid] = { name: r.name, apps: [] }
                s.root.push("folder:" + fid)
            }
        }
        let changed = seeding
        const fresh = Object.keys(apps).filter(id => !placed.has(id))
            .sort((a, b) => apps[a].name.localeCompare(apps[b].name))
        for (const id of fresh) {
            const name = category(apps[id])
            const fid = name ? Object.keys(s.folders).find(k => s.folders[k].name === name) : undefined
            if (fid) s.folders[fid].apps.push(id)
            else s.root.push("app:" + id)
            changed = true
        }
        if (seeding) {
            for (const fid of Object.keys(s.folders)) {
                if (s.folders[fid].apps.length) continue
                delete s.folders[fid]
                s.root = s.root.filter(k => k !== "folder:" + fid)
            }
            seeding = false
        }
        if (changed) { st = s; save() }
    }
    FileView {
        id: store
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/station-launchpad.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.st = { root: Array.isArray(d.root) ? d.root : [], folders: d.folders || {} }
            } catch (_) {
                root.st = { root: [], folders: {} }
                root.seeding = true
            }
            root.loaded = true
            root.reconcile()
        }
        onLoadFailed: { root.seeding = true; root.loaded = true; root.reconcile() }
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.reconcile() }
    }

    function launch(id) {
        const e = apps[id]
        if (!e) return
        close()
        if (e.runInTerminal)
            Hypr.exec("kitty -e " + e.command.map(a => "'" + a.replace(/'/g, "'\\''") + "'").join(" "))
        else
            Hypr.exec("'" + (id + ".desktop").replace(/'/g, "'\\''") + "'")
    }
    function activate(key) {
        if (key.startsWith("folder:")) { openFolder = key.slice(7); return }
        launch(key.slice(4))
    }
    function newFolder() {
        const s = clone()
        const fid = newId()
        s.folders[fid] = { name: "New folder", apps: [] }
        s.root.push("folder:" + fid)
        st = s; save()
        query = ""
        openFolder = fid
        Qt.callLater(() => { title.forceActiveFocus(); title.selectAll() })
    }
    function rename(fid, name) {
        const n = name.trim()
        if (!st.folders[fid] || n === "" || n === st.folders[fid].name) return
        const s = clone()
        s.folders[fid].name = n
        st = s; save()
    }
    function ungroup(fid) {
        if (!st.folders[fid]) return
        const s = clone()
        const at = s.root.indexOf("folder:" + fid)
        s.root.splice(at < 0 ? s.root.length : at, at < 0 ? 0 : 1, ...s.folders[fid].apps.map(a => "app:" + a))
        delete s.folders[fid]
        openFolder = ""
        st = s; save()
        search.forceActiveFocus()
    }

    function dropTarget(px, py) {
        if (openFolder !== "") {
            const p = folderPanel.mapFromItem(null, px, py)
            if (p.x < 0 || p.y < 0 || p.x > folderPanel.width || p.y > folderPanel.height)
                return { where: "out" }
            const c = folderGrid.contentItem.mapFromItem(null, px, py)
            const i = folderGrid.indexAt(c.x, c.y)
            if (i < 0) return { where: "folder", target: null }
            const it = folderGrid.itemAtIndex(i)
            return { where: "folder", target: "app:" + folderApps(openFolder)[i], into: false,
                     after: it.mapFromItem(null, px, py).x >= it.width / 2 }
        }
        const c = grid.contentItem.mapFromItem(null, px, py)
        const i = grid.indexAt(c.x, c.y)
        if (i < 0) return { where: "root", target: null }
        const it = grid.itemAtIndex(i)
        const l = it.mapFromItem(null, px, py)
        const key = rootItems[i]
        const into = drag.startsWith("app:") && key !== drag
            && l.x > it.width * 0.25 && l.x < it.width * 0.75 && l.y < it.height * 0.8
        return { where: "root", target: key, into: into, after: l.x >= it.width / 2 }
    }
    function beginDrag(key) { drag = key; hover = null }
    function moveDrag(px, py) {
        dragPos = Qt.point(px, py)
        const t = dropTarget(px, py)
        hover = t.target && t.target !== drag ? t : null
    }
    function endDrag(px, py) {
        const t = dropTarget(px, py)
        const key = drag
        drag = ""; hover = null
        Qt.callLater(() => commitDrop(key, t))
    }
    function commitDrop(key, t) {
        if (!key || t.target === key) return
        const s = clone()
        const id = key.slice(key.indexOf(":") + 1)
        if (t.where === "out" || t.where === "folder") {
            const f = s.folders[openFolder]
            if (!f) return
            if (t.where === "folder") {
                f.apps = insertNear(f.apps, id, t.target ? t.target.slice(4) : null, t.after)
            } else {
                f.apps = f.apps.filter(a => a !== id)
                s.root = insertNear(s.root, key, "folder:" + openFolder, true)
                openFolder = ""
            }
        } else if (t.into && t.target.startsWith("folder:")) {
            const f = s.folders[t.target.slice(7)]
            s.root = s.root.filter(k => k !== key)
            if (!f.apps.includes(id)) f.apps.push(id)
        } else if (t.into) {
            const fid = newId()
            s.folders[fid] = { name: category(apps[t.target.slice(4)]) || "New folder", apps: [t.target.slice(4), id] }
            s.root = s.root.filter(k => k !== key)
            s.root[s.root.indexOf(t.target)] = "folder:" + fid
            openFolder = fid
        } else {
            s.root = insertNear(s.root, key, t.target, t.after)
        }
        st = s; save()
    }

    function show() {
        const mon = Hyprland.focusedMonitor
        target = Quickshell.screens.find(s => mon && s.name === mon.name) || Quickshell.screens[0]
        hideDelay.stop()
        query = ""; openFolder = ""; selected = 0; drag = ""; hover = null
        presented = true; opened = true
        store.reload()
        search.forceActiveFocus()
    }
    function close() {
        if (!opened) return
        opened = false; drag = ""; hover = null
        hideDelay.restart()
    }
    function toggle() { opened ? close() : show() }
    Timer { id: hideDelay; interval: Shared.DesktopStyle.normal; onTriggered: if (!root.opened) root.presented = false }
    IpcHandler {
        target: "launchpad"
        function toggle(): void { root.toggle() }
        function close(): void { root.close() }
    }

    screen: target
    visible: presented
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "station-launchpad"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onQueryChanged: { selected = 0; if (query !== "") openFolder = "" }

    Item {
        id: body
        anchors.fill: parent
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Colors.background
            opacity: 0.64
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Item {
            id: content
            anchors.fill: parent
            scale: root.opened ? 1 : 1.04
            Behavior on scale { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }

            Row {
                id: header
                anchors.horizontalCenter: parent.horizontalCenter
                y: 64
                spacing: 12

                Rectangle {
                    width: 440
                    height: 44
                    radius: 22
                    color: Qt.rgba(Colors.darkBackground.r, Colors.darkBackground.g, Colors.darkBackground.b, 0.55)
                    border.width: 1
                    border.color: search.activeFocus ? Colors.accent : Qt.rgba(Colors.bright.r, Colors.bright.g, Colors.bright.b, 0.14)

                    Text {
                        id: lens
                        anchors.verticalCenter: parent.verticalCenter
                        x: 16
                        text: "\u{F0349}"
                        color: Colors.muted
                        font.family: Colors.iconFont
                        font.pixelSize: 18
                    }
                    TextInput {
                        id: search
                        anchors.left: lens.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.bright
                        selectionColor: Colors.selection
                        font.family: Colors.textFont
                        font.pixelSize: Colors.fontSize + 3
                        clip: true
                        text: root.query
                        onTextEdited: root.query = text
                        Text {
                            visible: !search.text
                            text: "Search apps"
                            color: Colors.muted
                            font: search.font
                        }
                        Keys.onPressed: e => root.handleKey(e)
                    }
                }
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: plus.containsMouse ? Qt.rgba(Colors.bright.r, Colors.bright.g, Colors.bright.b, 0.12)
                                              : Qt.rgba(Colors.darkBackground.r, Colors.darkBackground.g, Colors.darkBackground.b, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(Colors.bright.r, Colors.bright.g, Colors.bright.b, 0.14)
                    Text {
                        anchors.centerIn: parent
                        text: "\u{F0257}"
                        color: Colors.foreground
                        font.family: Colors.iconFont
                        font.pixelSize: 20
                    }
                    MouseArea {
                        id: plus
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.newFolder()
                    }
                }
            }

            GridView {
                id: grid
                anchors.top: header.bottom
                anchors.topMargin: 48
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.columns * root.cellW
                cellWidth: root.cellW
                cellHeight: root.cellH
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.query === "" ? root.rootItems : root.results
                delegate: LaunchpadTile {
                    required property string modelData
                    required property int index
                    pad: root
                    key: modelData
                    selected: root.query !== "" && index === root.selected
                }
                Text {
                    visible: root.query !== "" && root.results.length === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 40
                    text: "No apps match"
                    color: Colors.muted
                    font.family: Colors.textFont
                    font.pixelSize: Colors.fontSize + 3
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: root.openFolder !== ""

            Rectangle {
                anchors.fill: parent
                color: Colors.background
                opacity: 0.35
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { root.openFolder = ""; search.forceActiveFocus() }
            }
            Rectangle {
                id: folderPanel
                readonly property int cols: Math.min(6, root.columns)
                anchors.centerIn: parent
                width: cols * root.cellW + 48
                height: Math.min(parent.height * 0.75, 96 + Math.max(1, Math.ceil(root.folderApps(root.openFolder).length / cols)) * root.cellH + 24)
                radius: 24
                color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.88)
                border.width: 1
                border.color: Qt.rgba(Colors.bright.r, Colors.bright.g, Colors.bright.b, 0.12)
                MouseArea { anchors.fill: parent }

                TextInput {
                    id: title
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 26
                    width: Math.min(parent.width - 160, Math.max(contentWidth + 8, 120))
                    horizontalAlignment: TextInput.AlignHCenter
                    text: root.openFolder !== "" && root.st.folders[root.openFolder] ? root.st.folders[root.openFolder].name : ""
                    color: Colors.bright
                    selectionColor: Colors.selection
                    font.family: Colors.textFont
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    onTextEdited: root.rename(root.openFolder, text)
                    onAccepted: search.forceActiveFocus()
                    Keys.onEscapePressed: search.forceActiveFocus()
                }
                Rectangle {
                    anchors.bottom: title.bottom
                    anchors.bottomMargin: -4
                    anchors.horizontalCenter: title.horizontalCenter
                    width: title.width
                    height: 1
                    color: title.activeFocus ? Colors.accent : "transparent"
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    y: 22
                    width: ungroupLabel.implicitWidth + 24
                    height: 32
                    radius: 16
                    color: ungroup.containsMouse ? Qt.rgba(Colors.bright.r, Colors.bright.g, Colors.bright.b, 0.1) : "transparent"
                    Text {
                        id: ungroupLabel
                        anchors.centerIn: parent
                        text: "\u{F0259}  Ungroup"
                        color: Colors.muted
                        font.family: Colors.iconFont
                        font.pixelSize: Colors.fontSize
                    }
                    MouseArea {
                        id: ungroup
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.ungroup(root.openFolder)
                    }
                }

                GridView {
                    id: folderGrid
                    anchors.fill: parent
                    anchors.topMargin: 84
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    anchors.bottomMargin: 16
                    cellWidth: root.cellW
                    cellHeight: root.cellH
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.openFolder !== "" ? root.folderApps(root.openFolder).map(a => "app:" + a) : []
                    delegate: LaunchpadTile {
                        required property string modelData
                        pad: root
                        key: modelData
                    }
                    Text {
                        visible: folderGrid.count === 0
                        anchors.centerIn: parent
                        text: "Drag apps here"
                        color: Colors.muted
                        font.family: Colors.textFont
                        font.pixelSize: Colors.fontSize + 2
                    }
                }
            }
        }

        Image {
            visible: root.drag !== ""
            x: root.dragPos.x - width / 2
            y: root.dragPos.y - height / 2
            width: 80
            height: 80
            opacity: 0.9
            source: root.drag.startsWith("app:") && root.apps[root.drag.slice(4)] ? root.iconFor(root.apps[root.drag.slice(4)]) : ""
            sourceSize.width: 128
            sourceSize.height: 128
            fillMode: Image.PreserveAspectFit
        }
        Rectangle {
            visible: root.drag.startsWith("folder:")
            x: root.dragPos.x - 40
            y: root.dragPos.y - 40
            width: 80
            height: 80
            radius: 20
            opacity: 0.9
            color: Colors.lightBackground
            border.width: 1
            border.color: Colors.accent
        }
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Escape) {
            if (openFolder !== "") openFolder = ""
            else if (query !== "") query = ""
            else close()
            e.accepted = true
        } else if (query !== "" && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) {
            if (results.length) launch(results[Math.min(selected, results.length - 1)].slice(4))
            e.accepted = true
        } else if (query !== "" && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(e.key)) {
            const step = { [Qt.Key_Left]: -1, [Qt.Key_Right]: 1, [Qt.Key_Up]: -columns, [Qt.Key_Down]: columns }[e.key]
            selected = Math.max(0, Math.min(results.length - 1, selected + step))
            grid.positionViewAtIndex(selected, GridView.Contain)
            e.accepted = true
        }
    }
}
