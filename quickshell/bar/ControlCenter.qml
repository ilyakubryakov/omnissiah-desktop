pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import "../shared" as Shared

ColumnLayout {
    id: root
    signal notificationsRequested
    signal calendarRequested
    signal appearanceRequested
    property var cal: null
    property bool studioExpanded: false
    function launch(command) {
        Qt.callLater(() => Quickshell.execDetached(command));
    }
    readonly property bool laptop: Quickshell.env("STATION_LAPTOP") === "1"
    spacing: 16
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    PwObjectTracker {
        objects: root.nodes
    }
    component Heading: UiLabel {
        color: Colors.muted
        font.pixelSize: 12
        font.capitalization: Font.AllUppercase
        Layout.topMargin: 4
    }
    function signalGlyph(s) {
        return s >= 75 ? "\u{F0928}" : s >= 50 ? "\u{F0925}" : s >= 25 ? "\u{F0922}" : "\u{F091F}";
    }
    function btGlyph(icon) {
        const i = icon || "";
        return i.includes("headset") ? "\u{F02CE}" : i.includes("audio") || i.includes("headphone") ? "\u{F02CB}"
            : i.includes("keyboard") ? "\u{F030C}" : i.includes("mouse") ? "\u{F037D}" : i.includes("phone") ? "\u{F011C}"
            : i.includes("gaming") || i.includes("joystick") ? "\u{F0297}" : "\u{F00AF}";
    }
    function deviceName(node) {
        return (node.description || node.name || "Audio device").replace(/^.* HD Audio /, "");
    }
    component Card: SettingsCard {}
    component DevicePicker: UiComboBox {
        id: picker
        required property bool input
        readonly property var devices: root.nodes.filter(n => !n.isStream && n.isSink !== input)
        Layout.fillWidth: true
        model: devices.map(n => root.deviceName(n))
        currentIndex: devices.indexOf(input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink)
        Accessible.name: input ? "Input device" : "Output device"
        onActivated: index => {
            if (input)
                Pipewire.preferredDefaultAudioSource = devices[index];
            else
                Pipewire.preferredDefaultAudioSink = devices[index];
        }
        palette.button: Colors.selection
        palette.buttonText: Colors.foreground
        palette.base: Colors.background
        palette.text: Colors.foreground
        palette.highlight: Colors.accent
        palette.highlightedText: Colors.background
    }
    component AudioRow: ColumnLayout {
        id: audioRow
        required property var node
        property bool device: false
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            UiLabel {
                Layout.fillWidth: true
                text: root.deviceName(audioRow.node)
            }
            UiButton {
                visible: audioRow.device
                text: "Use"
                selected: audioRow.node === Pipewire.defaultAudioSink || audioRow.node === Pipewire.defaultAudioSource
                onClicked: {
                    if (audioRow.node.isSink)
                        Pipewire.preferredDefaultAudioSink = audioRow.node;
                    else
                        Pipewire.preferredDefaultAudioSource = audioRow.node;
                }
            }
            UiButton {
                text: audioRow.node.audio.muted ? "Muted" : "Mute"
                selected: audioRow.node.audio.muted
                onClicked: audioRow.node.audio.muted = !audioRow.node.audio.muted
            }
        }
        RowLayout {
            Layout.fillWidth: true
            UiSlider {
                Layout.fillWidth: true
                from: 0; to: 1; stepSize: 0.01
                value: audioRow.node.audio.volume
                tint: audioRow.node.audio.muted ? Colors.muted : Colors.accent
                onMoved: audioRow.node.audio.volume = value
                Accessible.name: "Volume " + audioRow.node.description
            }
            UiLabel {
                Layout.preferredWidth: 46
                text: Math.round(audioRow.node.audio.volume * 100) + "%"
            }
        }
    }

    Loader {
        id: sectionLoader
        Layout.fillWidth: true
        property real entrance: 1
        opacity: entrance
        transform: Translate { x: (1 - sectionLoader.entrance) * 12 }
        onLoaded: { if (initialized) sectionEnter.restart(); initialized = true }
        property bool initialized: false
        NumberAnimation { id: sectionEnter; target: sectionLoader; property: "entrance"; from: 0; to: 1; duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic }
        sourceComponent: DesktopData.controlTab === "power" ? powerPage : DesktopData.controlTab === "audio" ? audioPage : DesktopData.controlTab === "network" ? networkPage : DesktopData.controlTab === "system" ? systemPage : DesktopData.controlTab === "devices" ? devicesPage : DesktopData.controlTab === "session" ? sessionPage : DesktopData.controlTab === "displays" ? displaysPage : quickPage
    }
    Component {
        id: displaysPage
        DisplaysPage {}
    }
    Component {
        id: quickPage
        ControlDashboard { cal: root.cal; onNotificationsRequested: root.notificationsRequested(); onCalendarRequested: root.calendarRequested(); onAppearanceRequested: root.appearanceRequested(); onLaunchRequested: command => root.launch(command) }
    }

    Component {
        id: audioPage
        ColumnLayout {
            spacing: 14
            Card {
                Heading {
                    text: "Output"
                }
                DevicePicker {
                    input: false
                }
                Loader {
                    Layout.fillWidth: true
                    active: !!Pipewire.defaultAudioSink
                    sourceComponent: AudioRow {
                        node: Pipewire.defaultAudioSink
                    }
                }
            }
            Card {
                Heading {
                    text: "Microphone"
                }
                DevicePicker {
                    input: true
                }
                Loader {
                    Layout.fillWidth: true
                    active: !!Pipewire.defaultAudioSource
                    sourceComponent: AudioRow {
                        node: Pipewire.defaultAudioSource
                    }
                }
                UiLabel {
                    visible: !Pipewire.defaultAudioSource
                    text: "No input device"
                    color: Colors.muted
                }
            }
            Card {
                Heading {
                    text: "Applications"
                }
                UiLabel {
                    visible: !root.nodes.some(n => n.isStream)
                    text: "No applications playing or recording audio"
                    color: Colors.muted
                    Layout.fillWidth: true
                }
                Repeater {
                    model: root.nodes.filter(n => n.isStream)
                    AudioRow {
                        required property var modelData
                        node: modelData
                    }
                }
            }
            Card {
                RowLayout {
                    Layout.fillWidth: true
                    Heading {
                        text: "Music / recording"
                        Layout.fillWidth: true
                    }
                    UiButton {
                        glyph: "\u{F001}"
                        text: root.studioExpanded ? "Collapse" : "Studio tools"
                        selected: root.studioExpanded
                        onClicked: root.studioExpanded = !root.studioExpanded
                    }
                }
                Loader {
                    Layout.fillWidth: true
                    active: root.studioExpanded
                    sourceComponent: Shared.MusicControls {}
                }
            }
        }
    }
    Component {
        id: networkPage
        ColumnLayout {
            id: netPage
            spacing: 14
            readonly property var connections: DesktopData.controls.connections || []
            Card {
                visible: !!DesktopData.wifi.device
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        font.family: Colors.iconFont
                        font.pixelSize: 18
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: DesktopData.wifi.enabled ? "\u{F05A9}" : "\u{F05AA}"
                        color: DesktopData.wifi.enabled ? Colors.accent : Colors.muted
                    }
                    Heading {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        text: "Wi-Fi"
                    }
                    UiButton {
                        glyph: "\u{F0450}"
                        text: DesktopData.scanning ? "Scanning…" : "Scan"
                        enabled: DesktopData.wifi.enabled && !DesktopData.scanning && !DesktopData.busy
                        onClicked: DesktopData.scanWifi()
                    }
                    UiButton {
                        text: DesktopData.wifi.enabled ? "On" : "Off"
                        selected: DesktopData.wifi.enabled
                        enabled: !DesktopData.busy
                        onClicked: DesktopData.act("wifi-radio", [DesktopData.wifi.enabled ? "off" : "on"])
                    }
                }
                UiLabel {
                    visible: DesktopData.wifiError !== ""
                    Layout.fillWidth: true
                    text: DesktopData.wifiError
                    color: Colors.red
                }
                RowLayout {
                    visible: DesktopData.askSsid !== ""
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "\u{F033E}"; color: Colors.accent; font.family: Colors.iconFont; font.pixelSize: 18; Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter }
                    TextField {
                        id: wifiPassword
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: "Password for " + DesktopData.askSsid
                        color: Colors.foreground
                        placeholderTextColor: Colors.muted
                        font.family: Colors.textFont
                        background: Rectangle { color: Colors.background; border.width: 1; border.color: wifiPassword.activeFocus ? Colors.accent : Colors.selection }
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
                UiLabel {
                    color: Colors.muted
                    font.pixelSize: 12
                    visible: !DesktopData.wifi.enabled
                    text: "Wi-Fi is off"
                }
                Repeater {
                    model: DesktopData.wifi.enabled ? DesktopData.wifi.networks : []
                    Rectangle {
                        id: net
                        required property var modelData
                        readonly property bool secured: modelData.security !== "" && modelData.security !== "--"
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 8
                        color: netHover.containsMouse ? Colors.selection : "transparent"
                        MouseArea {
                            id: netHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: net.modelData.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (net.modelData.active || DesktopData.joining !== "") return;
                                if (net.secured && !net.modelData.known) DesktopData.askSsid = net.modelData.ssid;
                                else DesktopData.connectWifi(net.modelData.ssid, "");
                            }
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 10
                            Text {
                                font.family: Colors.iconFont
                                font.pixelSize: 18
                                Layout.preferredWidth: 22
                                horizontalAlignment: Text.AlignHCenter
                                text: root.signalGlyph(net.modelData.signal)
                                color: net.modelData.active ? Colors.accent : Colors.foreground
                            }
                            UiLabel {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: net.modelData.ssid
                                font.bold: net.modelData.active
                            }
                            Text {
                                font.family: Colors.iconFont
                                Layout.preferredWidth: 22
                                horizontalAlignment: Text.AlignHCenter
                                visible: net.secured
                                text: "\u{F033E}"
                                color: Colors.muted
                                font.pixelSize: 14
                            }
                            UiLabel {
                                font.pixelSize: 12
                                text: DesktopData.joining === net.modelData.ssid ? "Connecting…"
                                    : net.modelData.active ? "Connected" : net.modelData.known ? "Saved" : ""
                                color: net.modelData.active || DesktopData.joining === net.modelData.ssid ? Colors.accent : Colors.muted
                            }
                            UiButton {
                                visible: !!net.modelData.known && netHover.containsMouse
                                text: "Forget"
                                danger: true
                                implicitHeight: 28
                                enabled: !DesktopData.busy
                                onClicked: DesktopData.act("wifi-forget", [net.modelData.known])
                            }
                        }
                    }
                }
            }
            Card {
                id: wiredCard
                readonly property var wired: netPage.connections.filter(c => c.type === "802-3-ethernet" && c.active === "yes")
                visible: !root.laptop || wired.length > 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        font.family: Colors.iconFont
                        font.pixelSize: 18
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: "\u{F0200}"
                        color: wiredCard.wired.length ? Colors.accent : Colors.muted
                    }
                    Heading {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        text: "Wired"
                    }
                    UiLabel {
                        color: Colors.muted
                        font.pixelSize: 12
                        text: wiredCard.wired.length ? wiredCard.wired.map(c => c.name).join(", ") + " · connected" : "Disconnected"
                    }
                }
            }
            Card {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        font.family: Colors.iconFont
                        font.pixelSize: 18
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: "\u{F0582}"
                        color: DesktopData.activeVpns.length ? Colors.accent : Colors.muted
                    }
                    Heading {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        text: "VPN"
                    }
                }
                UiLabel {
                    visible: DesktopData.controls.vpns === null
                    text: "VPN profiles unavailable"
                    color: Colors.muted
                }
                Repeater {
                    model: DesktopData.vpnProfiles
                    RowLayout {
                        id: vpn
                        required property var modelData
                        readonly property bool up: modelData.active === "yes"
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            font.family: Colors.iconFont
                            font.pixelSize: 18
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: "\u{F0582}"
                            color: vpn.up ? Colors.accent : Colors.muted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            UiLabel { text: vpn.modelData.name }
                            UiLabel { text: ({connected: "Connected", connecting: "Connecting"})[vpn.modelData.state] || "Disconnected"; color: Colors.muted; font.pixelSize: 12 }
                        }
                        UiButton {
                            glyph: vpn.modelData.autostart ? "\u{F0132}" : "\u{F0131}"
                            text: "Auto-connect"
                            selected: !!vpn.modelData.autostart
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("vpn-autostart", [vpn.modelData.id, vpn.modelData.autostart ? "off" : "on"])
                        }
                        UiButton {
                            text: vpn.modelData.state === "disconnected" ? "Connect" : "Disconnect"
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("vpn", [vpn.modelData.id])
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        font.family: Colors.iconFont
                        font.pixelSize: 18
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: "\u{F0318}"
                        color: DesktopData.tailscale.online ? Colors.accent : Colors.muted
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        UiLabel { text: "Tailscale" }
                        UiLabel { text: DesktopData.tailscaleStatus; color: Colors.muted; font.pixelSize: 12 }
                    }
                }
                UiLabel {
                    color: Colors.muted
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    text: "Auto-connect brings a VPN up at login. A connected VPN reconnects by itself after sleep or a network change; a disconnected one stays off."
                }
            }
            Card {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        font.family: Colors.iconFont
                        font.pixelSize: 18
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "\u{F00AF}" : "\u{F00B2}"
                        color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? Colors.accent : Colors.muted
                    }
                    Heading {
                        Layout.fillWidth: true
                        Layout.topMargin: 0
                        text: "Bluetooth"
                    }
                    UiButton {
                        visible: !!Bluetooth.defaultAdapter
                        text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "On" : "Off"
                        selected: !!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
                        onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }
                UiLabel {
                    visible: !Bluetooth.defaultAdapter
                    text: "No Bluetooth adapter"
                    color: Colors.muted
                }
                id: btCard
                readonly property var adapter: Bluetooth.defaultAdapter
                readonly property bool usable: !!adapter && adapter.enabled

                property var pairRequested: ({})
                property bool scanStarted: false
                function pair(device) {
                    pairRequested[device.address] = true;
                    device.pair();
                }
                function settle(device) {
                    if (!device.paired || !pairRequested[device.address]) return;
                    delete pairRequested[device.address];
                    device.trusted = true;
                    if (!device.connected) device.connect();
                }
                function setScan(on) {
                    if (!usable) return;
                    adapter.discovering = on;
                    scanStarted = on;
                    if (on) scanTimer.restart(); else scanTimer.stop();
                }
                Timer {
                    id: scanTimer
                    interval: 60000
                    onTriggered: btCard.setScan(false)
                }
                Component.onDestruction: if (scanStarted && adapter) adapter.discovering = false
                Repeater {
                    model: btCard.adapter ? btCard.adapter.devices.values.filter(d => d.paired || d.connected) : []
                    RowLayout {
                        id: bt
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Component.onCompleted: btCard.settle(modelData)
                        Connections {
                            target: bt.modelData
                            function onPairedChanged() { btCard.settle(bt.modelData) }
                        }
                        Text {
                            font.family: Colors.iconFont
                            font.pixelSize: 18
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: root.btGlyph(bt.modelData.icon)
                            color: bt.modelData.connected ? Colors.accent : Colors.muted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            UiLabel { text: bt.modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
                            UiLabel {
                                color: Colors.muted
                                font.pixelSize: 12
                                text: (bt.modelData.pairing ? "Pairing…" : !bt.modelData.paired ? "Connected · not paired"
                                       : bt.modelData.connected ? "Connected" : "Paired")
                                    + (bt.modelData.batteryAvailable ? " · " + Math.round(bt.modelData.battery * 100) + "%" : "")
                            }
                        }
                        UiButton {
                            visible: !bt.modelData.paired
                            enabled: !bt.modelData.pairing
                            text: "Pair"
                            onClicked: btCard.pair(bt.modelData)
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
                RowLayout {
                    visible: btCard.usable
                    Layout.fillWidth: true
                    spacing: 10
                    Heading {
                        Layout.fillWidth: true
                        text: btCard.adapter && btCard.adapter.discovering ? "Searching for devices…" : "Pair a new device"
                    }
                    UiButton {
                        glyph: "\u{F0349}"
                        text: btCard.adapter && btCard.adapter.discovering ? "Stop" : "Search"
                        selected: !!btCard.adapter && btCard.adapter.discovering
                        onClicked: btCard.setScan(!btCard.adapter.discovering)
                    }
                }
                UiLabel {
                    visible: btCard.usable && btCard.adapter.discovering
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "Put the device into pairing mode. If it asks for confirmation, click the Bluetooth notification."
                }
                Repeater {
                    model: btCard.usable && btCard.adapter.discovering
                        ? btCard.adapter.devices.values.filter(d => !d.paired && !d.connected && d.deviceName)
                            .sort((a, b) => a.deviceName.localeCompare(b.deviceName))
                        : []
                    RowLayout {
                        id: found
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            font.family: Colors.iconFont
                            font.pixelSize: 18
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: root.btGlyph(found.modelData.icon)
                            color: Colors.muted
                        }
                        UiLabel { text: found.modelData.deviceName; Layout.fillWidth: true; elide: Text.ElideRight }
                        UiButton {
                            enabled: !found.modelData.pairing
                            text: found.modelData.pairing ? "Pairing…" : "Pair"
                            onClicked: btCard.pair(found.modelData)
                        }
                    }
                }
                UiButton {
                    glyph: "\u{F0493}"
                    text: "Bluetooth manager"
                    onClicked: root.launch(["blueman-manager"])
                }
            }
            UiButton {
                glyph: "\u{F0493}"
                text: "Advanced network settings"
                onClicked: root.launch(["nm-connection-editor"])
            }
        }
    }
    readonly property var layoutChoices: [["us", "English"], ["ru", "Russian"], ["ua", "Ukrainian"], ["lt", "Lithuanian"], ["de", "German"], ["pl", "Polish"], ["fr", "French"], ["es", "Spanish"]]
    readonly property var idleChoices: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]
    function idleLabel(m) {
        return m === 0 ? "Never" : m < 60 ? m + " min" : (m / 60) + " h";
    }
    function setInput(key, value) {
        DesktopData.act("input-set", [key, String(value)]);
    }
    function gib(bytes) {
        return (bytes / 1073741824).toFixed(0);
    }
    Component {
        id: devicesPage
        ColumnLayout {
            id: devices
            spacing: 14
            readonly property var s: DesktopData.settings || ({})
            readonly property var input: s.input || ({ layouts: "us" })
            UiLabel {
                visible: !devices.s.input
                text: "Loading…"
                color: Colors.muted
            }
            Card {
                visible: !!devices.s.input
                Heading { text: "Keyboard" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.layoutChoices
                        UiButton {
                            required property var modelData
                            readonly property var current: devices.input.layouts.split(",")
                            text: modelData[1]
                            selected: current.includes(modelData[0])
                            enabled: !DesktopData.busy
                            onClicked: {
                                const next = selected ? current.filter(l => l !== modelData[0]) : current.concat([modelData[0]]);
                                if (next.length > 0 && next.length <= 4)
                                    root.setInput("layouts", next.join(","));
                            }
                        }
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "Alt+Shift switches between them; the first one selected is the default."
                }
                SettingSlider {
                    label: "Repeat rate"
                    from: 10; to: 80; stepSize: 5
                    value: Number(devices.input.repeat_rate)
                    format: v => Math.round(v) + "/s"
                    onCommitted: v => root.setInput("repeat_rate", Math.round(v))
                }
                SettingSlider {
                    label: "Repeat delay"
                    from: 150; to: 1000; stepSize: 50
                    value: Number(devices.input.repeat_delay)
                    format: v => Math.round(v) + " ms"
                    onCommitted: v => root.setInput("repeat_delay", Math.round(v))
                }
            }
            Card {
                visible: !!devices.s.input
                Heading { text: "Mouse" }
                SettingSlider {
                    label: "Pointer speed"
                    from: -1; to: 1; stepSize: 0.05
                    value: Number(devices.input.mouse_speed)
                    format: v => (v > 0 ? "+" : "") + v.toFixed(2)
                    onCommitted: v => root.setInput("mouse_speed", v.toFixed(2))
                }
                UiButton {
                    glyph: devices.input.mouse_natural === "yes" ? "\u{F0132}" : "\u{F0131}"
                    text: "Natural scrolling"
                    selected: devices.input.mouse_natural === "yes"
                    enabled: !DesktopData.busy
                    onClicked: root.setInput("mouse_natural", selected ? "no" : "yes")
                }
            }
            Card {
                visible: !!devices.s.touchpad
                Heading { text: "Touchpad" }
                SettingSlider {
                    label: "Scroll speed"
                    from: 0.1; to: 2; stepSize: 0.05
                    value: Number(devices.input.scroll)
                    format: v => v.toFixed(2) + "×"
                    onCommitted: v => root.setInput("scroll", v.toFixed(2))
                }
                RowLayout {
                    spacing: 8
                    UiButton {
                        glyph: devices.input.natural === "yes" ? "\u{F0132}" : "\u{F0131}"
                        text: "Natural scrolling"
                        selected: devices.input.natural === "yes"
                        enabled: !DesktopData.busy
                        onClicked: root.setInput("natural", selected ? "no" : "yes")
                    }
                    UiButton {
                        glyph: devices.input.tap === "yes" ? "\u{F0132}" : "\u{F0131}"
                        text: "Tap to click"
                        selected: devices.input.tap === "yes"
                        enabled: !DesktopData.busy
                        onClicked: root.setInput("tap", selected ? "no" : "yes")
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "A two-finger press is the right click. Three fingers switch workspaces, up opens the Launchpad."
                }
            }
            Card {
                visible: !!devices.s.battery
                Heading { text: "Battery" }
                UiLabel {
                    text: {
                        const b = devices.s.battery || {};
                        return (b.health !== null ? "Health " + b.health + "% of design capacity" : "Health unknown")
                            + (b.cycles !== null ? " · " + b.cycles + " cycles" : "");
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: (devices.s.battery || {}).limit ? "Charging stops at " + devices.s.battery.limit + "%."
                        : "This laptop's firmware does not offer a charge limit to Linux."
                }
            }
            Card {
                visible: !!devices.s.input
                readonly property var p: devices.s.printers
                id: printerCard
                Heading { text: "Printers" }
                UiLabel {
                    visible: printerCard.p === null
                    Layout.fillWidth: true
                    color: Colors.muted
                    text: "Printing turns on after the next system rebuild."
                }
                UiLabel {
                    visible: !!printerCard.p && printerCard.p.queues.length === 0
                    color: Colors.muted
                    text: "No printers yet. Network printers usually appear by themselves."
                }
                Repeater {
                    model: printerCard.p ? printerCard.p.queues : []
                    RowLayout {
                        id: queue
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "\u{F02F}"
                            color: printerCard.p.default === queue.modelData ? Colors.accent : Colors.muted
                            font.family: Colors.iconFont
                            font.pixelSize: 16
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            text: queue.modelData
                        }
                        UiButton {
                            text: printerCard.p.default === queue.modelData ? "Default" : "Make default"
                            selected: printerCard.p.default === queue.modelData
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("printer-default", [queue.modelData])
                        }
                    }
                }
                RowLayout {
                    visible: !!printerCard.p && printerCard.p.jobs > 0
                    UiLabel {
                        Layout.fillWidth: true
                        text: printerCard.p ? printerCard.p.jobs + " job(s) waiting" : ""
                    }
                    UiButton {
                        text: "Cancel all"
                        danger: true
                        enabled: !DesktopData.busy
                        onClicked: DesktopData.act("print-cancel")
                    }
                }
                UiButton {
                    visible: printerCard.p !== null
                    glyph: "\u{F0493}"
                    text: "Printer settings…"
                    onClicked: root.launch(["system-config-printer"])
                }
            }
            Card {
                id: scanCard
                readonly property var sc: devices.s.scanners
                visible: !!devices.s.input
                Heading { text: "Scanners" }
                UiLabel {
                    visible: scanCard.sc === null
                    Layout.fillWidth: true
                    color: Colors.muted
                    text: "Scanning turns on after the next system rebuild."
                }
                UiLabel {
                    visible: !!scanCard.sc && scanCard.sc.devices.length === 0
                    color: Colors.muted
                    text: scanCard.sc && scanCard.sc.searching ? "Looking for scanners on the network…" : "No scanners found."
                }
                Repeater {
                    model: scanCard.sc ? scanCard.sc.devices : []
                    RowLayout {
                        id: scanner
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "\u{F06AB}"
                            color: Colors.accent
                            font.family: Colors.iconFont
                            font.pixelSize: 16
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: scanner.modelData.name
                        }
                    }
                }
                UiButton {
                    visible: scanCard.sc !== null
                    glyph: "\u{F06AB}"
                    text: "Scan a document…"
                    onClicked: root.launch(["skanpage"])
                }
            }
        }
    }
    Component {
        id: sessionPage
        ColumnLayout {
            id: session
            spacing: 14
            readonly property var s: DesktopData.settings || ({})
            UiLabel {
                visible: !session.s.autostart
                text: "Loading…"
                color: Colors.muted
            }
            Card {
                visible: !!session.s.autostart
                Heading { text: "Autostart" }
                Repeater {
                    model: session.s.autostart || []
                    RowLayout {
                        id: auto
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        UiLabel {
                            Layout.fillWidth: true
                            text: auto.modelData.name + (auto.modelData.applies ? "" : " · not for Hyprland")
                            color: auto.modelData.applies ? Colors.foreground : Colors.muted
                        }
                        UiButton {
                            text: auto.modelData.enabled ? "On" : "Off"
                            selected: auto.modelData.enabled
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("autostart-set", [auto.modelData.id, auto.modelData.enabled ? "off" : "on"])
                        }
                        UiButton {
                            visible: !auto.modelData.system
                            text: "Remove"
                            danger: true
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("autostart-remove", [auto.modelData.id])
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    SettingCombo {
                        id: addApp
                        model: session.s.apps || []
                        textRole: "name"
                    }
                    UiButton {
                        text: "Add"
                        enabled: !DesktopData.busy && addApp.currentIndex >= 0
                        onClicked: DesktopData.act("autostart-add", [session.s.apps[addApp.currentIndex].id])
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "Changes apply at the next login. Always started by the session: " + (session.s.sessionApps || []).join(", ") + "."
                }
            }
            Card {
                visible: !!session.s.workspaces
                readonly property var w: session.s.workspaces || ({ rules: [], running: [], fixed: [] })
                id: wsCard
                Heading { text: "Apps on workspaces" }
                Repeater {
                    model: wsCard.w.fixed
                    UiLabel {
                        required property var modelData
                        color: Colors.muted
                        text: modelData.class + " → " + modelData.workspace + " (fixed)"
                    }
                }
                Repeater {
                    model: wsCard.w.rules
                    RowLayout {
                        id: rule
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        UiLabel {
                            Layout.fillWidth: true
                            text: rule.modelData.class
                        }
                        SettingCombo {
                            Layout.fillWidth: false
                            Layout.preferredWidth: 90
                            model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
                            currentIndex: rule.modelData.workspace - 1
                            onActivated: i => DesktopData.act("workspace-set", [rule.modelData.class, String(i + 1)])
                        }
                        UiButton {
                            text: "Remove"
                            danger: true
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("workspace-set", [rule.modelData.class, "0"])
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    SettingCombo {
                        id: wsClass
                        editable: true
                        model: wsCard.w.running
                    }
                    SettingCombo {
                        id: wsNumber
                        Layout.fillWidth: false
                        Layout.preferredWidth: 90
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
                    }
                    UiButton {
                        text: "Add"
                        enabled: !DesktopData.busy && wsClass.editText.trim() !== ""
                        onClicked: DesktopData.act("workspace-set", [wsClass.editText.trim(), String(wsNumber.currentIndex + 1)])
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "Pick an open window's class or type one. New windows of that app open on its workspace."
                }
            }
            Card {
                visible: !!session.s.defaults
                Heading { text: "Default apps" }
                Repeater {
                    model: session.s.defaults || []
                    RowLayout {
                        id: def
                        required property var modelData
                        readonly property int index: modelData.choices.findIndex(c => c.id === modelData.current)
                        Layout.fillWidth: true
                        spacing: 10
                        UiLabel {
                            Layout.preferredWidth: 120
                            text: def.modelData.label
                        }
                        SettingCombo {
                            model: def.modelData.choices
                            textRole: "name"
                            currentIndex: def.index
                            displayText: def.index >= 0 ? currentText : (def.modelData.current || "Not set")
                            enabled: def.modelData.choices.length > 0 && !DesktopData.busy
                            onActivated: i => DesktopData.act("default-app", [def.modelData.key, def.modelData.choices[i].id])
                        }
                    }
                }
            }
            Card {
                id: capCard
                readonly property var cap: session.s.capture || null
                readonly property var keys: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".split("").concat(
                    ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "Print", "space"])
                visible: cap !== null
                Heading { text: "Capture shortcuts" }
                Repeater {
                    model: [["key", "Capture (bar mode)"], ["key_save", "Capture and save"]]
                    RowLayout {
                        id: shortcut
                        required property var modelData
                        readonly property string combo: capCard.cap ? capCard.cap[modelData[0]] : ""
                        property var mods: combo.split("+").slice(0, -1)
                        Layout.fillWidth: true
                        spacing: 6
                        onComboChanged: mods = combo.split("+").slice(0, -1)
                        UiLabel {
                            Layout.preferredWidth: 150
                            text: shortcut.modelData[1]
                        }
                        Repeater {
                            model: [["SUPER", "Win"], ["CTRL", "Ctrl"], ["ALT", "Alt"], ["SHIFT", "Shift"]]
                            UiButton {
                                required property var modelData
                                text: modelData[1]
                                selected: shortcut.mods.includes(modelData[0])
                                onClicked: shortcut.mods = selected ? shortcut.mods.filter(m => m !== modelData[0]) : shortcut.mods.concat([modelData[0]])
                            }
                        }
                        SettingCombo {
                            id: keyPick
                            Layout.fillWidth: false
                            Layout.preferredWidth: 90
                            model: capCard.keys
                            currentIndex: capCard.keys.indexOf(shortcut.combo.split("+").slice(-1)[0])
                        }
                        UiButton {
                            readonly property string next: ["SUPER", "CTRL", "ALT", "SHIFT"].filter(m => shortcut.mods.includes(m)).concat([keyPick.currentText]).join("+")
                            text: "Apply"
                            enabled: !DesktopData.busy && shortcut.mods.length > 0 && next !== shortcut.combo
                            onClicked: DesktopData.act("capture-set", [shortcut.modelData[0], next])
                        }
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "The camera menu on the bar picks what the capture key does: an area or window, the whole screen, or a video (press again to stop). Screenshots are saved to ~/Pictures/Screenshots, videos to ~/Videos/Screencasts."
                }
            }

        }
    }
    Component {
        id: powerPage
        ColumnLayout {
            spacing: 14
            Card {
                Heading { text: "Power and idle" }
                UiLabel {
                    Layout.fillWidth: true
                    text: "Timeouts count from your last activity and are saved for this machine. Never disables only that timer."
                    color: Colors.muted
                }
                RowLayout {
                    Layout.fillWidth: true
                    UiButton {
                        text: "Keep awake"
                        selected: !!DesktopData.controls.awake
                        onClicked: root.launch([Quickshell.env("HOME") + "/.config/hypr/scripts/keep-awake.sh"])
                    }
                    UiButton {
                        text: "Lock now"
                        onClicked: root.launch(["loginctl", "lock-session"])
                    }
                    UiButton {
                        text: "Screen off"
                        onClicked: root.launch(["sh", "-c", "sleep 1; hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = \"disable\" }))'"])
                    }
                    UiButton {
                        text: "Power menu"
                        onClicked: root.launch([Quickshell.env("HOME") + "/.config/hypr/scripts/power-menu.sh"])
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    text: DesktopData.controls.awake ? "Keep awake is active: automatic lock, screen off and sleep are paused." : "Screen off keeps apps running. Move the mouse or press a key to wake the displays."
                    color: DesktopData.controls.awake ? Colors.accent : Colors.muted
                }
            }
            Card {
                visible: !!DesktopData.settings.idle
                Heading { text: "Lock and sleep" }
                Repeater {
                    model: [["lock", "Lock screen after"], ["screen", "Turn off display after"], ["suspend", "Suspend after"]]
                    RowLayout {
                        id: idle
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        UiLabel {
                            Layout.preferredWidth: 180
                            text: idle.modelData[1]
                        }
                        SettingCombo {
                            readonly property int minutes: (DesktopData.settings.idle || {})[idle.modelData[0]] ?? 0
                            readonly property var choices: Array.from(new Set(root.idleChoices.concat([minutes]))).sort((a, b) => a - b)
                            model: choices.map(m => root.idleLabel(m))
                            currentIndex: choices.indexOf(minutes)
                            enabled: !DesktopData.busy
                            onActivated: i => DesktopData.act("idle-set", [idle.modelData[0], String(choices[i])])
                        }
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: "Keep awake pauses all three. Meta+L, closing the lid and sleep still lock at once."
                }
            }
            Card {
                visible: root.laptop
                Heading {
                    visible: root.laptop
                    text: "Laptop"
                }
                UiLabel {
                    visible: root.laptop
                    text: {
                        const b = (DesktopData.controls.laptop || {}).battery;
                        return b ? "Battery " + b.percent + "% · " + b.status : "Battery unavailable";
                    }
                }
                RowLayout {
                    visible: root.laptop
                    Repeater {
                        model: (DesktopData.controls.laptop || {}).profiles || []
                        UiButton {
                            required property string modelData
                            text: ({
                                    "power-saver": "Power saver",
                                    balanced: "Balanced",
                                    performance: "Performance"
                                })[modelData]
                            selected: (DesktopData.controls.laptop || {}).profile === modelData
                            enabled: !DesktopData.busy
                            onClicked: DesktopData.act("power-profile", [modelData])
                        }
                    }
                }
                RowLayout {
                    visible: root.laptop
                    UiLabel {
                        text: "Brightness"
                    }
                    UiSlider {
                        id: powerBrightness
                        Layout.fillWidth: true
                        from: 5; to: 100; stepSize: 1
                        tint: Colors.yellow
                        value: DesktopData.brightnessTarget >= 0 ? DesktopData.brightnessTarget : (DesktopData.controls.laptop || {}).brightness ?? 50
                        enabled: (DesktopData.controls.laptop || {}).brightness != null
                        Accessible.name: "Display brightness"
                        onMoved: DesktopData.setBrightness(Math.round(value))
                    }
                    UiLabel { text: Math.round(powerBrightness.value) + "%" }
                }
            }
        }
    }
    Component {
        id: systemPage
        ColumnLayout {
            spacing: 14

            Card {
                id: tzCard
                readonly property var tz: (DesktopData.settings || {}).timezone || null
                visible: tz !== null
                Heading { text: "Time zone" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "\u{F017}"
                        color: Colors.accent
                        font.family: Colors.iconFont
                        font.pixelSize: 16
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: tzCard.tz ? tzCard.tz.zone : ""
                    }
                    UiButton {
                        glyph: tzCard.tz && tzCard.tz.auto ? "\u{F0132}" : "\u{F0131}"
                        text: "Automatic"
                        selected: !!tzCard.tz && tzCard.tz.auto
                        enabled: !DesktopData.busy
                        onClicked: DesktopData.act("tz-auto", [tzCard.tz.auto ? "off" : "on"])
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    SettingCombo {
                        id: zonePick
                        editable: true
                        model: tzCard.tz ? tzCard.tz.zones : []
                        currentIndex: tzCard.tz ? tzCard.tz.zones.indexOf(tzCard.tz.zone) : -1
                    }
                    UiButton {
                        text: "Set"
                        enabled: !DesktopData.busy && !!tzCard.tz && tzCard.tz.zones.includes(zonePick.editText)
                        onClicked: DesktopData.act("tz-set", [zonePick.editText])
                    }
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    font.pixelSize: 12
                    text: !tzCard.tz ? "" : tzCard.tz.auto && !tzCard.tz.service ? "Automatic: waiting for a location fix (or the next system rebuild)."
                        : tzCard.tz.auto ? "Follows your location. Picking a zone by hand turns Automatic off." : "Set by hand."
                }
            }
            Card {
                id: nightCard
                readonly property var nl: (DesktopData.settings || {}).nightlight || null
                property bool custom: !!nl && nl.from !== ""
                visible: nl !== null
                Heading { text: "Night light" }
                RowLayout {
                    spacing: 8
                    UiButton {
                        glyph: "\u{F0EB}"
                        text: DesktopData.controls.nightlight ? "On" : "Off"
                        selected: !!DesktopData.controls.nightlight
                        enabled: !DesktopData.busy
                        onClicked: DesktopData.act("nightlight")
                    }
                    UiButton {
                        text: "Sunset to sunrise"
                        selected: !nightCard.custom
                        enabled: !DesktopData.busy
                        onClicked: { nightCard.custom = false; DesktopData.act("nightlight-set", [String(nightCard.nl.kelvin), "", ""]) }
                    }
                    UiButton {
                        text: "Custom hours"
                        selected: nightCard.custom
                        onClicked: nightCard.custom = true
                    }
                }
                RowLayout {
                    visible: nightCard.custom
                    spacing: 8
                    UiLabel { text: "From" }
                    TextField {
                        id: nightFrom
                        Layout.preferredWidth: 80
                        text: nightCard.nl && nightCard.nl.from ? nightCard.nl.from : "22:00"
                        inputMask: "99:99"
                        color: Colors.foreground
                        background: Rectangle { color: Colors.background; border.width: 1; border.color: Colors.selection }
                    }
                    UiLabel { text: "to" }
                    TextField {
                        id: nightTo
                        Layout.preferredWidth: 80
                        text: nightCard.nl && nightCard.nl.to ? nightCard.nl.to : "07:00"
                        inputMask: "99:99"
                        color: Colors.foreground
                        background: Rectangle { color: Colors.background; border.width: 1; border.color: Colors.selection }
                    }
                    UiButton {
                        text: "Apply"
                        enabled: !DesktopData.busy
                        onClicked: DesktopData.act("nightlight-set", [String(nightCard.nl.kelvin), nightFrom.text, nightTo.text])
                    }
                }
                SettingSlider {
                    label: "Warmth"
                    from: 2500; to: 6000; stepSize: 100
                    value: nightCard.nl ? nightCard.nl.kelvin : 4000
                    format: v => Math.round(v) + " K"
                    onCommitted: v => DesktopData.act("nightlight-set", [String(Math.round(v)), nightCard.nl.from, nightCard.nl.to])
                }
            }
            Card {
                id: nixCard
                readonly property var sys: (DesktopData.settings || {}).system || null
                visible: sys !== null
                Heading { text: "System" }
                UiLabel {
                    Layout.fillWidth: true
                    text: nixCard.sys ? nixCard.sys.version : ""
                }
                UiLabel {
                    Layout.fillWidth: true
                    color: Colors.muted
                    text: nixCard.sys ? "Kernel " + nixCard.sys.kernel : ""
                }
                Repeater {
                    model: nixCard.sys ? nixCard.sys.disks : []
                    RowLayout {
                        id: disk
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        UiLabel {
                            Layout.preferredWidth: 80
                            text: disk.modelData.mount
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            color: Colors.selection
                            Rectangle {
                                width: parent.width * disk.modelData.used / Math.max(1, disk.modelData.size)
                                height: parent.height
                                color: disk.modelData.used / disk.modelData.size > 0.9 ? Colors.red : Colors.accent
                            }
                        }
                        UiLabel {
                            color: Colors.muted
                            text: root.gib(disk.modelData.used) + " / " + root.gib(disk.modelData.size) + " GiB"
                        }
                    }
                }

            }
            UiLabel {
                Layout.fillWidth: true
                color: Colors.muted
                font.pixelSize: 13
                text: root.laptop ? "Balanced is the everyday profile. Use Performance for demanding work, or Power saver to extend battery life. Closing the lid suspends the laptop." : "Display changes keep your selected audio device."
            }
        }
    }
}
