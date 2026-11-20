pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    signal detailsRequested()
    spacing: 10
    readonly property var network: DesktopData.controls.network || ({})
    readonly property var links: network.links || []
    readonly property var primary: links.length ? links[0] : ({})
    readonly property string connectivity: network.connectivity || "unknown"
    property var previous: ({})
    property real receiving: -1
    property real sending: -1
    function bytes(value) {
        if (value === null || value === undefined || value < 0) return "Unavailable"
        if (value < 1024) return Math.round(value) + " B"
        if (value < 1048576) return (value / 1024).toFixed(1) + " KiB"
        if (value < 1073741824) return (value / 1048576).toFixed(1) + " MiB"
        return (value / 1073741824).toFixed(2) + " GiB"
    }
    onNetworkChanged: {
        const now = network.timestamp || 0
        const delta = now - (previous.timestamp || 0)
        const old = previous.link || ({})
        receiving = delta > 0 && old.device === primary.device && old.received !== null && primary.received !== null
            ? Math.max(0, (primary.received - old.received) / delta) : -1
        sending = delta > 0 && old.device === primary.device && old.sent !== null && primary.sent !== null
            ? Math.max(0, (primary.sent - old.sent) / delta) : -1
        previous = {timestamp: now, link: primary}
    }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            UiLabel { text: root.primary.name || "Network"; font.pixelSize: Shared.DesktopStyle.px(16); font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
            UiLabel {
                text: ({full: "Connected", portal: "Sign-in required", limited: "Limited connectivity", none: "Disconnected"})[root.connectivity] || "Connectivity unavailable"
                color: root.connectivity === "full" ? Colors.green : Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12)
            }
        }
        UiButton { text: "Wi-Fi"; selected: DesktopData.wifi.enabled; onClicked: root.detailsRequested() }
    }
    UiButton {
        visible: root.connectivity === "portal"
        text: "Open Captive Portal"; Layout.fillWidth: true
        onClicked: DesktopData.act("network-portal")
    }
    Repeater {
        model: [
            ["IP address", root.primary.address || "Unavailable"],
            ["Gateway", root.primary.gateway || "Unavailable"],
            ["Receiving", root.bytes(root.receiving) + (root.receiving >= 0 ? "/s" : "")],
            ["Sending", root.bytes(root.sending) + (root.sending >= 0 ? "/s" : "")],
            ["Downloaded", root.bytes(root.primary.received)],
            ["Uploaded", root.bytes(root.primary.sent)],
            ["DNS", (root.primary.dns || []).join(", ") || "Unavailable"],
            ["VPN", DesktopData.vpnStatus],
            ["Tailscale", DesktopData.tailscaleStatus]
        ]
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            UiLabel { text: parent.modelData[0]; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.preferredWidth: 95 }
            UiLabel { text: parent.modelData[1]; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12); maximumLineCount: 2; elide: Text.ElideRight }
        }
    }
    UiLabel { text: "DNS PROVIDER"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: 1 }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: [{id: "dhcp", label: "DHCP"}, {id: "cloudflare", label: "Cloudflare"}, {id: "google", label: "Google"}]
            UiButton {
                required property var modelData
                text: modelData.label; Layout.fillWidth: true
                enabled: !!root.primary.uuid && !DesktopData.busy
                onClicked: DesktopData.act("network-dns", [modelData.id, root.primary.uuid])
            }
        }
    }
    UiLabel { text: "Traffic totals are since this interface started. DNS changes apply to this connection."; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(10); Layout.fillWidth: true; wrapMode: Text.WordWrap }
    UiButton { text: "Wi-Fi & connection settings"; Layout.fillWidth: true; onClicked: root.detailsRequested() }
}
