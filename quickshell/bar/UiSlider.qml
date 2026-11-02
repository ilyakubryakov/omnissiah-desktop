import QtQuick
import QtQuick.Controls
import "../shared" as Shared

Slider {
    id: slider
    implicitHeight: 32
    implicitWidth: 160
    focusPolicy: Qt.StrongFocus
    snapMode: Slider.SnapAlways
    property color tint: Colors.accent

    property real drawnPosition: visualPosition
    Behavior on drawnPosition { enabled: !slider.pressed; NumberAnimation { duration: Shared.DesktopStyle.fast; easing.type: Easing.OutCubic } }
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth; height: 5; radius: 2.5; color: Colors.selection
        implicitHeight: 5
        Rectangle { width: slider.drawnPosition * parent.width; height: parent.height; radius: 2.5; color: slider.tint }
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.drawnPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: 14; implicitHeight: 20
        width: implicitWidth; height: slider.pressed ? 24 : implicitHeight; radius: 7
        color: slider.pressed ? Colors.bright : Colors.foreground
        border.width: slider.activeFocus ? 2 : 0
        border.color: slider.tint
        Behavior on height { NumberAnimation { duration: Shared.DesktopStyle.fast } }
    }
}
