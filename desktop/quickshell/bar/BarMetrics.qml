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
    required property var barWindow
    property real availableWidth: 1920
    property var cal: null
    signal openCalendar()
        spacing: 8

        // Station only: oninix-status is off on the laptop and stale data is never shown.
        Seg {
            id: gpuSeg
            onClicked: resourcePopup.togglePinned()
            readonly property var gpu: Shared.StationStatus.gpu
            visible: gpu.temp !== undefined && gpu.temp !== null
            glyph: "\u{F08AE}"
            label: Math.round(gpu.temp) + "°C" + (gpu.vramPct != null ? " " + Math.round(gpu.vramPct) + "%" : "")
            tint: gpu.temp >= 83 ? Colors.red : Colors.foreground
        }
        Seg {
            id: modelsSeg
            onClicked: resourcePopup.togglePinned()
            readonly property var models: Shared.StationStatus.ollama.models || []
            visible: models.length > 0
            glyph: "\u{F06A9}"
            tint: Colors.accent
        }
        Seg { id: tempSeg; onClicked: resourcePopup.togglePinned(); glyph: "\u{F050F}"; label: Sys.temp < 0 ? "--" : Sys.temp + "°C"; tint: Sys.temp >= 85 ? Colors.red : Colors.foreground }
        Seg { id: cpuSeg; onClicked: resourcePopup.togglePinned(); glyph: "\u{F0EE0}"; label: Sys.cpu < 0 ? "--" : Sys.cpu + "%" }
        Seg { id: memSeg; onClicked: resourcePopup.togglePinned(); glyph: "\u{F035B}"; label: Sys.mem < 0 ? "--" : Sys.mem + "%" }
        Seg { id: diskSeg; onClicked: resourcePopup.togglePinned(); glyph: "\u{F02CA}"; label: Sys.disk < 0 ? "--" : Sys.disk + "%"; sep: !draw.visible }
        Seg {
            id: draw
            readonly property var battery: (DesktopData.controls.laptop || {}).battery
            visible: !!battery && battery.status === "Discharging" && battery.watts > 0
            glyph: "\u{F0241}"
            label: visible ? battery.watts.toFixed(1) + " W" : ""
            toolTip: "Battery draw"
            sep: true
        }
        Rectangle { width: 1; height: 12; color: Colors.dim; Layout.leftMargin: 4; Layout.rightMargin: 4 }
        Seg {
            id: weatherSeg
            visible: true
            glyph: Weather.glyph(Weather.code, Weather.isDay)
            label: Weather.now ? Weather.now + (Weather.next !== "" ? " → " + Weather.next : "") : "--"
            onClicked: weatherPopup.togglePinned()
        }
        Seg {
            id: sunSeg
            onClicked: weatherPopup.togglePinned()
            visible: Weather.sun !== ""
            glyph: Weather.sunrise ? "\u{F059C}" : "\u{F059B}"
            label: Weather.sun
            sep: true
        }
        Seg {
            glyph: "\u{F030C}"
            label: Hypr.layout.toLowerCase().startsWith("russian") ? "ru" : "us"
            sep: true
            onClicked: Hyprland.dispatch("hl.dsp.exec_cmd(\"hyprctl switchxkblayout all next\")")
        }
        Seg {
            id: powerSeg
            glyph: "\u{F0425}"
            toolTip: powerPopup.opened ? "" : "Lock, sleep, restart or shut down"
            onClicked: powerPopup.togglePinned()
        }
    BarPopup {
        id: resourcePopup
        anchorItem: cpuSeg; barWindow: bar.barWindow; above: bar.barWindow.edge === "bottom"; cardWidth: Shared.DesktopStyle.px(440)
        triggerHovered: tempSeg.hovered || cpuSeg.hovered || memSeg.hovered || diskSeg.hovered || gpuSeg.hovered || modelsSeg.hovered
        ResourceCard { Layout.fillWidth: true }
    }
    BarPopup {
        id: weatherPopup
        anchorItem: weatherSeg; barWindow: bar.barWindow; above: bar.barWindow.edge === "bottom"
        cardWidth: Shared.DesktopStyle.px(500)
        triggerHovered: weatherSeg.hovered || sunSeg.hovered
        onOpenedChanged: if (opened && (Weather.stale || Weather.checkedAt === 0 || Weather.error !== "")) Weather.refresh()
        WeatherCard { Layout.fillWidth: true }
    }
    // Click only: a hover preview of session actions would be noise.
    BarPopup {
        id: powerPopup
        anchorItem: powerSeg; barWindow: bar.barWindow; above: bar.barWindow.edge === "bottom"; cardWidth: Shared.DesktopStyle.px(400)
        tone: ShellLayout.toneColor(ShellLayout.toneName("metrics"))
        PowerMenu { Layout.fillWidth: true; active: powerPopup.opened; onDone: powerPopup.dismiss() }
    }
    }
