import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    id: row

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool current: false
    property bool header: false
    signal clicked()

    Layout.fillWidth: true
    Layout.topMargin: header ? Shared.DesktopStyle.px(6) : 0
    implicitHeight: Shared.DesktopStyle.px(header ? 20 : 26)
    color: !header && hover.containsMouse ? Colors.selection : "transparent"

    RowLayout {
        anchors { fill: parent; leftMargin: Shared.DesktopStyle.px(6); rightMargin: Shared.DesktopStyle.px(6) }
        spacing: Shared.DesktopStyle.spaceUnit * 2

        Text {
            visible: !row.header
            Layout.preferredWidth: Shared.DesktopStyle.px(16)
            text: row.glyph
            color: row.current ? Colors.accent : Colors.muted
            font.family: Colors.iconFont
            font.pixelSize: Colors.fontSize + Shared.DesktopStyle.px(2)
        }
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.label
            color: row.header ? Colors.dim : (row.current ? Colors.bright : Colors.foreground)
            font.family: Colors.textFont
            font.pixelSize: row.header ? Colors.fontSize - Shared.DesktopStyle.px(1) : Colors.fontSize
            font.capitalization: row.header ? Font.AllUppercase : Font.MixedCase
        }
        Text {
            visible: row.detail !== ""
            Layout.maximumWidth: row.width * 0.55
            elide: Text.ElideRight
            text: row.detail
            color: Colors.dim
            font.family: Colors.iconFont
            font.pixelSize: Colors.fontSize - Shared.DesktopStyle.px(1)
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: !row.header
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
