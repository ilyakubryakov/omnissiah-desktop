pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

// Right-click on the empty desktop opens a menu of desktop actions. A transparent
// Bottom-layer surface over the wallpaper catches the click; windows and panels stay
// above it. Escape, a pick or a click anywhere else closes the menu.
Scope {
    id: root
    required property var screens
    signal openPanel(string page)
    property var menuScreen: null
    property point at: Qt.point(0, 0)
    readonly property bool opened: menuScreen !== null
    function close() { menuScreen = null }
    function run(action) { close(); action() }
    function exec(command) { Quickshell.execDetached(command) }
    readonly property string scripts: Quickshell.env("ONINIX_SHARE") + "/hypr/scripts/"

    Variants {
        model: root.screens
        PanelWindow {
            id: surface
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "oninix-desktop"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: m => { root.at = Qt.point(m.x, m.y); root.menuScreen = surface.modelData }
            }
        }
    }

    Shared.ClickCatcher { active: root.opened; onClicked: root.close() }

    LazyLoader {
        active: root.opened
        PanelWindow {
            id: menu
            screen: root.menuScreen
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "oninix-desktop-menu"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            readonly property string role: Shared.Screens.main && root.menuScreen && root.menuScreen.name === Shared.Screens.main.name ? "primary" : "secondary"
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.close()
            }
            Rectangle {
                id: card
                readonly property int edgeGap: Shared.DesktopStyle.px(8)
                width: Shared.DesktopStyle.px(260)
                height: column.implicitHeight + Shared.DesktopStyle.px(16)
                // Opens at the pointer, flipped inward near the screen edges.
                x: root.at.x + width + edgeGap > menu.width ? Math.max(edgeGap, root.at.x - width) : root.at.x
                y: root.at.y + height + edgeGap > menu.height ? Math.max(edgeGap, root.at.y - height) : root.at.y
                color: Colors.background
                border.width: 1
                border.color: Colors.lightBackground
                focus: true
                Keys.onEscapePressed: root.close()
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
                ColumnLayout {
                    id: column
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Shared.DesktopStyle.px(8) }
                    spacing: 2

                    DropdownRow { header: true; label: "Desktop" }
                    DropdownRow { glyph: "\u{F02E9}"; label: "Change wallpaper…"; onClicked: root.run(() => DesktopData.showWallpapers("shared")) }
                    DropdownRow { glyph: "\u{F03D8}"; label: "Themes & appearance"; onClicked: root.run(() => root.openPanel("appearance")) }
                    DropdownRow {
                        glyph: "\u{F056E}"; label: "Edit panels"
                        onClicked: {
                            const role = menu.role
                            root.run(() => { ShellPrefs.editRole = role; ShellPrefs.editingPanels = true; root.openPanel("panels") })
                        }
                    }
                    DropdownRow { glyph: "\u{F0379}"; label: "Display settings"; onClicked: root.run(() => root.openPanel("displays")) }

                    DropdownRow { header: true; label: "Launch" }
                    DropdownRow { glyph: "\u{F003B}"; label: "Applications"; detail: "Win+D"; onClicked: root.run(() => root.openPanel("launchpad")) }
                    DropdownRow { glyph: "\u{F018D}"; label: "Terminal"; detail: "Win+Enter"; onClicked: root.run(() => root.exec(["kitty"])) }
                    DropdownRow { glyph: "\u{F024B}"; label: "Files"; detail: "Win+E"; onClicked: root.run(() => root.exec(["dolphin"])) }

                    DropdownRow { header: true; label: "Station" }
                    DropdownRow { glyph: "\u{F1DE}"; label: "Control Station"; detail: "Win+Ctrl+C"; onClicked: root.run(() => root.openPanel("controls")) }
                    DropdownRow { glyph: "\u{F05F6}"; label: "Station Doctor"; onClicked: root.run(() => root.exec(["kitty", "--hold", "oninix-doctor", "--cache"])) }
                    // A short pause lets the menu vanish before the capture starts.
                    DropdownRow { glyph: "\u{F0100}"; label: "Capture"; onClicked: root.run(() => root.exec(["sh", "-c", "sleep 0.3; exec \"$0\"", root.scripts + "shot.sh"])) }
                    DropdownRow { glyph: "\u{F033E}"; label: "Lock"; detail: "Win+L"; onClicked: root.run(() => root.exec(["loginctl", "lock-session"])) }
                }
            }
        }
    }
}
