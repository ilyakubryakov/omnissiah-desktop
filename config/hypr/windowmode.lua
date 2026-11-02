local M = { enabled = false }
local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/station/"
local path = state_dir .. "window-mode.conf"
local tag = "station-mode-tiled"
local busy = false

local function tagged(window)
    for _, value in ipairs(window.tags or {}) do
        if value == tag then return true end
    end
    return false
end

local function eligible(window)
    return window and window.mapped and window.workspace and window.workspace.name ~= "edge"
end

local function float(window)
    if not eligible(window) or window.floating then return end
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. tag }))
    hl.dispatch(hl.dsp.window.float({ window = window, action = "enable" }))
    local m, size = window.monitor, window.size
    if m and size and window.fullscreen == 0 then
        local width, height = m.width / m.scale, m.height / m.scale
        if size.x > width * 0.85 or size.y > height * 0.85 then
            hl.dispatch(hl.dsp.window.resize({ window = window, relative = false,
                x = math.floor(math.min(1120, width * 0.78)), y = math.floor(math.min(820, height * 0.78)) }))
            hl.dispatch(hl.dsp.window.center({ window = window }))
        end
    end
end

local suppress_maximize = hl.window_rule({ name = "station-tiling-maximize", match = { class = ".*" }, suppress_event = "maximize" })

function M.apply(on)
    if busy then return end
    busy = true
    local ok, err = pcall(function()
        M.enabled = on
        suppress_maximize:set_enabled(not on)
        hl.config({ group = { auto_group = not on } })
        local windows = hl.get_windows()
        if on then

            for _, w in ipairs(windows) do
                if eligible(w) and not w.floating then
                    hl.dispatch(hl.dsp.window.tag({ window = w, tag = "+" .. tag }))
                end
            end
            for _, w in ipairs(windows) do float(w) end
        else
            for _, w in ipairs(windows) do
                if eligible(w) and tagged(w) then
                    hl.dispatch(hl.dsp.window.float({ window = w, action = "disable" }))
                    hl.dispatch(hl.dsp.window.tag({ window = w, tag = "-" .. tag }))
                end
            end
        end
    end)
    busy = false
    if not ok then error(err) end
end

function M.set(on)
    local f, err = io.open(path .. ".tmp", "w")
    if not f then error(err) end
    f:write("mode=" .. (on and "floating" or "tiling") .. "\n")
    f:close()
    local previous = M.enabled
    local ok, why = pcall(M.apply, on)
    if not ok then
        os.remove(path .. ".tmp")
        pcall(M.apply, previous)
        error(why)
    end
    local saved, save_error = os.rename(path .. ".tmp", path)
    if not saved then
        pcall(M.apply, previous)
        error(save_error)
    end
end

function M.toggle() M.set(not M.enabled) end

for _, kv in ipairs(require("prefs").lines("window-mode")) do
    if kv[1] == "mode" then M.enabled = kv[2] == "floating" end
end
hl.on("window.open", function(w) if M.enabled then float(w) end end)
hl.on("window.move_to_workspace", function(w) if M.enabled then float(w) end end)
M.apply(M.enabled)
return M
