pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// Updates stay visible when the adjacent media or briefing view changes.
RowLayout {
    id: root
    required property var barWindow
    implicitHeight: PanelStyle.barHeight
    spacing: 2
    Layout.fillHeight: true

    // Updates (owner decision 2026-11-08): no count, so waiting updates do not
    // pull attention; the glyph turns urgent red only when it is time to
    // update, the warning badge shows when the last check failed or a source
    // has not answered for three days. The count stays in the card.
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
