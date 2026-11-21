import QtQuick
import "../shared" as Shared
import QtQuick.Layouts

Item {
    id: root

    property string glyph: ""
    property Component iconComponent: null
    property string toolTip: ""
    property string label: ""
    property real maximumLabelWidth: 10000
    property color tint: Colors.foreground
    property bool preserveTint: false
    property bool sep: false
    property color badge: "transparent"
    property bool framed: true
    function inheritedGroup() {
        for (let item = parent; item; item = item.parent)
            if (item.panelAccentGroup !== undefined) return item.panelAccentGroup
        return "status"
    }
    readonly property string accentGroup: inheritedGroup()
    readonly property bool accentable: !preserveTint && (tint == Colors.foreground || tint == Colors.accent)
    readonly property color buttonTint: accentable ? ShellLayout.buttonColor(accentGroup) : tint
    readonly property bool hovered: mouse.containsMouse
    signal clicked()
    signal rightClicked()
    signal middleClicked()

    implicitWidth: row.implicitWidth + (framed ? 12 : 0) + (sep ? divider.width + 16 : 0)
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 0; anchors.rightMargin: root.sep ? 8 : 0
        anchors.topMargin: 3; anchors.bottomMargin: 3
        radius: Math.min(6, height / 3)
        color: Qt.rgba(root.buttonTint.r, root.buttonTint.g, root.buttonTint.b, mouse.pressed ? 0.18 : mouse.containsMouse ? 0.10 : 0)
        Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    }
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.framed ? 6 : 0
        spacing: 5

        Loader {
            visible: root.iconComponent !== null
            sourceComponent: root.iconComponent
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            visible: root.iconComponent === null && root.glyph !== ""
            text: root.glyph
            color: root.buttonTint
            font.family: Colors.iconFont
            font.pixelSize: Math.max(16, Colors.fontSize + 2)
            Rectangle {
                visible: root.badge.a > 0
                width: Shared.DesktopStyle.px(7); height: width; radius: width / 2
                x: parent.width - Shared.DesktopStyle.px(4); y: Shared.DesktopStyle.px(1)
                color: root.badge
                border.width: Shared.DesktopStyle.px(1.5); border.color: Colors.background
            }
        }
        Text {
            visible: root.label !== ""
            Layout.maximumWidth: root.maximumLabelWidth
            elide: Text.ElideRight
            text: root.label
            color: root.tint
            font.family: Colors.textFont
            font.pixelSize: Math.max(13, Colors.fontSize)
        }
    }

    Rectangle {
        id: divider
        visible: root.sep
        width: 1
        height: 12
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 0
        color: Colors.dim
    }

    BarToolTip {
        target: root
        shown: mouse.containsMouse
        text: root.toolTip
    }
    Accessible.name: toolTip || label
    Accessible.role: Accessible.Button
    Accessible.onPressAction: clicked()

    MouseArea {
        id: mouse
        hoverEnabled: true
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : m.button === Qt.MiddleButton ? root.middleClicked() : root.clicked()
    }
}
