pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../shared" as Shared

PanelWindow {
    id: root
    property bool opened: false
    property var windows: []
    property int selected: 0
    property string requestToken: ""
    property var releasedTokens: []
    screen: Shared.Screens.main
    visible: opened && Shared.Screens.main !== null
    implicitWidth: Math.min(960, screen ? screen.width - 80 : 800)
    implicitHeight: 240
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "station-switcher"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    function cycle(direction, token) {
        requestToken = token || requestToken;
        if (!opened) {
            windows = Hypr.clients.filter(c => c.mapped !== false && /^0x[0-9a-f]+$/i.test(c.address)).slice().sort((a, b) => a.focusHistoryID - b.focusHistoryID);
            if (!windows.length)
                return;
            selected = direction > 0 ? Math.min(1, windows.length - 1) : windows.length - 1;
            opened = true;
            body.forceActiveFocus();
        } else
            selected = (selected + direction + windows.length) % windows.length;
        cards.positionViewAtIndex(selected, ListView.Contain);
        if (releasedTokens.includes(requestToken))
            Qt.callLater(() => root.accept(root.requestToken));
    }
    function accept(token) {
        token = token || requestToken;
        releasedTokens = releasedTokens.filter(t => t !== token).slice(-15).concat([token]);
        if (token !== requestToken)
            return;
        if (!opened)
            return;
        const client = windows[selected];
        opened = false;
        if (client && Hypr.clients.some(c => c.address === client.address))
            Qt.callLater(() => Minimized.show(client));
    }
    IpcHandler {
        target: "switcher"
        function next(token: string): void {
            root.cycle(1, token);
        }
        function previous(token: string): void {
            root.cycle(-1, token);
        }
        function accept(token: string): void {
            root.accept(token);
        }
    }
    Rectangle {
        id: body
        anchors.fill: parent
        radius: 16
        color: Colors.background
        border.color: Colors.accent
        border.width: 1
        focus: true
        Keys.onEscapePressed: root.opened = false
        Keys.onReturnPressed: root.accept()
        Keys.onTabPressed: root.cycle(1)
        Keys.onBacktabPressed: root.cycle(-1)
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt)
                root.accept();
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12
            UiLabel {
                text: "APPLICATIONS · ALL WORKSPACES"
                color: Colors.muted
                font.letterSpacing: 2
                font.pixelSize: 12
            }
            ListView {
                id: cards
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                model: root.windows
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    width: 168
                    height: cards.height
                    radius: 10
                    color: index === root.selected ? Colors.selection : Colors.lightBackground
                    border.width: 1
                    border.color: index === root.selected ? Colors.accent : Colors.selection
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Hypr.icon(card.modelData.class)
                            font.family: Colors.iconFont
                            font.pixelSize: 34
                            color: Colors.accent
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            text: card.modelData.title || card.modelData.class
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            text: card.modelData.class
                            elide: Text.ElideRight
                            color: Colors.muted
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11
                        }
                        UiLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text: Minimized.isMinimized(card.modelData) ? "Minimized" : "Workspace " + card.modelData.workspace.name
                            color: Colors.muted
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selected = card.index;
                            root.accept();
                        }
                    }
                }
            }
            UiLabel {
                text: "Alt+Tab · next    Shift · previous    Release Alt · switch    Esc · cancel"
                color: Colors.muted
                font.pixelSize: 11
            }
        }
    }
}
