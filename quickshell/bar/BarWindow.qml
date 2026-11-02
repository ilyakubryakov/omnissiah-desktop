import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../shared" as Shared
import "../EdgeLogic.js" as Logic

RowLayout {
    id: bar
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true
    property real availableWidth: 1920
    property bool compact: false
    property var cal: null
    signal openCalendar()
        spacing: 6

        Seg {
            glyph: WindowMode.floating ? '\u{F05B2}' : '\u{F056D}'
            label: WindowMode.floating ? 'Floating' : 'Tiling'
            tint: WindowMode.floating ? Colors.accent : Colors.foreground
            toolTip: WindowMode.floating ? 'Global Floating · click to restore tiling' : 'Global Tiling · click to float all workspaces'
            onClicked: DesktopData.act('window-mode', ['toggle'])
        }

        readonly property var w: Hypr.active
        readonly property bool any: w && w.address !== undefined
        readonly property bool tabbed: any && w.grouped && w.grouped.length > 1
        readonly property bool floating: any && w.floating

        Seg {
            visible: !bar.compact && parent.any && label !== ""
            maximumLabelWidth: Math.min(180, bar.availableWidth)
            label: parent.any ? (parent.w.title || parent.w.class || "") : ""
            toolTip: parent.any ? parent.w.class + " · " + parent.w.title : ""
            tint: Colors.dim
        }
        Seg {
            visible: !WindowMode.floating && !bar.compact
            glyph: "\u{F04E9}"
            tint: parent.tabbed ? Colors.accent : Colors.dim
            onClicked: Hyprland.dispatch("hl.dsp.group.toggle()")
        }
        Seg {
            visible: !WindowMode.floating && !bar.compact
            glyph: "\u{F056D}"
            tint: parent.any && !parent.tabbed && !parent.floating ? Colors.accent : Colors.dim
            onClicked: Hyprland.dispatch("hl.dsp.layout(\"togglesplit\")")
        }
        Seg {
            visible: !WindowMode.floating && !bar.compact
            glyph: "\u{F05B2}"
            tint: parent.floating ? Colors.accent : Colors.dim
            onClicked: Hyprland.dispatch("hl.dsp.window.float({ action = \"toggle\" })")
        }
    }
