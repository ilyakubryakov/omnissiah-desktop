
hl.env("XCURSOR_THEME", "Breeze_Light")
hl.env("XCURSOR_SIZE", "24")

hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 1,
		layout = "dwindle",
		resize_on_border = true,
	},
	decoration = {
		rounding = 0,
		shadow = { enabled = false },
		blur = {
			enabled = true,
			size = 6,
			passes = 3,
			new_optimizations = true,
		},
	},
	animations = { enabled = false },
	input = {
		kb_options = "grp:caps_toggle",
		numlock_by_default = true,
		follow_mouse = 2,
		float_switch_override_focus = 0,
	},
	dwindle = {
		preserve_split = true,
	},
	group = {
		auto_group = true,
		groupbar = {
			font_family = "JetBrainsMono Nerd Font",
			font_size = 11,
			height = 18,
			gradients = true,
			gradient_rounding = 0,
			indicator_height = 0,
			keep_upper_gap = false,
			render_titles = true,
		},
	},
	ecosystem = {
		no_update_news = true,
		no_donation_nag = true,
	},
	misc = {
		on_focus_under_fullscreen = 1,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		background_color = "rgb(121010)",
		allow_session_lock_restore = true,
	},
	xwayland = {
		force_zero_scaling = true,
	},
	render = {
		cm_auto_hdr = 0,
	},
})

local prefs = require("prefs")
local default_layouts = os.getenv("ONINIX_XKB_LAYOUT") or "us,ru"
local input = { layouts = default_layouts, repeat_rate = "25", repeat_delay = "600", mouse_speed = "0",
    mouse_natural = "no", scroll = "0.7", natural = "yes", tap = "yes" }
for _, kv in ipairs(prefs.lines("input")) do
    if input[kv[1]] then input[kv[1]] = kv[2] end
end
hl.config({ input = {
    kb_layout = input.layouts:match("^[a-z]+[a-z,]*$") and input.layouts or default_layouts,
    repeat_rate = prefs.number(input.repeat_rate, 10, 80, 25),
    repeat_delay = prefs.number(input.repeat_delay, 150, 1000, 600),
    sensitivity = prefs.number(input.mouse_speed, -1, 1, 0),
    natural_scroll = input.mouse_natural == "yes",
    touchpad = { natural_scroll = input.natural == "yes", tap_to_click = input.tap == "yes",
        disable_while_typing = true, clickfinger_behavior = true,
        scroll_factor = prefs.number(input.scroll, 0.1, 2, 0.7) },
} })

if os.getenv("ONINIX_LAPTOP") == "1" then
    local launchpad = "oninix-shell ipc call launchpad "
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd(launchpad .. "toggle") end })
    hl.gesture({ fingers = 3, direction = "down", action = function() hl.exec_cmd(launchpad .. "close") end })
end
