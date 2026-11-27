pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    signal detailsRequested()
    spacing: Shared.DesktopStyle.px(14)
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "SOUND"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: Shared.DesktopStyle.px(2) }
        Item { Layout.fillWidth: true }
        UiButton { text: "Devices & apps"; onClicked: root.detailsRequested() }
    }
    AudioChannel { Layout.fillWidth: true; title: "Output"; node: Shared.AudioState.sink }
    AudioChannel { Layout.fillWidth: true; title: "Microphone"; node: Shared.AudioState.source; microphone: true }
}
