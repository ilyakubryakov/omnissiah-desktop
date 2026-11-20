.pragma library

// Pure helpers for the notification centre; quickshell/tests/notifications.test.cjs covers them.

// Live notifications first by id, then history; repeats of one title from one app
// fold into the newest card, which carries every id for dismissal.
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

// The rule that applies at a scope: the exact title, or the whole application.
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

function plainText(body) {
    return String(body || "").replace(/<[^>]*>/g, "")
        .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
}

// Expose explicit web links only; never execute notification-supplied markup.
function links(body) {
    var matches = String(body || "").match(/https?:\/\/[^\s<>"']+/gi) || []
    var out = []
    matches.forEach(function (url) {
        url = url.replace(/&amp;/g, "&").replace(/[.,;!?)]+$/, "")
        if (out.indexOf(url) < 0 && out.length < 3) out.push(url)
    })
    return out
}

function verificationCode(summary, body) {
    var text = plainText(summary + " " + body)
    if (!/verif|one.time|login|sign.in|authentic|security|код|подтвержд|вход/i.test(text)) return ""
    var match = text.match(/\b\d{4,8}\b/)
    return match ? match[0] : ""
}
