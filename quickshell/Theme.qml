pragma Singleton

import Quickshell
import QtQuick
import "shared" as Shared

Singleton {
    readonly property color cView: Shared.Palette.darkBackground
    readonly property color cBg: Shared.Palette.background
    readonly property color cButton: Shared.Palette.lightBackground
    readonly property color cFg: Shared.Palette.foreground
    readonly property color cAccent: Shared.Palette.accent
    readonly property color cDim: Shared.Palette.muted
    readonly property color cOk: Shared.Palette.green
    readonly property color cBad: Shared.Palette.red
    readonly property color cWarn: Shared.Palette.yellow

    readonly property color cInfo: Shared.Palette.blue

    function co2Col(v)  { return v >= 1200 ? cBad : (v >= 800 ? cWarn : cOk) }
    function tempCol(v) { return (v >= 27 || v <= 17) ? cBad : ((v >= 25 || v <= 19) ? cWarn : cOk) }
    function humCol(v)  { return (v >= 65 || v <= 25) ? cBad : ((v >= 60 || v <= 30) ? cWarn : cOk) }

    readonly property string uiFont:      "Inter"
    readonly property string displayFont: "Inter Display"
    readonly property string monoFont:    Shared.Palette.iconFont
}
