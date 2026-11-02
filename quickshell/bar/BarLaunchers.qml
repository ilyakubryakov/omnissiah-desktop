import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../shared" as Shared
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

BarGroup {
    required property var bar
    property real budget: 600

        id: launchGroup
        group: "launchers"
        RowLayout {
        height: parent.height
        spacing: 6

        Seg { glyph: "\u{F003B}"; toolTip: "Applications"; tint: Colors.accent; onClicked: bar.openPanel("launchpad") }
        Seg { glyph: "\u{F044}"; toolTip: "Notebook"; tint: Colors.accent; onClicked: bar.openPanel("notebook") }
        LauncherStrip { barWindow: bar; maximumWidth: Math.max(60, Math.min(460, budget - 100)) }

    }
    }
