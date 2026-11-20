pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../shared" as Shared

// Session actions. Lock and sleep act at once; shut down and restart need a
// second click within a few seconds so a stray click never ends the session.
ColumnLayout {
    id: root
    property bool active: false
    signal done()
    spacing: 14
    property string armed: ""
    property real uptime: -1
    readonly property var actions: [
        { id: "lock", title: "Lock", glyph: "\u{F033E}", tone: Colors.accent, confirm: false, command: ["loginctl", "lock-session"] },
        { id: "sleep", title: "Sleep", glyph: "\u{F0904}", tone: Colors.cyan, confirm: false, command: ["systemctl", "suspend"] },
        { id: "reboot", title: "Restart", glyph: "\u{F0709}", tone: Colors.yellow, confirm: true, command: ["systemctl", "reboot"] },
        { id: "poweroff", title: "Shut down", glyph: "\u{F0425}", tone: Colors.red, confirm: true, command: ["systemctl", "poweroff"] }
    ]
    function run(action) {
        if (action.confirm && armed !== action.id) { armed = action.id; disarm.restart(); return }
        armed = ""
        root.done()
        // Let the card close first so the lock screen and suspend start from a clean desktop.
        Qt.callLater(() => Quickshell.execDetached(action.command))
    }
    onActiveChanged: { armed = ""; if (active) uptimeFile.reload() }
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = "" }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptime = parseFloat(text())
    }
    property string host: ""
    FileView { path: "/etc/hostname"; printErrors: false; onLoaded: root.host = text().trim() }
    function uptimeText(seconds) {
        if (seconds < 0) return ""
        const m = Math.floor(seconds / 60), h = Math.floor(m / 60), d = Math.floor(h / 24)
        return "up " + (d ? d + "d " + h % 24 + "h" : h ? h + "h " + m % 60 + "m" : m + "m")
    }

    RowLayout {
        Layout.fillWidth: true; spacing: 12
        Image {
            Layout.preferredWidth: 40; Layout.preferredHeight: 40
            source: "file://" + Quickshell.env("HOME") + "/.config/fastfetch/mechanicus.png"
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            Accessible.ignored: true
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            UiLabel { text: "SESSION"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: 3 }
            UiLabel {
                text: [Quickshell.env("USER") + (root.host ? "@" + root.host : ""), root.uptimeText(root.uptime)].filter(s => s).join("  ·  ")
                color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 0
        Repeater {
            id: tiles
            model: root.actions
            Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool armed: root.armed === modelData.id
                readonly property bool lit: hit.containsMouse || activeFocus || armed
                readonly property color tone: modelData.tone
                Layout.fillWidth: true
                implicitHeight: 96
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                Accessible.onPressAction: root.run(modelData)
                Keys.onReturnPressed: root.run(modelData)
                Keys.onSpacePressed: root.run(modelData)
                Keys.onLeftPressed: tiles.itemAt((index + 3) % 4).forceActiveFocus()
                Keys.onRightPressed: tiles.itemAt((index + 1) % 4).forceActiveFocus()
                Rectangle {
                    id: disc
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: 58; height: 58; radius: 29
                    color: tile.armed ? tile.tone
                        : tile.lit ? Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, 0.16) : Colors.lightBackground
                    border.width: tile.activeFocus && !tile.armed ? 2 : 1
                    border.color: tile.lit ? Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, 0.55) : Colors.selection
                    scale: hit.pressed ? 0.94 : tile.lit ? 1.04 : 1
                    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                    Behavior on border.color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                    Behavior on scale { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: tile.modelData.glyph
                        font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(24)
                        color: tile.armed ? Colors.background : tile.lit ? tile.tone : Colors.foreground
                        Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                    }
                    // Countdown ring while a confirmation is pending.
                    Canvas {
                        id: ring
                        anchors.fill: parent
                        anchors.margins: -5
                        visible: tile.armed
                        property real progress: 1
                        onProgressChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.lineWidth = 2.5
                            ctx.lineCap = "round"
                            ctx.strokeStyle = tile.tone
                            ctx.beginPath()
                            ctx.arc(width / 2, height / 2, width / 2 - 2, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress)
                            ctx.stroke()
                        }
                        NumberAnimation on progress { from: 1; to: 0; duration: disarm.interval; running: tile.armed }
                    }
                }
                UiLabel {
                    anchors { horizontalCenter: parent.horizontalCenter; top: disc.bottom; topMargin: 10 }
                    text: tile.armed ? "Confirm" : tile.modelData.title
                    color: tile.armed ? tile.tone : tile.lit ? Colors.foreground : Colors.muted
                    font.pixelSize: Shared.DesktopStyle.px(12); font.weight: tile.lit ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                }
                MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.run(tile.modelData) }
            }
        }
    }
    UiLabel {
        Layout.fillWidth: true
        text: root.armed ? "Click again to " + (root.armed === "poweroff" ? "shut down" : "restart") + "  ·  Esc cancels"
            : "Restart and shut down ask to confirm"
        color: Colors.dim; font.pixelSize: Shared.DesktopStyle.px(11)
        horizontalAlignment: Text.AlignHCenter
    }
}
