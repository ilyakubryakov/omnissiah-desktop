import QtQuick
import QtQuick.Controls
import "../shared" as Shared

Slider {
    id: slider
    implicitHeight: Shared.DesktopStyle.metrics.slider_height
    implicitWidth: Shared.DesktopStyle.px(160)
    focusPolicy: Qt.StrongFocus
    snapMode: Slider.SnapAlways
    property color tint: Colors.accent
    property real drawnPosition: visualPosition
    Behavior on drawnPosition { enabled: !slider.pressed; NumberAnimation { duration: Shared.DesktopStyle.fast; easing.type: Easing.OutCubic } }
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth; height: Shared.DesktopStyle.px(5); radius: Shared.DesktopStyle.px(5) / 2; color: Colors.selection
        implicitHeight: Shared.DesktopStyle.px(5)
        Rectangle { width: slider.drawnPosition * parent.width; height: parent.height; radius: Shared.DesktopStyle.px(5) / 2; color: slider.tint }
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.drawnPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: Shared.DesktopStyle.px(14); implicitHeight: Shared.DesktopStyle.px(20)
        width: implicitWidth; height: slider.pressed ? Shared.DesktopStyle.px(24) : implicitHeight; radius: Shared.DesktopStyle.px(7)
        color: slider.pressed ? Colors.bright : Colors.foreground
        border.width: slider.activeFocus ? (Shared.DesktopStyle.unified ? Shared.DesktopStyle.focusWidth : Shared.DesktopStyle.px(2)) : 0
        border.color: slider.tint
        Behavior on height { NumberAnimation { duration: Shared.DesktopStyle.fast } }
    }
}
