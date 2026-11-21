import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    id: root
    property string text: ""
    property string glyph: ""
    property color tone: Colors.accent
    property bool selected: false
    signal clicked()
    implicitHeight: Shared.DesktopStyle.px(34)
    radius: Shared.DesktopStyle.radiusSmall
    color: selected ? Colors.selection : mouse.containsMouse || activeFocus ? Qt.alpha(Colors.selection, 0.5) : "transparent"
    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    RowLayout {
        anchors { fill: parent; leftMargin: Shared.DesktopStyle.px(6); rightMargin: Shared.DesktopStyle.px(8) }
        spacing: Shared.DesktopStyle.px(10)
        Rectangle {
            implicitWidth: Shared.DesktopStyle.px(24); implicitHeight: implicitWidth
            radius: Shared.DesktopStyle.px(6)
            color: root.tone
            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: Colors.background
                font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(13)
            }
        }
        UiLabel {
            Layout.fillWidth: true
            text: root.text; elide: Text.ElideRight; wrapMode: Text.NoWrap
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
