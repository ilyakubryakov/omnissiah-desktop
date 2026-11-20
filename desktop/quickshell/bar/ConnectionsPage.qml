pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: Shared.DesktopStyle.px(20)
    property string tab: "network"
    readonly property bool laptop: Quickshell.env("ONINIX_LAPTOP") === "1"
    readonly property var connections: DesktopData.controls.connections || []
    readonly property var wired: connections.filter(c => c.type === "802-3-ethernet" && c.active === "yes")
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool usable: !!adapter && adapter.enabled
    property var pairRequested: ({})
    property bool scanStarted: false

    function launch(command) { Qt.callLater(() => Quickshell.execDetached(command)) }
    function signalGlyph(s) {
        return s >= 75 ? "\u{F0928}" : s >= 50 ? "\u{F0925}" : s >= 25 ? "\u{F0922}" : "\u{F091F}"
    }
    function btGlyph(icon) {
        const i = icon || ""
        return i.includes("headset") ? "\u{F02CE}" : i.includes("audio") || i.includes("headphone") ? "\u{F02CB}"
            : i.includes("keyboard") ? "\u{F030C}" : i.includes("mouse") ? "\u{F037D}" : i.includes("phone") ? "\u{F011C}"
            : i.includes("gaming") || i.includes("joystick") ? "\u{F0297}" : "\u{F00AF}"
    }
    function pair(device) {
        pairRequested[device.address] = true
        device.pair()
    }
    function settle(device) {
        if (!device.paired || !pairRequested[device.address]) return
        delete pairRequested[device.address]
        device.trusted = true
        if (!device.connected) device.connect()
    }
    function setScan(on) {
        if (!usable) return
        adapter.discovering = on
        scanStarted = on
        if (on) scanTimer.restart(); else scanTimer.stop()
    }
    Timer { id: scanTimer; interval: 60000; onTriggered: root.setScan(false) }
    Component.onDestruction: if (scanStarted && adapter) adapter.discovering = false

    readonly property var targetTabs: ({
        "Wi-Fi": "network", "Wired": "network", "Advanced network settings": "network",
        "Bluetooth": "bluetooth"
    })
    function reveal(target) {
        const tab = targetTabs[target]
        if (!tab || root.tab === tab) return false
        root.tab = tab
        return true
    }

    component Glyph: Text {
        font.family: Colors.iconFont
        font.pixelSize: Shared.DesktopStyle.px(16)
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: Shared.DesktopStyle.px(22)
        color: Colors.muted
    }
    component ClickRow: Item {
        id: click
        property bool stacked: false
        property alias title: inner.title
        property alias subtitle: inner.subtitle
        default property alias control: inner.control
        property bool clickable: true
        readonly property bool hovered: area.containsMouse
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight
        readonly property bool first: {
            const kids = parent ? parent.children : []
            for (let i = 0; i < kids.length; i++) if (kids[i].visible && ("stacked" in kids[i])) return kids[i] === click
            return true
        }
        Rectangle {
            anchors { fill: parent; margins: Shared.DesktopStyle.px(3) }
            radius: Shared.DesktopStyle.radiusSmall
            color: Qt.alpha(Colors.selection, 0.5)
            visible: area.containsMouse && click.clickable
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: click.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (click.clickable) click.clicked()
        }
        SettingsRow { id: inner; anchors.fill: parent }
        Rectangle {
            visible: !click.first
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Shared.DesktopStyle.px(14); rightMargin: Shared.DesktopStyle.px(14) }
            height: 1; color: Colors.selection
        }
    }

    Segmented {
        Layout.alignment: Qt.AlignHCenter
        model: [{id: "network", title: "Wi-Fi & wired"}, {id: "bluetooth", title: "Bluetooth"}]
        current: root.tab
        onChosen: id => root.tab = id
    }

    SettingsGroup {
        visible: root.tab === "network" && !!DesktopData.wifi.device
        title: "Wi-Fi"
        SettingsRow {
            title: "Wi-Fi"
            subtitle: DesktopData.wifi.enabled ? "" : "Wi-Fi is off"
            UiButton {
                glyph: "\u{F0450}"
                text: DesktopData.scanning ? "Scanning…" : "Scan"
                enabled: DesktopData.wifi.enabled && !DesktopData.scanning && !DesktopData.busy
                onClicked: DesktopData.scanWifi()
            }
            Segmented {
                model: [{id: "on", title: "On"}, {id: "off", title: "Off"}]
                current: DesktopData.wifi.enabled ? "on" : "off"
                enabled: !DesktopData.busy
                onChosen: id => { if (id !== current) DesktopData.act("wifi-radio", [id]) }
            }
        }
        SettingsRow {
            visible: DesktopData.wifiError !== ""
            stacked: true
            UiLabel { Layout.fillWidth: true; text: DesktopData.wifiError; color: Colors.red }
        }
        SettingsRow {
            visible: DesktopData.askSsid !== ""
            title: "Password for " + DesktopData.askSsid
            TextField {
                id: wifiPassword
                Layout.preferredWidth: Shared.DesktopStyle.px(220)
                echoMode: TextInput.Password
                placeholderText: "Password"
                color: Colors.foreground
                placeholderTextColor: Colors.muted
                font.family: Colors.textFont
                background: Rectangle { radius: Shared.DesktopStyle.radiusSmall; color: Colors.background; border.width: 1; border.color: wifiPassword.activeFocus ? Colors.accent : Colors.selection }
                onVisibleChanged: { text = ""; if (visible) forceActiveFocus() }
                onAccepted: if (text.length >= 8) DesktopData.connectWifi(DesktopData.askSsid, text)
                Keys.onEscapePressed: DesktopData.askSsid = ""
            }
            UiButton {
                text: "Join"
                enabled: wifiPassword.text.length >= 8
                onClicked: DesktopData.connectWifi(DesktopData.askSsid, wifiPassword.text)
            }
            UiButton {
                text: "Cancel"
                onClicked: DesktopData.askSsid = ""
            }
        }
        Repeater {
            model: DesktopData.wifi.enabled ? DesktopData.wifi.networks : []
            ClickRow {
                id: net
                required property var modelData
                readonly property bool secured: modelData.security !== "" && modelData.security !== "--"
                clickable: !modelData.active
                title: modelData.ssid
                subtitle: DesktopData.joining === modelData.ssid ? "Connecting…"
                    : modelData.active ? "Connected" : modelData.known ? "Saved" : ""
                onClicked: {
                    if (net.modelData.active || DesktopData.joining !== "") return
                    if (net.secured && !net.modelData.known) DesktopData.askSsid = net.modelData.ssid
                    else DesktopData.connectWifi(net.modelData.ssid, "")
                }
                UiButton {
                    visible: !!net.modelData.known && net.hovered
                    text: "Forget"
                    danger: true
                    implicitHeight: Shared.DesktopStyle.px(28)
                    enabled: !DesktopData.busy
                    onClicked: DesktopData.act("wifi-forget", [net.modelData.known])
                }
                Glyph { visible: net.secured; text: "\u{F033E}"; font.pixelSize: Shared.DesktopStyle.px(14) }
                Glyph {
                    text: root.signalGlyph(net.modelData.signal)
                    font.pixelSize: Shared.DesktopStyle.px(18)
                    color: net.modelData.active || DesktopData.joining === net.modelData.ssid ? Colors.accent : Colors.foreground
                }
            }
        }
    }

    SettingsGroup {
        visible: root.tab === "network" && (!root.laptop || root.wired.length > 0)
        title: "Wired"
        SettingsRow {
            title: "Wired"
            subtitle: root.wired.length ? root.wired.map(c => c.name).join(", ") + " · connected" : "Disconnected"
            Glyph { text: "\u{F0200}"; font.pixelSize: Shared.DesktopStyle.px(18); color: root.wired.length ? Colors.accent : Colors.muted }
        }
    }

    SettingsGroup {
        visible: root.tab === "network"
        SettingsRow {
            title: "Advanced network settings"
            subtitle: "Profiles, addresses and DNS in the connection editor"
            UiButton { glyph: "\u{F0493}"; text: "Open"; onClicked: root.launch(["nm-connection-editor"]) }
        }
    }

    SettingsGroup {
        visible: root.tab === "bluetooth"
        title: "Bluetooth"
        SettingsRow {
            title: "Bluetooth"
            subtitle: !root.adapter ? "No Bluetooth adapter" : root.adapter.enabled ? "" : "Off"
            Segmented {
                visible: !!root.adapter
                model: [{id: "on", title: "On"}, {id: "off", title: "Off"}]
                current: root.usable ? "on" : "off"
                onChosen: id => { if (root.adapter) root.adapter.enabled = id === "on" }
            }
        }
        Repeater {
            model: root.adapter ? root.adapter.devices.values.filter(d => d.paired || d.connected) : []
            SettingsRow {
                id: bt
                required property var modelData
                title: modelData.name
                subtitle: (modelData.pairing ? "Pairing…" : !modelData.paired ? "Connected · not paired"
                           : modelData.connected ? "Connected" : "Paired")
                    + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                Component.onCompleted: root.settle(modelData)
                Connections {
                    target: bt.modelData
                    function onPairedChanged() { root.settle(bt.modelData) }
                }
                Glyph { text: root.btGlyph(bt.modelData.icon); font.pixelSize: Shared.DesktopStyle.px(18); color: bt.modelData.connected ? Colors.accent : Colors.muted }
                UiButton {
                    visible: !bt.modelData.paired
                    enabled: !bt.modelData.pairing
                    text: "Pair"
                    onClicked: root.pair(bt.modelData)
                }
                UiButton {
                    visible: bt.modelData.paired
                    text: bt.modelData.connected ? "Disconnect" : "Connect"
                    onClicked: bt.modelData.connected = !bt.modelData.connected
                }
                UiButton {
                    glyph: "\u{F0A7A}"
                    danger: true
                    Accessible.name: "Forget"
                    onClicked: bt.modelData.forget()
                }
            }
        }
    }

    SettingsGroup {
        visible: root.tab === "bluetooth" && root.usable
        title: "Pair a new device"
        SettingsRow {
            title: root.adapter && root.adapter.discovering ? "Searching for devices…" : "Pair a new device"
            subtitle: root.usable && root.adapter.discovering ? "Put the device into pairing mode. If it asks for confirmation, click the Bluetooth notification." : ""
            UiButton {
                glyph: "\u{F0349}"
                text: root.adapter && root.adapter.discovering ? "Stop" : "Search"
                selected: !!root.adapter && root.adapter.discovering
                onClicked: root.setScan(!root.adapter.discovering)
            }
        }
        Repeater {
            model: root.usable && root.adapter.discovering
                ? root.adapter.devices.values.filter(d => !d.paired && !d.connected && d.deviceName)
                    .sort((a, b) => a.deviceName.localeCompare(b.deviceName))
                : []
            SettingsRow {
                id: found
                required property var modelData
                title: modelData.deviceName
                Glyph { text: root.btGlyph(found.modelData.icon); font.pixelSize: Shared.DesktopStyle.px(18) }
                UiButton {
                    enabled: !found.modelData.pairing
                    text: found.modelData.pairing ? "Pairing…" : "Pair"
                    onClicked: root.pair(found.modelData)
                }
            }
        }
    }

    SettingsGroup {
        visible: root.tab === "bluetooth"
        SettingsRow {
            title: "Bluetooth manager"
            subtitle: "Device details, file transfer and audio profiles"
            UiButton { glyph: "\u{F0493}"; text: "Open"; onClicked: root.launch(["blueman-manager"]) }
        }
    }
}
