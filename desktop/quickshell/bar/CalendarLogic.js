.pragma library

function endTime(event) {
    const start = Date.parse(event.s), end = Date.parse(event.e)
    return isFinite(end) && end > start ? end : start
}

function onDay(events, date) {
    const from = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
    const to = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime()
    return events.filter(event => {
        const start = Date.parse(event.s), end = endTime(event)
        return isFinite(start) && start < to && (end > start ? end > from : start >= from)
    }).sort((a, b) => Number(b.a) - Number(a.a) || Date.parse(a.s) - Date.parse(b.s))
}

function upcoming(events, now, limit) {
    return events.filter(event => {
        const start = Date.parse(event.s)
        return isFinite(start) && (start >= now || endTime(event) > now)
    }).sort((a, b) => {
        const rank = e => !e.a && Date.parse(e.s) <= now ? 0 : e.a ? 2 : 1
        return rank(a) - rank(b) || Date.parse(a.s) - Date.parse(b.s)
    }).slice(0, limit)
}

function ongoing(event, now) {
    return !event.a && Date.parse(event.s) <= now && endTime(event) > now
}

function duration(event) {
    if (event.a) return "All day"
    const minutes = Math.round((endTime(event) - Date.parse(event.s)) / 60000)
    if (minutes <= 0) return ""
    return minutes < 60 ? minutes + " min" : Math.floor(minutes / 60) + " h" + (minutes % 60 ? " " + minutes % 60 + " min" : "")
}

function countdown(event, now) {
    if (event.a) return "All day"
    if (ongoing(event, now)) return "Now · " + Math.ceil((endTime(event) - now) / 60000) + " min left"
    const minutes = Math.ceil((Date.parse(event.s) - now) / 60000)
    return minutes >= 0 && minutes <= 60 ? "In " + minutes + " min" : ""
}
