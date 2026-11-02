.pragma library

function number(value) {
    return typeof value === "number" && isFinite(value) ? value : null;
}
function percent(value) {
    var n = number(value);
    return n === null ? 0 : Math.max(0, Math.min(100, n));
}
function reading(value, unit) {
    var n = number(value);
    return n === null ? "n/a" : Math.round(n) + unit;
}
function quota(window) {
    return window && number(window.pct) !== null ? Math.round(window.pct) + "%" : "n/a";
}
function nextEvent(events, now) {
    var best = null, bestTime = Infinity;
    for (var i = 0; i < events.length; i++) {
        var e = events[i], start = Date.parse(e.s), end = Date.parse(e.e);
        if (e.a || !isFinite(start)) continue;
        var ongoing = isFinite(end) && start <= now && end > now;
        if (!ongoing && start < now) continue;
        var order = ongoing ? -Infinity : start;
        if (order < bestTime) { best = e; bestTime = order; }
    }
    return best;
}
function alerts(keys, levels, announced, pending, current) {
    var seen = {}, queue = [];
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (levels[key] === 2 && announced[key]) seen[key] = true;
    }
    for (var j = 0; j < pending.length; j++) {
        var old = pending[j];
        if (levels[old] === 2 && old !== current && queue.indexOf(old) < 0) queue.push(old);
    }
    for (var k = 0; k < keys.length; k++) {
        var fresh = keys[k];
        if (levels[fresh] === 2 && !seen[fresh]) {
            seen[fresh] = true;
            if (fresh !== current && queue.indexOf(fresh) < 0) queue.push(fresh);
        }
    }
    return { announced: seen, pending: queue };
}
function clampScroll(position, contentHeight, viewHeight) {
    return Math.max(0, Math.min(position, Math.max(0, contentHeight - viewHeight)));
}
