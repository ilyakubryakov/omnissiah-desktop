local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local prefs = { windows = "flat", gap = "0", outer = "0", motion = "off", density = "compact" }
local file = io.open(state .. "/theme/desktop.conf", "r")
if file then
    for line in file:lines() do
        local key, value = line:match("^(%w+)=(%w+)$")
        if key and prefs[key] then prefs[key] = value end
    end
    file:close()
end
local function bounded(key)
    return math.max(0, math.min(24, tonumber(prefs[key]) or 0))
end
local soft = prefs.windows == "soft"
local smooth = prefs.motion == "smooth"
hl.config({
    general = { gaps_in = bounded("gap") / 2, gaps_out = bounded("outer") },
    decoration = { rounding = soft and 10 or 0,
        shadow = { enabled = soft, range = 16, render_power = 3 } },
    animations = { enabled = prefs.motion == "subtle" or smooth },
})
hl.curve("stationEase", { type = "bezier", points = { { 0.2, 0.8 }, { 0.2, 1 } } })
hl.animation({ leaf = "global", enabled = true, speed = smooth and 2.8 or 1.5, bezier = "stationEase" })
hl.animation({ leaf = "windows", enabled = true, speed = smooth and 2.8 or 1.5, bezier = "stationEase", style = "popin 98%" })
hl.animation({ leaf = "fade", enabled = true, speed = smooth and 2.2 or 1.2, bezier = "stationEase" })
hl.animation({ leaf = "workspaces", enabled = true, speed = smooth and 3.2 or 1.8, bezier = "stationEase", style = "fade" })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })
