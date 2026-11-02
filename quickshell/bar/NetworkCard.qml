pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    signal detailsRequested()
    spacing: 12
    readonly property var links: (DesktopData.controls.connections || []).filter(c => c.active === "yes" && ["802-11-wireless", "802-3-ethernet"].includes(c.type))
    UiLabel { text: "CONNECTIONS"; color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 2 }
    Repeater {
        model: [
            {title: "Network", value: DesktopData.controls.connections === null ? "Unavailable" : root.links.map(c => c.name).join(" · ") || "Disconnected"},
            {title: "VPN", value: DesktopData.vpnStatus},
            {title: "Tailscale", value: DesktopData.tailscaleStatus}
        ]
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 4
            UiLabel { text: parent.modelData.title; color: Colors.muted; font.pixelSize: 11 }
            UiLabel { text: parent.modelData.value; Layout.fillWidth: true; font.pixelSize: 14; maximumLineCount: 2; elide: Text.ElideRight }
        }
    }
    UiButton { text: "Connection settings"; Layout.fillWidth: true; onClicked: root.detailsRequested() }
}
