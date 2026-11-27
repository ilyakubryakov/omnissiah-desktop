
local M = {}
local ROOTS = "/nix/var/nix/gcroots/oninix-titlebars/"
local STATE = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/oninix/"
local QUARANTINE = STATE .. "titlebars-quarantine"
local ENABLED = "/etc/oninix/titlebars-enabled"
local LOADED = STATE .. "titlebars-loaded"
M.WORKSPACE_TAG = "oninix-floating-workspace"

M.self_framed = table.concat({
    "org\\.gnome\\..*",
}, "|")

local function exists(path)
    local file = io.open(path, "r")
    if not file then return false end
    file:close()
    return true
end

local function read(command)
    local pipe = io.popen(command)
    if not pipe then return "" end
    local out = pipe:read("*a") or ""
    pipe:close()
    return (out:gsub("%s+$", ""))
end

local function slurp(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local out = file:read("*a")
    file:close()
    return out
end

local function compositor()
    local pid = read("echo $PPID")
    return pid, read("readlink /proc/" .. pid .. "/exe 2>/dev/null")
end

local function boot_id()
    return (slurp("/proc/sys/kernel/random/boot_id") or ""):gsub("%s+$", "")
end

local function plugin_path()
    local _, exe = compositor()
    local key = exe:match("^/nix/store/([^/]+)/")
    if not key or not key:match("^[%w%.%-_+]+$") then return nil end
    local so = read("readlink -f '" .. ROOTS .. key .. "/lib/omarchy-hyprland-titlebars/titlebars.so' 2>/dev/null")
    local expected = ((slurp(ENABLED) or ""):match("^[^\n]*\n([^\n]+)") or "")
    if so == expected and exists(so) then return so end
    return nil
end

local function dispatch(lua)
    return "hyprctl eval '" .. lua .. "'"
end

local function quarantine(reason)
    os.execute("mkdir -p '" .. STATE .. "'")
    local file = io.open(QUARANTINE, "w")
    if file then file:write(os.date("!%Y-%m-%dT%H:%M:%SZ") .. " " .. reason .. "\n"); file:close() end
    hl.notification.create({ timeout = 20000, text = "Titlebars are off: " .. reason .. ". "
        .. "To turn them back on, delete " .. QUARANTINE .. " and run hyprctl reload." })
end

local function write_record(plugin, state)
    os.execute("mkdir -p '" .. STATE .. "'")
    local tmp = LOADED .. ".tmp"
    local file = io.open(tmp, "w")
    if not file then return false end
    local pid = compositor()
    local body = boot_id() .. "\n" .. pid .. "\n" .. plugin .. "\n" .. os.time() .. "\n" .. state .. "\n"
    file:write(body)
    file:close()
    os.rename(tmp, LOADED)
    return slurp(LOADED) == body
end

local GRACE = 120
local function check_last_session()
    local text = slurp(LOADED)
    if not text then return false end
    local boot, pid, since, state = text:match("^(%S+)\n(%d+)\n%S+\n(%d+)\n(%a+)")
    if pid == compositor() and boot == boot_id() then return false end
    if not boot then os.remove(LOADED); return false end
    local scope = boot == boot_id() and "-b" or ("-b " .. boot)
    if read("journalctl --no-pager -q " .. scope .. " -n 1 -o cat >/dev/null 2>&1 && echo ok") ~= "ok" then
        os.remove(LOADED)
        quarantine("the journal of the last session that loaded the titlebars plugin cannot be read")
        return false
    end
    local hit = read("journalctl --no-pager -q " .. scope .. " --since=@" .. since
        .. " -t systemd-coredump -g 'Process " .. pid .. " \\(' -o short-unix -n 1 --reverse 2>/dev/null")
    local at = tonumber(hit:match("^(%d+)"))
    if at then
        os.remove(LOADED)
        if state == "loaded" or at - tonumber(since) <= 30 then
            quarantine("Hyprland crashed in a session that loaded the titlebars plugin")
        end
        return false
    end
    local uptime = tonumber(read("ps -o etimes= -p " .. compositor()):match("%d+") or "") or GRACE
    if uptime < GRACE then return true end
    os.remove(LOADED)
    return false
end
local pending = check_last_session()
if pending then
    hl.timer(function()
        if not check_last_session() and require("windowmode").anything_floats() then
            os.execute("hyprctl reload >/dev/null 2>&1 &")
        end
    end, { type = "oneshot", timeout = GRACE * 1000 })
end

local ready = false

function M.setup()
    if ready then return false end
    if not exists(ENABLED) then
        local text = slurp(LOADED)
        if text and text:match("^%S+\n(%d+)\n") == compositor() then os.remove(LOADED) end
        return false
    end
    if exists(QUARANTINE) or pending or check_last_session() then return false end
    local plugin = plugin_path()
    if not plugin then return false end
    if not write_record(plugin, hl.plugin.hyprbars and "loaded" or "attempt") then return false end
    ready = true
    hl.plugin.load(plugin)
    if not hl.plugin.hyprbars then return true end

    local colors = ONINIX_TITLEBAR or {}
    local window = 'window = "address:%WINDOW%"'
    hl.config({
        plugin = {
            hyprbars = {
                enabled = true,
                workspace_tag = M.WORKSPACE_TAG,
                bar_height = 30,
                bar_color = colors.bar or "rgb(303030)",
                bar_color_inactive = colors.bar_inactive or colors.bar or "rgb(303030)",
                col = { text = colors.text or "rgb(dededc)" },
                bar_text_font = "JetBrainsMono Nerd Font",
                bar_text_size = 11,
                bar_text_align = "left",
                bar_buttons_alignment = "right",
                bar_part_of_window = true,
                bar_precedence_over_border = true,
                bar_padding = 10,
                bar_button_padding = 8,
                button_rounding = 0,
                icon_on_hover = false,
                on_double_click = dispatch('hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle", ' .. window .. ' }))'),
            },
        },
    })

    hl.window_rule({ name = "oninix-titlebar-self-framed", match = { class = "^(" .. M.self_framed .. ")$" }, ["hyprbars:no_bar"] = true })

    for _, button in ipairs({
        { icon = "×", action = dispatch('hl.dispatch(hl.dsp.window.close({ ' .. window .. ' }))') },
        { icon = "□", action = dispatch('hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle", ' .. window .. ' }))') },
        { icon = "−", action = dispatch('require("minimize").minimize("address:%WINDOW%")') },
    }) do
        hl.plugin.hyprbars.add_button({
            bg_color = colors.bar or "rgb(303030)",
            fg_color = colors.text or "rgb(dededc)",
            size = 20,
            icon = button.icon,
            action = button.action,
        })
    end
end

function M.loaded()
    for _, plugin in ipairs(hl.get_loaded_plugins and hl.get_loaded_plugins() or {}) do
        if plugin.name == "hyprbars" then return true end
    end
    return false
end

return M
