-- The same role map is read by Quickshell and oninix-display.
-- Control Center overrides live in $XDG_STATE_HOME/oninix/monitors.conf, keyed by
-- monitor description (or port), and are read here as data, never executed.
local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local function read_ini(file, section_pattern)
    local list, by_name, current = {}, {}, nil
    if not file then return list, by_name end
    for line in file:lines() do
        local section = line:match(section_pattern)
        if section then
            current = {}; list[#list + 1] = current; by_name[section] = current
        elseif current then
            local key, value = line:match("^([%w_]+)%s*=%s*(.-)%s*$")
            if key then
                if value == "true" then current[key] = true
                elseif value == "false" then current[key] = false
                elseif value:match("^%-?%d+%.?%d*$") then current[key] = tonumber(value)
                else current[key] = value end
            end
        end
    end
    file:close()
    return list, by_name
end
local roles, by_name = read_ini(io.open("/etc/oninix/monitors.conf", "r") or io.open(os.getenv("HOME") .. "/.config/oninix/monitors.conf", "r"), "^%[([%w_]+)%]$")
local _, saved = read_ini(io.open(state .. "/oninix/monitors.conf", "r"), "^%[(.+)%]$")
local by_output = {}
for _, role in ipairs(roles) do by_output[role.output] = role end

-- On the laptop any connected external display is the desk: it becomes main, and
-- closing the lid then turns the internal panel off instead of suspending.
local internal = os.getenv("ONINIX_LAPTOP") == "1" and by_name.main and by_name.main.output or nil
local lid_closed = false
local lid_state_path
if internal then
    -- Discover once; later checks read procfs directly without spawning a process
    -- on the compositor event loop.
    local paths = io.popen("printf '%s\\n' /proc/acpi/button/lid/*/state")
    if paths then
        lid_state_path = paths:read("*l")
        paths:close()
    end
end
local function read_lid()
    local file = lid_state_path and io.open(lid_state_path, "r")
    if not file then return nil end
    local value = file:read("*a") or ""
    file:close()
    return value:match("closed") ~= nil
end
if internal then
    lid_closed = read_lid() == true
end
local function external_monitor(preferred)
    if not internal then return nil end
    local ok, list = pcall(hl.get_monitors)
    local first = nil
    for _, m in ipairs(ok and list or {}) do
        if m.name ~= internal then
            if m.name == preferred then return m end
            if not first or m.name < first.name then first = m end
        end
    end
    return first
end

local profile_file = io.open(state .. "/theme/displays.conf", "r")
if profile_file then
    local profile = profile_file:read("*a")
    profile_file:close()
    if by_name.tv and profile:match("^profile=extended%s*$") then
        local tv = by_name.tv
        tv.disabled = false
        -- Use declared geometry before outputs exist; reconcile actual geometry later.
        local main = by_name.main
        local mw = tonumber(main.mode:match("^(%d+)x"))
        local mx, my = main.position:match("^(%-?%d+)x(%-?%d+)$")
        local w, h = tv.mode:match("^(%d+)x(%d+)@")
        if mw and mx and w and h then
            tv.position = math.floor(tonumber(mx) + (mw / main.scale - tonumber(w) / tv.scale) / 2) .. "x" .. math.floor(tonumber(my) - tonumber(h) / tv.scale)
        else tv.position = "auto-up" end
    end
end

-- Saved settings follow the physical monitor. Before outputs exist, trust the
-- last port it was seen on, unless another monitor now sits there.
local function live_monitors()
    local by_desc, desc_of = {}, {}
    local ok, list = pcall(hl.get_monitors)
    for _, m in ipairs(ok and list or {}) do
        if m.description then by_desc[m.description] = m.name; desc_of[m.name] = m.description end
    end
    return by_desc, desc_of
end
local function resolve(key, by_desc, desc_of)
    if key:sub(1, 5) ~= "desc:" then return key end
    local desc = key:sub(6)
    if by_desc[desc] then return by_desc[desc] end
    local last = saved[key] and saved[key].output
    if last and desc_of[last] == nil then return last end
    return nil
end
local SETTINGS = { "mode", "position", "scale", "transform", "vrr", "disabled", "sdrbrightness" }
local function custom_rules()
    local by_desc, desc_of = live_monitors()
    local rules = {}
    for key, entry in pairs(saved) do
        local name = key ~= "primary" and resolve(key, by_desc, desc_of)
        if name then
            local rule = {}
            for k, v in pairs(by_output[name] or {}) do rule[k] = v end
            for _, k in ipairs(SETTINGS) do if entry[k] ~= nil then rule[k] = entry[k] end end
            if entry.hdr == true then rule.cm, rule.bitdepth = "hdr", 10 end
            if type(entry.mirror) == "string" and entry.mirror ~= "" then
                rule.mirror = resolve(entry.mirror, by_desc, desc_of)
            end
            rule.output = name
            rules[name] = rule
        end
    end
    return rules
end
local function primary_name()
    local p = saved.primary
    if not p or type(p.display) ~= "string" then return nil end
    local by_desc, desc_of = live_monitors()
    return resolve(p.display, by_desc, desc_of)
end

local custom, applied = custom_rules(), {}
local function signature(rule)
    local parts = {}
    for k, v in pairs(rule) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    table.sort(parts)
    return table.concat(parts, ";")
end
local function set_monitor(rule)
    if rule.output == internal and lid_closed and external_monitor() then rule = { output = internal, disabled = true } end
    if rule.disabled then rule = { output = rule.output, disabled = true } end
    local sig = signature(rule)
    if applied[rule.output] == sig then return end
    hl.monitor(rule)
    applied[rule.output] = sig
end
for _, monitor in ipairs(roles) do set_monitor(custom[monitor.output] or monitor) end
for name, rule in pairs(custom) do
    if not by_output[name] then set_monitor(rule) end
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- A docked laptop learns which port each monitor landed on only after it appears.
local function refresh_custom()
    local before = custom
    custom = custom_rules()
    for _, rule in pairs(custom) do set_monitor(rule) end
    for name in pairs(before) do
        if not custom[name] then
            set_monitor(by_output[name] or { output = name, mode = "preferred", position = "auto", scale = 1 })
        end
    end
end

-- The Edge is an appliance surface, never an application monitor.
local function main_monitor()
    local primary = primary_name()
    local external = external_monitor(primary)
    if external then return external end
    local main = (primary and hl.get_monitor(primary)) or (by_name.main and hl.get_monitor(by_name.main.output))
    if main then return main end
    local ok, list = pcall(hl.get_monitors)
    for _, m in ipairs(ok and list or {}) do
        if not (by_name.edge and m.name == by_name.edge.output) then return m end
    end
end
local bound_main, tv_geometry = nil, nil
local function reconcile(main)
    if bound_main ~= main.name then
        for i = 1, 10 do
            hl.workspace_rule({ workspace = tostring(i), monitor = main.name, default = i == 1 })
        end
        -- Docking moves the desktop to the external display at once.
        if internal and main.name ~= internal then
            for _, ws in ipairs(hl.get_workspaces()) do
                local n = tonumber(ws.name)
                if not ws.special and n and n >= 1 and n <= 10 and ws.monitor and ws.monitor.name == internal then
                    hl.dispatch(hl.dsp.workspace.move({ workspace = ws, monitor = main }))
                end
            end
        end
        bound_main = main.name
    end
    local tv = by_name.tv and hl.get_monitor(by_name.tv.output)
    -- A TV placed by hand in Control Center keeps its position.
    if tv and not (custom[tv.name] and custom[tv.name].position) then
        local x = math.floor(main.x + (main.width / main.scale - tv.width / tv.scale) / 2)
        local y = math.floor(main.y - tv.height / tv.scale)
        local geometry = table.concat({main.name, x, y, tv.width, tv.height, tv.scale}, ":")
        if geometry ~= tv_geometry then
            local rule = {}
            for key, value in pairs(by_name.tv) do rule[key] = value end
            rule.output, rule.position, rule.disabled = tv.name, x .. "x" .. y, false
            hl.monitor(rule)
            tv_geometry = geometry
        end
    else tv_geometry = nil end
end
if by_name.edge then
    hl.workspace_rule({ workspace = "name:edge", monitor = by_name.edge.output, default = true, persistent = true })
end
if by_name.tv then
    hl.workspace_rule({ workspace = "11", monitor = by_name.tv.output, default = true })
end
-- Ordinary windows follow the active workspace, including the TV.
hl.config({ misc = { mouse_move_focuses_monitor = false } })

local protecting = false
local function protect_edge()
    if protecting then return end
    local main = main_monitor()
    if not main then return end
    protecting = true
    local ok, err = pcall(function()
        reconcile(main)
        if not by_name.edge then return end
        for _, ws in ipairs(hl.get_workspaces()) do
            if not ws.special and ws.name ~= "edge" and ws.monitor and ws.monitor.name == by_name.edge.output then
                hl.dispatch(hl.dsp.workspace.move({ workspace = ws, monitor = main }))
            end
        end
        for _, win in ipairs(hl.get_windows()) do
            local minimized = win.workspace and win.workspace.name == "special:minimized"
            if not minimized and win.monitor and win.monitor.name == by_name.edge.output then
                hl.dispatch(hl.dsp.window.move({ window = win, workspace = "1", follow = false }))
                if win.floating then
                    hl.dispatch(hl.dsp.window.move({ window = win, x = main.x + 80, y = main.y + 80 }))
                end
            end
        end
    end)
    protecting = false
    if not ok then print("Edge protection will retry: " .. tostring(err)) end
end
-- Re-enabling uses the same rule as at startup, so saved Displays settings stay in force.
local function apply_lid()
    if not internal then return end
    set_monitor(custom[internal] or by_name.main)
end
hl.on("monitor.added", function()
    local ok, err = pcall(refresh_custom)
    if not ok then print("Display settings will retry: " .. tostring(err)) end
    apply_lid()
    protect_edge()
end)
if internal then
    -- Unplugging with the lid shut brings the panel back; logind then suspends.
    hl.on("monitor.removed", function() apply_lid(); protect_edge() end)
    -- Switch events can be missed across resume/input reconfiguration. Reconcile
    -- against the kernel state, including a display connected while already shut.
    hl.timer(function()
        local closed = read_lid()
        if closed ~= nil then lid_closed = closed end
        apply_lid()
    end, { timeout = 1000, type = "repeat" })
    hl.bind("switch:on:Lid Switch", function() lid_closed = true; apply_lid(); protect_edge() end, { locked = true })
    hl.bind("switch:off:Lid Switch", function() lid_closed = false; apply_lid(); protect_edge() end, { locked = true })
end
for _, event in ipairs({ "window.open", "window.move_to_workspace", "workspace.move_to_monitor", "config.reloaded" }) do
    hl.on(event, protect_edge)
end
-- Also catches floating windows dragged across the output boundary.
hl.timer(protect_edge, { timeout = 500, type = "repeat" })
protect_edge()

return {
    tv_monitor = function() return by_name.tv and hl.get_monitor(by_name.tv.output) end,
    main_monitor = main_monitor,
}
