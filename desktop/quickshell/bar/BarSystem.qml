pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

RowLayout {
    id: root
    required property var barWindow
    implicitHeight: PanelStyle.barHeight
    spacing: Shared.DesktopStyle.px(2)
    Layout.fillHeight: true

    StatusChip {
        id: doctorSeg
        glyph: "\u{F1663}"
        badge: DoctorData.report.level === "fail" ? Colors.statusUrgent
            : DoctorData.issues.length ? Colors.statusWarning : "transparent"
        Accessible.name: "Doctor · " + DoctorData.label
        onClicked: doctorPopup.togglePinned()

        BarPopup {
            id: doctorPopup
            anchorItem: doctorSeg; barWindow: root.barWindow; above: true
            triggerHovered: doctorSeg.hovered
            cardWidth: Shared.DesktopStyle.px(500)
            DoctorCard {
                Layout.fillWidth: true
                maxHeight: (root.barWindow.screen ? root.barWindow.screen.height : Shared.DesktopStyle.px(1080)) * 0.6
                onRepairRequested: doctorPopup.dismiss()
            }
        }
    }

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
            UpdatesCard {
                Layout.fillWidth: true
                maxHeight: (root.barWindow.screen ? root.barWindow.screen.height : Shared.DesktopStyle.px(1080)) * 0.6
                onUpdateRequested: {
                    updatesPopup.dismiss()
                    updatesSeg.updates.launch()
                }
            }
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: Shared.DesktopStyle.px(6); Layout.rightMargin: Shared.DesktopStyle.px(6)
        implicitWidth: 1; implicitHeight: Shared.DesktopStyle.px(12); color: Colors.dim
    }
}
