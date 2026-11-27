pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

Scope {
    id: root
    required property var screens
    required property var cal
    signal openPanel(string page)
    property var menuScreen: null
    property point at: Qt.point(0, 0)
    readonly property bool opened: menuScreen !== null
    function show(screen, position) { at = position; menuScreen = screen }
    function close() { menuScreen = null }
    function run(action) { close(); action() }
    function exec(command) { Quickshell.execDetached(command) }
    readonly property string scripts: Quickshell.env("ONINIX_SHARE") + "/hypr/scripts/"
    readonly property var installer: AppIcons.apps["oninix-installer"]

    Variants {
        model: root.screens
        PanelWindow {
            id: surface
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "oninix-desktop"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {
                id: desktopMask
                readonly property bool cardScreen: surface.modelData === cards.screenTarget
                intersection: Intersection.Subtract
                Region { item: desktopMask.cardScreen && cards.editing ? desktopArea : null }
                Region {
                    readonly property rect bounds: desktopMask.cardScreen ? cards.todayRect : Qt.rect(0, 0, 0, 0)
                    x: bounds.x; y: bounds.y; width: bounds.width; height: bounds.height
                }
            }
            MouseArea {
                id: desktopArea
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: m => root.show(surface.modelData, Qt.point(m.x, m.y))
            }
            UiButton {
                visible: !!root.installer
                x: Shared.DesktopStyle.px(24)
                y: Shared.DesktopStyle.px(60)
                glyph: "\u{F0193}"
                text: root.installer ? root.installer.name : ""
                onClicked: PinnedApps.start(root.installer.id)
            }
        }
    }

    DesktopCards {
        id: cards
        screenTarget: Shared.Screens.main
        cal: root.cal
        onMenuRequested: position => root.show(cards.screenTarget, position)
    }

    Shared.ClickCatcher { active: root.opened; onClicked: root.close() }

    LazyLoader {
        active: root.opened
        PanelWindow {
            id: menu
            screen: root.menuScreen
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
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
                    spacing: Shared.DesktopStyle.px(2)

                    DropdownRow { header: true; label: "Desktop" }
                    DropdownRow { glyph: "\u{F02E9}"; label: "Change wallpaper…"; onClicked: root.run(() => root.openPanel("wallpaper")) }
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

                    DropdownRow { header: true; label: "OniNix" }
                    DropdownRow { glyph: "\u{F1DE}"; label: "Control Station"; detail: "Win+,"; onClicked: root.run(() => root.openPanel("settings")) }
                    DropdownRow { glyph: "\u{F0100}"; label: "Capture"; onClicked: root.run(() => root.exec(["sh", "-c", "sleep 0.3; exec \"$0\"", root.scripts + "shot.sh"])) }
                    DropdownRow { glyph: "\u{F033E}"; label: "Lock"; detail: "Win+L"; onClicked: root.run(() => root.exec(["loginctl", "lock-session"])) }
                }
            }
        }
    }
}
