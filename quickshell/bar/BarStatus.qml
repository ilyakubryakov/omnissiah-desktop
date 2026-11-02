import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../shared" as Shared
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

BarGroup {
    required property var bar
    property real budget: 600

        id: statusGroup
        group: "status"
        RowLayout {
        height: parent.height
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
                id: tray
                required property var modelData
                visible: trayState.shown

                readonly property int iconSize: Math.round((Colors.fontSize + 2) * 0.8)
                implicitWidth: Colors.fontSize + 4
                implicitHeight: bar.implicitHeight

                readonly property string glyph: {
                    const k = ((tray.modelData.id || "") + " " + (tray.modelData.title || "") + " "
                               + (tray.modelData.tooltipTitle || "")).toLowerCase()
                    const ic = ("" + (tray.modelData.icon || "")).toLowerCase()
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
                    visible: tray.glyph !== ""
                    anchors.centerIn: parent
                    text: tray.glyph
                    color: trayMenu.open && trayMenu.item === tray.modelData ? Colors.bright : Colors.foreground
                    font.family: Colors.iconFont
                    font.pixelSize: Colors.fontSize + 2
                }
                Image {
                    visible: tray.glyph === ""
                    anchors.centerIn: parent
                    width: tray.iconSize
                    height: tray.iconSize
                    source: {
                        const ic = "" + (tray.modelData.icon || "")
                        if (ic === "") return ""
                        if (ic.indexOf("/") < 0 && ic.indexOf(":") < 0)
                            return (Quickshell.iconPath(ic, true) || Quickshell.iconPath("application-x-executable"))
                        return ic
                    }
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: trayMenu.open && trayMenu.item === tray.modelData ? Colors.bright : Colors.foreground
                    }
                }
                BarToolTip {
                    target: tray
                    shown: hover.containsMouse && !trayMenu.open
                    text: tray.modelData.tooltipTitle || tray.modelData.title || ""
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: m => {
                        const item = tray.modelData
                        if (m.button === Qt.MiddleButton) item.secondaryActivate()
                        else if (m.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) trayMenu.show(item, tray)
                        } else item.activate()
                    }
                    onWheel: w => tray.modelData.scroll(Math.round(w.angleDelta.y / 120), false)
                }
            }
        }

        Seg {
            id: networkSeg
            readonly property var links: (DesktopData.controls.connections || []).filter(c => c.active === "yes")
            readonly property bool wired: links.some(c => c.type === "802-3-ethernet")
            readonly property bool wireless: links.some(c => c.type === "802-11-wireless")
            glyph: wired ? "\u{F0200}" : wireless ? "\u{F05A9}" : "\u{F05AA}"
            label: wired || wireless ? "" : Quickshell.env("STATION_LAPTOP") === "1" ? "No Wi-Fi" : "Offline"
            tint: DesktopData.activeVpns.length ? Colors.accent : Colors.foreground
            onClicked: networkPopup.togglePinned()
        }
        Seg {
            id: batterySeg
            readonly property var battery: (DesktopData.controls.laptop || {}).battery
            visible: Quickshell.env("STATION_LAPTOP") === "1"
            glyph: battery && battery.status === "Charging" ? "\u{F0084}" : "\u{F0079}"
            label: battery ? battery.percent + "%" : "--"
            tint: battery && battery.percent <= 15 && battery.status === "Discharging" ? Colors.red : Colors.foreground
            onClicked: powerPopup.togglePinned()
        }

        Seg {
            visible: statusGroup.recording
            glyph: "\u{F044A}"
            tint: Colors.red
            onClicked: Hypr.exec(statusGroup.scripts + "screenrecord.sh")
        }
        Seg {
            readonly property var vdi: DesktopData.controls.vdi
            visible: statusGroup.awake
            glyph: "\u{F0176}"
            toolTip: "Keep awake" + (vdi ? " · " + vdi.sessions + " VDI session" + (vdi.sessions === 1 ? "" : "s")
                + " pinged " + Qt.formatTime(new Date(vdi.at * 1000), "HH:mm") : "")
            tint: Colors.accent
            onClicked: Hypr.exec(statusGroup.scripts + "keep-awake.sh")
        }

        Seg {
            id: captureSeg
            readonly property var cap: DesktopData.controls.capture || ({ mode: "region", key: "SUPER+SHIFT+S" })
            glyph: cap.mode === "video" ? "\u{F0567}" : cap.mode === "screen" ? "\u{F0E51}" : "\u{F0100}"
            tint: captureMenu.open ? Colors.accent : Colors.foreground
            toolTip: captureMenu.open ? "" : "Capture · " + ({ region: "area or window", screen: "whole screen", video: "video" })[cap.mode]
                + " · " + captureMenu.pretty(cap.key)
            onClicked: captureMenu.open = !captureMenu.open
        }

        Seg {
            id: micSeg
            onHoveredChanged: if (hovered) audioPopup.anchorItem = micSeg
            readonly property var input: Shared.AudioState.input
            glyph: input && !input.muted ? "\u{F036C}" : "\u{F036D}"

            tint: !input ? Colors.muted : input.muted ? Colors.foreground : Colors.accent
            onClicked: { audioPopup.anchorItem = micSeg; audioPopup.togglePinned() }
            onRightClicked: if (Shared.AudioState.input) Shared.AudioState.input.muted = !Shared.AudioState.input.muted
        }

        Seg {
            id: notificationSeg
            glyph: "\u{F009A}"
            label: DesktopData.unreadCount > 0 ? String(DesktopData.unreadCount) : ""

            tint: DesktopData.controls.dnd ? Colors.muted : DesktopData.unreadCount > 0 ? Colors.accent : Colors.foreground
            onClicked: { notificationPopup.dismiss(); bar.openPanel("notifications") }
        }
        Seg {
            id: volSeg
            onHoveredChanged: if (hovered) audioPopup.anchorItem = volSeg
            readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
            glyph: audio && audio.muted ? "\u{F0581}" : "\u{F057E}"
            label: audio ? Math.round(audio.volume * 100) + "%" : "--"
            onClicked: { audioPopup.anchorItem = volSeg; audioPopup.togglePinned() }
            onRightClicked: if (audio) audio.muted = !audio.muted
        }

        Seg {
            id: clockSeg
            label: Qt.formatDateTime(clock.date, "ddd d · HH:mm")
            onClicked: calendarPopup.togglePinned()
            BarPopup {
                id: calendarPopup
                anchorItem: clockSeg
                barWindow: bar
                triggerHovered: clockSeg.hovered
                cardWidth: 396
                onOpenedChanged: if (opened) calendarBody.reset()
                CalendarCard { id: calendarBody; Layout.fillWidth: true; cal: bar.cal; onAccountsRequested: { PopupState.close(); bar.openPanel("calendars") } }
            }
        }
        Seg {
            glyph: "\u{F1DE}"
            toolTip: "Control Station · " + (DesktopData.controls.mode || "normal") + " · Meta+Ctrl+C"
            tint: (DesktopData.controls.mode || "normal") === "normal" ? Colors.foreground : Colors.accent
            onClicked: bar.openPanel("controls")
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    BarPopup {
        id: notificationPopup
        anchorItem: notificationSeg; barWindow: bar
        triggerHovered: notificationSeg.hovered && !DesktopData.notificationsOpen
        cardWidth: 420
        onOpenedChanged: if (opened) DesktopData.readNotifications()
        Timer { interval: 5000; repeat: true; running: notificationPopup.opened; onTriggered: DesktopData.readNotifications() }
        NotificationCard { Layout.fillWidth: true; onDetailsRequested: bar.openPanel("notifications") }
    }
    BarPopup {
        id: audioPopup
        anchorItem: volSeg; barWindow: bar
        triggerHovered: volSeg.hovered || micSeg.hovered
        AudioCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "audio"; bar.openPanel("controls") } }
    }
    BarPopup {
        id: networkPopup
        anchorItem: networkSeg; barWindow: bar
        triggerHovered: networkSeg.hovered
        onOpenedChanged: if (opened) DesktopData.refresh()
        NetworkCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "network"; bar.openPanel("controls") } }
    }
    BarPopup {
        id: powerPopup
        anchorItem: batterySeg; barWindow: bar
        triggerHovered: batterySeg.hovered
        onOpenedChanged: if (opened) DesktopData.refresh()
        PowerCard { Layout.fillWidth: true; onDetailsRequested: { DesktopData.controlTab = "power"; bar.openPanel("controls") } }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Dropdown {
        id: captureMenu
        anchorItem: captureSeg
        barWindow: bar
        cardWidth: 300
        readonly property var cap: captureSeg.cap
        function pretty(combo) {
            const names = { SUPER: "Win", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" }
            return (combo || "").split("+").map(k => names[k] || k).join("+")
        }
        function pick(key, value) { DesktopData.act("capture-set", [key, value]) }
        function flip(key) { pick(key, cap[key] === "yes" ? "no" : "yes") }

        function now(args) {
            open = false
            Hypr.exec("sh -c 'sleep 0.3; exec " + statusGroup.scripts + "shot.sh " + args + "'")
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
            glyph: statusGroup.recording ? "\u{F044A}" : "\u{F0100}"
            label: statusGroup.recording ? "Stop recording" : "Capture"
            onClicked: captureMenu.now("")
        }
        DropdownRow {
            visible: !statusGroup.recording && captureMenu.cap.mode !== "video"
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
            onClicked: { captureMenu.open = false; DesktopData.controlTab = "session"; bar.openPanel("controls") }
        }
    }

    TrayMenu {
        id: trayMenu
        barWindow: bar
        anchorItem: bar.contentItem
    }

    property bool recording: false
    property bool awake: false
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { if (!states.running) states.running = true }
    }
    Process {
        id: states
        command: ["sh", "-c", "pgrep -f '(^|/)wf-recorder( |$)' >/dev/null && echo rec; systemctl --user is-active --quiet station-keep-awake.service && echo awake"]
        stdout: StdioCollector {
            onStreamFinished: {
                statusGroup.recording = text.indexOf("rec") >= 0
                statusGroup.awake = text.indexOf("awake") >= 0
            }
        }
    }
}
