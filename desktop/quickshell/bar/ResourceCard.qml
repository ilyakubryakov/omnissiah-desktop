import QtQuick
import QtQuick.Layouts
import Quickshell
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 12
    UiLabel { text: "THIS MACHINE"; font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.accent; font.letterSpacing: 2 }
    GridLayout {
        Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
        StatMeter { label: "CPU"; value: Sys.cpu; tone: Colors.accent; detail: "Processor utilization" }
        StatMeter { label: "Memory"; value: Sys.mem; tone: Colors.cyan; detail: Sys.memTotalGiB ? Sys.memUsedGiB.toFixed(1) + " / " + Sys.memTotalGiB.toFixed(1) + " GiB" : "" }
        StatMeter { label: "Root disk"; value: Sys.disk; tone: Sys.disk >= 90 ? Colors.red : Colors.green; detail: Sys.diskTotalGiB ? Sys.diskUsedGiB.toFixed(0) + " / " + Sys.diskTotalGiB.toFixed(0) + " GiB" : "" }
        StatMeter { label: "CPU temp"; value: Sys.temp; suffix: "°C"; tone: Sys.temp >= 85 ? Colors.red : Colors.yellow; detail: "Hardware sensor" }
    }
    UiButton { text: "Open system monitor"; Layout.fillWidth: true; onClicked: { PopupState.close(); Quickshell.execDetached(["oninix-app", "kitty", "-e", "btop"]) } }
}
