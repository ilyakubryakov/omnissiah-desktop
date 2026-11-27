const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const geometry = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/../bar/DesktopCardGeometry.js', 'utf8').replace('.pragma library', ''), geometry);

const minimum = {width: 268, height: 256}, maximum = {width: 1280, height: 960};
const area = {width: 1024, height: 704};
const saved = {x: 1650, y: 780, width: 600, height: 480};
assert.ok(geometry.valid(saved));
assert.ok(!geometry.valid({x: 0, width: 300, height: 200}));
assert.ok(!geometry.valid({x: 0, y: 0, width: 0, height: 200}));
const moved = {...geometry.fit(saved, area, minimum, maximum)};
assert.deepEqual(moved, {x: 424, y: 224, width: 600, height: 480}, 'restore after resolution change');
assert.deepEqual({...geometry.fit(saved, {width: 240, height: 220}, minimum, maximum)},
    {x: 0, y: 0, width: 240, height: 220}, 'stay visible even below minimum size');
assert.deepEqual({...geometry.edit(moved, -480, 20, false, area, minimum, maximum)},
    {x: 0, y: 224, width: 600, height: 480}, 'move within screen without changing size');
assert.deepEqual({...geometry.edit(moved, 800, -400, true, area, minimum, maximum)},
    {x: 424, y: 224, width: 600, height: 256}, 'resize stays anchored at its top left');
assert.deepEqual({...geometry.edit({x: 0, y: 0, width: 352, height: 384}, 2000, 2000,
    true, {width: 3000, height: 2000}, minimum, maximum)},
    {x: 0, y: 0, width: 1280, height: 960}, 'large screens still respect the size caps');

assert.deepEqual({...geometry.snap({x: 37, y: 13, width: 300, height: 300}, 24, false, area, minimum, maximum)},
                 {x: 48, y: 24, width: 300, height: 300});
assert.deepEqual({...geometry.snap({x: 48, y: 24, width: 461, height: 390}, 24, true, area, minimum, maximum)},
                 {x: 48, y: 24, width: 456, height: 384});
assert.deepEqual({...geometry.snap({x: 5, y: 5, width: 300, height: 300}, 0, false, area, minimum, maximum)},
                 {x: 5, y: 5, width: 300, height: 300});
const portrait = {x: 48, y: 48, width: 256, height: 426};
const portraitMin = {width: 176, height: 306}, portraitMax = {width: 640, height: 1002};
assert.deepEqual({...geometry.resizeAspect(portrait, true, 31, 24, area, portraitMin, portraitMax, 2 / 3, 42)},
    {x: 48, y: 48, width: 288, height: 474});
assert.deepEqual({...geometry.resizeAspect(portrait, false, 27, 24, area, portraitMin, portraitMax, 2 / 3, 42)},
    {x: 48, y: 48, width: 276, height: 456});
assert.deepEqual({...geometry.fit(portrait, {width: 240, height: 240}, portraitMin, portraitMax, 2 / 3, 42)},
    {x: 48, y: 0, width: 132, height: 240});
console.log('Desktop cards: clamped drag, resize, screen changes, grid snapping and aspect ratios passed');
