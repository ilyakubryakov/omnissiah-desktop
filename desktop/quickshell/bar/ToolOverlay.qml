pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shared" as Shared

// A standalone tool over the desktop (Windows, Clipboard): a centered card on a
// dimmed main screen, opened by its hotkey. Escape or a click outside closes it.
// Not part of the settings window, like Mission Control on macOS.
PanelWindow {
    id: root
    property string title: ""
    property bool opened: false
    property int cardWidth: Shared.DesktopStyle.px(960)
    property int cardHeight: Shared.DesktopStyle.px(720)
    default property alias content: body.data
    function open() { PopupState.close(); opened = true }
    function close() { opened = false }
    function toggle() { opened ? close() : open() }
    screen: Shared.Screens.main
    visible: (opened || fade.running) && Shared.Screens.main !== null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-tool"
    // Opened by the owner's hotkey: take the keyboard for search and Escape.
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Rectangle {
        id: shade
        anchors.fill: parent
        color: Qt.alpha(Colors.darkBackground, 0.55)
        opacity: root.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Shared.DesktopStyle.fast } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }
    FocusScope {
        id: scope
        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width - Shared.DesktopStyle.px(80))
        height: Math.min(root.cardHeight, root.height - Shared.DesktopStyle.px(120))
        focus: root.opened
        opacity: shade.opacity
        scale: 0.97 + 0.03 * shade.opacity
        Keys.onEscapePressed: root.close()
        Rectangle {
            anchors.fill: parent
            radius: Shared.DesktopStyle.px(20)
            color: Colors.background
            border.width: 1; border.color: Colors.selection
            MouseArea { anchors.fill: parent }
        }
        ColumnLayout {
            anchors { fill: parent; margins: Shared.DesktopStyle.px(20) }
            spacing: Shared.DesktopStyle.px(12)
            RowLayout {
                Layout.fillWidth: true
                UiLabel { text: root.title; font.pixelSize: Shared.DesktopStyle.px(20); font.weight: Font.DemiBold; Layout.fillWidth: true }
                UiButton { subtle: true; glyph: ""; Accessible.name: "Close " + root.title; onClicked: root.close() }
            }
            Flickable {
                id: flick
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                contentWidth: width; contentHeight: body.implicitHeight
                ColumnLayout { id: body; width: flick.width }
            }
        }
    }
}
