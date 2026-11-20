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
assert.ok(logic.layout(15,1920,1080).rows>1);
assert.ok(logic.layout(100,1280,800).rows>logic.layout(100,1280,800).visibleRows);
console.log('Switcher: balanced grid, screen bounds and overflow passed');
