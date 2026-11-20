// Keep endpoint URLs and diagnostics out of the UI; only display server names and health.
function parseMcp(text) {
    return String(text).replace(/\x1b\[[0-9;]*m/g, "").split(/\r?\n/).flatMap(line => {
        const match = line.match(/^(.+?):\s+.*? - (.+)$/)
        if (!match) return []
        const detail = match[2]
        const connected = detail.includes("✔ Connected")
        return [{name: match[1], connected: connected,
            status: connected ? "Connected" : detail.includes("Needs authentication") ? "Sign-in required"
                : detail.includes("Not configured") ? "Not configured" : "Unavailable"}]
    })
}
