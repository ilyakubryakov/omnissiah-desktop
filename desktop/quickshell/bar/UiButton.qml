import "../shared" as Shared
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string text: ""
    property string glyph: ""
    property bool selected: false
    property bool subtle: false
    property bool alignLeft: false
    property bool danger: false
    signal clicked()
    readonly property real naturalContentWidth: Math.ceil(labelMeasure.advanceWidth) + (glyph ? icon.implicitWidth + (text ? Shared.DesktopStyle.spaceUnit * 2 : 0) : 0)
    implicitWidth: naturalContentWidth + 2 * Shared.DesktopStyle.controlPadding
    implicitHeight: Shared.DesktopStyle.controlHeight
    radius: Shared.DesktopStyle.radiusControl
    color: selected || mouse.containsMouse || activeFocus ? Colors.selection : subtle ? "transparent" : Colors.lightBackground
    border.width: activeFocus || selected ? Shared.DesktopStyle.focusWidth : 0
    border.color: danger ? Colors.red : Colors.accent
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    TextMetrics { id: labelMeasure; text: root.text; font: label.font }
    RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        x: root.alignLeft ? Shared.DesktopStyle.controlPadding : (parent.width - width) / 2
        width: Math.min(root.naturalContentWidth, Math.max(0, parent.width - 2 * Shared.DesktopStyle.controlPadding))
        spacing: Shared.DesktopStyle.spaceUnit * 2
        Text {
            id: icon
            visible: root.glyph !== ""
            text: root.glyph
            color: root.danger ? Colors.red : root.selected ? Colors.accent : Colors.foreground
            font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(16)
        }
        Text {
            id: label
            visible: root.text !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            textFormat: Text.PlainText
            color: root.danger ? Colors.red : Colors.foreground
            font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.buttonFontSize
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
