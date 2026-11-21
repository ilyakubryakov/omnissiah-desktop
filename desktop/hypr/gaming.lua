local M = { enabled = false }
local prefix = "oninix-game-restore-"

local function restore_tag(w)
    for _, tag in ipairs(w.tags or {}) do
        if tag == prefix .. "0" then return tag, 0 end
        if tag == prefix .. "1" then return tag, 1 end
    end
end

local function is_game(w)
    if not w or not w.mapped or not w.workspace or w.workspace.special then return false end
    local class = (w.class or ""):lower()
    if class == "steam" or class:find("steamwebhelper", 1, true) then return false end
    if class:match("^steam_app_%d+$") or class == "xonotic-sdl" or w.content_type == "game" then return true end
    local f = io.open("/proc/" .. tostring(w.pid) .. "/environ", "rb")
    if not f then return false end
    local env = "\0" .. (f:read("*a") or ""); f:close()
    local id = env:match("%zSteamAppId=(%d+)%z")
    return id ~= nil and tonumber(id) > 0
end

local games, exit_timer = {}, nil

function M.has_games()
    for _, w in ipairs(hl.get_windows()) do
        if is_game(w) then return true end
    end
    return false
end

local offered, last_offer = {}, 0
local function offer(w)
    if M.enabled or not w or not w.pid or offered[w.pid] then return end
    offered[w.pid] = true
    if os.time() - last_offer < 120 then return end
    last_offer = os.time()
    hl.exec_cmd("oninix-desktop game-offer")
end

local function apply(w)
    if not is_game(w) then return end
    games[w.address] = true
    offer(w)
    if not M.enabled or restore_tag(w) or w.fullscreen >= 2 then return end
    hl.dispatch(hl.dsp.window.tag({ window = w, tag = "+" .. prefix .. tostring(w.fullscreen) }))
    hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "fullscreen", action = "set" }))
end

function M.set(on)
    M.enabled = on
    for _, w in ipairs(hl.get_windows()) do
        if on then apply(w) else
            local tag, previous = restore_tag(w)
            if tag then
                if w.fullscreen == 2 then
                    hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "fullscreen", action = "unset" }))
                    if previous == 1 then
                        hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = "maximized", action = "set" }))
                    end
                end
                hl.dispatch(hl.dsp.window.tag({ window = w, tag = "-" .. tag }))
            end
        end
    end
end

hl.on("window.open", apply)
hl.on("window.class", apply)
hl.on("window.close", function(w)
    if not w or not games[w.address] then return end
    games[w.address] = nil
    if not M.enabled then return end
    if exit_timer then exit_timer:set_enabled(false) end
    exit_timer = hl.timer(function()
        if M.enabled and not M.has_games() then
            hl.exec_cmd("oninix-desktop game-offer normal")
        end
    end, { timeout = 1000, type = "oneshot" })
end)
local path = (os.getenv("XDG_RUNTIME_DIR") or "/nonexistent") .. "/oninix-desktop/mode.json"
local f = io.open(path, "r")
if f then
    local value = f:read("*a"); f:close()
    M.set(value:match('"name"%s*:%s*"game"') ~= nil)
else M.set(false) end
return M
