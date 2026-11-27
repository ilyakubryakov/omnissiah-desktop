pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    signal detailsRequested()
    spacing: Shared.DesktopStyle.px(10)
    readonly property var network: DesktopData.network
    readonly property var links: network.links || []
    readonly property var primary: network.primary === undefined ? (links[0] || ({}))
        : links.find(link => link.device === network.primary) || ({})
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
    function rate(before, after, seconds) {
        return Number.isFinite(before) && Number.isFinite(after) && after >= before ? (after - before) / seconds : -1
    }
    function sample(snapshot) {
        const now = snapshot.timestamp || 0
        if (now && now === previous.timestamp) return
        const delta = now - (previous.timestamp || 0)
        const old = previous.link || ({})
        const available = snapshot.links || []
        const link = (snapshot.primary === undefined ? available[0] : available.find(row => row.device === snapshot.primary)) || ({})
        const sameDevice = delta > 0 && link.device && old.device === link.device && old.uuid === link.uuid
        receiving = sameDevice ? rate(old.received, link.received, delta) : -1
        sending = sameDevice ? rate(old.sent, link.sent, delta) : -1
        previous = {timestamp: now, link: link}
    }
    property bool ready: false
    Component.onCompleted: { ready = true; sample(network) }
    onNetworkChanged: if (ready) sample(network)
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            UiLabel { text: root.primary.name || "Network"; font.pixelSize: Shared.DesktopStyle.px(16); font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
            UiLabel {
                text: ({full: "Connected", portal: "Sign-in required", limited: "Limited connectivity", none: "Disconnected"})[root.connectivity] || "Connectivity unavailable"
                color: root.connectivity === "full" ? Colors.statusAvailable : Colors.statusWarning; font.pixelSize: Shared.DesktopStyle.px(12)
            }
        }
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
            ["DNS", (root.primary.dns || []).join(", ") || "Unavailable"]
        ]
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            UiLabel { text: parent.modelData[0]; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.preferredWidth: Shared.DesktopStyle.px(95) }
            UiLabel { text: parent.modelData[1]; Layout.fillWidth: true; font.pixelSize: Shared.DesktopStyle.px(12); maximumLineCount: 2; elide: Text.ElideRight }
        }
    }
    UiLabel {
        visible: !!root.primary.uuid
        text: "DNS PROVIDER"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: Shared.DesktopStyle.px(1)
    }
    RowLayout {
        visible: !!root.primary.uuid
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
    UiLabel {
        visible: !DesktopData.networkManager
        text: DesktopData.networkManagement
        color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true; wrapMode: Text.WordWrap
    }
    UiButton { text: "Connection settings"; Layout.fillWidth: true; onClicked: root.detailsRequested() }
}
