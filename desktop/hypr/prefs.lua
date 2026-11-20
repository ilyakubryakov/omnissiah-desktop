-- Control Center preferences: key=value lines in $XDG_STATE_HOME/oninix/<name>.conf,
-- per machine. Read as data with a bounded character set, never executed.
local M = {}
local dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/oninix/"

function M.lines(name)
    local out = {}
    local file = io.open(dir .. name .. ".conf", "r")
    if not file then return out end
    for line in file:lines() do
        local key, value = line:match("^([%w%._ %-]+)=([%w%.,%-%+]+)$")
        if key then out[#out + 1] = { key, value } end
    end
    file:close()
    return out
end

function M.number(value, low, high, default)
    return math.max(low, math.min(high, tonumber(value) or default))
end

return M
