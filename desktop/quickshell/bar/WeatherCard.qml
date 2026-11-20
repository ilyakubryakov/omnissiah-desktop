pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            UiLabel { text: "VILNIUS · HOURLY"; font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.accent; font.letterSpacing: 2 }
            UiLabel { text: (Weather.now ? Weather.now + "  " : "") + Weather.description(Weather.code); font.pixelSize: Shared.DesktopStyle.px(20) }
        }
        Item { Layout.fillWidth: true }
        UiButton { glyph: "\u{F0450}"; Accessible.name: "Refresh weather"; enabled: !Weather.loading; onClicked: Weather.refresh() }
    }
    UiLabel { visible: Weather.error !== "" || Weather.stale; text: Weather.error || "Forecast is out of date"; color: Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
    UiLabel { visible: Weather.hours.length === 0; text: Weather.loading ? "Loading forecast…" : "No hourly data available"; color: Colors.muted }
    GridLayout {
        Layout.fillWidth: true
        columns: 6; columnSpacing: 5; rowSpacing: 5
        Repeater {
            model: Weather.hours
            Rectangle {
                id: hour
                required property var modelData
                required property int index
                Layout.fillWidth: true; Layout.preferredWidth: 1
                implicitHeight: 116; radius: Shared.DesktopStyle.radiusSmall
                color: index === 0 ? Colors.selection : Colors.lightBackground
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 5
                    UiLabel { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.time.slice(11, 16); color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
                    Text { Layout.alignment: Qt.AlignHCenter; text: Weather.glyph(hour.modelData.code, hour.modelData.day); font.family: Colors.iconFont; font.pixelSize: Shared.DesktopStyle.px(23); color: Colors.accent }
                    UiLabel { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.temp === null ? "--" : Math.round(hour.modelData.temp) + "°"; font.pixelSize: Shared.DesktopStyle.px(17) }
                    UiLabel { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.rain === null ? "--" : hour.modelData.rain + "%"; color: Colors.cyan; font.pixelSize: Shared.DesktopStyle.px(10) }
                    UiLabel { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.wind === null ? "--" : Math.round(hour.modelData.wind) + " m/s"; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(10) }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { Layout.fillWidth: true; text: Weather.sun ? (Weather.sunrise ? "Sunrise " : "Sunset ") + Weather.sun : ""; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
        UiLabel { text: "Open-Meteo · " + (Weather.checkedAt ? Qt.formatTime(new Date(Weather.checkedAt), "HH:mm") : "--"); color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
    }
    UiLabel { text: "Local time · °C · precipitation probability · wind"; font.pixelSize: Shared.DesktopStyle.px(10); color: Colors.dim }
}
