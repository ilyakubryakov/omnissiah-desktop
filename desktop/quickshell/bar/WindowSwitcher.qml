pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../shared" as Shared
import "SwitcherLogic.js" as Logic

PanelWindow {
    id: root
    property bool opened: false
    property var windows: []
    property int selected: 0
    property string requestToken: ""
    property var releasedTokens: []
    screen: Shared.Screens.main
    visible: opened && Shared.Screens.main !== null
    readonly property var grid: Logic.layout(windows.length, screen ? screen.width : 1280,
        screen ? screen.height : 800, n => Shared.DesktopStyle.px(n))
    implicitWidth: grid.width
    implicitHeight: grid.height
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "oninix-switcher"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    function newer(token, than) { return Logic.newer(token, than); }
    property string lastToken: ""
    function cycle(direction, token) {
        if (token && !opened && lastToken && !newer(token, lastToken))
            return;
        if (token && newer(token, lastToken))
            lastToken = token;
        if (token && (!opened || newer(token, requestToken)))
            requestToken = token;
        if (!opened) {
            windows = Hypr.clients.filter(c => c.mapped !== false && /^0x[0-9a-f]+$/i.test(c.address)).slice().sort((a, b) => a.focusHistoryID - b.focusHistoryID);
            if (!windows.length)
                return;
            selected = direction > 0 ? Math.min(1, windows.length - 1) : windows.length - 1;
            opened = true;
            body.forceActiveFocus();
        } else
            selected = (selected + direction + windows.length) % windows.length;
        Qt.callLater(() => cards.positionViewAtIndex(root.selected, GridView.Contain));
        if (releasedTokens.includes(requestToken)) {
            const token = requestToken;
            Qt.callLater(() => root.accept(token));
        }
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
        clip: true
        radius: Shared.DesktopStyle.px(16)
        color: Colors.background
        border.color: Colors.accent
        border.width: 1
        focus: true
        Keys.onEscapePressed: root.opened = false
        Keys.onReturnPressed: root.accept()
        Keys.onTabPressed: root.cycle(1)
        Keys.onBacktabPressed: root.cycle(-1)
        Keys.onLeftPressed: root.cycle(-1)
        Keys.onRightPressed: root.cycle(1)
        Keys.onUpPressed: root.cycle(-root.grid.columns)
        Keys.onDownPressed: root.cycle(root.grid.columns)
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt)
                root.accept();
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.grid.padding
            spacing: Shared.DesktopStyle.px(12)
            UiLabel {
                Layout.fillWidth: true
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: "APPLICATIONS · ALL WORKSPACES"
                color: Colors.muted
                font.letterSpacing: Shared.DesktopStyle.px(2)
                font.pixelSize: Shared.DesktopStyle.px(12)
            }
            GridView {
                id: cards
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: root.grid.cellWidth
                cellHeight: root.grid.cellHeight
                currentIndex: root.selected
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                clip: true
                model: root.windows
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    width: Math.max(1, cards.cellWidth - Shared.DesktopStyle.px(10))
                    height: Math.max(1, cards.cellHeight - Shared.DesktopStyle.px(10))
                    clip: true
                    radius: Shared.DesktopStyle.px(10)
                    color: index === root.selected ? Colors.selection : Colors.lightBackground
                    border.width: 1
                    border.color: index === root.selected ? Colors.accent : Colors.selection
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Shared.DesktopStyle.px(12)
                        ApplicationIcon {
                            Layout.alignment: Qt.AlignHCenter
                            appClass: card.modelData.class
                            iconSize: Shared.DesktopStyle.px(34)
                            glyphColor: Colors.accent
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            text: Hypr.title(card.modelData) || card.modelData.class
                            maximumLineCount: 2
                            Layout.preferredHeight: Shared.DesktopStyle.px(36)
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        UiLabel {
                            Layout.fillWidth: true
                            text: (AppIcons.windowEntry(card.modelData.class) || {}).name || card.modelData.class
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            color: Colors.muted
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Shared.DesktopStyle.px(11)
                        }
                        UiLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text: Minimized.isMinimized(card.modelData) ? "Minimized" : "Workspace " + card.modelData.workspace.name
                            color: Colors.muted
                            font.pixelSize: Shared.DesktopStyle.px(11)
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
                Layout.fillWidth: true
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                text: "Alt+Tab · next    Arrows · navigate    Release Alt · switch    Esc · cancel"
                color: Colors.muted
                font.pixelSize: Shared.DesktopStyle.px(11)
            }
        }
    }
}
