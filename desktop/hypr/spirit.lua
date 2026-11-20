local prefix = "spirit" .. tostring({}):gsub("%W", "")
local sequence = 0
local token = nil
local command = "oninix-dictation "

hl.bind("SUPER + A", hl.dsp.exec_cmd("oninix-app kitty --class oninix-spirit --title 'Machine spirit' oninix-spirit"),
    { description = "machine spirit: ask the system to change itself" })

hl.bind("Control_R", function()
    if token then return end
    local window = hl.get_active_window()
    local address = window and tostring(window.address) or "0x0"
    local pid = window and tonumber(window.pid) or 0
    sequence = sequence + 1
    token = prefix .. sequence
    hl.exec_cmd(command .. "press " .. token .. " " .. address .. " " .. tostring(pid) .. " --assistant")
end, { ignore_mods = true, description = "machine spirit: hold Right Ctrl and speak" })

hl.bind("Control_R", function()
    if not token then return end
    hl.exec_cmd(command .. "release " .. token .. " --keys-up")
    token = nil
end, { release = true, ignore_mods = true, transparent = true, locked = true })

hl.window_rule({ match = { class = "^oninix-spirit$" }, float = true, center = true, size = { 1100, 760 } })
