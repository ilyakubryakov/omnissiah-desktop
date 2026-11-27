pragma Singleton
import QtQuick
import Quickshell
import "../shared" as Shared

Singleton {
    id: root
    readonly property string location: Shared.WeatherData.location
    readonly property bool configured: Shared.WeatherData.configured
    function setLocation(value) { return Shared.WeatherData.setLocation(value) }
    readonly property var data: Shared.WeatherData.forecast
    readonly property var current: data.current || ({})
    readonly property var forecast: data.hourly || []
    readonly property string now: roundTemp(current.temp)
    readonly property int code: current.code ?? -1
    readonly property int isDay: current.day ?? 1
    readonly property double checkedAt: Shared.WeatherData.checkedAt
    readonly property bool loading: Shared.WeatherData.loading
    readonly property string error: Shared.WeatherData.error
    readonly property bool stale: checkedAt > 0 && Shared.WeatherData.clock - checkedAt > 45 * 60 * 1000
    readonly property string localHour: new Date(Shared.WeatherData.clock + (data.utcOffset || 0) * 1000).toISOString().slice(0, 13)
    readonly property var hours: forecast.filter(h => h.time.slice(0, 13) >= localHour).slice(0, 12)
    readonly property string next: {
        const index = forecast.findIndex(h => h.time.slice(0, 13) === (current.time || "").slice(0, 13))
        return index < 0 ? "" : roundTemp(forecast[index + 1]?.temp)
    }
    readonly property var nextSun: {
        for (const day of data.daily || []) {
            if (day.sunrise > current.time) return {time: day.sunrise, up: true}
            if (day.sunset > current.time) return {time: day.sunset, up: false}
        }
        return null
    }
    readonly property string sun: nextSun?.time.slice(11, 16) || ""
    readonly property bool sunrise: nextSun?.up || false

    function roundTemp(temp) { return Number.isFinite(temp) ? Math.round(temp) + "°" : "" }
    function refresh() { Shared.WeatherData.refresh() }
    function description(c) {
        if (c === null || c < 0) return "Unknown conditions"
        if (c === 0) return "Clear sky"
        if (c <= 3) return "Cloudy"
        if (c <= 48) return "Fog"
        if (c <= 57) return "Drizzle"
        if (c <= 67) return "Rain"
        if (c <= 77) return "Snow"
        if (c <= 82) return "Rain showers"
        if (c <= 86) return "Snow showers"
        return "Thunderstorm"
    }
    function glyph(c, day) {
        if (c === null || c < 0) return "\u{F0590}"
        if (day === 0 && c <= 2) return "\u{F0594}"
        if (c === 3) return "\u{F0590}"
        if (c === 0) return "\u{F0599}"
        if (c <= 3) return "\u{F0595}"
        if (c <= 48) return "\u{F0591}"
        if (c <= 67 || (c >= 80 && c <= 82)) return "\u{F0597}"
        if (c <= 77 || c === 85 || c === 86) return "\u{F0598}"
        return "\u{F0593}"
    }
}
