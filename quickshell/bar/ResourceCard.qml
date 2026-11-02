import QtQuick
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 12
    readonly property var gpu: Shared.StationStatus.gpu
    UiLabel { text: "THIS MACHINE"; font.pixelSize: 11; color: Colors.accent; font.letterSpacing: 2 }
    GridLayout {
        Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
        StatMeter { label: "CPU"; value: Sys.cpu; tone: Colors.accent; detail: "Processor utilization" }
        StatMeter { label: "Memory"; value: Sys.mem; tone: Colors.cyan; detail: Sys.memTotalGiB ? Sys.memUsedGiB.toFixed(1) + " / " + Sys.memTotalGiB.toFixed(1) + " GiB" : "" }
        StatMeter { label: "Root disk"; value: Sys.disk; tone: Sys.disk >= 90 ? Colors.red : Colors.green; detail: Sys.diskTotalGiB ? Sys.diskUsedGiB.toFixed(0) + " / " + Sys.diskTotalGiB.toFixed(0) + " GiB" : "" }
        StatMeter { label: "CPU temp"; value: Sys.temp; suffix: "°C"; tone: Sys.temp >= 85 ? Colors.red : Colors.yellow; detail: "Hardware sensor" }
        StatMeter { visible: root.gpu.load != null; label: "GPU"; value: root.gpu.load; tone: Colors.magenta; detail: root.gpu.name || "" }
        StatMeter { visible: root.gpu.vramPct != null; label: "VRAM"; value: root.gpu.vramPct; tone: Colors.cyan; detail: root.gpu.temp != null ? Math.round(root.gpu.temp) + "°C" + (root.gpu.powerW != null ? " · " + Math.round(root.gpu.powerW) + " W" : "") : "" }
    }
    UiLabel {
        Layout.fillWidth: true; font.pixelSize: 12; color: Colors.muted
        readonly property var models: Shared.StationStatus.ollama.models || []
        visible: models.length > 0
        text: "Ollama: " + models.map(m => m.name).join(", ")
    }
    UiButton { text: "Open system monitor"; Layout.fillWidth: true; onClicked: { PopupState.close(); Quickshell.execDetached(["uwsm", "app", "--", "kitty", "-e", "btop"]) } }
}
