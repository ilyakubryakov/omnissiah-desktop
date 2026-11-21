import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property color tint: Colors.accent
    property bool checked: false
    property bool hasDetail: false
    signal clicked()
    signal detail()
    implicitHeight: 72
    implicitWidth: 210
    radius: Shared.DesktopStyle.radiusCard
    color: checked ? Qt.rgba(tint.r, tint.g, tint.b, 0.18) : Colors.lightBackground
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus ? tint : checked ? Qt.rgba(tint.r, tint.g, tint.b, 0.38) : Colors.selection
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: title + ". " + subtitle
    Accessible.onPressAction: clicked()
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    Keys.onRightPressed: if (hasDetail) detail()
    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    scale: hit.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: Shared.DesktopStyle.fast } }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: root.tint; opacity: hit.containsMouse ? 0.06 : 0 }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    RowLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 10
        Text { text: root.glyph; color: root.checked ? root.tint : Colors.foreground; font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(22) }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 3
            UiLabel { Layout.fillWidth: true; text: root.title; font.pixelSize: Shared.DesktopStyle.px(14); font.weight: Font.DemiBold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            UiLabel { Layout.fillWidth: true; text: root.subtitle; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11); maximumLineCount: 2; elide: Text.ElideRight }
        }
        UiButton { visible: root.hasDetail; text: "›"; implicitWidth: 32; onClicked: root.detail(); Accessible.name: root.title + " settings" }
    }
    BarToolTip { target: root; text: root.title + (root.subtitle ? " · " + root.subtitle : ""); shown: hit.containsMouse }
}
