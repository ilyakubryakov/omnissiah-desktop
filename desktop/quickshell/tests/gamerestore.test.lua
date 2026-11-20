local here = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local plan = {slots={{id=1,address=nil,class="org.telegram.desktop",title="Telegram",w=1298,h=1662,fullscreen=0},{id=2,address=nil,class="chrome-teams",title="Teams",w=1296,h=1642,fullscreen=0},{id=3,address=nil,class="thunderbird",title="Inbox",w=1296,h=1642,fullscreen=0},{id=4,address=nil,class="slack",title="Slack",w=1484,h=1662,fullscreen=0},{id=5,address="k",class="kitty",title="",w=2042,h=828,fullscreen=0},{id=6,address=nil,class="google-chrome",title="Proxmox",w=2042,h=828,fullscreen=0},{id=7,address=nil,class="google-chrome",title="New Tab",w=2042,h=1662,fullscreen=0},{id=8,address=nil,class="slack",title="Huddle",w=800,h=600,fullscreen=0}},workspaces={{name="3",tree={dir="h",a={members={1},current=1},b={dir="h",a={members={2,3},current=2},b={members={4},current=4}}}},{name="2",tree={dir="h",a={dir="v",a={members={5},current=5},b={members={6},current=6}},b={members={7},current=7}}}},floating={{slot=8,workspace="4",x=100,y=200}},special={}}

local windows, trees, events, timers = {}, {}, {}, {}
local focused, presel, resized = nil, nil, {}

local function get(selector)
    if type(selector) == "table" then return selector end
    return windows[(selector or ""):match("^address:(.*)$")]
end
local function tile(w) return w.group and w.group.members[1] or w end
local function remove(node, address)
    if not node then return nil end
    if node.leaf then return node.leaf ~= address and node or nil end
    local a, b = remove(node.a, address), remove(node.b, address)
    if a and b then node.a, node.b = a, b; return node end
    return a or b
end
local function find(node, address)
    if not node then return nil end
    if node.leaf == address then return node end
    return find(node.a, address) or find(node.b, address)
end
local function last(node) while not node.leaf do node = node.b end return node end
local function insert(w, name)
    local t = tile(w)
    local tree = trees[name]
    if not tree then trees[name] = { leaf = t.address }; return end
    local anchor = focused and focused.workspace.name == name and find(tree, tile(focused).address) or last(tree)
    local old = anchor.leaf
    anchor.leaf, anchor.dir = nil, presel == "d" and "v" or "h"
    anchor.a, anchor.b = { leaf = old }, { leaf = t.address }
    presel = nil
end
local function place(w, name)
    local t = tile(w)
    local members = t.group and t.group.members or { t }
    if t.workspace and not t.floating then trees[t.workspace.name] = remove(trees[t.workspace.name], t.address) end
    for _, m in ipairs(members) do m.workspace = { name = name } end
    if not t.floating then insert(t, name) end
end

local hl = {
    on = function(name, cb) events[name] = cb end,
    timer = function(cb) timers[#timers + 1] = cb; return { set_enabled = function() end } end,
    get_window = get,
    get_active_window = function() return focused end,
    get_active_workspace = function() return { id = 1 } end,
    get_workspace_windows = function(name)
        local out = {}
        for _, w in pairs(windows) do if w.workspace and w.workspace.name == name then out[#out + 1] = w end end
        return out
    end,
    dispatch = function(f) f() end,
    dsp = {
        focus = function(a) return function() focused = get(a.window) end end,
        layout = function(msg) return function() presel = msg:match("preselect (%a)") end end,
        window = {
            move = function(a) return function()
                local w = get(a.window)
                if a.workspace then place(w, a.workspace) else w.at = { a.x, a.y } end
            end end,
            float = function(a) return function()
                local w = get(a.window)
                trees[w.workspace.name] = remove(trees[w.workspace.name], w.address)
                w.floating = true
            end end,
            resize = function(a) return function() resized[get(a.window).address] = { a.x, a.y } end end,
            fullscreen = function() return function() end end,
        },
        group = {
            toggle = function(a) return function()
                local w = get(a.window)
                local group = { members = { w } }
                function group.add(self, other)
                    trees[other.workspace.name] = remove(trees[other.workspace.name], other.address)
                    other.workspace = { name = w.workspace.name }
                    self.members[#self.members + 1] = other
                    other.group = self
                end
                w.group = group
            end end,
        },
    },
}

local M = assert(loadfile(here .. "../../nixos/hyprland/hypr/gamerestore.lua", "t", setmetatable({ hl = hl, os = { getenv = function() return "/nonexistent" end, time = os.time, rename = os.rename } }, { __index = _G })))()

local function open(address, class, title, name)
    local w = { address = address, class = class, title = title, mapped = true }
    windows[address] = w
    place(w, name)
    events["window.open"](w)
    return w
end
local function shape(node)
    if node.leaf then
        local w = windows[node.leaf]
        if not w.group then return w.class end
        local names = {}
        for _, m in ipairs(w.group.members) do names[#names + 1] = m.class end
        return "[" .. table.concat(names, "+") .. "]"
    end
    return node.dir .. "(" .. shape(node.a) .. "," .. shape(node.b) .. ")"
end

windows.k = { address = "k", class = "kitty", title = "zsh", mapped = true }
place(windows.k, "2")
windows.z = { address = "z", class = "kitty", title = "agents", mapped = true }
place(windows.z, "5")
focused = windows.z

M.expect(plan)
open("n1", "slack", "Slack", "3")
open("n2", "google-chrome", "New Tab", "1")
open("n3", "thunderbird", "Inbox", "3")
open("n4", "google-chrome", "Proxmox", "1")
open("n5", "org.telegram.desktop", "Telegram", "3")
open("n6", "chrome-teams", "Teams", "1")
open("n7", "slack", "Huddle", "3")
assert(#timers >= 2, "All windows arrived: a settle timer is armed")
local extra = { address = "n8", class = "kitty", title = "unrelated", mapped = true }
windows.n8 = extra; place(extra, "1"); events["window.open"](extra)
assert(extra.workspace.name == "1", "Unplanned windows are left alone")
timers[#timers]()

assert(shape(trees["3"]) == "h(org.telegram.desktop,h([chrome-teams+thunderbird],slack))", shape(trees["3"]))
assert(shape(trees["2"]) == "h(v(kitty,google-chrome),google-chrome)", shape(trees["2"]))
assert(windows.n4.workspace.name == "2" and find(trees["2"].a, "n4"), "Proxmox matched by title to its old place")
assert(windows.n7.floating and windows.n7.workspace.name == "4" and windows.n7.at[1] == 100, "Floating huddle back at 100,200")
assert(resized.n7[1] == 800 and resized.n1[1] == 1484, "Recorded sizes restored")
assert(focused == windows.z, "Focus returns to the window active before the restore")
assert(#hl.get_workspace_windows("special:oninix-restore") == 0, "Nothing stays hidden")
print("gamerestore ok")
