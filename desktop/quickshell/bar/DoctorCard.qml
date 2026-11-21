pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

ColumnLayout {
    id: root
    signal repairRequested()
    property real maxHeight: 600
    property bool expanded: false
    readonly property var doctor: DoctorData
    readonly property color tone: doctor.level === "fail" ? Colors.statusUrgent
        : doctor.level === "warn" || doctor.level === "stale" ? Colors.statusWarning
        : doctor.level === "ok" ? Colors.green : Colors.muted
    spacing: Shared.DesktopStyle.px(10)

    component Note: UiLabel {
        Layout.fillWidth: true
        wrapMode: Text.WrapAnywhere
        font.pixelSize: Shared.DesktopStyle.px(12)
    }
    component Detail: RowLayout {
        id: detail
        required property string label
        required property string message
        property color dot: "transparent"
        Layout.fillWidth: true
        spacing: Shared.DesktopStyle.px(8)

        Rectangle {
            visible: detail.dot.a > 0
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Shared.DesktopStyle.px(5)
            implicitWidth: Shared.DesktopStyle.px(7)
            implicitHeight: implicitWidth
            radius: width / 2
            color: detail.dot
        }
        UiLabel {
            text: detail.label
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Shared.DesktopStyle.px(76)
            font.pixelSize: Shared.DesktopStyle.px(12)
            font.weight: Font.DemiBold
        }
        Note { text: detail.message; color: Colors.muted }
    }

    CardHeader {
        glyph: "\u{F1663}"; title: "Doctor"
        note: root.doctor.known ? "Checked " + root.doctor.ago(root.doctor.clock - root.doctor.report.checked) : ""
    }
    UiLabel {
        Layout.fillWidth: true
        color: root.tone
        font.weight: Font.DemiBold
        text: root.doctor.label
    }

    Flickable {
        id: details
        visible: root.doctor.known
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.min(checks.implicitHeight, root.maxHeight) : 0
        contentWidth: width
        contentHeight: checks.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: checks
            width: Math.max(0, details.width - Shared.DesktopStyle.px(10))
            spacing: Shared.DesktopStyle.px(5)
            Repeater {
                model: root.doctor.rows
                Detail {
                    required property var modelData
                    label: modelData.check
                    message: modelData.message
                    dot: modelData.level === "fail" ? Colors.statusUrgent
                        : modelData.level === "warn" ? Colors.statusWarning : Colors.green
                }
            }
            UiLabel {
                visible: root.expanded && root.doctor.rebuild !== null
                Layout.topMargin: Shared.DesktopStyle.px(6)
                text: "Last switch"
                font.weight: Font.DemiBold
            }
            Repeater {
                model: root.expanded ? (root.doctor.rebuild?.changes || []).slice(0, 8) : []
                Note {
                    required property var modelData
                    text: modelData.name + " " + modelData.detail + " (" + modelData.kind + ")"
                    color: Colors.muted
                }
            }
            Note {
                visible: root.expanded && (root.doctor.rebuild?.count || 0) > 8
                text: "Full diff: /var/lib/oninix-maintenance/last-rebuild.txt"
                color: Colors.muted
            }
            UiLabel {
                visible: root.expanded && root.doctor.events.length > 0
                Layout.topMargin: Shared.DesktopStyle.px(6)
                text: "Recent activity"
                font.weight: Font.DemiBold
            }
            Repeater {
                model: root.expanded ? root.doctor.events.slice(0, 8) : []
                Detail {
                    required property var modelData
                    label: Qt.formatTime(new Date(modelData.at * 1000), "HH:mm")
                    message: modelData.text
                    dot: modelData.level === "fail" ? Colors.statusUrgent
                        : modelData.level === "warn" ? Colors.statusWarning : Colors.muted
                }
            }
        }
    }
    Note {
        visible: root.doctor.error !== ""
        text: root.doctor.error
        color: Colors.red
    }
    RowLayout {
        Layout.fillWidth: true
        UiButton {
            text: root.doctor.running ? "Checking…" : "Run full check"
            enabled: !root.doctor.running
            onClicked: root.doctor.runFull()
        }
        UiButton {
            text: root.expanded ? "Hide details" : "Details"
            subtle: true
            visible: root.doctor.rebuild !== null || root.doctor.events.length > 0
            onClicked: root.expanded = !root.expanded
        }
        Item { Layout.fillWidth: true }
        UiButton {
            text: "Fix it…"
            glyph: "\u{F1322}"
            visible: root.doctor.issues.length > 0 && Quickshell.env("ONINIX_LAYER") !== "1"
            enabled: !root.doctor.stale && !root.doctor.running
            onClicked: { root.doctor.offerRepair(); root.repairRequested() }
        }
    }
}
