

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

hl.window_rule({ match = { class = "(?i)^(battle\\.net(\\.exe)?)$", title = "^(Battle\\.net)$" }, size = { 1238, 963 }, center = true })

hl.window_rule({ match = { class = "(?i)^wow.*\\.exe$" }, render_unfocused = true })

hl.window_rule({ match = { class = "^(1Password|com\\.onepassword\\.OnePassword)$" }, float = true, center = true })

hl.window_rule({ match = { class = "^REAPER$", title = "^(REAPER( [^v].*)?|About REAPER.*|Actions|MIDI take.*|Render.*|Tuner|Control Surface Settings|Configure MIDI.*|New electronic session|AI Stems.*|New guitar session|Voice tools|FX:.*|Add FX.*|Customize.*|Toolbar.*|Project (Settings|Bay).*|Select toolbar icon|Set toolbar item.*|Import stems.*)$" }, float = true, center = true })

hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

for _, kv in ipairs(require("prefs").lines("workspaces")) do
    local ws = tonumber(kv[2])
    if ws and ws >= 1 and ws <= 10 then
        local class = (kv[1]:gsub("[%.%-%+%*%?%(%)%[%]%^%$|]", "\\%0"))
        hl.window_rule({ match = { class = "^(" .. class .. ")$" }, workspace = tostring(math.floor(ws)) })
    end
end

hl.window_rule({ match = { title = "^(Picture.in.[Pp]icture)$" }, float = true, pin = true })

hl.layer_rule({ match = { namespace = "^(quickshell.*)$" }, no_anim = true })

hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^Wallpaper (for .*|gallery|collection)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^(Control Station)$" }, float = true, center = true, no_anim = true, border_size = 0, no_blur = true, rounding = 20, rounding_power = 2 })

hl.layer_rule({ match = { namespace = "^oninix-panel$" }, blur = true, ignore_alpha = 0.05, no_anim = true })
hl.layer_rule({ match = { namespace = "^oninix-launchpad$" }, blur = true, xray = false, ignore_alpha = 0, no_anim = true })
hl.layer_rule({ match = { namespace = "^oninix-(card|calendar|notebook|notifications|desktop|desktop-menu)$" }, no_anim = true })

hl.layer_rule({ match = { namespace = "^rofi$" }, no_anim = true })

hl.window_rule({ match = { class = "^REAPER$", title = "^(FX: Track [0-9]+.*)$" }, float = true, no_anim = true })
