const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "../bar/LiveWallpaper.js"), "utf8");
const live = vm.runInNewContext(
    source.replace(/^\.pragma library\s*/, "") +
        "\n({ response, statusText, queryArgs, gridItem, typeLabel, sorts, periods, workshopPage," +
        " boolValue, colorValue, samePropertyValue, propertyVisible, propertyArgs, textValue })"
);
const plain = value => JSON.parse(JSON.stringify(value));

const localScene = {
    id: "3400123", title: "Rainy street", type: "scene",
    preview: "/games/Steam Library/3400123/夜 #1%.gif",
    supported: true, reason: "", tags: ["Cyberpunk"], rating: "Everyone",
    path: "/games/Steam Library/3400123", updated: 1795680000
};
const workshopScene = {
    id: localScene.id, title: localScene.title, type: localScene.type,
    preview_url: "https://steamusercontent.example/3400123.gif?size=small",
    subscriptions: 27624, installed: true, favorited: 932,
    tags: localScene.tags, rating: "Everyone", file_size: 1000000, time_updated: 1795680000
};
const status = {
    mode: "live", item: localScene, state: "playing", reason: "", error: "",
    output: "DP-3", assets: true, key: true, workshop_dir: "/games/Steam Library"
};
const defaults = {
    sort: "trend", days: 7, types: [], ratings: ["everyone"], tags: [], resolution: "", search: ""
};

test("reads one JSON object and preserves backend errors on exit 1", () => {
    const fixtures = [
        status,
        { items: [localScene] },
        { items: [workshopScene], next_cursor: "AoE+BC/==", total: 2 },
        { type: ["Scene"], rating: ["Everyone"], genre: ["Cyberpunk"], resolution: ["3840 x 2160"], misc: [] },
        {}
    ];
    for (const fixture of fixtures) {
        assert.deepEqual(plain(live.response(JSON.stringify(fixture) + "\n", 0)), fixture);
    }
    const failure = { error: "Steam rejected the key" };
    assert.deepEqual(plain(live.response(JSON.stringify(failure), 1)), failure);
    assert.match(live.response("", 1).error, /No response/);
    assert.match(live.response("{", 0).error, /Invalid response/);
    assert.match(live.response("[]", 0).error, /Invalid response/);
    assert.match(live.response("{}", 1).error, /code 1/);
});

test("renders the status, pause reasons, and service error", () => {
    assert.equal(live.statusText(status), "Playing");
    assert.equal(live.statusText({ ...status, state: "paused", reason: "maximized" }), "Paused: window maximized");
    assert.equal(live.statusText({ ...status, state: "waiting", reason: "gpu" }), "Waiting for GPU memory: showing the still");
    assert.equal(live.statusText({ ...status, state: "paused", reason: "fullscreen" }), "Paused: fullscreen");
    assert.equal(live.statusText({ ...status, state: "paused", reason: "dpms" }), "Paused: display is off");
    assert.equal(live.statusText({ ...status, state: "unloaded", reason: "game" }), "Unloaded: Game mode");
    assert.equal(live.statusText({ ...status, state: "stopped", mode: "static" }), "Stopped");
    assert.equal(live.statusText({ ...status, state: "error", error: "Missing renderer" }), "Error: Missing renderer");
    assert.match(live.statusText({ ...status, state: "stopped", error: "Service is not running" }), /Service is not running/);
});

test("maps Workshop sorts, periods and multi-select filters to argv", () => {
    assert.deepEqual(plain(live.sorts.map(sort => sort.value)), ["trend", "newest", "top", "subscribed", "updated"]);
    for (const [index, days] of [1, 7, 30, 90, 180, 365].entries()) {
        assert.equal(live.periods[index].value, days);
        assert.deepEqual(plain(live.queryArgs({ ...defaults, days }, "")),
            ["query", "--sort", "trend", "--days", String(days), "--rating", "everyone"]);
    }
    const filtered = {
        sort: "top", days: 30, types: ["scene", "video", "web"], ratings: ["everyone", "questionable", "mature"],
        tags: ["Cyberpunk", "Audio responsive"], resolution: "3840 x 2160", search: "  rain & neon  "
    };
    assert.deepEqual(plain(live.queryArgs(filtered, "AoE+BC/==")), [
        "query", "--sort", "top", "--type", "scene", "--type", "video", "--type", "web",
        "--rating", "everyone", "--rating", "questionable", "--rating", "mature",
        "--tag", "Cyberpunk", "--tag", "Audio responsive", "--resolution", "3840 x 2160",
        "--search", "rain & neon", "--cursor", "AoE+BC/=="
    ]);
    assert.ok(live.queryArgs({ ...defaults, search: "--cursor title" }, "").includes("--search=--cursor title"));
});

