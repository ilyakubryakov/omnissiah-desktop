
local titlebars = require("titlebars")
local own_float = require("rules").own_float

local M = { enabled = false, modes = {} }
local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/oninix/"
local path = state_dir .. "window-mode.conf"
local tag = "oninix-mode-tiled"
local ws_tag = titlebars.WORKSPACE_TAG
local opened_tag = "oninix-mode-opened"
local LAST_WORKSPACE = 2147483647
local busy = false

local function has_tag(window, name)
    for _, value in ipairs(window.tags or {}) do
        if value == name or value == name .. "*" then return true end
    end
    return false
end

local function managed_id(ws)
    if not ws or ws.special then return nil end
    local id = tonumber(ws.id)
    if not id or id < 1 then return nil end
    return id
end

function M.floating_ws(ws)
    local id = managed_id(ws)
    if not id then return false end
    local mode = M.modes[tostring(id)]
    if mode then return mode == "floating" end
    return M.enabled
end

function M.anything_floats()
    if M.enabled then return true end
    for _, mode in pairs(M.modes) do
        if mode == "floating" then return true end
    end
    return false
end

local function floating_ranges()
    local ranges = {}
    if M.enabled then
        local tiled = {}
        for id, mode in pairs(M.modes) do
            local n = tonumber(id)
            if n and n >= 1 and mode ~= "floating" then tiled[#tiled + 1] = n end
        end
        table.sort(tiled)
        local from = 1
        for _, n in ipairs(tiled) do
            if n > from then ranges[#ranges + 1] = { from, n - 1 } end
            from = math.max(from, n + 1)
        end
        ranges[#ranges + 1] = { from, LAST_WORKSPACE }
    else
        for id, mode in pairs(M.modes) do
            local n = tonumber(id)
            if n and n >= 1 and mode == "floating" then ranges[#ranges + 1] = { n, n } end
        end
        table.sort(ranges, function(a, b) return a[1] < b[1] end)
    end
    return ranges
end

local function workarea(window)
    local m = window.monitor
    if not m or not m.width then return nil end
    local width, height = m.width / m.scale, m.height / m.scale
    if (m.transform or 0) % 2 == 1 then width, height = height, width end
    local reserved = m.reserved or {}
    return width - (reserved.left or 0) - (reserved.right or 0), height - (reserved.top or 0) - (reserved.bottom or 0)
end

local OPEN_WIDTH = "min(1600,monitor_w*0.6)"
local OPEN_HEIGHT = "min(1100,monitor_h*0.75)"

local function place(window)
    local width, height = workarea(window)
    if not width then return end
    hl.dispatch(hl.dsp.window.resize({ window = window, relative = false,
        x = math.floor(math.min(1600, width * 0.6)), y = math.floor(math.min(1100, height * 0.75)) }))
    hl.dispatch(hl.dsp.window.center({ window = window }))
end

local function cascade(window)
    local at = window.at
    if not at then return end
    for _ = 1, 8 do
        local taken = false
        for _, other in ipairs(hl.get_windows()) do
            local same_group = false
            for _, m in ipairs((window.group and window.group.members) or {}) do
                if m.address == other.address then same_group = true end
            end
            if other.address ~= window.address and not same_group and other.floating and other.mapped
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

local function float_all(windows)
    local claiming = {}
    local all, seen = {}, {}
    for _, w in ipairs(windows) do
        local members = (w.group and w.group.members) or { w }
        for _, m in ipairs(members) do
            if m.address and not seen[m.address] then seen[m.address] = true; all[#all + 1] = m end
        end
    end
    windows = all
    for _, w in ipairs(windows) do
        hl.dispatch(hl.dsp.window.tag({ window = w, tag = "+" .. ws_tag }))
        if not w.floating and (w.fullscreen or 0) == 0 then
            hl.dispatch(hl.dsp.window.tag({ window = w, tag = "+" .. tag }))
            claiming[#claiming + 1] = w
        end
    end
    local placed = {}
    for _, w in ipairs(claiming) do
        local first = (w.group and w.group.members and w.group.members[1]) or w
        if not placed[first.address or w.address] then
            placed[first.address or w.address] = true
            hl.dispatch(hl.dsp.window.float({ window = w, action = "enable" }))
            place(w)
            cascade(w)
        end
    end
end

local function tile(window)
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. ws_tag }))
    if not has_tag(window, tag) or window.pinned then return end
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. tag }))
    hl.dispatch(hl.dsp.window.float({ window = window, action = "disable" }))
end

