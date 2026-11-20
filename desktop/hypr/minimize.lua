-- macOS-style minimize. The hidden special workspace is the only state, so a
-- panel restart loses nothing. Restore lands on the current desktop, never the Edge.
-- A tab group moves as one window: Hyprland carries every member along.
local M = { workspace = "special:minimized" }
-- Static tags survive config reloads with their windows.
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
    if not ws or ws.special or ws.name == "edge" then
        local main = require("outputs").main_monitor()
        ws = main and main.active_workspace
    end
    if ws and not ws.special and ws.name ~= "edge" then return ws end
    return nil
end

local function target_workspace()
    local ws = current_workspace()
    return ws and tostring(ws.id) or "1"
end

-- Hyprland hands focus to the next window of the workspace, but an emptied
-- workspace keeps the hidden window focused and it would receive typing.
-- Leaving and re-entering the workspace in the same dispatch clears it.
local function release_focus()
    if not is_minimized(hl.get_active_window()) then return end
    local ws = current_workspace()
    if not ws then return end
    -- Read the id first: the emptied workspace is destroyed once we leave it.
    local id = tostring(ws.id)
    hl.dispatch(hl.dsp.focus({ workspace = id == "1" and "2" or "1" }))
    hl.dispatch(hl.dsp.focus({ workspace = id }))
end

local function park(window)
    if not window or not window.mapped or window.pinned or is_minimized(window) then return false end
    if window.workspace and (window.workspace.special or window.workspace.name == "edge") then return false end
    -- Fullscreen (bit 2) is dropped, as on macOS; maximized windows stay maximized.
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

-- Cmd+Option+M: every window of the application, on every desktop.
function M.minimize_app(selector)
    local window = find(selector)
    if not window or not window.class or window.class == "" then return end
    for _, w in ipairs(hl.get_windows()) do
        if w.class == window.class then park(w) end
    end
    release_focus()
end

-- Focuses a visible window; a minimized one first moves to the current desktop.
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

-- Show desktop: minimize the current desktop; the second press brings the
-- same windows back, unless they were restored or closed in between.
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
