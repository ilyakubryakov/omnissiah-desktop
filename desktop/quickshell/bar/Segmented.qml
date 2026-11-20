pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// A macOS segmented control: page tabs, or one choice out of a few options.
// model: [{id, title}]; `current` is the selected id.
Rectangle {
    id: root
    property var model: []
    property string current: ""
    signal chosen(string id)
    implicitWidth: segments.implicitWidth + Shared.DesktopStyle.px(6)
    implicitHeight: Shared.DesktopStyle.controlHeight
    radius: Shared.DesktopStyle.radiusControl
    color: Colors.lightBackground
    border.width: 1; border.color: Colors.selection
    opacity: enabled ? 1 : 0.45
    RowLayout {
        id: segments
        anchors.centerIn: parent
        spacing: Shared.DesktopStyle.px(2)
        Repeater {
            model: root.model
            Rectangle {
                id: segment
                required property var modelData
                readonly property bool active: root.current === modelData.id
                implicitWidth: label.implicitWidth + Shared.DesktopStyle.px(28)
                implicitHeight: root.height - Shared.DesktopStyle.px(6)
                radius: Math.max(0, root.radius - Shared.DesktopStyle.px(3))
                color: active ? Colors.selection : mouse.containsMouse ? Qt.alpha(Colors.selection, 0.5) : "transparent"
                border.width: activeFocus ? Shared.DesktopStyle.focusWidth : 0; border.color: Colors.accent
                Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
                activeFocusOnTab: true
                Accessible.role: Accessible.PageTab; Accessible.name: modelData.title
                Accessible.onPressAction: root.chosen(modelData.id)
                Keys.onReturnPressed: root.chosen(modelData.id)
                Keys.onSpacePressed: root.chosen(modelData.id)
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: segment.modelData.title
                    color: segment.active ? Colors.bright : Colors.foreground
                    font.family: Colors.textFont; font.pixelSize: Shared.DesktopStyle.buttonFontSize
                    font.weight: segment.active ? Font.DemiBold : Font.Normal
                }
                MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen(segment.modelData.id) }
            }
        }
    }
}
