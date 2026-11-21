pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../shared" as Shared

ColumnLayout {
    id: root
    spacing: 12
    property bool editing: false
    property string locationError: ""
    function saveLocation() {
        if (!locationField.text.trim() || !Weather.setLocation(locationField.text)) {
            locationError = "Enter latitude and longitude in decimal degrees."
            return
        }
        locationError = ""
        editing = false
    }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            UiLabel { text: "HOURLY WEATHER"; font.pixelSize: Shared.DesktopStyle.px(11); color: Colors.accent; font.letterSpacing: 2 }
            UiLabel { visible: Weather.configured && !root.editing; text: (Weather.now ? Weather.now + "  " : "") + Weather.description(Weather.code); font.pixelSize: Shared.DesktopStyle.px(20) }
        }
        Item { Layout.fillWidth: true }
        UiButton {
            visible: Weather.configured && !root.editing
            text: "Location"
            onClicked: {
                locationField.text = Weather.location
                root.editing = true
                locationField.forceActiveFocus()
            }
        }
        UiButton { visible: Weather.configured && !root.editing; glyph: "\u{F0450}"; Accessible.name: "Refresh weather"; enabled: !Weather.loading; onClicked: Weather.refresh() }
    }
    RowLayout {
        visible: root.editing || !Weather.configured
        Layout.fillWidth: true
        CalendarField {
            id: locationField
            Layout.fillWidth: true
            Accessible.name: "Weather latitude and longitude"
            placeholderText: "Latitude, longitude"
            onAccepted: root.saveLocation()
        }
        UiButton { text: "Save"; onClicked: root.saveLocation() }
        UiButton {
            visible: Weather.configured
            text: "Clear"
            onClicked: { Weather.setLocation(""); locationField.clear(); root.locationError = ""; root.editing = false }
        }
    }
    UiLabel {
        visible: root.editing || !Weather.configured
        text: root.locationError || "Use decimal degrees. Open-Meteo uses the coordinates to fetch the forecast."
        color: root.locationError ? Colors.yellow : Colors.muted
        font.pixelSize: Shared.DesktopStyle.px(12)
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }
    UiLabel { visible: Weather.configured && !root.editing && (Weather.error !== "" || Weather.stale); text: Weather.error || "Forecast is out of date"; color: Colors.yellow; font.pixelSize: Shared.DesktopStyle.px(12); Layout.fillWidth: true }
    UiLabel { visible: Weather.configured && !root.editing && Weather.hours.length === 0; text: Weather.loading ? "Loading forecast…" : "No hourly data available"; color: Colors.muted }
    GridLayout {
        visible: Weather.configured && !root.editing
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
        visible: Weather.configured && !root.editing
        Layout.fillWidth: true
        UiLabel { Layout.fillWidth: true; text: Weather.sun ? (Weather.sunrise ? "Sunrise " : "Sunset ") + Weather.sun : ""; color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
        UiLabel { text: "Open-Meteo · " + (Weather.checkedAt ? Qt.formatTime(new Date(Weather.checkedAt), "HH:mm") : "--"); color: Colors.muted; font.pixelSize: Shared.DesktopStyle.px(11) }
    }
    UiLabel { visible: Weather.configured && !root.editing; text: "Local time · °C · precipitation probability · wind"; font.pixelSize: Shared.DesktopStyle.px(10); color: Colors.dim }
}
