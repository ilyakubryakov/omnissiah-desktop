pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: page
    spacing: Shared.DesktopStyle.px(20)
    property var draft: []
    property string primary: ""
    property string selectedKey: ""
    property bool dirty: false
    readonly property var server: DesktopData.displays
    readonly property var selected: draft.find(d => d.key === selectedKey) || null
    readonly property var placed: draft.filter(d => d.enabled && !d.mirror)
    readonly property var scaleChoices: [1, 1.25, 4 / 3, 1.5, 1.6, 5 / 3, 1.75, 2, 2.25, 2.5, 3]
    readonly property var rotations: ["Normal", "90°", "180°", "270°"]

    onServerChanged: if (!dirty) load()
    Component.onCompleted: { load(); DesktopData.readDisplays() }
    Connections {
        target: DesktopData
        function onDisplaysApplied() { page.dirty = false }
    }

    function load() {
        draft = (server.displays || []).map(d => Object.assign({}, d, { sdrbrightness: d.sdrBrightness }))
        primary = (draft.find(d => d.primary) || {}).key || ""
        if (!draft.some(d => d.key === selectedKey))
            selectedKey = draft.length ? (draft.find(d => d.primary) || draft[0]).key : ""
    }
    function update(key, changes) {
        draft = draft.map(d => d.key === key ? Object.assign({}, d, changes) : d)
        dirty = true
    }
    function title(d) { return d.model ? (d.make + " " + d.model).trim() : d.description }
    function appliance(d) { return d.role === "tv" }
    function logical(d) {
        const w = d.transform % 2 ? d.height : d.width
        const h = d.transform % 2 ? d.width : d.height
        return [Math.round(w / d.scale), Math.round(h / d.scale)]
    }
    function validScale(w, h, s) {
        return Math.abs(s * 120 - Math.round(s * 120)) < 0.01 && [w, h].every(n => Math.abs(n / s - Math.round(n / s)) < 0.01)
    }
    function scalesFor(d) { return scaleChoices.filter(s => validScale(d.width, d.height, s)) }
    function scaleLabel(s) { return (Math.round(s * 100) / 100).toString() + "×" }
    function overlaps(x, y, w, h, others) {
        return others.some(o => {
            const [ow, oh] = logical(o)
            return x < o.x + ow && o.x < x + w && y < o.y + oh && o.y < y + h
        })
    }
    function align(p, size, o, osize) {
        const v = Math.max(o - size + 1, Math.min(o + osize - 1, p))
        for (const t of [o, o + osize - size, o + Math.round((osize - size) / 2)])
            if (Math.abs(v - t) < Math.max(size, osize) * 0.08) return t
        return v
    }
    function snap(key, px, py) {
        const me = draft.find(d => d.key === key)
        const [w, h] = logical(me)
        const others = placed.filter(d => d.key !== key)
        if (!others.length) return [0, 0]
        let best = null
        for (const o of others) {
            const [ow, oh] = logical(o)
            const ay = align(py, h, o.y, oh), ax = align(px, w, o.x, ow)
            for (const c of [[o.x - w, ay], [o.x + ow, ay], [ax, o.y - h], [ax, o.y + oh]]) {
                if (overlaps(c[0], c[1], w, h, others)) continue
                const dist = Math.hypot(c[0] - px, c[1] - py)
                if (!best || dist < best.dist) best = { x: c[0], y: c[1], dist: dist }
            }
        }
        return best ? [best.x, best.y] : [me.x, me.y]
    }
    function normalize() {
        if (!placed.length) return
        const mx = Math.min(...placed.map(d => d.x)), my = Math.min(...placed.map(d => d.y))
        if (mx !== 0 || my !== 0)
            draft = draft.map(d => d.enabled && !d.mirror ? Object.assign({}, d, { x: d.x - mx, y: d.y - my }) : d)
    }
    function placeRight(key) {
        const others = placed.filter(d => d.key !== key)
        const right = others.length ? Math.max(...others.map(o => o.x + logical(o)[0])) : 0
        update(key, { x: right, y: 0 })
    }
    function setMode(d, width, height, refresh) {
        const scale = validScale(width, height, d.scale) ? d.scale
            : scalesFor({ width: width, height: height }).reduce((a, b) => Math.abs(b - d.scale) < Math.abs(a - d.scale) ? b : a, 1)
        update(d.key, { width: width, height: height, refresh: refresh, scale: scale })
        relayout()
    }
    function relayout() {
        const d = selected
        if (d && d.enabled && !d.mirror) {
            const [x, y] = snap(d.key, d.x, d.y)
            update(d.key, { x: x, y: y })
        }
        normalize()
    }
    function apply() {
        const request = {
            primary: primary,
            displays: draft.map(d => ({
                key: d.key, enabled: d.enabled, mode: d.width + "x" + d.height + "@" + d.refresh,
                position: d.x + "x" + d.y, scale: d.scale, transform: d.transform, vrr: d.vrr,
                hdr: d.hdr, sdrbrightness: d.sdrbrightness, mirror: d.mirror || ""
            }))
        }
        DesktopData.displayCommand(["apply"], JSON.stringify(request))
    }

    readonly property int controlWidth: Shared.DesktopStyle.px(220)

    UiLabel {
        visible: DesktopData.displayError !== ""
        Layout.fillWidth: true
        color: Colors.red
        text: DesktopData.displayError
    }

    SettingsGroup {
        title: "Arrangement"
        footer: "Drag a display; it snaps to the nearest edge. ★ marks the primary display: workspaces 1-10 and the panels live there."
        SettingsRow {
        stacked: true
        Item {
            id: canvas
            Layout.fillWidth: true
            implicitHeight: 230
            clip: true
            property bool dragging: false
            property real frozenK: 1
            readonly property var bounds: {
                const list = page.placed
                if (!list.length) return { x: 0, y: 0, w: 1, h: 1 }
                const xs = list.map(d => d.x), ys = list.map(d => d.y)
                const x2 = list.map(d => d.x + page.logical(d)[0]), y2 = list.map(d => d.y + page.logical(d)[1])
                const x = Math.min(...xs), y = Math.min(...ys)
                return { x: x, y: y, w: Math.max(...x2) - x, h: Math.max(...y2) - y }
            }
            readonly property real fitK: Math.min((width - 40) / bounds.w, (height - 40) / bounds.h)
            readonly property real k: dragging ? frozenK : fitK
            readonly property real ox: (width - bounds.w * k) / 2 - bounds.x * k
            readonly property real oy: (height - bounds.h * k) / 2 - bounds.y * k
            Rectangle { anchors.fill: parent; radius: Shared.DesktopStyle.radiusSmall; color: Colors.darkBackground }
            Repeater {
                model: page.placed
                Rectangle {
                    id: box
                    required property var modelData
                    readonly property var size: page.logical(modelData)
                    readonly property bool current: modelData.key === page.selectedKey
                    x: canvas.ox + modelData.x * canvas.k
                    y: canvas.oy + modelData.y * canvas.k
                    width: Math.max(8, size[0] * canvas.k)
                    height: Math.max(8, size[1] * canvas.k)
                    radius: 4
                    color: current ? Colors.selection : Colors.background
                    border.width: current ? 2 : 1
                    border.color: current ? Colors.accent : Colors.dim
                    Accessible.role: Accessible.Button
                    Accessible.name: page.title(modelData)
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: (box.modelData.key === page.primary ? "★ " : "") + (box.modelData.model || box.modelData.name)
                            color: Colors.foreground
                            font.family: Colors.textFont
                            font.pixelSize: Shared.DesktopStyle.px(12)
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: box.height > 44
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: box.modelData.name + " · " + box.size[0] + "×" + box.size[1]
                            color: Colors.muted
                            font.family: Colors.textFont
                            font.pixelSize: Shared.DesktopStyle.px(11)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: page.placed.length > 1 ? box : null
                        drag.threshold: 4
                        onPressed: { page.selectedKey = box.modelData.key; canvas.frozenK = canvas.k }
                        drag.onActiveChanged: {
                            if (drag.active) { canvas.dragging = true; return }
                            const [x, y] = page.snap(box.modelData.key,
                                Math.round((box.x - canvas.ox) / canvas.k), Math.round((box.y - canvas.oy) / canvas.k))
                            canvas.dragging = false
                            page.update(box.modelData.key, { x: x, y: y })
                            page.normalize()
                        }
                    }
                }
            }
        }
        }
        SettingsRow {
            title: "Display"
            Segmented {
                model: page.draft.map(d => ({id: d.key, title: d.name + (d.enabled ? (d.mirror ? " · mirror" : "") : " · off")}))
                current: page.selectedKey
                onChosen: id => page.selectedKey = id
            }
        }
    }

    SettingsGroup {
        id: settings
        visible: page.selected !== null
        readonly property var d: page.selected || ({ key: "", name: "", description: "", make: "", model: "", modes: [], width: 0, height: 0, scale: 1, transform: 0, vrr: 0,
            enabled: false, hdr: false, hdrCapable: false, saved: false, mirror: "", role: "" })
        readonly property var mode: d.modes.find(m => m.width === d.width && m.height === d.height) || ({ rates: [] })
        title: page.title(settings.d)
        SettingsRow {
            title: settings.d.name
            subtitle: settings.d.saved ? "Saved for this machine" : ""
            UiButton {
                text: settings.d.key === page.primary ? "Primary" : "Make primary"
                glyph: "\u{F005}"
                selected: settings.d.key === page.primary
                enabled: settings.d.enabled && !settings.d.mirror && !page.appliance(settings.d) && settings.d.key !== page.primary
                onClicked: { page.primary = settings.d.key; page.dirty = true }
            }
        }
        SettingsRow {
            title: "Display"
            subtitle: settings.d.key === page.primary ? "The primary display stays on" : ""
            Segmented {
                model: [{id: "on", title: "On"}, {id: "off", title: "Off"}]
                current: settings.d.enabled ? "on" : "off"
                onChosen: id => {
                    const on = id === "on"
                    if (settings.d.enabled === on || (!on && settings.d.key === page.primary)) return
                    page.update(settings.d.key, { enabled: on })
                    if (on && !settings.d.mirror) page.placeRight(settings.d.key)
                    page.normalize()
                }
            }
        }
        SettingsRow {
            title: "Resolution"
            visible: settings.d.enabled
            SettingCombo {
                Layout.preferredWidth: page.controlWidth
                model: settings.d.modes.map(m => m.width + " × " + m.height)
                currentIndex: settings.d.modes.findIndex(m => m.width === settings.d.width && m.height === settings.d.height)
                onActivated: i => {
                    const m = settings.d.modes[i]
                    page.setMode(settings.d, m.width, m.height, m.rates[0])
                }
            }
        }
        SettingsRow {
            title: "Refresh rate"
            visible: settings.d.enabled
            SettingCombo {
                Layout.preferredWidth: page.controlWidth
                model: settings.mode.rates.map(r => r.toFixed(2).replace(/\.?0+$/, "") + " Hz")
                currentIndex: settings.mode.rates.findIndex(r => Math.abs(r - settings.d.refresh) < 0.02)
                onActivated: i => page.update(settings.d.key, { refresh: settings.mode.rates[i] })
            }
        }
        SettingsRow {
            title: "Scale"
            visible: settings.d.enabled
            SettingCombo {
                Layout.preferredWidth: page.controlWidth
                readonly property var choices: page.scalesFor(settings.d)
                model: choices.map(s => page.scaleLabel(s))
                currentIndex: choices.findIndex(s => Math.abs(s - settings.d.scale) < 0.001)
                displayText: currentIndex >= 0 ? currentText : page.scaleLabel(settings.d.scale)
                onActivated: i => { page.update(settings.d.key, { scale: choices[i] }); page.relayout() }
            }
        }
        SettingsRow {
            title: "Rotation"
            visible: settings.d.enabled
            SettingCombo {
                Layout.preferredWidth: page.controlWidth
                model: page.rotations
                currentIndex: settings.d.transform
                onActivated: i => { page.update(settings.d.key, { transform: i }); page.relayout() }
            }
        }
        SettingsRow {
            title: "Variable refresh"
            visible: settings.d.enabled
            Segmented {
                model: [{id: "0", title: "Off"}, {id: "1", title: "On"}, {id: "2", title: "Fullscreen"}]
                current: String(settings.d.vrr)
                onChosen: id => page.update(settings.d.key, { vrr: Number(id) })
            }
        }
        SettingsRow {
            title: "HDR"
            subtitle: settings.d.hdrCapable === false ? "Not reported by the display" : settings.d.hdrCapable === null ? "Support unknown" : ""
            visible: settings.d.enabled
            Segmented {
                model: [{id: "off", title: "Off"}, {id: "on", title: "On"}]
                current: settings.d.hdr ? "on" : "off"
                onChosen: id => { if (id === "on" && settings.d.hdrCapable === false) return; page.update(settings.d.key, { hdr: id === "on" }) }
            }
        }
        SettingsRow {
            title: "SDR brightness"
            visible: settings.d.enabled && settings.d.hdr
            SettingSlider {
                Layout.preferredWidth: Shared.DesktopStyle.px(300)
                from: 0.5; to: 2; stepSize: 0.05
                value: settings.d.sdrbrightness || 1
                format: v => Math.round(v * 100) + "%"
                onCommitted: v => page.update(settings.d.key, { sdrbrightness: v })
            }
        }
        SettingsRow {
            title: "Mirror"
            visible: settings.d.enabled && !page.appliance(settings.d)
            SettingCombo {
                Layout.preferredWidth: page.controlWidth
                readonly property var targets: page.draft.filter(o => o.key !== settings.d.key && o.enabled && !o.mirror && !page.appliance(o))
                model: ["Off (extend)"].concat(targets.map(o => "Mirror " + o.name))
                currentIndex: settings.d.mirror ? targets.findIndex(o => o.key === settings.d.mirror) + 1 : 0
                enabled: settings.d.key !== page.primary
                onActivated: i => {
                    page.update(settings.d.key, { mirror: i === 0 ? "" : targets[i - 1].key })
                    if (i === 0) page.placeRight(settings.d.key)
                    page.normalize()
                }
            }
        }
        SettingsRow {
            visible: settings.d.saved === true
            title: "Saved settings"
            subtitle: "Stored on this machine, over the defaults in monitors.conf."
            UiButton {
                text: "Reset to defaults"
                enabled: !DesktopData.displayBusy && !page.dirty
                onClicked: DesktopData.displayCommand(["forget", settings.d.key])
            }
        }
    }

    SettingsGroup {
        SettingsRow {
            title: page.dirty ? "Unapplied changes" : "Apply"
            subtitle: "Changes apply to all displays at once and revert after 20 s unless kept."
            UiButton { text: "Discard"; enabled: page.dirty; onClicked: { page.dirty = false; page.load() } }
            UiButton {
                text: DesktopData.displayBusy ? "Applying…" : "Apply"
                selected: page.dirty
                enabled: page.dirty && !DesktopData.displayBusy
                onClicked: page.apply()
            }
        }
    }
}
