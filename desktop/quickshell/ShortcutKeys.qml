pragma ComponentBehavior: Bound
import QtQuick
import "bar" as Bar
import "ShortcutLogic.js" as Logic
import "shared" as Shared

Item {
    id: caps
    property string keys
    property bool copied: false
    signal copyRequested()
    property bool command: false
    implicitHeight: chips.implicitHeight
    Flow {
        id: chips; width: parent.width; spacing: Shared.DesktopStyle.spaceUnit
        Repeater {
            model: caps.command ? [caps.keys] : Logic.keycaps(caps.keys)
            Rectangle {
                id: key
                required property string modelData
                width: Math.min(label.implicitWidth + Shared.DesktopStyle.px(16), chips.width)
                height: label.height + Shared.DesktopStyle.px(10); radius: Shared.DesktopStyle.px(6)
                color: copyArea.containsMouse ? Bar.Colors.selection : Bar.Colors.background
                border.width: 1; border.color: Bar.Colors.selection
                Text {
                    id: label; anchors.centerIn: parent
                    width: Math.min(implicitWidth, chips.width - Shared.DesktopStyle.px(16))
                    text: key.modelData; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere
                    color: caps.copied ? Bar.Colors.accent : Bar.Colors.foreground
                    font.family: Bar.Colors.textFont; font.pixelSize: Shared.DesktopStyle.metrics.caption_text_px; font.weight: Font.Medium
                }
            }
        }
    }
    MouseArea { id: copyArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: caps.copyRequested() }
}
