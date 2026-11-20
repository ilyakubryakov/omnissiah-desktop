pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

RowLayout {
    id: root
    required property var barWindow
    implicitHeight: PanelStyle.barHeight
    spacing: 2
    Layout.fillHeight: true

    StatusChip {
        id: updatesSeg
        readonly property var updates: Shared.UpdatesData
        readonly property string level: updates.level
        glyph: '\u{F06B0}'
        value: level === 'stale' ? '?' : level === 'checking' ? '…' : ''
        valueColor: Colors.muted
        tint: level === 'due' ? Colors.statusUrgent : 'transparent'
        badge: level === 'error' || (updates.unreachable || []).length ? Colors.statusWarning : 'transparent'
        Accessible.name: 'System updates ' + updates.summary
        onClicked: updatesPopup.togglePinned()
        BarPopup {
            id: updatesPopup
            anchorItem: updatesSeg; barWindow: root.barWindow; above: true; cardWidth: Shared.DesktopStyle.px(500)
            triggerHovered: updatesSeg.hovered
            UpdatesCard { Layout.fillWidth: true; maxHeight: (root.barWindow.screen ? root.barWindow.screen.height : 1080) * 0.6 }
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 6; Layout.rightMargin: 6
        implicitWidth: 1; implicitHeight: 12; color: Colors.dim
    }
}
