pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 12
    property string query: ""
    readonly property var rows: DesktopData.clips.filter(c => c.text.toLowerCase().includes(query.toLowerCase()))
    TextField {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search text and screenshots…"
        color: Colors.foreground; placeholderTextColor: Colors.muted
        font.family: Colors.textFont; font.pixelSize: 16
        padding: 12
        background: Rectangle { color: Colors.lightBackground; border.width: 1; border.color: search.activeFocus ? Colors.accent : Colors.selection }
        onTextChanged: root.query = text
        onAccepted: if (root.rows.length && !DesktopData.busy) DesktopData.act("copy", [root.rows[0].id])
        Component.onCompleted: Qt.callLater(() => search.forceActiveFocus())
    }
    UiLabel { text: "Enter copies the first match. Paste with Ctrl+V. Recent images have previews."; color: Colors.muted; font.pixelSize: 12; Layout.fillWidth: true }
    UiLabel { visible: root.rows.length === 0; text: "No matching entries"; color: Colors.muted }
    Repeater {
        model: root.rows
        Rectangle {
            id: entry
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + 24
            color: Colors.lightBackground
            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10
                Image {
                    Layout.fillWidth: true; Layout.preferredHeight: visible ? 160 : 0
                    visible: entry.modelData.image !== ""
                    source: entry.modelData.image
                    sourceSize.width: 580; sourceSize.height: 160
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; cache: false
                }
                UiLabel {
                    Layout.fillWidth: true
                    text: entry.modelData.text
                    maximumLineCount: 5; elide: Text.ElideRight
                    font.family: entry.modelData.image ? Colors.textFont : "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
                RowLayout {
                    UiButton { text: "Copy"; enabled: !DesktopData.busy; onClicked: DesktopData.act("copy", [entry.modelData.id]) }
                    UiButton { text: "Delete"; danger: true; enabled: !DesktopData.busy; onClicked: DesktopData.act("delete", [entry.modelData.id]) }
                }
            }
        }
    }
}
