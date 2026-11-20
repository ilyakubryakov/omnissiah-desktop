// node quickshell/tests/panel_window.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const logic = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../bar/PanelWindowLogic.js`, 'utf8'), logic);
const monitor = { id: 1, name: 'DP-3', x: 0, y: 0, width: 5120, height: 2160,
  scale: 1.25, reserved: [0, 30, 0, 30], activeWorkspace: { id: 1 } };
const win = (address, at, size, extra = {}) => ({ address, at, size, monitor: 1,
  mapped: true, visible: true, floating: false, workspace: { id: 1 }, class: 'kitty', ...extra });
const left = win('left', [3, 33], [2022, 1662]);
const right = win('right', [2031, 53], [2062, 1642]);
const surface = clients => logic.surfaceWindow(clients, [monitor], 'DP-3', 0, 6);
// Actual workspace 1: a tab group reserves 20 logical px above its client.
assert.equal(surface([left, right]), null);
const grouped = { ...right, grouped: ['right', 'inactive'] };
assert.ok(surface([left, grouped]));
// Inactive tabs with old geometry must not fill real holes.
const inactive = { ...right, visible: false, grouped: ['right', 'inactive'] };
assert.equal(surface([left, inactive]), null);
assert.equal(surface([left, { ...grouped, floating: true }]), null);
assert.equal(surface([left, { ...grouped, at: [2031, 100], size: [2062, 1595] }]), null);
assert.equal(surface([left, { ...grouped, workspace: { id: 2 } }]), null);
// Overlap and bounding-box coverage must not hide an uncovered interior.
assert.equal(logic.coversArea([
  win('a', [0, 0], [60, 40]), win('b', [40, 0], [60, 40]),
  win('c', [0, 60], [100, 40])
], [0, 0, 100, 100], 0), false);
assert.ok(surface([win('max', [100, 100], [500, 500], { floating: true, fullscreen: 1 })]));
console.log('Panel coverage: grouped tabs, visibility, gaps, workspace, floating and maximized passed');
