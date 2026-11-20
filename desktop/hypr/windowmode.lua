-- Global desktop-style floating. Static tags survive config reloads with their windows.
local M = { enabled = false }
local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/oninix/"
local path = state_dir .. "window-mode.conf"
local tag = "oninix-mode-tiled"
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

local function workarea(window)
    local m = window.monitor
    if not m then return nil end
    return m.width / m.scale, m.height / m.scale
end

-- Keep an oversized floating window inside a desktop-like default size.
local function fit(window)
    local width, height = workarea(window)
    local size = window.size
    if not width or not size or window.fullscreen ~= 0 then return end
    if size.x > width * 0.85 or size.y > height * 0.85 then
        hl.dispatch(hl.dsp.window.resize({ window = window, relative = false,
            x = math.floor(math.min(1600, width * 0.6)), y = math.floor(math.min(1100, height * 0.75)) }))
        hl.dispatch(hl.dsp.window.center({ window = window }))
    end
end

local function float(window)
    if not eligible(window) or window.floating then return end
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. tag }))
    hl.dispatch(hl.dsp.window.float({ window = window, action = "enable" }))
    fit(window)
end

-- Cascade a new window off one that sits at exactly the same spot.
local function cascade(window)
    local at = window.at
    if not at then return end
    for _ = 1, 8 do
        local taken = false
        for _, other in ipairs(hl.get_windows()) do
            if other ~= window and other.address ~= window.address and other.floating and other.mapped
                and other.workspace and window.workspace and other.workspace.id == window.workspace.id
                and other.at and math.abs(other.at.x - at.x) < 8 and math.abs(other.at.y - at.y) < 8 then
                taken = true
                break
            end
        end
        if not taken then return end
        hl.dispatch(hl.dsp.window.move({ window = window, x = 32, y = 32, relative = true }))
        at = { x = at.x + 32, y = at.y + 32 }
    end
end

-- A window opened in Floating maps floating at the size it asks for, like on a
-- stacking desktop. A remembered maximized state is not restored; the title bar
-- or a double click maximizes on demand.
local function opened(window)
    if not window or not window.mapped or not window.workspace then return end
    if window.workspace.name == "edge" then return end
    if not window.floating then return float(window) end
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. tag }))
    if window.fullscreen == 1 then
        hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = "maximized", action = "unset" }))
    end
    fit(window)
    cascade(window)
end

-- New windows float from their first frame instead of flashing tiled first.
local new_floating = hl.window_rule({ name = "oninix-floating-desktop", match = { class = ".*" }, float = true, center = true })
-- Maximization should work normally in Floating, including application titlebars.
local suppress_maximize = hl.window_rule({ name = "oninix-tiling-maximize", match = { class = ".*" }, suppress_event = "maximize" })

function M.apply(on)
    if busy then return end
    busy = true
    local ok, err = pcall(function()
        M.enabled = on
        suppress_maximize:set_enabled(not on)
        new_floating:set_enabled(on)
        hl.config({ group = { auto_group = not on } })
        local windows = hl.get_windows()
        if on then
            -- Mark the complete original set before a group dispatch can affect its peers.
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
hl.on("window.open", function(w) if M.enabled then opened(w) end end)
hl.on("window.move_to_workspace", function(w) if M.enabled then float(w) end end)
M.apply(M.enabled)
return M
