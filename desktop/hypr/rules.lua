-- Window and layer rules. Dialogs and utilities float; everything else tiles.

-- Global Floating controls maximize suppression in windowmode.lua.

local floating = {
	"(?i)^(battle\\.net(\\.exe)?)$",
	"^(org\\.pulseaudio\\.pavucontrol|pavucontrol)$",
	"^(alsa-scarlett-gui|com\\.focusrite\\.alsa-scarlett-gui)$",
	"^(org\\.kde\\.polkit-kde-authentication-agent-1)$",
	"^(xdg-desktop-portal.*)$",
	"^(org\\.kde\\.kwalletmanager5?)$",
	"^(nm-connection-editor)$",
	"^(nmtui)$",
	"^(blueman-manager)$",
}
for _, class in ipairs(floating) do
	hl.window_rule({ match = { class = class }, float = true })
end

-- Battle.net's main window maps at the full screen size it cannot lay out;
-- open it at the owner's size (2026-11-17). Login and dialogs keep theirs.
hl.window_rule({ match = { class = "(?i)^(battle\\.net(\\.exe)?)$", title = "^(Battle\\.net)$" }, size = { 1238, 963 }, center = true })

-- WoW runs as a native Wayland Wine window. Hidden on another workspace it gets
-- no frame callbacks, its render loop blocks on present and input stalls for a
-- while after returning (2026-11-17). Keep feeding it frames (render_unfocused_fps).
hl.window_rule({ match = { class = "(?i)^wow.*\\.exe$" }, render_unfocused = true })

-- Password management stays floating, including Quick Access and unlock.
hl.window_rule({ match = { class = "^(1Password|com\\.onepassword\\.OnePassword)$" }, float = true, center = true })

-- SWELL dialogs float centered; otherwise they appear partly outside an offset
-- laptop display. The main window ("REAPER v7...", "<song> - REAPER v7...") tiles.
hl.window_rule({ match = { class = "^REAPER$", title = "^(REAPER( [^v].*)?|About REAPER.*|Actions|MIDI take.*|Render.*|Tuner|Control Surface Settings|Configure MIDI.*|New electronic session|AI Stems.*|New guitar session|Voice tools|FX:.*|Add FX.*|Customize.*|Toolbar.*|Project (Settings|Bay).*|Select toolbar icon|Set toolbar item.*|Import stems.*)$" }, float = true, center = true })

-- A fullscreen game or video keeps the screen awake, even with no keyboard
-- or mouse input (gamepad, watching).
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- Control Center's app-to-workspace map: "class=workspace", exact class names.
for _, kv in ipairs(require("prefs").lines("workspaces")) do
    local ws = tonumber(kv[2])
    if ws and ws >= 1 and ws <= 10 then
        local class = (kv[1]:gsub("[%.%-%+%*%?%(%)%[%]%^%$|]", "\\%0"))
        hl.window_rule({ match = { class = "^(" .. class .. ")$" }, workspace = tostring(math.floor(ws)) })
    end
end

-- Picture-in-picture from Chrome stays on top, out of the tiling.
hl.window_rule({ match = { title = "^(Picture.in.[Pp]icture)$" }, float = true, pin = true })

hl.layer_rule({ match = { namespace = "^(quickshell.*)$" }, no_anim = true })

-- The appearance file chooser is an ordinary Qt window beside layer panels.
hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^Wallpaper (for .*|gallery|collection)$" }, float = true, center = true })
-- Control Station is an ordinary persistent utility window, including in tiling mode.
-- QML draws its own rounded outline; a compositor border would remain square.
-- Keep the compositor clip/shadow circular and equal to DesktopPanel's radius.
-- Blur behind transparent corner pixels otherwise paints a square tinted patch.
hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^(Control Station)$" }, float = true, center = true, no_anim = true, border_size = 0, no_blur = true, rounding = 20, rounding_power = 2 })

-- Translucent panels use blur; zero-alpha gaps between islands stay clear.
hl.layer_rule({ match = { namespace = "^oninix-panel$" }, blur = true, ignore_alpha = 0.05, no_anim = true })
-- Launchpad blurs live windows, never only the cached wallpaper (xray).
hl.layer_rule({ match = { namespace = "^oninix-launchpad$" }, blur = true, xray = false, ignore_alpha = 0, no_anim = true })
-- These surfaces animate their own content in QML. A compositor pop-in on top
-- doubles the motion and makes text and slider thumbs scale on every reveal.
hl.layer_rule({ match = { namespace = "^oninix-(card|calendar|notebook|notifications|desktop|desktop-menu)$" }, no_anim = true })

-- Search must be ready immediately; do not fade or slide its layer surface.
hl.layer_rule({ match = { namespace = "^rofi$" }, no_anim = true })

-- Embedded Wine FX repaint during configure events; a second animated resize
-- makes their editor lag behind the host frame on fractional-scale displays.
hl.window_rule({ match = { class = "^REAPER$", title = "^(FX: Track [0-9]+.*)$" }, float = true, no_anim = true })
