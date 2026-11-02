local floating = {
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

hl.window_rule({ match = { class = "^(1Password|com\\.onepassword\\.OnePassword)$" }, float = true, center = true })

hl.window_rule({ match = { class = "^REAPER$", title = "^(REAPER( [^v].*)?|About REAPER.*|Actions|MIDI take.*|Render.*|Tuner|Control Surface Settings|Configure MIDI.*|New electronic session|AI Stems.*|New guitar session|Station Studio|Voice tools|FX:.*|Add FX.*|Customize.*|Toolbar.*|Project (Settings|Bay).*|Select toolbar icon|Set toolbar item.*|Import stems.*)$" }, float = true, center = true })

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

hl.window_rule({ match = { class = "^(org\\.quickshell)$", title = "^Control Station$" }, float = true, center = true, no_anim = true, border_size = 0, no_blur = true, rounding = 20, rounding_power = 2 })

hl.window_rule({ match = { class = "^(com\\.nextcloud\\.desktopclient\\.nextcloud)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(com\\.nextcloud\\.desktopclient\\.nextcloud)$", title = "^(Nextcloud Settings)$" }, size = { 1000, 760 } })

hl.layer_rule({ match = { namespace = "^station-panel$" }, blur = true, ignore_alpha = 0.05, no_anim = true })

hl.layer_rule({ match = { namespace = "^station-launchpad$" }, blur = true, xray = false, ignore_alpha = 0, no_anim = true })

hl.layer_rule({ match = { namespace = "^station-(card|calendar|notebook|notifications)$" }, no_anim = true })

hl.layer_rule({ match = { namespace = "^rofi$" }, no_anim = true })
