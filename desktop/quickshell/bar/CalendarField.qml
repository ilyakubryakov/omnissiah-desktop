import QtQuick
import QtQuick.Controls
import "../shared" as Shared

TextField {
    color: Colors.foreground
    placeholderTextColor: Colors.muted
    selectionColor: Colors.selection
    selectedTextColor: Colors.foreground
    font.family: Colors.textFont
    font.pixelSize: Shared.DesktopStyle.px(14)
    padding: 12
    selectByMouse: true
    background: Rectangle {
        radius: Shared.DesktopStyle.radiusSmall
        color: Colors.lightBackground
        border.width: 1
        border.color: parent.activeFocus ? Colors.accent : Colors.selection
    }
}
