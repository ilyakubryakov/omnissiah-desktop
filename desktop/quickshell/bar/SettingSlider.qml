import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

RowLayout {
    id: root
    property string label: ""
    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property real value: 0
    property var format: v => String(v)
    signal committed(real value)
    Layout.fillWidth: true
    spacing: Shared.DesktopStyle.cardSpacing

    UiLabel {
        visible: root.label !== ""
        Layout.preferredWidth: Shared.DesktopStyle.px(150)
        text: root.label
    }
    UiSlider {
        id: slider
        Layout.fillWidth: true
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        Accessible.name: root.label
        onPressedChanged: if (!pressed) root.committed(Math.round(value / stepSize) * stepSize)
        onMoved: if (!pressed) root.committed(Math.round(value / stepSize) * stepSize)
    }
    UiLabel {
        Layout.preferredWidth: Shared.DesktopStyle.px(64)
        horizontalAlignment: Text.AlignRight
        text: root.format(slider.value)
        color: Colors.muted
    }
}
