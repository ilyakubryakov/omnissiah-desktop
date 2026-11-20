pragma ComponentBehavior: Bound
import QtQuick

// One font, size and solid color for all application symbols on panel surfaces.
Text {
    property string appClass: ""
    property int iconSize: 17
    property color glyphColor: Colors.foreground
    text: appClass ? Hypr.icon(appClass) : "\u{F0130}"
    font.family: Colors.iconFont
    font.pixelSize: iconSize
    color: glyphColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
