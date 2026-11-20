// node quickshell/tests/bar_items.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../bar/BarItemsLogic.js'), 'utf8').replace('.pragma library', ''), m);
const plain = value => JSON.parse(JSON.stringify(value));

const pinned = ['kitty', 'slack'];
const status = m.DEFAULTS.status;

// Defaults: pinned apps follow the launcher applets in pin order.
assert.deepEqual(plain(m.resolve(null, pinned)), {
  launchers: ['applications', 'notebook', 'app:kitty', 'app:slack'], status: plain(status) });

// Unknown, duplicate and unpinned tokens drop out; controls stays in status.
const messy = { launchers: ['controls', 'bogus', 'app:gone', 'notebook', 'notebook', 'app:slack'], status: ['clock'] };
const resolved = plain(m.resolve(messy, pinned));
assert.deepEqual(resolved.launchers, ['applications', 'notebook', 'app:slack', 'app:kitty']);
assert.equal(resolved.status.filter(t => t === 'controls').length, 1);
assert.equal(resolved.status[resolved.status.length - 1], 'controls');
// A missing applet returns before its next default neighbour.
assert.ok(resolved.status.indexOf('volume') < resolved.status.indexOf('clock'));

// Moving between groups, before a token and to the end.
let items = plain(m.move(null, pinned, 'volume', 'launchers', 'app:kitty'));
assert.deepEqual(items.launchers, ['applications', 'notebook', 'volume', 'app:kitty', 'app:slack']);
assert.ok(!items.status.includes('volume'));
items = plain(m.move(items, pinned, 'app:slack', 'status', ''));
assert.equal(items.status[items.status.length - 1], 'app:slack');
items = plain(m.move(items, pinned, 'app:slack', 'status', 'tray'));
assert.equal(items.status[0], 'app:slack');

// A newly pinned app joins the launchers after the last app there.
assert.deepEqual(plain(m.resolve(items, pinned.concat(['steam']))).launchers,
  ['applications', 'notebook', 'volume', 'app:kitty', 'app:steam']);
// All apps moved away: new pins go to the end of launchers.
const none = plain(m.move(m.move(null, ['kitty'], 'app:kitty', 'status', ''), ['kitty'], 'notebook', 'status', ''));
assert.deepEqual(plain(m.resolve(none, ['kitty', 'steam'])).launchers, ['applications', 'app:steam']);

// Control Station cannot leave status; unknown tokens and groups change nothing.
const base = plain(m.resolve(null, pinned));
assert.deepEqual(plain(m.move(null, pinned, 'controls', 'launchers', '')), base);
assert.deepEqual(plain(m.move(null, pinned, 'bogus', 'status', '')), base);
assert.deepEqual(plain(m.move(null, pinned, 'clock', 'metrics', '')), base);
// Reordering inside status.
assert.deepEqual(plain(m.move(null, pinned, 'controls', 'status', 'tray')).status[0], 'controls');

console.log('bar items: ok');
