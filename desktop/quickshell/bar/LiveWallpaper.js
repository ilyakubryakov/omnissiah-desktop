.pragma library

const sorts = [
    { value: "trend", label: "Trending" },
    { value: "newest", label: "Newest" },
    { value: "top", label: "Most popular all time" },
    { value: "subscribed", label: "Most subscribed" },
    { value: "updated", label: "Recently updated" }
]

const periods = [
    { value: 1, label: "Today" },
    { value: 7, label: "Week" },
    { value: 30, label: "Month" },
    { value: 90, label: "3 months" },
    { value: 180, label: "6 months" },
    { value: 365, label: "Year" }
]

function plain(value) {
    return value === undefined ? value : JSON.parse(JSON.stringify(value))
}

function response(stdout, exitCode) {
    let data
    try {
        data = JSON.parse(stdout)
    } catch (_) {
        data = null
    }
    if (!data || typeof data !== "object" || Array.isArray(data))
        return { error: stdout.trim() ? "Invalid response from oninix-livewall" : "No response from oninix-livewall" }
    if (exitCode !== 0 && !data.error)
        return { error: "oninix-livewall exited with code " + exitCode }
    return data
}

function statusText(status) {
    switch (status.state) {
    case "playing": return "Playing"
    case "starting": return "Starting"
    case "paused":
        return ({
            maximized: "Paused: window maximized",
            fullscreen: "Paused: fullscreen",
            dpms: "Paused: display is off",
            locked: "Paused: screen locked",
            covered: "Paused: desktop covered by windows"
        })[status.reason] || "Paused"
    case "unloaded":
        if (status.reason === "game") return "Unloaded: Game mode"
        if (status.reason === "dpms") return "Unloaded: display is off"
        return "Unloaded"
    case "waiting": return "Waiting for GPU memory: showing the still"
    case "stopped": return status.error ? "Stopped: " + status.error : "Stopped"
    case "error": return status.error ? "Error: " + status.error : "Error"
    default: return "Checking live wallpaper status…"
    }
}

function queryArgs(filters, cursor) {
    const args = ["query", "--sort", filters.sort]
    if (filters.sort === "trend") args.push("--days", String(filters.days))
    for (const type of filters.types) args.push("--type", type)
    for (const rating of filters.ratings) args.push("--rating", rating)
    for (const tag of filters.tags) args.push("--tag", tag)
    if (filters.resolution) args.push("--resolution", filters.resolution)
    const search = filters.search.trim()
    if (search.startsWith("-")) args.push("--search=" + search)
    else if (search) args.push("--search", search)
    if (cursor) args.push("--cursor", cursor)
    return args
}

function typeLabel(type) {
    return ({ video: "Video", scene: "Scene", web: "Web", application: "Application" })[type] || "Unknown type"
}

function previewSource(item, workshop) {
    if (workshop) return /^https?:\/\//i.test(item.preview_url || "") ? item.preview_url : ""
    if (!item.preview || !item.preview.startsWith("/")) return ""
    return "file://" + item.preview.split("/").map(encodeURIComponent).join("/")
}

function gridItem(item, workshop) {
    return {
        wallpaperId: item.id,
        wallpaperTitle: item.title,
        wallpaperType: item.type,
        previewUrl: previewSource(item, workshop),
        installedInQuery: workshop && item.installed === true,
        subscriptions: workshop ? item.subscriptions : 0
    }
}

function workshopPage(result, cursor, seen) {
    const items = []
    for (const item of result.items) {
        if (!item.id || seen.has(item.id)) continue
        seen.add(item.id)
        items.push(gridItem(item, true))
    }
    const next = result.next_cursor
    return { items, nextCursor: typeof next === "string" && next !== cursor ? next : "" }
}

function boolValue(value) {
    return value === true || value === 1 || value === "1" || value === "true"
}

function colorValue(value) {
    const text = String(value ?? "").trim()
    const hex = /^#([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i.exec(text)
    const channels = hex ? hex.slice(1).map(part => (parseInt(part, 16) / 255).toFixed(8)) : text.split(/\s+/)
    if (channels.length !== 3 || !channels.every(channel => /^(?:\d+(?:\.\d*)?|\.\d+)$/.test(channel) && Number(channel) <= 1))
        return null
    return channels.map(channel => channel.replace(/^0+(?=\d)/, "").replace(/^\./, "0.")
        .replace(/(\.\d*?)0+$/, "$1").replace(/\.$/, "")).join(" ")
}

function samePropertyValue(type, left, right) {
    if (left === right) return true
    switch (type) {
    case "bool": return boolValue(left) === boolValue(right)
    case "slider": return left != null && right != null && Number(left) === Number(right)
    case "color": {
        const rgb = colorValue(left)
        return rgb !== null && rgb === colorValue(right)
    }
    default: return String(left ?? "") === String(right ?? "")
    }
}

function propertyVisible(property, values) {
    const condition = /^\s*([\w-]+)\.value(?:\s*==\s*(-?\d+(?:\.\d+)?))?\s*$/.exec(property.condition)
    if (!condition || !values.has(condition[1])) return true
    const value = values.get(condition[1])
    if (condition[2] === undefined) return Boolean(value)
    if (value == null || (typeof value === "string" && !value.trim())) return true
    const number = Number(value)
    return !Number.isFinite(number) || number === Number(condition[2])
}

function propertyArgs(id, key, value) {
    if (key === undefined) return ["prop", id, "--reset-all"]
    if (value === undefined) return ["prop", "--reset", "--", id, key]
    return ["prop", "--", id, key, String(value)]
}

function textValue(text) {
    return /[\r\n=\0]/.test(text) ? null : text
}
