local function start(cmd)
	hl.exec_cmd("oninix-app " .. cmd)
end

hl.on("hyprland.start", function()
	if os.getenv("ONINIX_LAYER") == "1" then
        hl.exec_cmd("oninix-layer-ready")
    else
        hl.exec_cmd("systemctl --user start --no-block oninix-panel.service oninix-theme-schedule.timer")
    end
	start("wl-paste --watch cliphist store")
	start("wl-paste --type text/uri-list --watch sh -c 'oninix-desktop shelf-clip >/dev/null 2>&1'")
end)
