pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string now: ""
    property string next: ""
    property string sun: ""
    property bool sunrise: true
    property int code: -1
    property int isDay: 1
    property var forecast: []
    property int utcOffset: 0
    property double checkedAt: 0
    property double clock: Date.now()
    property string error: ""
    readonly property bool loading: fetch?.running === true
    readonly property bool stale: checkedAt > 0 && clock - checkedAt > 45 * 60 * 1000
    readonly property string localHour: new Date(clock + utcOffset * 1000).toISOString().slice(0, 13)
    readonly property var hours: forecast.filter(h => h.time.slice(0, 13) >= localHour).slice(0, 12)
    readonly property string url: "https://api.open-meteo.com/v1/forecast?latitude=" + Integrations.latitude + "&longitude=" + Integrations.longitude
        + "&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,is_day"
        + "&daily=sunrise,sunset&timezone=auto&forecast_days=2&wind_speed_unit=ms"
    function refresh() { if (Integrations.weather && !fetch.running) fetch.running = true }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.clock = Date.now() }
    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "10", root.url]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (!d.current || !d.hourly || !Array.isArray(d.hourly.time)) throw new Error("Incomplete forecast")
                    const value = (key, i) => Number.isFinite(d.hourly[key]?.[i]) ? d.hourly[key][i] : null
                    root.forecast = d.hourly.time.map((t, i) => ({time: t,
                        temp: value("temperature_2m", i), code: value("weather_code", i), day: value("is_day", i),
                        rain: value("precipitation_probability", i), wind: value("wind_speed_10m", i)}))
                    root.utcOffset = d.utc_offset_seconds || 0
                    root.now = Number.isFinite(d.current.temperature_2m) ? Math.round(d.current.temperature_2m) + "°" : ""
                    root.code = d.current.weather_code ?? -1
                    root.isDay = d.current.is_day ?? 1
                    const i = d.hourly.time.findIndex(t => t.slice(0, 13) === d.current.time.slice(0, 13))
                    root.next = i >= 0 && Number.isFinite(value("temperature_2m", i + 1)) ? Math.round(value("temperature_2m", i + 1)) + "°" : ""
                    const events = []
                    for (let k = 0; k < (d.daily?.sunrise || []).length; k++) {
                        events.push({t: d.daily.sunrise[k], up: true}, {t: d.daily.sunset[k], up: false})
                    }
                    const e = events.filter(x => x.t > d.current.time).sort((a, b) => a.t.localeCompare(b.t))[0]
                    root.sun = e ? e.t.slice(11, 16) : ""
                    root.sunrise = !!e && e.up
                    root.checkedAt = Date.now()
                    root.clock = root.checkedAt
                    root.error = ""
                } catch (_) { root.error = "Forecast unavailable. Please try again." }
            }
        }
        onExited: code => { if (code !== 0) root.error = "Could not update. Showing the last available forecast." }
    }
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
