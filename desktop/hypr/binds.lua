
local function app(cmd)
	return hl.dsp.exec_cmd("oninix-app " .. cmd)
end

local function bind(keys, action, description, opts)
	opts = opts or {}
	opts.description = description
	hl.bind(keys, action, opts)
end

local home = os.getenv("HOME")
local scripts = (os.getenv("ONINIX_SHARE") or "/run/current-system/sw/share/oninix") .. "/hypr/scripts/"

bind("SUPER + Return", app("kitty"), "terminal")
bind("SUPER + space", hl.dsp.exec_cmd("oninix-launcher"), "launcher: apps, projects, files")
bind("SUPER + D", hl.dsp.exec_cmd("oninix-shell ipc call launchpad toggle"), "launchpad: apps in folders")
bind("SUPER + E", app("dolphin"), "files")
bind("SUPER + N", hl.dsp.exec_cmd("oninix-shell ipc call notebook toggle"), "notebook: notes, calculator and timers")
bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("oninix-shell ipc call notebook capture"), "notebook: add selected text to the open note")
bind("CTRL + ALT + space", app("1password --quick-access"), "1Password quick access")
local function panel(page)
    return hl.dsp.exec_cmd("oninix-shell ipc call desktop toggle " .. page)
end
bind("SUPER + SHIFT + V", panel("clipboard"), "clipboard with previews")
bind("SUPER + CTRL + C", panel("controls"), "control center: quick toggles and sliders")
bind("SUPER + comma", panel("settings"), "settings (Control Station)")
bind("SUPER + slash", hl.dsp.exec_cmd("oninix-shell ipc call keys toggle"), "shortcuts you use every day")
bind("SUPER + CTRL + A", panel("appearance"), "appearance: palettes and wallpapers")
bind("SUPER + CTRL + U", panel("notifications"), "notification history")
bind("SUPER + CTRL + Tab", panel("overview"), "window and workspace overview")
local switcher_prefix = tostring({}):gsub("%W", "")
local switcher_sequence = 0
local function switcher(action)
    return function()
        if action ~= "accept" then switcher_sequence = switcher_sequence + 1 end
        hl.exec_cmd("oninix-shell ipc call switcher "
            .. action .. " " .. switcher_prefix .. switcher_sequence)
    end
end
bind("ALT + Tab", switcher("next"), "switch between all application windows")
for _, key in ipairs({ "Alt_L", "Alt_R" }) do
    bind(key, switcher("accept"), nil, { release = true, ignore_mods = true, non_consuming = true, transparent = true })
end
local function focus_or_start(class, cmd)
	return hl.dsp.exec_cmd(scripts .. "launch-or-focus.sh '" .. class .. "' " .. cmd)
end
local function installed(cmd)
	for _, dir in ipairs({ "/run/current-system/sw/bin/", home .. "/.nix-profile/bin/", "/etc/profiles/per-user/" .. (os.getenv("USER") or "") .. "/bin/" }) do
		local f = io.open(dir .. cmd, "r")
		if f then f:close(); return true end
	end
	return false
end
for _, app in ipairs({
	{ "SUPER + ALT + B", "google-chrome", "google-chrome-stable", "Chrome (focus or start)" },
	{ "SUPER + ALT + S", "slack", "slack", "Slack" },
	{ "SUPER + ALT + T", "telegram", "Telegram", "Telegram" },
	{ "SUPER + ALT + M", "thunderbird", "thunderbird", "Thunderbird" },
	{ "SUPER + ALT + O", "obsidian", "obsidian", "Obsidian" },
}) do
	if installed(app[3]) then bind(app[1], focus_or_start(app[2], app[3]), app[4]) end
end
bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("oninix-shell ipc call cheat toggle"),
	"this cheatsheet")

local function tv_workspace(move)
    local tv = require("outputs").tv_monitor()
    if not tv then
        hl.notification.create({ text = "Enable the TV in Control Center first", timeout = 2000 })
        return
    end
    hl.dispatch(move and hl.dsp.window.move({ workspace = "11", follow = false }) or hl.dsp.focus({ workspace = "11" }))
end
bind("SUPER + CTRL + T", function() tv_workspace(false) end, "TV workspace")
bind("SUPER + CTRL + SHIFT + T", function() tv_workspace(true) end, "send window to TV workspace")

bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), "lock")
bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(scripts .. "power-menu.sh --logout"), "log out (confirm)")
bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }), "displays off / on")
bind("SUPER + CTRL + N", hl.dsp.exec_cmd("oninix-theme-schedule --nightlight toggle"), "night light on / off")

bind("SUPER + Q", hl.dsp.window.close(), "close window")
bind("SUPER + SHIFT + W", function() require("minimize").minimize() end, "minimize window to the panel")
bind("SUPER + CTRL + W", function() require("minimize").minimize_app() end, "minimize all windows of the app")
bind("SUPER + CTRL + D", function() require("minimize").toggle_desktop() end, "show desktop / bring windows back")
bind("SUPER + V", function()
    if require("windowmode").enabled then return end
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
end, "float / tile window")
bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "maximize")
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "fullscreen")
bind("SUPER + R", hl.dsp.layout("togglesplit"), "flip split (dwindle)")

