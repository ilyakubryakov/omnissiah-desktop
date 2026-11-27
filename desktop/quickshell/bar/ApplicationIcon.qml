pragma ComponentBehavior: Bound
import QtQuick
import "../shared" as Shared

Text {
    property string appClass: ""
    property int iconSize: Shared.DesktopStyle.px(17)
    property color glyphColor: Colors.foreground
    text: appClass ? Hypr.icon(appClass) : "\u{F0130}"
    font.family: Colors.iconFont
    font.pixelSize: iconSize
    color: glyphColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
