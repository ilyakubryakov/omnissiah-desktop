import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Item {
    id: root
    default property alias content: row.data
    property string group: "launchers"
    readonly property string panelAccentGroup: group
    readonly property string toneName: ShellLayout.toneName(group)
    readonly property color tone: ShellLayout.toneColor(toneName)
    readonly property real strength: toneName === "none" ? 0 : ShellLayout.groupStrength
    property real hoverTint: groupHover.hovered ? 0.035 : 0
    Behavior on hoverTint { NumberAnimation { duration: Shared.DesktopStyle.fast } }
    HoverHandler { id: groupHover }
    implicitWidth: row.implicitWidth + Shared.DesktopStyle.px(24)
    implicitHeight: PanelStyle.barHeight
    height: PanelStyle.barHeight
    RowLayout {
        id: row
        x: (parent.width - implicitWidth) / 2
        height: parent.height
        spacing: Shared.DesktopStyle.px(6)
    }
}
