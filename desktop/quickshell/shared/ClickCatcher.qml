import QtQuick
import Quickshell
import Quickshell.Wayland

// Transparent layers on every screen while a panel is open: a click anywhere
// outside the panel closes it. HyprlandFocusGrab never cleared on outside
// clicks here (Hyprland 0.56), so the panels rely on this instead. The panels
// sit on the Overlay layer, above these.
Scope {
    id: root
    property bool active: false
    property int topInset: 0
    property int bottomInset: 0
    signal clicked()

    Variants {
        model: root.active ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            margins { top: root.topInset; bottom: root.bottomInset }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "oninix-click-catcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.clicked()
            }
        }
    }
}
