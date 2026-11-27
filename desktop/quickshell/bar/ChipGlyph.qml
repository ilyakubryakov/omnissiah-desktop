import QtQuick
import "../shared" as Shared

Item {
    id: glyphBox
    property alias text: glyphText.text
    property alias color: glyphText.color
    readonly property real size: Math.max(Shared.DesktopStyle.px(16), Colors.fontSize + Shared.DesktopStyle.px(2))
    implicitWidth: Math.ceil(size * 1.15)
    implicitHeight: glyphText.implicitHeight
    TextMetrics { id: ink; font: glyphText.font; text: glyphText.text }
    Text {
        id: glyphText
        x: (glyphBox.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
        font.family: Colors.iconFont; font.pixelSize: glyphBox.size
    }
}
