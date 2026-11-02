pragma Singleton
import QtQuick
import Quickshell
import "../shared" as Shared

Singleton {
    readonly property color background: Shared.Palette.background
    readonly property color windowBackground: Shared.Palette.windowBackground
    readonly property color darkBackground: Shared.Palette.darkBackground
    readonly property color lightBackground: Shared.Palette.lightBackground
    readonly property color selection: Shared.Palette.selection
    readonly property color foreground: Shared.Palette.foreground
    readonly property color dim: Shared.Palette.dim
    readonly property color muted: Shared.Palette.muted
    readonly property color bright: Shared.Palette.bright
    readonly property color accent: Shared.Palette.accent
    readonly property color red: Shared.Palette.red
    readonly property color green: Shared.Palette.green
    readonly property color yellow: Shared.Palette.yellow
    readonly property color blue: Shared.Palette.blue
    readonly property color magenta: Shared.Palette.magenta
    readonly property color cyan: Shared.Palette.cyan
    readonly property string textFont: Shared.Palette.textFont
    readonly property string iconFont: Shared.Palette.iconFont
    readonly property int fontSize: Shared.Palette.fontSize
}
