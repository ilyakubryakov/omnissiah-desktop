pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    signal detailsRequested()
    readonly property var laptop: DesktopData.controls.laptop || ({})
    readonly property var battery: laptop.battery
    spacing: Shared.DesktopStyle.cardSpacing
    RowLayout {
        Layout.fillWidth: true
        UiLabel { text: "POWER & DISPLAY"; color: Colors.accent; font.pixelSize: Shared.DesktopStyle.px(11); font.letterSpacing: Shared.DesktopStyle.px(2); Layout.fillWidth: true }
        UiLabel { text: root.battery ? root.battery.percent + "%" : "--"; font.pixelSize: Shared.DesktopStyle.px(24) }
    }
    Rectangle {
        Layout.fillWidth: true; implicitHeight: Shared.DesktopStyle.px(6); radius: Shared.DesktopStyle.px(3); color: Colors.selection
        Rectangle { height: parent.height; width: parent.width * (root.battery ? root.battery.percent : 0) / 100; radius: Shared.DesktopStyle.px(3); color: Colors.green
            Behavior on width { NumberAnimation { duration: Shared.DesktopStyle.normal } }
        }
    }
    UiLabel { text: root.battery ? root.battery.status + (root.battery.status === "Discharging" && root.battery.watts > 0 ? " · " + root.battery.watts.toFixed(1) + " W" : "") : "Battery unavailable"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(12) }
    UiLabel { text: "Brightness"; visible: root.laptop.brightness != null; font.pixelSize: Shared.DesktopStyle.px(13) }
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
        UiLabel { text: Math.round(brightness.value) + "%"; font.pixelSize: Shared.DesktopStyle.px(12); Layout.preferredWidth: Shared.DesktopStyle.px(40) }
    }
    UiLabel { text: "Profile: " + (root.laptop.profile || "Unavailable"); font.pixelSize: Shared.DesktopStyle.px(13); color: Colors.muted }
    UiButton { text: "Power, lock & sleep settings"; Layout.fillWidth: true; onClicked: root.detailsRequested() }
}
