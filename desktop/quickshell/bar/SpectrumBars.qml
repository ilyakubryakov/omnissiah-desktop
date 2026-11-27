import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

Item {
    id: root
    property color tone: Colors.accent
    property bool live: Spectrum.running
    readonly property int count: Spectrum.count
    implicitWidth: count * Shared.DesktopStyle.px(3) + (count - 1) * Shared.DesktopStyle.px(2)
    implicitHeight: Shared.DesktopStyle.px(18)
    Layout.alignment: Qt.AlignVCenter
    Row {
        anchors.centerIn: parent
        spacing: Shared.DesktopStyle.px(2)
        Repeater {
            model: root.count
            Rectangle {
                required property int index
                readonly property real level: root.live ? (Spectrum.levels[index] || 0) / 100 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: Shared.DesktopStyle.px(3); radius: Shared.DesktopStyle.px(3) / 2
                height: Math.max(Shared.DesktopStyle.px(3), root.height * level)
                color: root.tone
                opacity: root.live ? 0.45 + 0.55 * level : 0.3
                Behavior on height { enabled: Shared.DesktopStyle.motion; NumberAnimation { duration: 70 } }
            }
        }
    }
}
