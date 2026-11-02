pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 14
    readonly property var host: Homelab.host
    readonly property bool fresh: Homelab.hostFresh

    function usageColor(pct) { return pct >= 90 ? Colors.red : pct >= 80 ? Colors.yellow : Colors.accent }
    function uptimeText(sec) {
        if (sec == null) return ""
        const h = Math.floor(sec / 3600), d = Math.floor(h / 24)
        return "up " + (d ? d + "d " + h % 24 + "h" : h + "h " + Math.floor(sec % 3600 / 60) + "m")
    }
    function driveName(d) {
        const family = d.family && d.family !== "unknown" ? d.family.replace(/^(Seagate|Western Digital|WDC|Samsung|Crucial)\s+/, "") : ""
        const model = d.model.replace(/^CT\d+BX500SSD1$/, "Crucial BX500").replace(/\s*SSD\s*/, " ").replace(/\s+\d+(GB|TB)$/, "")
        return family || model
    }
    function capacityText(tb) { return tb == null ? "" : tb >= 1 ? tb.toFixed(tb % 1 ? 1 : 0) + " TB" : Math.round(tb * 1000) + " GB" }

    component SectionTitle: UiLabel { color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 2; Layout.topMargin: 2 }
    component Bar: Rectangle {
        property real value: 0
        property color tone: Colors.accent
        Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: Colors.selection
        Rectangle {
            height: parent.height; radius: 2; color: parent.tone
            width: parent.width * Math.max(0, Math.min(1, parent.value / 100))
            Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
        }
    }
    component Metric: ColumnLayout {
        property string label
        property var value: null
        property string suffix: "%"
        property real scale: 100
        property color tone: Colors.accent
        readonly property bool known: typeof value === "number" && isFinite(value)
        Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 5
        UiLabel { text: parent.label; color: Colors.muted; font.pixelSize: 11 }
        UiLabel { text: parent.known ? Math.round(parent.value) + parent.suffix : "--"; font.pixelSize: 17; color: parent.known ? Colors.foreground : Colors.muted }
        Bar { value: parent.known ? parent.value / parent.scale * 100 : 0; tone: parent.tone }
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 12
        Text { text: "\u{F048D}"; font.family: Colors.iconFont; font.pixelSize: 26; color: Colors.accent }
        ColumnLayout {
            spacing: 2
            UiLabel { text: "HOMESERVER"; color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 3 }
            RowLayout {
                spacing: 6
                Rectangle {
                    implicitWidth: 7; implicitHeight: 7; radius: 3.5
                    color: root.fresh && root.host.up ? Colors.green : root.fresh && root.host.up === false ? Colors.red : Colors.dim
                }
                UiLabel {
                    text: !root.fresh ? (Homelab.hostLoading ? "Updating…" : "Telemetry unavailable")
                        : root.host.up === null ? "Host status unknown" : root.host.up ? "Online" : "Node exporter offline"
                    color: root.fresh && root.host.up ? Colors.foreground : Colors.muted; font.pixelSize: 13
                }
                UiLabel { visible: root.fresh && root.host.uptimeSec != null; text: "·  " + root.uptimeText(root.host.uptimeSec); color: Colors.muted; font.pixelSize: 12 }
            }
        }
        Item { Layout.fillWidth: true }
        UiButton { glyph: "\u{F0450}"; Accessible.name: "Refresh server metrics"; enabled: !Homelab.hostLoading; onClicked: Homelab.readHost(true) }
    }
    UiLabel { visible: Homelab.hostError !== ""; text: Homelab.hostError; font.pixelSize: 12; color: Colors.muted; Layout.fillWidth: true }

    RowLayout {
        visible: root.fresh
        Layout.fillWidth: true; spacing: 14
        Metric { label: "CPU"; value: root.host.cpu }
        Metric { label: "Memory"; value: root.host.ram; tone: Colors.cyan }
        Metric { label: "CPU temp"; value: root.host.temp; suffix: "°"; tone: root.host.temp >= 80 ? Colors.red : Colors.yellow }
        Metric { label: "Disk busy"; value: root.host.diskio; tone: Colors.magenta }
    }

    SectionTitle { visible: root.fresh && (root.host.disks || []).length > 0; text: "STORAGE" }
    Repeater {
        model: root.fresh ? root.host.disks || [] : []
        ColumnLayout {
            id: pool
            required property var modelData
            readonly property bool degraded: !!modelData.health && modelData.health !== "online"
            Layout.fillWidth: true; spacing: 5
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: pool.modelData.pool ? "\u{F01BC}" : "\u{F02CA}"; font.family: Colors.iconFont; font.pixelSize: 15; color: Colors.muted }
                UiLabel { text: pool.modelData.name; font.pixelSize: 13; font.weight: Font.DemiBold }
                UiLabel {
                    visible: !!pool.modelData.health
                    text: pool.degraded ? pool.modelData.health.toUpperCase() : "ZFS · " + pool.modelData.health + (pool.modelData.fragPct != null ? " · frag " + pool.modelData.fragPct + "%" : "")
                    color: pool.degraded ? Colors.red : Colors.dim; font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                UiLabel { text: pool.modelData.usedTb + " / " + pool.modelData.totalTb + " TiB"; color: Colors.muted; font.pixelSize: 12 }
                UiLabel { text: Math.round(pool.modelData.pct) + "%"; color: root.usageColor(pool.modelData.pct); font.pixelSize: 13; font.weight: Font.DemiBold; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight }
            }
            Bar { value: pool.modelData.pct; tone: root.usageColor(pool.modelData.pct) }
        }
    }

    SectionTitle { visible: root.fresh && (root.host.drives || []).length > 0; text: "DRIVES" }
    Repeater {
        model: root.fresh ? root.host.drives || [] : []
        RowLayout {
            id: drive
            required property var modelData

            readonly property int hot: modelData.kind === "hdd" ? 55 : 75
            Layout.fillWidth: true; spacing: 8
            Text {
                text: drive.modelData.kind === "nvme" ? "\u{F0FB2}" : "\u{F02CA}"
                font.family: Colors.iconFont; font.pixelSize: 15
                color: drive.modelData.ok === false ? Colors.red : Colors.muted
                Layout.preferredWidth: 18
            }
            UiLabel { text: root.driveName(drive.modelData); font.pixelSize: 12; elide: Text.ElideRight; Layout.maximumWidth: 150 }
            UiLabel { text: root.capacityText(drive.modelData.capacityTb) + " · " + drive.modelData.device; color: Colors.dim; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
            UiLabel {
                visible: drive.modelData.wearPct != null
                text: "wear " + drive.modelData.wearPct + "%"
                color: drive.modelData.wearPct >= 80 ? Colors.yellow : Colors.dim; font.pixelSize: 11
            }
            UiLabel {
                text: drive.modelData.tempC != null ? drive.modelData.tempC + "°" : "--"
                color: drive.modelData.tempC >= drive.hot ? Colors.red : drive.modelData.tempC >= drive.hot - 5 ? Colors.yellow : Colors.foreground
                font.pixelSize: 12; Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight
            }
            Text {
                text: drive.modelData.ok === false ? "\u{F05D6}" : "\u{F05E1}"
                color: drive.modelData.ok === false ? Colors.red : drive.modelData.ok ? Colors.green : Colors.dim
                font.family: Colors.iconFont; font.pixelSize: 14
                HoverHandler { id: smartHover }
                BarToolTip {
                    target: parent; shown: smartHover.hovered
                    text: (drive.modelData.ok === false ? "SMART reports a failure" : "SMART passed")
                        + (drive.modelData.powerOnDays != null ? " · " + drive.modelData.powerOnDays + " days powered on" : "")
                }
            }
        }
    }

    RowLayout {
        visible: root.fresh && !!root.host.ups?.present
        Layout.fillWidth: true; spacing: 8
        Text { text: root.host.ups?.onBattery ? "\u{F010C}" : "\u{F06A5}"; font.family: Colors.iconFont; font.pixelSize: 15; color: root.host.ups?.onBattery ? Colors.yellow : Colors.muted }
        UiLabel {
            Layout.fillWidth: true
            text: "UPS " + (root.host.ups?.onBattery ? "on battery" : "online") + " · " + (root.host.ups?.batt ?? "--") + "%"
                + (root.host.ups?.runtimeMin != null ? " · " + root.host.ups.runtimeMin + " min runtime" : "")
                + (root.host.ups?.load != null ? " · load " + Math.round(root.host.ups.load) + "%" : "")
            color: root.host.ups?.onBattery ? Colors.yellow : Colors.muted; font.pixelSize: 12
        }
    }

    SectionTitle { text: "ALERTS" }
    UiLabel { visible: !Homelab.reachable || Homelab.alerts.length === 0; text: Homelab.reachable ? "No active alerts" : "Alert source unavailable"; color: Homelab.reachable ? Colors.green : Colors.muted; font.pixelSize: 12 }
    Repeater {
        model: Homelab.alerts.slice(0, 3)
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 3
            UiLabel { text: parent.modelData.name; color: parent.modelData.severity === "critical" ? Colors.red : Colors.yellow; font.pixelSize: 13; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
            UiLabel { text: parent.modelData.target; color: Colors.muted; font.pixelSize: 11; Layout.fillWidth: true; maximumLineCount: 1; elide: Text.ElideRight }
        }
    }
    UiLabel { visible: Homelab.alerts.length > 3; text: "+ " + (Homelab.alerts.length - 3) + " more alerts"; color: Colors.muted; font.pixelSize: 12 }
    UiLabel { visible: root.fresh; text: "Updated " + Qt.formatTime(new Date(root.host.updatedAt || 0), "HH:mm:ss") + " · Prometheus"; color: Colors.dim; font.pixelSize: 10 }
}
