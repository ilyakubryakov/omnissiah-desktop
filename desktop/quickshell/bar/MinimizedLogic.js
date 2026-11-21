.pragma library

var WORKSPACE = "special:minimized"
var CLASS_OF = {"com.google.chrome": "google-chrome", "com.anthropic.claude": "claude", "md.obsidian.obsidian": "obsidian"}

function isMinimized(c) { return !!(c && c.workspace && c.workspace.name === WORKSPACE) }
function isVisible(c) { return !!(c && c.workspace && c.workspace.id > 0) }
function className(c) { return ((c && (c["class"] || c.initialClass)) || "").toLowerCase() }

function classIndex(apps) {
    var out = Object.create(null)
    Object.keys(apps).forEach(function (id) {
        var key = id.toLowerCase()
        ;[key, CLASS_OF[key], ((apps[id] || {}).startupClass || "").toLowerCase()].forEach(function (cls) {
            if (cls && !(cls in out)) out[cls] = id
        })
    })
    return out
}

function appId(c, index) { var cls = className(c); return index[cls] || "class:" + cls }

function matches(id, c, apps) {
    var cls = className(c), key = id.toLowerCase()
    if (!cls) return false
    if (key.indexOf("class:") === 0) return key.slice(6) === cls
    var e = apps[id]
    return cls === key || cls === CLASS_OF[key] || (!!e && (e.startupClass || "").toLowerCase() === cls)
}

function updateOrder(order, sequence, minimized) {
    var next = {}, n = sequence
    minimized.forEach(function (c) { if (order[c.address] !== undefined) next[c.address] = order[c.address] })
    minimized.filter(function (c) { return order[c.address] === undefined })
        .sort(function (a, b) { return b.focusHistoryID - a.focusHistoryID })
        .forEach(function (c) { next[c.address] = ++n })
    return {order: next, sequence: n}
}

function rank(c, order) { return order[c.address] !== undefined ? order[c.address] : -c.focusHistoryID }

function extraIds(minimized, pinned, apps, order) {
    var index = classIndex(apps), seen = []
    minimized.slice().sort(function (a, b) { return rank(a, order) - rank(b, order) }).forEach(function (c) {
        if (pinned.some(function (id) { return matches(id, c, apps) })) return
        var id = appId(c, index)
        if (seen.indexOf(id) < 0) seen.push(id)
    })
    return seen
}

function pick(windows, order) {
    var visible = windows.filter(isVisible).sort(function (a, b) { return a.focusHistoryID - b.focusHistoryID })
    if (visible.length) return visible[0]
    var hidden = windows.filter(isMinimized).sort(function (a, b) { return rank(a, order) - rank(b, order) })
    return hidden.length ? hidden[hidden.length - 1] : null
}

function unreadKey(id) {
    var key = id.toLowerCase()
    if (key.indexOf("telegram") >= 0) return "telegram"
    if (key.indexOf("slack") >= 0) return "slack"
    if (key.indexOf("thunderbird") >= 0) return "mail"
    return ""
}

function badge(id, unread) {
    var key = unreadKey(id)
    if (!key || !unread) return ""
    var n = Number(unread[key]) || 0
    if (n > 0) return n > 99 ? "99+" : String(n)
    return key === "slack" && unread.slack_dot ? "dot" : ""
}
