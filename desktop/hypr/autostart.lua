local function start(cmd)
	hl.exec_cmd("uwsm app -- " .. cmd)
end

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start --no-block oninix-panel.service oninix-theme-schedule.timer")
	start("wl-paste --watch cliphist store")
	start("wl-paste --type text/uri-list --watch sh -c 'oninix-desktop shelf-clip >/dev/null 2>&1'")
end)
