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

    readonly property real naturalContentWidth: Math.ceil(labelMeasure.advanceWidth) + (glyph ? icon.implicitWidth + (text ? 8 : 0) : 0)
    implicitWidth: naturalContentWidth + 24
    implicitHeight: Shared.DesktopStyle.comfortable ? 40 : 36
    radius: Shared.DesktopStyle.radiusSmall
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Shared.DesktopStyle.fast; easing.type: Easing.OutCubic } }
    color: selected || mouse.containsMouse || activeFocus ? Colors.selection : subtle ? "transparent" : Colors.lightBackground
    border.width: activeFocus || selected ? 1 : 0
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
        x: root.alignLeft ? 12 : (parent.width - width) / 2
        width: root.alignLeft ? Math.max(0, parent.width - 24) : Math.min(root.naturalContentWidth, Math.max(0, parent.width - 24))
        spacing: 8
        Text {
            id: icon
            visible: root.glyph !== ""
            text: root.glyph
            color: root.danger ? Colors.red : root.selected ? Colors.accent : Colors.foreground
            font.family: Colors.iconFont; font.pixelSize: 16
        }
        Text {
            id: label
            visible: root.text !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            horizontalAlignment: root.alignLeft ? Text.AlignLeft : Text.AlignHCenter
            text: root.text
            textFormat: Text.PlainText
            color: root.danger ? Colors.red : Colors.foreground
            font.family: Colors.textFont; font.pixelSize: 14
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
