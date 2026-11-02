import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    id: root
    property string label: ""
    property var value: null
    property string suffix: "%"
    property string detail: ""
    property color tone: Colors.accent
    readonly property bool known: typeof value === "number" && isFinite(value) && value >= 0
    Layout.fillWidth: true; Layout.preferredWidth: 1
    implicitHeight: 86; radius: Shared.DesktopStyle.radiusSmall
    color: Colors.lightBackground
    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: root.label; color: Colors.muted; font.pixelSize: 12; Layout.fillWidth: true }
            UiLabel { text: root.known ? Math.round(root.value) + root.suffix : "--"; font.pixelSize: 18; color: root.known ? root.tone : Colors.muted }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 5; radius: 2.5; color: Colors.selection
            Rectangle {
                height: parent.height; radius: 2.5; color: root.tone
                width: parent.width * (root.known ? Math.max(0, Math.min(100, root.value)) / 100 : 0)
                Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
            }
        }
        UiLabel { text: root.detail || (root.known ? "" : "Unavailable"); visible: text !== ""; font.pixelSize: 10; color: Colors.muted; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
    }
}