for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d" }) do
	bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }), "focus (arrows)")
	bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), "move window (arrows)")
	bind("SUPER + ALT + " .. key, hl.dsp.group.move_window({ direction = dir }),
		"move tab in group (arrows)")
	bind("SUPER + CTRL + " .. key, hl.dsp.window.resize({
		x = (dir == "l" and -60) or (dir == "r" and 60) or 0,
		y = (dir == "u" and -60) or (dir == "d" and 60) or 0,
		relative = true,
	}), "resize (arrows)", { repeating = true })
end

local function active_workspace()
	return hl.get_active_special_workspace() or hl.get_active_workspace()
end

local function workspace_key(ws)
	return ws.special and tostring(ws.name) or tostring(ws.id)
end

local function announce(text)
	hl.notification.create({ text = text, timeout = 1200 })
end

local layouts = { "dwindle", "master", "scrolling", "monocle" }
bind("SUPER + T", function()
	if require("windowmode").enabled then return end
	local ws = active_workspace()
	if not ws then
		return
	end
	local next_layout = layouts[1]
	for i, name in ipairs(layouts) do
		if name == ws.tiled_layout then
			next_layout = layouts[i % #layouts + 1]
			break
		end
	end
	hl.workspace_rule({ workspace = workspace_key(ws), layout = next_layout })
	announce("Layout: " .. next_layout)
end, "next layout: dwindle, master, scrolling, monocle")

local floating_workspaces = {}

local function set_floating(window, on)
	hl.dispatch(hl.dsp.window.float({ action = on and "enable" or "disable", window = window }))
end

bind("SUPER + SHIFT + space", function()
	if require("windowmode").enabled then return end
	local ws = active_workspace()
	if not ws then
		return
	end
	local key = workspace_key(ws)
	local on = not floating_workspaces[key]
	floating_workspaces[key] = on or nil
	for _, window in ipairs(hl.get_workspace_windows(key) or {}) do
		set_floating(window, on)
	end
	announce(on and "Floating" or "Tiling: " .. ws.tiled_layout)
end, "float / tile the whole workspace")

hl.on("window.open", function(window)
	if window and window.workspace and floating_workspaces[workspace_key(window.workspace)] then
		set_floating(window, true)
	end
end)
hl.on("window.move_to_workspace", function(window, ws)
	if window and ws and floating_workspaces[workspace_key(ws)] then
		set_floating(window, true)
	end
end)

bind("SUPER + W", hl.dsp.group.toggle(), "group into tabs / ungroup")
bind("SUPER + Tab", hl.dsp.group.next(), "next tab")
bind("SUPER + SHIFT + Tab", hl.dsp.group.prev(), "previous tab")

for i = 1, 10 do
	local key = tostring(i % 10)
	bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(i) }), "go to workspace (1..0)")
	bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }),
		"send window to workspace (1..0)")
end
bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "next workspace with mouse wheel")
bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "previous workspace with mouse wheel")

bind("SUPER + mouse:272", hl.dsp.window.drag(), "drag window", { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), "resize window", { mouse = true })

local capture = { key = "SUPER+SHIFT+S", key_save = "CTRL+SUPER+SHIFT+S" }
for _, kv in ipairs(require("prefs").lines("capture")) do
    if capture[kv[1]] and kv[2]:match("^[%w_]+[%w_+]*$") then capture[kv[1]] = kv[2] end
end
bind((capture.key:gsub("%+", " + ")), hl.dsp.exec_cmd(scripts .. "shot.sh"), "capture: area / screen / video (bar menu), to clipboard")
bind((capture.key_save:gsub("%+", " + ")), hl.dsp.exec_cmd(scripts .. "shot.sh save"), "capture and save to ~/Pictures/Screenshots")
bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), "screenshot to clipboard")
bind("SUPER + Print", hl.dsp.exec_cmd(scripts .. "capture.sh colour"), "pick a colour")
bind("SUPER + ALT + Print", hl.dsp.exec_cmd(scripts .. "capture.sh text"), "text from a region (OCR)")
bind("SUPER + CTRL + Print", hl.dsp.exec_cmd(scripts .. "capture.sh qr"), "QR code from a region")
bind("ALT + Print", hl.dsp.exec_cmd(scripts .. "screenrecord.sh"), "record screen / stop")
bind("ALT + SHIFT + Print", hl.dsp.exec_cmd(scripts .. "screenrecord.sh region"), "record region / stop")
bind("SUPER + SHIFT + T", hl.dsp.exec_cmd(scripts .. "tv-toggle.sh"), "TV on / off")

local locked = { locked = true }
local held = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), locked)
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), locked)

if os.getenv("ONINIX_LAPTOP") == "1" then
    bind("XF86MonBrightnessUp", app("brightnessctl -c backlight set +5%"), "brightness up", { repeating = true, locked = true })
    bind("XF86MonBrightnessDown", app("brightnessctl -c backlight -n 5 set 5%-"), "brightness down", { repeating = true, locked = true })
end
