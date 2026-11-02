pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    signal detailsRequested()
    readonly property var laptop: DesktopData.controls.laptop || ({})
    readonly property var battery: laptop.battery
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "POWER & DISPLAY"; color: Colors.accent; font.pixelSize: 11; font.letterSpacing: 2; Layout.fillWidth: true }
        UiLabel { text: root.battery ? root.battery.percent + "%" : "--"; font.pixelSize: 24 }
    }
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Colors.selection
        Rectangle { height: parent.height; width: parent.width * (root.battery ? root.battery.percent : 0) / 100; radius: 3; color: Colors.green
            Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal } }
        }
    }
    UiLabel { text: root.battery ? root.battery.status + (root.battery.status === "Discharging" && root.battery.watts > 0 ? " · " + root.battery.watts.toFixed(1) + " W" : "") : "Battery unavailable"; color: Colors.muted; font.pixelSize: 12 }
    UiLabel { text: "Brightness"; visible: root.laptop.brightness != null; font.pixelSize: 13 }
    RowLayout {
        visible: root.laptop.brightness != null
        Layout.fillWidth: true
        UiSlider {
            id: brightness
            Layout.fillWidth: true; from: 5; to: 100; stepSize: 1
            value: DesktopData.brightnessTarget >= 0 ? DesktopData.brightnessTarget : root.laptop.brightness ?? 5
            Accessible.name: "Display brightness"
            onMoved: DesktopData.setBrightness(Math.round(value))
        }
        UiLabel { text: Math.round(brightness.value) + "%"; font.pixelSize: 12; Layout.preferredWidth: 40 }
    }
    UiLabel { text: "Profile: " + (root.laptop.profile || "Unavailable"); font.pixelSize: 13; color: Colors.muted }
    UiButton { text: "Power, lock & sleep settings"; Layout.fillWidth: true; onClicked: root.detailsRequested() }
}