local function arrange(windows)
    local floating = {}
    for _, w in ipairs(windows) do
        if w.mapped then
            if not managed_id(w.workspace) then
                if has_tag(w, ws_tag) then hl.dispatch(hl.dsp.window.tag({ window = w, tag = "-" .. ws_tag })) end
            elseif M.floating_ws(w.workspace) then
                floating[#floating + 1] = w
            else
                tile(w)
            end
        end
    end
    float_all(floating)
end

local function arrange_later(window)
    local address = window and window.address
    if not address then return end
    hl.timer(function()
        local w = hl.get_window("address:" .. address)
        if w then arrange({ w }) end
    end, { type = "oneshot", timeout = 1 })
end

local open_rules = 0
local function not_floating_on_their_own(match)
    local alternatives = {}
    for _, pattern in ipairs(own_float.class) do alternatives[#alternatives + 1] = "(?:" .. pattern .. ")" end
    match.class = "negative:^(?:" .. table.concat(alternatives, "|") .. ")$"
    alternatives = {}
    for _, pattern in ipairs(own_float.title) do alternatives[#alternatives + 1] = "(?:" .. pattern .. ")" end
    match.title = "negative:^(?:" .. table.concat(alternatives, "|") .. ")$"
    return match
end

local suppress_rules = 0
local function sync_rules()
    local ranges = floating_ranges()
    for i, r in ipairs(ranges) do
        hl.window_rule({
            name = "oninix-floating-open-" .. i, enabled = true,
            match = not_floating_on_their_own({ workspace = string.format("r[%d-%d]", r[1], r[2]), modal = false }),
            float = true, size = OPEN_WIDTH .. " " .. OPEN_HEIGHT, center = true, tag = "+" .. opened_tag,
        })
    end
    for i = #ranges + 1, open_rules do hl.window_rule({ name = "oninix-floating-open-" .. i, enabled = false }) end
    open_rules = math.max(open_rules, #ranges)

    local tiled, from = {}, 1
    for _, r in ipairs(ranges) do
        if r[1] > from then tiled[#tiled + 1] = { from, r[1] - 1 } end
        from = r[2] + 1
    end
    if from <= LAST_WORKSPACE then tiled[#tiled + 1] = { from, LAST_WORKSPACE } end
    for i, r in ipairs(tiled) do
        hl.window_rule({ name = "oninix-tiling-maximize-" .. i, enabled = true,
            match = { workspace = string.format("r[%d-%d]", r[1], r[2]) }, suppress_event = "maximize" })
    end
    for i = #tiled + 1, suppress_rules do hl.window_rule({ name = "oninix-tiling-maximize-" .. i, enabled = false }) end
    suppress_rules = math.max(suppress_rules, #tiled)
end

local floating_ready = false
local function set_up_floating()
    if floating_ready then return titlebars.setup() end
    floating_ready = true
    if not hl.get_config("decoration.shadow.enabled") then
        local colors = ONINIX_TITLEBAR or {}
        hl.config({ decoration = { shadow = { enabled = true, range = 16, render_power = 3, color = colors.shadow or "rgba(00000059)" } } })
        hl.window_rule({ name = "oninix-no-shadow", match = { class = ".*" }, no_shadow = true })
        hl.window_rule({ name = "oninix-floating-shadow", match = { tag = ws_tag }, no_shadow = false })
    end
    return titlebars.setup()
end

local function opened(window)
    if not window or not window.mapped then return end
    if not M.floating_ws(window.workspace) then
        if has_tag(window, opened_tag) and managed_id(window.workspace) then
            hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. tag }))
            tile(window)
        end
        return
    end
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. ws_tag }))
    if has_tag(window, opened_tag) then
        hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. tag }))
    elseif not window.floating then
        float_all({ window })
    end
    for _, other in ipairs(hl.get_windows()) do
        if other.address ~= window.address and other.workspace and window.workspace
            and other.workspace.id == window.workspace.id and (other.fullscreen or 0) == 1 then
            hl.dispatch(hl.dsp.window.fullscreen({ window = other, mode = "maximized", action = "unset" }))
        end
    end
    cascade(window)
end

local function apply_all()
    hl.config({ group = { auto_group = not M.enabled } })
    sync_rules()
    if M.anything_floats() or titlebars.loaded() then set_up_floating() end
    arrange(hl.get_windows())
end

local function save(enabled, modes)
    local f, err = io.open(path .. ".tmp", "w")
    if not f then error(err) end
    f:write("mode=" .. (enabled and "floating" or "tiling") .. "\n")
    local ids = {}
    for id in pairs(modes) do ids[#ids + 1] = tonumber(id) end
    table.sort(ids)
    for _, id in ipairs(ids) do f:write("ws." .. id .. "=" .. modes[tostring(id)] .. "\n") end
    f:close()
end

local function change(enabled, modes)
    if busy then return end
    busy = true
    local before_enabled, before_modes = M.enabled, M.modes
    local ok, err = pcall(function()
        save(enabled, modes)
        M.enabled, M.modes = enabled, modes
        apply_all()
        local saved, why = os.rename(path .. ".tmp", path)
        if not saved then error(why) end
    end)
    if not ok then
        os.remove(path .. ".tmp")
        M.enabled, M.modes = before_enabled, before_modes
        pcall(apply_all)
    end
    busy = false
    if not ok then error(err) end
end

local function copy(modes)
    local out = {}
    for k, v in pairs(modes) do out[k] = v end
    return out
end

function M.set(on) change(on, M.modes) end
function M.toggle() M.set(not M.enabled) end

function M.toggle_workspace(ws)
    ws = ws or hl.get_active_workspace()
    local id = managed_id(ws)
    if not id then return nil end
    local want = M.floating_ws(ws) and "tiling" or "floating"
    local modes = copy(M.modes)
    if (want == "floating") == M.enabled then modes[tostring(id)] = nil else modes[tostring(id)] = want end
    change(M.enabled, modes)
    return want
end

for _, kv in ipairs(require("prefs").lines("window-mode")) do
    if kv[1] == "mode" then
        M.enabled = kv[2] == "floating"
    else
        local id = kv[1]:match("^ws%.(%d+)$")
        if id and (kv[2] == "floating" or kv[2] == "tiling") then M.modes[id] = kv[2] end
    end
end

hl.on("window.open", function(w) opened(w) end)
hl.on("window.move_to_workspace", function(w) arrange_later(w) end)
hl.on("window.fullscreen", function(w) arrange_later(w) end)

local ok, err = pcall(apply_all)
if not ok then hl.notification.create({ text = "Window mode: " .. tostring(err), timeout = 8000 }) end
return M
