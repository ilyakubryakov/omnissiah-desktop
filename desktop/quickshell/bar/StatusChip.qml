pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

// A Seg-like chip: accent glyph, optional value, per-source status dots,
// provider meters or level bars.
Item {
    id: chip
    property string glyph
    property string value
    property color valueColor: Colors.foreground
    property var dots: []
    property var meters: []
    property color badge: "transparent"
    readonly property bool hovered: chipMouse.containsMouse
    // Each item is { value: 0-100, color }; drawn as thin vertical level bars.
    property var bars: []
    function inheritedGroup() {
        for (let item = parent; item; item = item.parent)
            if (item.panelAccentGroup !== undefined) return item.panelAccentGroup
        return "status"
    }
    // Optional status tint for the glyph; transparent keeps the panel accent.
    property color tint: "transparent"
    readonly property color glyphColor: tint.a > 0 ? tint : ShellLayout.buttonColor(inheritedGroup())
    signal clicked()
    implicitWidth: chipRow.implicitWidth + 16
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true
    Accessible.role: Accessible.Button
    Accessible.onPressAction: clicked()
    Rectangle {
        anchors { fill: parent; topMargin: 3; bottomMargin: 3 }
        radius: Math.min(6, height / 3)
        color: Qt.rgba(chip.glyphColor.r, chip.glyphColor.g, chip.glyphColor.b, chipMouse.pressed ? 0.18 : chipMouse.containsMouse ? 0.10 : 0)
        Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.fast } }
    }
    RowLayout {
        id: chipRow
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 }
        spacing: 6
        ChipGlyph {
            visible: chip.glyph !== ""
            text: chip.glyph; color: chip.glyphColor
            Rectangle {
                visible: chip.badge.a > 0
                width: 7; height: 7; radius: 3.5
                x: parent.width - 4; y: 1
                color: chip.badge
                border.width: 1.5; border.color: Colors.background
            }
        }
        Repeater {
            model: chip.meters
            RowLayout {
                id: meter
                required property var modelData
                required property int index
                spacing: 5
                Layout.leftMargin: index > 0 ? 6 : 0
                ChipGlyph { text: meter.modelData.glyph; color: chip.glyphColor }
                Item {
                    implicitWidth: meterText.implicitWidth
                    implicitHeight: meterText.implicitHeight
                    Text {
                        id: meterText
                        text: meter.modelData.value; color: meter.modelData.color
                        font.family: Colors.textFont; font.pixelSize: Math.max(13, Colors.fontSize)
                        font.features: { "tnum": 1 }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: meterText.bottom; topMargin: 1 }
                        height: 2; radius: 1; color: Colors.selection
                        Rectangle {
                            height: parent.height; radius: 1; color: meter.modelData.color
                            width: parent.width * Math.max(0, Math.min(1, meter.modelData.fill))
                            Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal } }
                        }
                    }
                }
            }
        }
        Text {
            visible: chip.value !== ""
            text: chip.value; color: chip.valueColor
            font.family: Colors.textFont; font.pixelSize: Math.max(13, Colors.fontSize)
            font.features: { "tnum": 1 }
        }
        Row {
            visible: chip.dots.length > 0
            spacing: 4
            Repeater {
                model: chip.dots
                Rectangle {
                    required property var modelData
                    width: 7; height: 7; radius: 3.5
                    color: modelData
                    Behavior on color { ColorAnimation { duration: Shared.DesktopStyle.normal } }
                }
            }
        }
        Row {
            visible: chip.bars.length > 0
            spacing: 3
            Repeater {
                model: chip.bars
                Rectangle {
                    required property var modelData
                    width: 4; height: 14; radius: 2
                    color: Colors.selection
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; radius: 2
                        height: Math.max(2, parent.height * Math.max(0, Math.min(1, modelData.value / 100)))
                        color: modelData.color
                        Behavior on height { NumberAnimation { duration: Shared.DesktopStyle.normal; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
    MouseArea {
        id: chipMouse
        anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
