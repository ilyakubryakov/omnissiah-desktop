import QtQuick

// Mono Nerd Font glyphs can overhang their cell; center the visible ink instead.
Item {
    id: glyphBox
    property alias text: glyphText.text
    property alias color: glyphText.color
    readonly property real size: Math.max(16, Colors.fontSize + 2)
    implicitWidth: Math.ceil(size * 1.15)
    implicitHeight: glyphText.implicitHeight
    TextMetrics { id: ink; font: glyphText.font; text: glyphText.text }
    Text {
        id: glyphText
        x: (glyphBox.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
        font.family: Colors.iconFont; font.pixelSize: glyphBox.size
    }
}