test("maps library and Workshop cards to distinct preview sources", () => {
    const localCard = live.gridItem(localScene, false);
    assert.equal(localCard.previewUrl, "file:///games/Steam%20Library/3400123/%E5%A4%9C%20%231%25.gif");
    assert.equal(localCard.wallpaperTitle, localScene.title);
    assert.equal(live.typeLabel(localCard.wallpaperType), "Scene");
    assert.equal(live.typeLabel("video"), "Video");
    assert.equal(live.typeLabel("web"), "Web");
    assert.equal(live.typeLabel("application"), "Application");

    const workshopCard = live.gridItem(workshopScene, true);
    assert.equal(workshopCard.wallpaperId, localCard.wallpaperId);
    assert.equal(workshopCard.previewUrl, workshopScene.preview_url);
    assert.equal(workshopCard.installedInQuery, true);
    assert.equal(workshopCard.subscriptions, workshopScene.subscriptions);
    assert.equal(live.gridItem({ ...workshopScene, preview_url: "file:///tmp/example" }, true).previewUrl, "");
    assert.equal(live.gridItem({ ...localScene, preview: "" }, false).previewUrl, "");
});

test("loads Workshop pages without duplicate items and stops on a repeated cursor", () => {
    const seen = new Set();
    const first = live.workshopPage({ items: [workshopScene], next_cursor: "AoE+BC/==" }, "", seen);
    assert.equal(first.items[0].wallpaperId, workshopScene.id);
    assert.equal(first.nextCursor, "AoE+BC/==");

    const secondItem = { ...workshopScene, id: "3400124", installed: false };
    const second = live.workshopPage(
        { items: [workshopScene, secondItem], next_cursor: first.nextCursor }, first.nextCursor, seen
    );
    assert.equal(second.items.length, 1);
    assert.equal(second.items[0].wallpaperId, secondItem.id);
    assert.equal(second.items[0].installedInQuery, false);
    assert.equal(second.nextCursor, "");
});

test("converts hex and decimal RGB to the renderer format", () => {
    assert.equal(live.colorValue("#FF8000"), "1 0.50196078 0");
    assert.equal(live.colorValue("  .50  1.0  0.00000001  "), "0.5 1 0.00000001");
    assert.equal(live.colorValue("00.000000001 01. 000"), "0.000000001 1 0");
    for (const invalid of ["", "#11223344", "0.3 0.5", "0 1.01 1", "-0.1 0 1", "0 0 NaN"])
        assert.equal(live.colorValue(invalid), null);
});

test("compares property defaults across equivalent CLI representations", () => {
    assert.equal(live.boolValue("false"), false);
    assert.equal(live.samePropertyValue("bool", false, "0"), true);
    assert.equal(live.samePropertyValue("bool", false, "true"), false);
    assert.equal(live.samePropertyValue("combo", 2, "2"), true);
    assert.equal(live.samePropertyValue("slider", "-0.5000", -0.5), true);
    assert.equal(live.samePropertyValue("color", "1.0 0.5 0.0", "1 .50 0"), true);
    assert.equal(live.samePropertyValue("color", "1 1 1", "0 1 1"), false);
    assert.equal(live.samePropertyValue("textinput", "rain ", "rain"), false);
});

test("hides clearly false conditions and leaves unknown expressions visible", () => {
    const values = new Map([["clock", "2"], ["fog", false], ["offset", -0.5], ["caption", ""]]);
    const visible = condition => live.propertyVisible({ condition }, values);
    assert.equal(visible("clock.value == 2"), true);
    assert.equal(visible("clock.value == 1"), false);
    assert.equal(visible("offset.value == -0.5"), true);
    assert.equal(visible("fog.value"), false);
    assert.equal(visible("caption.value"), false);
    assert.equal(visible("missing.value == 3"), true);
    assert.equal(visible("fog.value && clock.value == 2"), true);
    assert.equal(visible("fog.value == false"), true);
    assert.equal(visible(""), true);
});

test("passes value and reset commands as argv, preserving literal text", () => {
    assert.deepEqual(plain(live.propertyArgs("42", "fog", false)), ["prop", "--", "42", "fog", "false"]);
    assert.deepEqual(plain(live.propertyArgs("42", "size", -0.5)), ["prop", "--", "42", "size", "-0.5"]);
    for (const text of ["", "  rain & neon  ", "--reset", "--"])
        assert.deepEqual(plain(live.propertyArgs("42", "caption", text)), ["prop", "--", "42", "caption", text]);
    assert.deepEqual(plain(live.propertyArgs("42", "caption")), ["prop", "--reset", "--", "42", "caption"]);
    assert.deepEqual(plain(live.propertyArgs("42")), ["prop", "42", "--reset-all"]);
    assert.equal(live.textValue("  rain  "), "  rain  ");
    for (const text of ["line\nbreak", "line\rbreak", "a=b", "a\0b"])
        assert.equal(live.textValue(text), null);
});
