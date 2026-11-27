local M = { workspace = "special:minimized" }
local desktop_tag = "oninix-show-desktop"

local function is_minimized(window)
    return window and window.workspace and window.workspace.name == M.workspace
end

local function find(selector)
    if selector == nil then return hl.get_active_window() end
    return hl.get_window(selector)
end

local function tagged(window)
    for _, value in ipairs(window.tags or {}) do
        if value == desktop_tag then return true end
    end
    return false
end

local function current_workspace()
    local monitor = hl.get_active_monitor()
    local ws = monitor and monitor.active_workspace
    if not ws or ws.special then
        local main = require("outputs").main_monitor()
        ws = main and main.active_workspace
    end
    if ws and not ws.special then return ws end
    return nil
end

local function target_workspace()
    local ws = current_workspace()
    return ws and tostring(ws.id) or "1"
end

local function release_focus()
    if not is_minimized(hl.get_active_window()) then return end
    local ws = current_workspace()
    if not ws then return end
    local id = tostring(ws.id)
    hl.dispatch(hl.dsp.focus({ workspace = id == "1" and "2" or "1" }))
    hl.dispatch(hl.dsp.focus({ workspace = id }))
end

local function park(window)
    if not window or not window.mapped or window.pinned or window.modal or is_minimized(window) then return false end
    if window.workspace and window.workspace.special then return false end
    if (window.fullscreen or 0) >= 2 then
        hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = "fullscreen", action = "unset" }))
    end
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = M.workspace, follow = false }))
    return true
end

function M.minimize(selector)
    local window = find(selector)
    if park(window) then release_focus() end
end

function M.minimize_app(selector)
    local window = find(selector)
    if not window or not window.class or window.class == "" then return end
    for _, w in ipairs(hl.get_windows()) do
        if w.class == window.class then park(w) end
    end
    release_focus()
end

function M.show(selector)
    local window = find(selector)
    if not window then return end
    if is_minimized(window) then
        hl.dispatch(hl.dsp.window.move({ window = window, workspace = target_workspace(), follow = false }))
    end
    if tagged(window) then hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. desktop_tag })) end
    hl.dispatch(hl.dsp.focus({ window = window }))
end

function M.close(selector)
    local window = find(selector)
    if window then hl.dispatch(hl.dsp.window.close({ window = window })) end
end

function M.toggle_desktop()
    local hidden = {}
    for _, w in ipairs(hl.get_windows()) do
        if is_minimized(w) and tagged(w) then hidden[#hidden + 1] = w end
    end
    if #hidden > 0 then
        local target = target_workspace()
        for _, w in ipairs(hidden) do
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = target, follow = false }))
            hl.dispatch(hl.dsp.window.tag({ window = w, tag = "-" .. desktop_tag }))
        end
        return
    end
    local ws = current_workspace()
    if not ws then return end
    for _, w in ipairs(hl.get_workspace_windows(tostring(ws.id)) or {}) do
        if park(w) then hl.dispatch(hl.dsp.window.tag({ window = w, tag = "+" .. desktop_tag })) end
    end
    release_focus()
end

M.is_minimized = is_minimized
return M
