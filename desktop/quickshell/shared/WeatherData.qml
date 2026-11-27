pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var forecast: ({})
    property double clock: Date.now()
    readonly property real checkedAt: forecast.updatedAt || 0
    readonly property bool loading: fetch.running
    property string error: ""
    property string location: ""
    readonly property bool configured: location !== ""
    readonly property string url: {
        if (!configured) return ""
        const [latitude, longitude] = location.split(",")
        return "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude
            + "&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,is_day"
            + "&daily=sunrise,sunset&timezone=auto&forecast_days=2&wind_speed_unit=ms"
    }
    function coordinates(value) {
        const parts = value.split(",").map(part => part.trim())
        if (parts.length !== 2 || parts.some(part => !/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)$/.test(part)))
            return null
        const [latitude, longitude] = parts.map(Number)
        if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null
        return latitude.toFixed(4) + "," + longitude.toFixed(4)
    }
    function setLocation(value) {
        const next = value.trim() === "" ? "" : coordinates(value)
        if (next === null) return false
        store.setText(next + "\n")
        location = next
        return true
    }
    function refresh() {
        if (!configured || fetch.running) return
        fetch.request = url
        fetch.running = true
    }
    onUrlChanged: {
        forecast = ({})
        error = ""
        refresh()
    }
    FileView {
        id: store
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/oninix-weather"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.location = root.coordinates(text().trim()) || ""
    }
    SystemClock {
        enabled: root.configured
        precision: SystemClock.Minutes
        onDateChanged: root.clock = date.getTime()
    }
    Timer {
        interval: 15 * 60 * 1000
        running: root.configured
        repeat: true
        onTriggered: root.refresh()
    }
    Process {
        id: fetch
        property string request: ""
        command: ["curl", "-sf", "--max-time", "10", request]
        stdout: StdioCollector {
            onStreamFinished: {
                if (fetch.request !== root.url || !text) return
                try {
                    const d = JSON.parse(text)
                    if (!d.current || !Array.isArray(d.hourly?.time)) throw new Error("Incomplete forecast")
                    const value = (key, i) => Number.isFinite(d.hourly[key]?.[i]) ? d.hourly[key][i] : null
                    const hourly = d.hourly.time.map((time, i) => ({time,
                        temp: value("temperature_2m", i), code: value("weather_code", i), day: value("is_day", i),
                        rain: value("precipitation_probability", i), wind: value("wind_speed_10m", i)}))
                    const daily = (d.daily?.sunrise || []).map((sunrise, i) => ({sunrise, sunset: d.daily.sunset?.[i]}))
                    const current = {time: d.current.time, temp: d.current.temperature_2m,
                        code: d.current.weather_code, day: d.current.is_day}
                    root.clock = Date.now()
                    root.forecast = {current, hourly, daily, utcOffset: d.utc_offset_seconds || 0, updatedAt: root.clock}
                    root.error = ""
                } catch (_) { root.error = "Forecast unavailable. Please try again." }
            }
        }
        onExited: code => {
            if (request !== root.url) Qt.callLater(root.refresh)
            else if (code !== 0) root.error = root.checkedAt
                ? "Could not update. Showing the last available forecast."
                : "Forecast unavailable. Please try again."
        }
    }
}
