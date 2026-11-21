import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "../shared" as Shared

Item {
    id: root
    required property string token
    required property var bar
    readonly property bool shown: token === "battery" ? Quickshell.env("ONINIX_LAPTOP") === "1"
        : token === "recording" ? StatusState.recording
        : token === "awake" ? StatusState.awake : true
    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: PanelStyle.barHeight

    Loader {
        id: loader
        height: parent.height
        sourceComponent: ({
            applications: applications, notebook: notebook, tray: tray, network: network, battery: battery,
            recording: recording, awake: awake, capture: capture, microphone: microphone,
            notifications: notifications, volume: volume, clock: clock, controls: controls
        })[root.token] || null
    }

    Component {
        id: applications
        Seg { glyph: "\u{F003B}"; toolTip: "Applications"; tint: Colors.accent; onClicked: root.bar.openPanel("launchpad") }
    }
    Component {
        id: notebook
        Seg {
            glyph: "\u{F044}"
            toolTip: "Notebook"
            tint: Colors.accent
            onClicked: root.bar.openPanel("notebook")
        }
    }

    Component {
        id: tray
        RowLayout {
            spacing: 6
            PersistentProperties {
                id: trayState
                reloadableId: "compactTrayState"
                property bool shown: false
            }
            Seg {
                glyph: trayState.shown ? "\u{F0142}" : "\u{F0141}"
                tint: Colors.muted
                toolTip: trayState.shown ? "Hide tray" : "Show tray"
                onClicked: trayState.shown = !trayState.shown
            }
            Repeater {
                model: SystemTray.items.values
                Item {
                    id: trayIcon
                    required property var modelData
                    visible: trayState.shown
                    readonly property int iconSize: Math.round((Colors.fontSize + 2) * 0.8)
                    implicitWidth: Colors.fontSize + 4
                    implicitHeight: root.bar.implicitHeight
                    readonly property string glyph: {
                        const k = ((trayIcon.modelData.id || "") + " " + (trayIcon.modelData.title || "") + " "
                                   + (trayIcon.modelData.tooltipTitle || "")).toLowerCase()
                        const ic = ("" + (trayIcon.modelData.icon || "")).toLowerCase()
                        if (k.includes("blueman")) {
                            if (ic.includes("disabled")) return "\u{F00B2}"
                            if (ic.includes("active")) return "\u{F00B1}"
                            return "\u{F00AF}"
                        }
                        if (k.includes("nextcloud")) {
                            if (ic.includes("state-sync")) return "\u{F063F}"
                            if (ic.includes("state-ok")) return "\u{F0160}"
                            if (ic.includes("state-offline")) return "\u{F0164}"
                            if (ic.includes("state-pause")) return "\u{F0163}"
                            if (ic.includes("state-error") || ic.includes("state-warning")) return "\u{F09E0}"
                            return "\u{F015F}"
                        }
                        if (k.includes("kde connect")) return "\u{F011C}"
                        const app = Hypr.icon(k)
                        return app === "\u{F05AF}" ? "" : app
                    }
                    Text {
                        visible: trayIcon.glyph !== ""
                        anchors.centerIn: parent
                        text: trayIcon.glyph
                        color: trayMenu.open && trayMenu.item === trayIcon.modelData ? Colors.bright : Colors.foreground
                        font.family: Colors.iconFont
                        font.pixelSize: Colors.fontSize + 2
                    }
                    Image {
                        visible: trayIcon.glyph === ""
                        anchors.centerIn: parent
                        width: trayIcon.iconSize
                        height: trayIcon.iconSize
                        source: {
                            const ic = "" + (trayIcon.modelData.icon || "")
                            if (ic === "") return ""
                            if (ic.indexOf("/") < 0 && ic.indexOf(":") < 0)
                                return Quickshell.iconPath(ic, "application-x-executable")
                            return ic
                        }
                        sourceSize.width: 32
                        sourceSize.height: 32
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                        layer.effect: MultiEffect {
                            brightness: 1.0
                            colorization: 1.0
                            colorizationColor: trayMenu.open && trayMenu.item === trayIcon.modelData ? Colors.bright : Colors.foreground
                        }
                    }
                    BarToolTip {
                        target: trayIcon
                        shown: hover.containsMouse && !trayMenu.open
                        text: trayIcon.modelData.tooltipTitle || trayIcon.modelData.title || ""
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const item = trayIcon.modelData
                            if (m.button === Qt.MiddleButton) item.secondaryActivate()
                            else if (m.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) trayMenu.show(item, trayIcon)
                            } else {
                                const keys = [item.id, item.title].map(v => ("" + (v || "")).toLowerCase()).filter(v => v.length > 2)
                                const parked = Minimized.windows.find(c => keys.some(k =>
                                    ("" + (c["class"] || "")).toLowerCase().includes(k) || ("" + (c.title || "")).toLowerCase() === k))
                                if (parked) Minimized.show(parked)
                                item.activate()
                            }
                        }
                        onWheel: w => trayIcon.modelData.scroll(Math.round(w.angleDelta.y / 120), false)
                    }
                }
            }
            TrayMenu {
                id: trayMenu
                barWindow: root.bar
                anchorItem: root.bar.contentItem
            }
        }
    }

    Component {
        id: network
        Seg {
            id: networkSeg
            readonly property var links: DesktopData.network.links || []
            readonly property bool wired: links.some(c => c.type === "ethernet")
            readonly property bool wireless: links.some(c => c.type === "wifi")
            glyph: wired ? "\u{F0200}" : wireless ? "\u{F05A9}" : "\u{F05AA}"
            label: wired || wireless ? "" : ({
                full: "Connected", portal: "Sign-in required", limited: "Limited", none: "Offline"
            })[DesktopData.network.connectivity] || "Network"
            tint: Colors.foreground
            onClicked: networkPopup.togglePinned()
            BarPopup {
                id: networkPopup
                anchorItem: networkSeg; barWindow: root.bar
                triggerHovered: networkSeg.hovered
                onOpenedChanged: if (opened) DesktopData.refresh()
                NetworkCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "network"; root.bar.openPanel("controls") } }
            }
        }
    }
    Component {
        id: battery
        Seg {
            id: batterySeg
            readonly property var battery: (DesktopData.controls.laptop || {}).battery
            glyph: battery && battery.status === "Charging" ? "\u{F0084}" : "\u{F0079}"
            label: battery ? battery.percent + "%" : "--"
            tint: battery && battery.percent <= 15 && battery.status === "Discharging" ? Colors.red : Colors.foreground
            onClicked: powerPopup.togglePinned()
            BarPopup {
                id: powerPopup
                anchorItem: batterySeg; barWindow: root.bar
                triggerHovered: batterySeg.hovered
                onOpenedChanged: if (opened) DesktopData.refresh()
                PowerCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "power"; root.bar.openPanel("controls") } }
            }
        }
    }

    Component {
        id: recording
        Seg {
            glyph: "\u{F044A}"
            tint: Colors.red
            onClicked: Hypr.exec(StatusState.scripts + "screenrecord.sh")
        }
    }
    Component {
        id: awake
        Seg {
            glyph: "\u{F0176}"
            toolTip: "Keep awake"
            tint: Colors.accent
            onClicked: Hypr.exec(StatusState.scripts + "keep-awake.sh")
        }
    }

    Component {
        id: capture
        Seg {
            id: captureSeg
            readonly property var cap: DesktopData.controls.capture || ({ mode: "region", key: "SUPER+SHIFT+S" })
            glyph: cap.mode === "video" ? "\u{F0567}" : cap.mode === "screen" ? "\u{F0E51}" : "\u{F0100}"
            tint: captureMenu.open ? Colors.accent : Colors.foreground
            toolTip: captureMenu.open ? "" : "Capture · " + ({ region: "area or window", screen: "whole screen", video: "video" })[cap.mode]
                + " · " + captureMenu.pretty(cap.key)
            onClicked: captureMenu.open = !captureMenu.open
            Dropdown {
                id: captureMenu
                anchorItem: captureSeg
                barWindow: root.bar
                cardWidth: Shared.DesktopStyle.px(300)
                readonly property var cap: captureSeg.cap
                function pretty(combo) {
                    const names = { SUPER: "Win", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" }
                    return (combo || "").split("+").map(k => names[k] || k).join("+")
                }
                function pick(key, value) { DesktopData.act("capture-set", [key, value]) }
                function flip(key) { pick(key, cap[key] === "yes" ? "no" : "yes") }
                function now(args) {
                    open = false
                    Hypr.exec("sh -c 'sleep 0.3; exec " + StatusState.scripts + "shot.sh " + args + "'")
                }

                DropdownRow { header: true; label: captureMenu.pretty(captureMenu.cap.key) + " captures" }
                DropdownRow { glyph: "\u{F0A6D}"; label: "Area or window"; current: captureMenu.cap.mode === "region"; detail: current ? "\u{F012C}" : ""; onClicked: captureMenu.pick("mode", "region") }
                DropdownRow { glyph: "\u{F0E51}"; label: "Whole screen"; current: captureMenu.cap.mode === "screen"; detail: current ? "\u{F012C}" : ""; onClicked: captureMenu.pick("mode", "screen") }
                DropdownRow { glyph: "\u{F0567}"; label: "Video recording"; current: captureMenu.cap.mode === "video"; detail: current ? "\u{F012C}" : ""; onClicked: captureMenu.pick("mode", "video") }
                DropdownRow { header: true; label: "Options" }
                DropdownRow { glyph: captureMenu.cap.audio === "yes" ? "\u{F0132}" : "\u{F0131}"; label: "Record system audio"; current: captureMenu.cap.audio === "yes"; onClicked: captureMenu.flip("audio") }
                DropdownRow { glyph: captureMenu.cap.mic === "yes" ? "\u{F0132}" : "\u{F0131}"; label: "Record microphone"; current: captureMenu.cap.mic === "yes"; onClicked: captureMenu.flip("mic") }
                DropdownRow { glyph: captureMenu.cap.pointer === "yes" ? "\u{F0132}" : "\u{F0131}"; label: "Show pointer"; current: captureMenu.cap.pointer === "yes"; onClicked: captureMenu.flip("pointer") }
                DropdownRow { header: true; label: "Now" }
                DropdownRow {
                    glyph: StatusState.recording ? "\u{F044A}" : "\u{F0100}"
                    label: StatusState.recording ? "Stop recording" : "Capture"
                    onClicked: captureMenu.now("")
                }
                DropdownRow {
                    visible: !StatusState.recording && captureMenu.cap.mode !== "video"
                    glyph: "\u{F0193}"
                    label: "Capture and save"
                    detail: captureMenu.pretty(captureMenu.cap.key_save)
                    onClicked: captureMenu.now("save")
                }
                DropdownRow {
                    glyph: "\u{F024F}"
                    label: "Screenshots folder"
                    onClicked: { captureMenu.open = false; Hypr.exec("xdg-open " + Quickshell.env("HOME") + "/Pictures/Screenshots") }
                }
                DropdownRow {
                    glyph: "\u{F097B}"
                    label: "Shortcuts…"
                    onClicked: { captureMenu.open = false; DesktopData.controlTab = "session"; root.bar.openPanel("controls") }
                }
            }
        }
    }

    Component {
        id: microphone
        Seg {
            id: micSeg
            readonly property var input: Shared.AudioState.input
            glyph: input && !input.muted ? "\u{F036C}" : "\u{F036D}"
            tint: !input ? Colors.muted : input.muted ? Colors.foreground : Colors.accent
            onClicked: micPopup.togglePinned()
            onRightClicked: if (Shared.AudioState.input) Shared.AudioState.input.muted = !Shared.AudioState.input.muted
            BarPopup {
                id: micPopup
                anchorItem: micSeg; barWindow: root.bar
                triggerHovered: micSeg.hovered
                AudioCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "audio"; root.bar.openPanel("controls") } }
            }
        }
    }
    Component {
        id: notifications
        Seg {
            id: notificationSeg
            glyph: "\u{F009A}"
            badge: DesktopData.unreadCount === 0 ? "transparent" : DesktopData.controls.dnd ? Colors.muted : Colors.statusUrgent
            tint: DesktopData.controls.dnd ? Colors.muted : Colors.foreground
            onClicked: { notificationPopup.dismiss(); root.bar.openPanel("notifications") }
            BarPopup {
                id: notificationPopup
                anchorItem: notificationSeg; barWindow: root.bar
                triggerHovered: notificationSeg.hovered && !DesktopData.notificationsOpen
                cardWidth: Shared.DesktopStyle.px(420)
                onOpenedChanged: if (opened) DesktopData.readNotifications()
                Timer { interval: 5000; repeat: true; running: notificationPopup.opened; onTriggered: DesktopData.readNotifications() }
                NotificationCard { Layout.fillWidth: true; onDetailsRequested: root.bar.openPanel("notifications") }
            }
        }
    }
    Component {
        id: volume
        Seg {
            id: volSeg
            readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
            glyph: audio && audio.muted ? "\u{F0581}" : "\u{F057E}"
            label: audio ? Math.round(audio.volume * 100) + "%" : "--"
            onClicked: audioPopup.togglePinned()
            onRightClicked: if (audio) audio.muted = !audio.muted
            PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
            BarPopup {
                id: audioPopup
                anchorItem: volSeg; barWindow: root.bar
                triggerHovered: volSeg.hovered
                AudioCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "audio"; root.bar.openPanel("controls") } }
            }
        }
    }
    Component {
        id: clock
        Seg {
            id: clockSeg
            label: Qt.formatDateTime(systemClock.date, "ddd d · HH:mm")
            onClicked: calendarPopup.togglePinned()
            SystemClock { id: systemClock; precision: SystemClock.Minutes }
            BarPopup {
                id: calendarPopup
                anchorItem: clockSeg
                barWindow: root.bar
                triggerHovered: clockSeg.hovered
                cardWidth: Shared.DesktopStyle.px(396)
                onOpenedChanged: if (opened) calendarBody.reset()
                CalendarCard { id: calendarBody; Layout.fillWidth: true; cal: root.bar.cal; onAccountsRequested: { PopupState.close(); root.bar.openPanel("calendars") } }
            }
        }
    }
    Component {
        id: controls
        Seg {
            id: controlsSeg
            glyph: "\u{F1DE}"
            toolTip: "Control Center · " + (DesktopData.controls.mode || "normal") + " · Meta+Ctrl+C"
            tint: (DesktopData.controls.mode || "normal") === "normal" ? Colors.foreground : Colors.accent
            onClicked: controlCenter.togglePinned()
            readonly property bool primary: root.bar.screen === Shared.Screens.main
            onPrimaryChanged: ControlCenterState.chips += primary ? 1 : -1
            Component.onCompleted: if (primary) ControlCenterState.chips += 1
            Component.onDestruction: if (primary) ControlCenterState.chips -= 1
            Connections {
                target: ControlCenterState
                function onToggleRequested() { if (controlsSeg.primary) controlCenter.togglePinned() }
            }
            BarPopup {
                id: controlCenter
                anchorItem: controlsSeg; barWindow: root.bar
                cardWidth: Shared.DesktopStyle.px(420)
                onOpenedChanged: if (opened) DesktopData.refresh()
                ControlCenterCard {
                    Layout.fillWidth: true
                    onSettingsRequested: page => { controlCenter.dismiss(); if (page) DesktopData.controlTab = page; root.bar.openPanel("controls") }
                }
            }
        }
    }
}
