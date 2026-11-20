-- Put apps that Game mode quit back where they were (station_gameapps.py).
-- expect(plan) arrives just before the apps relaunch. Their new windows wait
-- on a hidden workspace until all have mapped (or 8 s pass without one), then every affected workspace
-- is rebuilt: the dwindle tree from the recorded splits, tab groups, split
-- sizes, floating geometry and fullscreen state. Windows that stayed open on
-- those workspaces take part, so neighbours return to their places too.
local M = {}
local holding = "special:oninix-restore"
local plan, held, timer = nil, {}, nil

-- Progress for the Xeneon card (GameProgress.qml); Python writes the earlier steps.
local function report(step, state, done, total)
    local dir = (os.getenv("XDG_RUNTIME_DIR") or "/nonexistent") .. "/oninix-desktop/"
    local f = io.open(dir .. "game-progress.tmp", "w")
    if not f then return end
    f:write(string.format('{"direction":"off","step":"%s","state":"%s","done":%d,"total":%d,"at":%d}',
        step, state or "running", done or 0, total or 0, os.time()))
    f:close()
    os.rename(dir .. "game-progress.tmp", dir .. "game-progress.json")
end

local function win(address) return address and hl.get_window("address:" .. address) or nil end
local function move(w, workspace) hl.dispatch(hl.dsp.window.move({ window = w, workspace = workspace, follow = false })) end

local function expected()
    local need = {}
    for _, s in ipairs(plan.slots) do
        if not s.address then need[s.class] = (need[s.class] or 0) + 1 end
    end
    return need
end

local function count(class)
    local n = 0
    for _, h in ipairs(held) do
        local w = win(h)
        if w and w.class == class then n = n + 1 end
    end
    return n
end

