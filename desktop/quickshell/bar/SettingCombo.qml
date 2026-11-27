import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../shared" as Shared

ComboBox {
    id: control
    Layout.fillWidth: true
    implicitHeight: Shared.DesktopStyle.metrics.control_height
    font.family: Colors.textFont
    font.pixelSize: Shared.DesktopStyle.px(13)
    leftPadding: Shared.DesktopStyle.controlPadding
    background: Rectangle {
        radius: Shared.DesktopStyle.radiusSmall
        color: control.hovered || control.popup.visible ? Colors.selection : Colors.lightBackground
        border.width: 1
        border.color: control.activeFocus ? Colors.accent : Colors.selection
        Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    }
    palette.button: Colors.selection
    palette.buttonText: Colors.foreground
    palette.base: Colors.background
    palette.text: Colors.foreground
    palette.window: Colors.background
    palette.windowText: Colors.foreground
    palette.highlight: Colors.accent
    palette.highlightedText: Colors.background
}
