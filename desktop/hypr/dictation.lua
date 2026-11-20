local prefix = tostring({}):gsub("%W", "")
local sequence = 0
local token = nil
local command = "oninix-dictation "

hl.bind("Alt_R", function()
    if token then return end
    local window = hl.get_active_window()
    local address = window and tostring(window.address) or "0x0"
    local pid = window and tonumber(window.pid) or 0
    if not address:match("^0x%x+$") or not pid then return end
    sequence = sequence + 1
    token = prefix .. sequence
    hl.exec_cmd(command .. "press " .. token .. " " .. address .. " " .. tostring(pid))
end, { ignore_mods = true, description = "dictation: hold Right Alt to speak, release to insert" })

hl.bind("Alt_R", function()
    if not token then return end
    hl.exec_cmd(command .. "release " .. token .. " --keys-up")
    token = nil
end, { release = true, ignore_mods = true, transparent = true, locked = true })

hl.bind("SUPER + ALT + Escape", function()
    hl.exec_cmd(command .. "cancel")
    token = nil
end, { description = "cancel dictation", locked = true })
