-- Keybinds. KDE muscle memory where it existed: Meta+Return terminal,
-- Meta+L lock, Meta+Shift+T TV, Meta+E files.
--
-- A description makes a bind show up on the cheatsheet (Meta+Shift+H), which
-- reads them back from `hyprctl binds`. Equal descriptions are grouped into
-- one row, with only the keys actually registered in this session.

local function app(cmd)
	return hl.dsp.exec_cmd("uwsm app -- " .. cmd)
end

local function bind(keys, action, description, opts)
	opts = opts or {}
	opts.description = description
	hl.bind(keys, action, opts)
end

local scripts = (os.getenv("ONINIX_SHARE") or "/run/current-system/sw/share/oninix") .. "/hypr/scripts/"


-- Apps
bind("SUPER + Return", app("kitty"), "terminal")
-- Open the menu directly; oninix-launcher gives selected apps their own UWSM scope.
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
-- Tokens pair each IPC request with its Alt release, including very fast taps.
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
-- Single-instance apps: focus the window if there is one, else start it.
local function focus_or_start(class, cmd)
	return hl.dsp.exec_cmd(scripts .. "launch-or-focus.sh '" .. class .. "' " .. cmd)
end
bind("SUPER + ALT + B", focus_or_start("google-chrome", "google-chrome-stable"), "Chrome (focus or start)")
bind("SUPER + ALT + S", focus_or_start("slack", "slack"), "Slack")
bind("SUPER + ALT + T", focus_or_start("telegram", "Telegram"), "Telegram")
bind("SUPER + ALT + M", focus_or_start("thunderbird", "thunderbird"), "Thunderbird")
bind("SUPER + ALT + O", focus_or_start("obsidian", "obsidian"), "Obsidian")
bind("SUPER + ALT + C", focus_or_start("claude", "claude-desktop"), "Claude")
bind("SUPER + ALT + G", focus_or_start("chatgpt|codex", "chatgpt"), "ChatGPT / Codex")
bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("oninix-shell ipc call cheat toggle"),
	"this cheatsheet")

local function tv_workspace(move)
    -- Workspace 11 may not exist yet even though the TV is enabled.
    local tv = require("outputs").tv_monitor()
    if not tv then
        hl.notification.create({ text = "Enable the TV in Control Center first", timeout = 2000 })
        return
    end
    hl.dispatch(move and hl.dsp.window.move({ workspace = "11", follow = false }) or hl.dsp.focus({ workspace = "11" }))
end
bind("SUPER + CTRL + T", function() tv_workspace(false) end, "TV workspace")
bind("SUPER + CTRL + SHIFT + T", function() tv_workspace(true) end, "send window to TV workspace")

-- Session
bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), "lock")
bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(scripts .. "power-menu.sh --logout"), "log out (confirm)")
bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }), "displays off / on")
bind("SUPER + CTRL + N", hl.dsp.exec_cmd("oninix-theme-schedule --nightlight toggle"), "night light on / off")

-- Windows
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

-- Workspace modes: Meta+T cycles the tiling layout, Meta+Shift+Space floats
-- the whole workspace (new windows included) and back.
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

-- Tabs (groups)
bind("SUPER + W", hl.dsp.group.toggle(), "group into tabs / ungroup")
bind("SUPER + Tab", hl.dsp.group.next(), "next tab")
bind("SUPER + SHIFT + Tab", hl.dsp.group.prev(), "previous tab")

-- Workspaces 1..10
for i = 1, 10 do
	local key = tostring(i % 10)
	bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(i) }), "go to workspace (1..0)")
	bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }),
		"send window to workspace (1..0)")
end
bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "next workspace with mouse wheel")
bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "previous workspace with mouse wheel")

-- Mouse
bind("SUPER + mouse:272", hl.dsp.window.drag(), "drag window", { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), "resize window", { mouse = true })

-- Screens
-- The capture key does what the bar's camera menu says (area, screen or video);
-- with the save key screenshots also land in ~/Pictures/Screenshots.
-- Both are set in Control Center > Session.
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

-- Media and volume, also on the lock screen. Printed on the keys, so no
-- descriptions: they would only crowd the cheatsheet.
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