-- New windows take slots by exact title, then in recorded order.
local function resolve(p)
    local windows, free = {}, {}
    for _, h in ipairs(held) do
        local w = win(h)
        if w then free[#free + 1] = w end
    end
    local function take(test)
        for i, w in ipairs(free) do
            if test(w) then table.remove(free, i); return w end
        end
    end
    for _, s in ipairs(p.slots) do
        if s.address then windows[s.id] = win(s.address)
        else windows[s.id] = take(function(w) return w.class == s.class and w.title == s.title end) end
    end
    for _, s in ipairs(p.slots) do
        if not s.address and not windows[s.id] then
            windows[s.id] = take(function(w) return w.class == s.class end)
        end
    end
    return windows, free
end

local function build()
    if timer then timer:set_enabled(false); timer = nil end
    if not plan then return end
    local p = plan
    plan = nil
    report("Arranging windows")
    local windows, leftover = resolve(p)
    held = {}
    local active = hl.get_active_window()
    local slots = {}
    for _, s in ipairs(p.slots) do slots[s.id] = s end

    local function rep(leaf)
        for _, id in ipairs(leaf.members) do
            if windows[id] then return windows[id] end
        end
    end
    -- Drop leaves whose windows are gone (closed while gaming, not restored).
    local function prune(n)
        if n.members then return rep(n) and n or nil end
        local a, b = prune(n.a), prune(n.b)
        if a and b then n.a, n.b = a, b; return n end
        return a or b
    end
    local function first(n) while not n.members do n = n.a end return n end
    local function leaves(n, out)
        if n.members then out[#out + 1] = n else leaves(n.a, out); leaves(n.b, out) end
        return out
    end
    local function regroup(leaf)
        local lead = rep(leaf)
        if #leaf.members < 2 then return end
        if not lead.group then hl.dispatch(hl.dsp.group.toggle({ window = lead })) end
        lead = win(lead.address)
        local function member(w)
            for _, m in ipairs(lead.group.members or {}) do
                if m.address == w.address then return true end
            end
        end
        for _, id in ipairs(leaf.members) do
            local w = windows[id] and win(windows[id].address)
            if w and not member(w) then lead.group:add(w) end
        end
    end
    local function grow(n, workspace)
        if n.members then return end
        hl.dispatch(hl.dsp.focus({ window = rep(first(n.a)) }))
        hl.dispatch(hl.dsp.layout(n.dir == "h" and "preselect r" or "preselect d"))
        move(rep(first(n.b)), workspace)
        grow(n.a, workspace)
        grow(n.b, workspace)
    end

    for _, ws in ipairs(p.workspaces) do
        local tree = prune(ws.tree)
        if tree then
            local all = leaves(tree, {})
            for _, leaf in ipairs(all) do
                for _, id in ipairs(leaf.members) do
                    if windows[id] then move(windows[id], holding) end
                end
            end
            for _, leaf in ipairs(all) do regroup(leaf) end
            move(rep(first(tree)), ws.name)
            grow(tree, ws.name)
            -- Splits nest, so a second pass settles sizes the first one shifted.
            for _ = 1, 2 do
                for _, leaf in ipairs(all) do
                    local s = slots[leaf.current] or slots[leaf.members[1]]
                    hl.dispatch(hl.dsp.window.resize({ window = rep(leaf), relative = false, x = s.w, y = s.h }))
                end
            end
            -- The visible tab, chosen only now: focusing on the hidden workspace would show it.
            for _, leaf in ipairs(all) do
                local current = windows[leaf.current]
                if #leaf.members > 1 and current then hl.dispatch(hl.dsp.focus({ window = current })) end
            end
        end
    end
    for _, f in ipairs(p.floating) do
        local w, s = windows[f.slot], slots[f.slot]
        if w then
            move(w, f.workspace)
            hl.dispatch(hl.dsp.window.float({ window = w, action = "enable" }))
            hl.dispatch(hl.dsp.window.resize({ window = w, relative = false, x = s.w, y = s.h }))
            hl.dispatch(hl.dsp.window.move({ window = w, x = f.x, y = f.y }))
        end
    end
    for _, sp in ipairs(p.special) do
        local w = windows[sp.slot]
        if w then
            if sp.floating then hl.dispatch(hl.dsp.window.float({ window = w, action = "enable" })) end
            move(w, sp.workspace)
        end
    end
    for id, w in pairs(windows) do
        local s = slots[id]
        if s.fullscreen and s.fullscreen > 0 and not s.address then
            hl.dispatch(hl.dsp.window.fullscreen({ window = w, mode = s.fullscreen >= 2 and "fullscreen" or "maximized", action = "set" }))
        end
    end
    -- More windows than recorded (e.g. Chrome restored an extra one): next to their kin.
    for _, w in ipairs(leftover) do
        local target
        for id, s in pairs(slots) do
            if s.class == w.class and windows[id] and windows[id].workspace then target = windows[id].workspace.name end
        end
        move(w, target or tostring((hl.get_active_workspace() or { id = 1 }).id))
    end
    if active and win(active.address) then hl.dispatch(hl.dsp.focus({ window = active })) end
    report("Desktop restored", "done")
end

local function settle(ms)
    if timer then timer:set_enabled(false) end
    timer = hl.timer(function()
        local ok, err = pcall(build)
        if not ok then
            plan = nil
            local found, stranded = pcall(hl.get_workspace_windows, holding)
            for _, w in ipairs(found and stranded or {}) do move(w, "1") end
            print("gamerestore: " .. tostring(err))
            report("Some windows could not be placed", "error")
        end
    end, { timeout = ms, type = "oneshot" })
end

function M.expect(value)
    plan, held = value, {}
    -- Apps that never map a window must not hold the others back for long.
    settle(30000)
end

local function on_window(w)
    if not plan or not w or not w.mapped then return end
    for _, h in ipairs(held) do if h == w.address then return end end
    local need = expected()
    if not need[w.class] or count(w.class) >= need[w.class] then return end
    held[#held + 1] = w.address
    move(w, holding)
    local total, arrived = 0, 0
    for class, n in pairs(need) do total = total + n; arrived = arrived + math.min(count(class), n) end
    report("Waiting for windows", "running", arrived, total)
    for class, n in pairs(need) do
        -- A missing window (a profile or web app that did not come back) must
        -- not keep the rest hidden: arrange after 8 s without a new arrival.
        if count(class) < n then settle(8000); return end
    end
    -- Everyone is here; give titles a moment to settle before matching.
    settle(2000)
end

hl.on("window.open", on_window)
hl.on("window.class", on_window)

-- A config reload forgets the plan; never leave windows hidden.
local ok, stranded = pcall(hl.get_workspace_windows, holding)
for _, w in ipairs(ok and stranded or {}) do move(w, "1") end
return M
