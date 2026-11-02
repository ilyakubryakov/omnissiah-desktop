.pragma library

function groups(current, history) {
    var live = {}, rows = [], byKey = {}, out = []
    current.forEach(function (n) { live[n.id] = true })
    rows = current.concat(history.filter(function (n) { return !live[n.id] }))
        .sort(function (a, b) { return b.id - a.id })
    rows.forEach(function (n) {
        var key = (n.app_name || "") + "\u0000" + (n.summary || "")
        var g = byKey[key]
        if (!g) {
            g = byKey[key] = {notification: n, ids: [], count: 0, live: !!live[n.id]}
            out.push(g)
        }
        g.ids.push(String(n.id)); g.count++
    })
    return out
}

function ruleTier(rules, app, summary) {
    for (var i = 0; i < (rules || []).length; i++) {
        var r = rules[i]
        if (r.app === app && r.summary === summary) return r.tier
    }
    return "normal"
}

function tierLabel(tier) {
    return {important: "Important", quiet: "Quiet", hidden: "Hidden", critical: "Critical"}[tier] || ""
}
