const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../bar/SwitcherLogic.js'), 'utf8').replace('.pragma library', ''), logic);
for (const [width,height] of [[4096,1728],[1536,864],[1280,800],[640,480]]) {
    for (const count of [0,1,4,7,15,30,100]) {
        const l = logic.layout(count,width,height);
        assert.ok(l.width <= width - 40);
        assert.ok(l.height <= height - 40);
        assert.ok(l.rows*l.columns >= count);
        assert.ok(l.visibleRows <= l.rows);
    }
}
assert.equal(logic.layout(4,1920,1080).rows,1);
assert.equal(logic.layout(4, 1920, 1080).width, 752);
assert.equal(logic.layout(4, 1920, 1080).height, 264);
const zoomed = logic.layout(4, 1920, 1080, n => Math.round(n * 1.5));
assert.equal(zoomed.cellWidth, 267);
assert.equal(zoomed.cellHeight, 255);
assert.equal(zoomed.width, 1128);
assert.equal(zoomed.height, 396);
const maxFont = n => Math.max(1, Math.round(n * Math.round(15 * 20 / 11) / 15));
for (const count of [1, 24]) {
    const small = logic.layout(count, 640, 450, maxFont);
    assert.ok(small.width <= 640);
    assert.ok(small.height <= 450);
    assert.ok(small.columns * small.rows >= count);
    assert.equal(small.visibleRows, 1);
    assert.equal(small.width, small.columns * small.cellWidth + 2 * small.padding);
    assert.equal(small.height, small.cellHeight + 2 * small.padding + maxFont(54));
}
const narrow = logic.layout(12, 320, 450, maxFont);
assert.ok(narrow.width <= 320);
assert.equal(narrow.columns, 1);
assert.ok(narrow.cellWidth > 0);
assert.ok(logic.layout(15,1920,1080).rows>1);
assert.ok(logic.layout(100,1280,800).rows>logic.layout(100,1280,800).visibleRows);
const n = logic.newer;
assert.ok(n('100c5xA-2', '100c5xA-1'));
assert.ok(!n('100c5xA-1', '100c5xA-2'));
assert.ok(n('100c9xB-1', '100c5xA-10'));
assert.ok(!n('100c5xA-10', '100c9xB-1'));
assert.ok(n('101c1xB-1', '100c900xA-3'));
assert.ok(n('100c5xA-1', ''));
console.log('Switcher: balanced grid, screen bounds, overflow and token order passed');
