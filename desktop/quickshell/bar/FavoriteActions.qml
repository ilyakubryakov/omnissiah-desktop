pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../shared" as Shared

ColumnLayout {
    id: root
    property bool editing: false
    // In the Control Center card: two columns always, no section title.
    property bool compact: false
    // Tiles that lead to a settings page (Connections, Audio output, details).
    signal settingsRequested(string page)
    function openSettings(page) { DesktopData.controlTab = page; settingsRequested(page) }
    property string dragging: ""
    function finish(id, point) {
        let before = "", matched = false
        const remaining = ShellPrefs.favorites.filter(item => item !== id)
        for (let i = 0; i < favorites.count; i++) {
            const item = favorites.itemAt(i), pos = item.mapToItem(root, 0, 0)
            if (item.modelData !== id && point.x >= pos.x && point.x < pos.x + item.width && point.y >= pos.y && point.y < pos.y + item.height) {
                before = point.x < pos.x + item.width / 2 ? item.modelData : (remaining[remaining.indexOf(item.modelData) + 1] || "")
                matched = true; break
            }
        }
        if (matched) ShellPrefs.moveFavorite(id, before)
        dragging = ""
    }
    readonly property var catalog: [
        {id:"network", title:"Connections", glyph:"\uf0ac"}, {id:"bluetooth", title:"Bluetooth", glyph:"\uf293"},
        {id:"dnd", title:"Do not disturb", glyph:"\uf1f6"}, {id:"awake", title:"Keep awake", glyph:"\uf0f4"},
        {id:"nightlight", title:"Night light", glyph:"\uf186"}, {id:"microphone", title:"Microphone", glyph:"\uf130"},
        {id:"output", title:"Audio output", glyph:"\uf028"},
        {id:"mode:work", title:"Work", glyph:"\uf0b1"},
        {id:"mode:call", title:"Call", glyph:"\uf095"}, {id:"mode:music", title:"Recording", glyph:"\uf001"},
        {id:"mode:game", title:"Game", glyph:"\uf11b"}, {id:"mode:normal", title:"Normal", glyph:"\uf015"}
    ]
    function meta(id) { return catalog.find(t => t.id === id) || catalog[0] }
    function vpn(id) { return DesktopData.vpnProfiles.find(v => v.id === id.split(":")[1]) }
    function checked(id) {
        if (id === "bluetooth") return !!Bluetooth.defaultAdapter?.enabled
        if (id === "microphone") return !!Shared.AudioState.input && !Shared.AudioState.input.muted
        if (id.startsWith("vpn:")) return vpn(id)?.active === "yes"
        if (id.startsWith("mode:")) return (DesktopData.controls.mode || "normal") === id.split(":")[1]
        return !!DesktopData.controls[id]
    }
    function subtitle(id) {
        if (id === "network") return "LAN · Wi-Fi"
        if (id === "output") return Shared.AudioState.sink?.description || "No output device"
        if (id.startsWith("vpn:") && !vpn(id)) return "Not configured on this machine"
        if (id === "bluetooth" && !Bluetooth.defaultAdapter) return "No adapter"
        if (id === "microphone" && !Shared.AudioState.input) return "No input device"
        if (id.startsWith("mode:")) return checked(id) ? "Active · click to restore" : "Apply work mode"
        return checked(id) ? "On" : "Off"
    }
    function invoke(id) {
        if (id === "network") openSettings("network")
        else if (id === "output") openSettings("audio")
        else if (id === "bluetooth" && Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
        else if (id === "microphone" && Shared.AudioState.input) Shared.AudioState.input.muted = !Shared.AudioState.input.muted
        else if (id === "awake") { Quickshell.execDetached([Quickshell.env("ONINIX_SHARE") + "/hypr/scripts/keep-awake.sh"]); refresh.restart() }
        else if (id.startsWith("vpn:") && vpn(id)) DesktopData.act("vpn", [vpn(id).id])
        else if (id.startsWith("mode:")) DesktopData.act("mode", [checked(id) ? "normal" : id.split(":")[1]])
        else DesktopData.act(id)
    }
    Timer { id: refresh; interval: 300; onTriggered: DesktopData.refresh() }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: root.compact ? "" : "Favorites"; font.weight: Font.DemiBold; Layout.fillWidth: true }
        UiButton { text: root.editing ? "Done" : root.compact ? "" : "Edit"; glyph: "\uf044"; subtle: root.compact && !root.editing; selected: root.editing; Accessible.name: "Edit favorites"; onClicked: root.editing = !root.editing }
    }
    UiLabel { visible: root.editing; text: "Drag the handles to reorder. Select actions below to add or remove them."; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
    GridLayout {
        Layout.fillWidth: true; columns: root.compact || root.width >= 440 ? 2 : 1; rowSpacing: 10; columnSpacing: 10
        Repeater {
            id: favorites
            model: ShellPrefs.favorites
            Item {
                id: slot; required property string modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 76
                z: root.dragging === modelData ? 10 : 0
                QuickTile {
                    id: tile
                    property string actionId: slot.modelData
                    width: slot.width; height: slot.height
                    title: root.meta(actionId).title; glyph: root.meta(actionId).glyph
                    subtitle: root.editing ? "Drag to reorder" : root.subtitle(actionId)
                    checked: !root.editing && root.checked(actionId)
                    tint: actionId === "microphone" ? Colors.green : actionId === "nightlight" ? Colors.yellow : Colors.accent
                    enabled: root.editing || (!DesktopData.busy && (!actionId.startsWith("vpn:") || !!root.vpn(actionId)) && (actionId !== "bluetooth" || !!Bluetooth.defaultAdapter))
                    hasDetail: !root.editing && ["microphone", "bluetooth"].includes(actionId)
                    onClicked: if (!root.editing) root.invoke(actionId)
                    onDetail: root.openSettings(actionId === "microphone" ? "audio" : "network")
                    MouseArea {
                        id: dragger; visible: root.editing; anchors.fill: parent
                        preventStealing: true; cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point start
                        onPressed: m => start = mapToItem(root, m.x, m.y)
                        onPositionChanged: m => {
                            if (!pressed) return
                            const p = mapToItem(root, m.x, m.y)
                            if (Math.hypot(p.x - start.x, p.y - start.y) > 6) root.dragging = slot.modelData
                            if (root.dragging) { tile.x = p.x - start.x; tile.y = p.y - start.y }
                        }
                        onReleased: m => { if (root.dragging) root.finish(slot.modelData, mapToItem(root, m.x, m.y)); tile.x = 0; tile.y = 0 }
                        onCanceled: { root.dragging = ""; tile.x = 0; tile.y = 0 }
                    }
                }

            }
        }
    }
    Flow {
        visible: root.editing; Layout.fillWidth: true; spacing: 6
        Repeater {
            model: root.catalog
            UiButton {
                required property var modelData
                text: modelData.title; glyph: modelData.glyph; selected: ShellPrefs.favorites.includes(modelData.id)
                onClicked: ShellPrefs.toggleFavorite(modelData.id)
            }
        }
    }
}
