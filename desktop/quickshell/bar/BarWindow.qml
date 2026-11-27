import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../shared" as Shared

RowLayout {
    id: bar
    implicitHeight: PanelStyle.barHeight
    Layout.fillHeight: true
    property real availableWidth: 1920
    property bool compact: false
    property var cal: null
    property var barWindow: null
    signal openCalendar()
        spacing: Shared.DesktopStyle.px(6)

        ShelfChip { visible: bar.barWindow !== null && items.length > 0; barWindow: bar.barWindow }
        Seg {
            glyph: WindowMode.floating ? '\u{F0137}' : '\u{F0574}'
            Accessible.name: WindowMode.floating ? 'Desktop mode: Floating' : 'Desktop mode: Tiling'
            tint: WindowMode.floating ? Colors.accent : Colors.foreground
            toolTip: WindowMode.floating ? 'Desktop mode: Floating\nClick to restore tiling for windows changed by this mode. Utility windows stay floating.' : 'Desktop mode: Tiling\nClick to float windows across all workspaces. New windows will also float.'
            onClicked: DesktopData.act('window-mode', ['toggle'])
        }

        readonly property var w: Hypr.active
        readonly property bool any: w && w.address !== undefined
        readonly property bool tabbed: any && w.grouped && w.grouped.length > 1
        readonly property bool floating: any && w.floating

        Seg {
            visible: !bar.compact && parent.any && label !== ""
            maximumLabelWidth: Math.min(Shared.DesktopStyle.px(180), bar.availableWidth)
            label: parent.any ? (parent.w.title || parent.w.class || "") : ""
            toolTip: parent.any ? parent.w.class + " · " + parent.w.title : ""
            tint: Colors.dim
        }
        Seg {
            visible: !WindowMode.floating && !bar.compact
            toolTip: parent.tabbed ? "Ungroup active window\nClick to remove it from its tab group." : "Group active window\nClick to toggle a tab group for this window."
            glyph: "\u{F04E9}"
            tint: parent.tabbed ? Colors.accent : Colors.dim
            onClicked: Hyprland.dispatch("hl.dsp.group.toggle()")
        }
        Seg {
            visible: !WindowMode.floating && !bar.compact
            toolTip: "Tile split direction\nClick to switch between horizontal and vertical splits for the active tiled window."
            glyph: "\u{F056D}"
            tint: parent.any && !parent.tabbed && !parent.floating ? Colors.accent : Colors.dim
            onClicked: Hyprland.dispatch("hl.dsp.layout(\"togglesplit\")")
        }
        Seg {
            visible: !WindowMode.floating && !bar.compact
            toolTip: parent.floating ? "Active window: Floating\nClick to tile this window." : "Active window: Tiled\nClick to float this window. Other windows keep their mode."
            glyph: "\u{F05B2}"
            tint: parent.floating ? Colors.accent : Colors.dim
            onClicked: Hyprland.dispatch("hl.dsp.window.float({ action = \"toggle\" })")
        }
    }
