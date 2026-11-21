.pragma library

var GROUPS = ["launchers", "status"]
var DEFAULTS = {
    launchers: ["applications", "notebook"],
    status: ["tray", "network", "battery", "recording", "awake", "capture",
             "microphone", "notifications", "volume", "clock", "controls"]
}
var APPLETS = DEFAULTS.launchers.concat(DEFAULTS.status)

function isApp(token) { return typeof token === "string" && token.indexOf("app:") === 0 }

function resolve(items, pinned) {
    var pins = {}, seen = {}, out = { launchers: [], status: [] }
    ;(pinned || []).forEach(function (id) { pins["app:" + id] = true })
    GROUPS.forEach(function (group) {
        var list = items && Array.isArray(items[group]) ? items[group] : []
        list.forEach(function (token) {
            if (typeof token !== "string" || seen[token]) return
            if (isApp(token) ? !pins[token] : APPLETS.indexOf(token) < 0) return
            if (token === "controls" && group !== "status") return
            seen[token] = true; out[group].push(token)
        })
    })
    GROUPS.forEach(function (group) {
        var defaults = DEFAULTS[group]
        defaults.forEach(function (token, i) {
            if (seen[token]) return
            var at = -1
            for (var j = i + 1; j < defaults.length && at < 0; j++) at = out[group].indexOf(defaults[j])
            if (at < 0) out[group].push(token); else out[group].splice(at, 0, token)
            seen[token] = true
        })
    })
    ;(pinned || []).forEach(function (id) {
        var token = "app:" + id
        if (seen[token]) return
        var list = out.launchers, last = -1
        for (var i = 0; i < list.length; i++) if (isApp(list[i])) last = i
        if (last < 0) list.push(token); else list.splice(last + 1, 0, token)
        seen[token] = true
    })
    return out
}

function move(items, pinned, token, group, before) {
    var out = resolve(items, pinned)
    if (GROUPS.indexOf(group) < 0 || token === before) return out
    if (token === "controls" && group !== "status") return out
    if (out.launchers.indexOf(token) < 0 && out.status.indexOf(token) < 0) return out
    GROUPS.forEach(function (g) { out[g] = out[g].filter(function (t) { return t !== token }) })
    var at = before ? out[group].indexOf(before) : -1
    if (at < 0) out[group].push(token); else out[group].splice(at, 0, token)
    return out
}

function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }
