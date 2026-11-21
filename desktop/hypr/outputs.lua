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

local tv_output = by_name.tv and by_name.tv.output
local internal = os.getenv("ONINIX_LAPTOP") == "1" and by_name.main and by_name.main.output or nil
local lid_closed = false
local lid_state_path
if internal then
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
        if m.name ~= internal and m.name ~= tv_output then
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
        local main = by_name.main or {}
        local mw = tonumber(tostring(main.mode):match("^(%d+)x"))
        local mx, my = tostring(main.position):match("^(%-?%d+)x(%-?%d+)$")
        local w, h = tostring(tv.mode):match("^(%d+)x(%d+)@")
        local ms, ts = tonumber(main.scale), tonumber(tv.scale)
        if mw and mx and w and ms and ms > 0 and ts and ts > 0 then
            local x = math.floor(tonumber(mx) + (mw / ms - tonumber(w) / ts) / 2)
            local y = math.floor(tonumber(my) - tonumber(h) / ts)
            tv.position = x .. "x" .. y
        else
            tv.position = "auto-up"
        end
    end
end

local function live_monitors()
    local by_desc, desc_of = {}, {}
    local ok, list = pcall(hl.get_monitors)
    for _, m in ipairs(ok and list or {}) do
        local desc = m.description and m.description:match("^%s*(.-)%s*$")
        if desc and desc ~= "" then
            by_desc[desc] = by_desc[desc] == nil and m.name or false
            desc_of[m.name] = desc
        end
    end
    return by_desc, desc_of
end
local function resolve(key, by_desc, desc_of)
    if key:sub(1, 5) ~= "desc:" then return key end
    local desc = key:sub(6)
    if by_desc[desc] then return by_desc[desc] end
    local last = saved[key] and saved[key].output
    if last and (desc_of[last] == nil or desc_of[last] == desc) then return last end
    return nil
end
local SETTINGS = { "mode", "position", "scale", "transform", "vrr", "disabled", "sdrbrightness" }
local function custom_rules()
    local by_desc, desc_of = live_monitors()
    local rules = {}
    for key, entry in pairs(saved) do
        local name = key ~= "primary" and resolve(key, by_desc, desc_of)
        if name and (key == name or not saved[name]) then
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

local function main_monitor()
    local primary = primary_name()
    local external = external_monitor(primary)
    if external then return external end
    local main = (primary and hl.get_monitor(primary)) or (by_name.main and hl.get_monitor(by_name.main.output))
    if main then return main end
    local ok, list = pcall(hl.get_monitors)
    for _, monitor in ipairs(ok and list or {}) do
        if monitor.name ~= tv_output then return monitor end
    end
end
local bound_main, tv_geometry = nil, nil
local function reconcile(main)
    if bound_main ~= main.name then
        for i = 1, 10 do
            hl.workspace_rule({ workspace = tostring(i), monitor = main.name, default = i == 1 })
        end
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
if by_name.tv then
    hl.workspace_rule({ workspace = "11", monitor = by_name.tv.output, default = true })
end
hl.config({ misc = { mouse_move_focuses_monitor = false } })

local function reconcile_displays()
    local main = main_monitor()
    if not main then return end
    local ok, err = pcall(reconcile, main)
    if not ok then print("Display configuration will retry: " .. tostring(err)) end
end
local function apply_lid()
    if not internal then return end
    set_monitor(custom[internal] or by_name.main)
end
hl.on("monitor.added", function()
    local ok, err = pcall(refresh_custom)
    if not ok then print("Display settings will retry: " .. tostring(err)) end
    apply_lid()
    reconcile_displays()
end)
if internal then
    hl.on("monitor.removed", function() apply_lid(); reconcile_displays() end)
    hl.timer(function()
        local closed = read_lid()
        if closed ~= nil then lid_closed = closed end
        apply_lid()
    end, { timeout = 1000, type = "repeat" })
    hl.bind("switch:on:Lid Switch", function() lid_closed = true; apply_lid(); reconcile_displays() end, { locked = true })
    hl.bind("switch:off:Lid Switch", function() lid_closed = false; apply_lid(); reconcile_displays() end, { locked = true })
end
hl.on("config.reloaded", reconcile_displays)
hl.on("monitor.removed", reconcile_displays)
reconcile_displays()

local function fit_control_station()
    for _, window in ipairs(hl.get_windows()) do
        local m = window.monitor
        if window.class == "org.quickshell" and window.title == "Control Station" and window.mapped and window.floating
            and window.workspace and not window.workspace.special and m and window.at and window.size then
            local w, h = m.width / m.scale, m.height / m.scale
            if (m.transform or 0) % 2 ~= 0 then w, h = h, w end
            local width = math.min(window.size.x, math.max(1, math.floor(w - 40)))
            local height = math.min(window.size.y, math.max(1, math.floor(h - 80)))
            local clipped = window.at.x < m.x or window.at.y < m.y
                or window.at.x + window.size.x > m.x + w or window.at.y + window.size.y > m.y + h
            if width < window.size.x or height < window.size.y then
                hl.dispatch(hl.dsp.window.resize({ window = window, relative = false, x = width, y = height }))
                clipped = true
            end
            if clipped then hl.dispatch(hl.dsp.window.center({ window = window })) end
        end
    end
end

return {
    has_tv_role = function() return by_name.tv ~= nil end,
    tv_monitor = function() return by_name.tv and hl.get_monitor(by_name.tv.output) end,
    main_monitor = main_monitor,
    fit_control_station = fit_control_station,
}
