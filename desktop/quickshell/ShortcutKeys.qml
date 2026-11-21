pragma ComponentBehavior: Bound
import QtQuick
import "bar" as Bar
import "ShortcutLogic.js" as Logic

Item {
    id: caps
    property string keys
    property bool copied: false
    signal copyRequested()
    property bool command: false
    implicitHeight: chips.implicitHeight
    Flow {
        id: chips; width: parent.width; spacing: 4
        Repeater {
            model: caps.command ? [caps.keys] : Logic.keycaps(caps.keys)
            Rectangle {
                id: key
                required property string modelData
                width: Math.min(label.implicitWidth + 16, chips.width)
                height: label.height + 10; radius: 6
                color: copyArea.containsMouse ? Bar.Colors.selection : Bar.Colors.background
                border.width: 1; border.color: Bar.Colors.selection
                Text {
                    id: label; anchors.centerIn: parent
                    width: Math.min(implicitWidth, chips.width - 16)
                    text: key.modelData; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                    color: caps.copied ? Bar.Colors.accent : Bar.Colors.foreground
                    font.family: Bar.Colors.textFont; font.pixelSize: 12; font.weight: Font.Medium
                }
            }
        }
    }
    MouseArea { id: copyArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: caps.copyRequested() }
}
