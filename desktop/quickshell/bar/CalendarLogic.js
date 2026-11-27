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

function today(events, now) {
    const date = new Date(now)
    const seen = new Set()
    const allday = [], timed = []
    let current = null, next = null
    for (const event of onDay(events, date)) {
        const key = JSON.stringify([event.a, event.t, event.s])
        if (seen.has(key)) continue
        seen.add(key)
        if (event.a) {
            allday.push({title: event.t})
            continue
        }
        const live = ongoing(event, now)
        const start = Date.parse(event.s)
        const state = live ? "now" : start <= now ? "past" : next ? "later" : "next"
        const entry = {start: event.s, end: event.e, title: event.t, join: event.j, state,
            minutes: Math.ceil((start - now) / 60000)}
        timed.push(entry)
        if (live && !current) current = entry
        if (state === "next") next = entry
    }
    return {date, now, allday, events: timed, next: current || next, done: timed.length > 0 && !current && !next}
}
