hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm finalize && systemctl --user start omnissiah.target")
end)
