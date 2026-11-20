import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// Mirrored spectrum in the group accent. At rest (paused, no cava) the bars
// settle into a row of dots instead of disappearing, so the bar width stays put.
Item {
    id: root
    property color tone: Colors.accent
    property bool live: Spectrum.running
    readonly property int count: Spectrum.count
    implicitWidth: count * 3 + (count - 1) * 2
    implicitHeight: 18
    Layout.alignment: Qt.AlignVCenter
    Row {
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.count
            Rectangle {
                required property int index
                readonly property real level: root.live ? (Spectrum.levels[index] || 0) / 100 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: 3; radius: 1.5
                height: Math.max(3, root.height * level)
                color: root.tone
                opacity: root.live ? 0.45 + 0.55 * level : 0.3
                Behavior on height { enabled: Shared.DesktopStyle.motion; NumberAnimation { duration: 70 } }
            }
        }
    }
}
