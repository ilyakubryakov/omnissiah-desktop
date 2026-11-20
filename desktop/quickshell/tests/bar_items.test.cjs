const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../bar/BarItemsLogic.js'), 'utf8').replace('.pragma library', ''), m);
const plain = value => JSON.parse(JSON.stringify(value));

const pinned = ['kitty', 'slack'];
const status = m.DEFAULTS.status;

assert.deepEqual(plain(m.resolve(null, pinned)), {
  launchers: ['applications', 'notebook', 'app:kitty', 'app:slack'], status: plain(status) });

const messy = { launchers: ['controls', 'bogus', 'app:gone', 'notebook', 'notebook', 'app:slack'], status: ['clock'] };
const resolved = plain(m.resolve(messy, pinned));
assert.deepEqual(resolved.launchers, ['applications', 'notebook', 'app:slack', 'app:kitty']);
assert.equal(resolved.status.filter(t => t === 'controls').length, 1);
assert.equal(resolved.status[resolved.status.length - 1], 'controls');
assert.ok(resolved.status.indexOf('volume') < resolved.status.indexOf('clock'));

let items = plain(m.move(null, pinned, 'volume', 'launchers', 'app:kitty'));
assert.deepEqual(items.launchers, ['applications', 'notebook', 'volume', 'app:kitty', 'app:slack']);
assert.ok(!items.status.includes('volume'));
items = plain(m.move(items, pinned, 'app:slack', 'status', ''));
assert.equal(items.status[items.status.length - 1], 'app:slack');
items = plain(m.move(items, pinned, 'app:slack', 'status', 'tray'));
assert.equal(items.status[0], 'app:slack');

assert.deepEqual(plain(m.resolve(items, pinned.concat(['steam']))).launchers,
  ['applications', 'notebook', 'volume', 'app:kitty', 'app:steam']);
const none = plain(m.move(m.move(null, ['kitty'], 'app:kitty', 'status', ''), ['kitty'], 'notebook', 'status', ''));
assert.deepEqual(plain(m.resolve(none, ['kitty', 'steam'])).launchers, ['applications', 'app:steam']);

const base = plain(m.resolve(null, pinned));
assert.deepEqual(plain(m.move(null, pinned, 'controls', 'launchers', '')), base);
assert.deepEqual(plain(m.move(null, pinned, 'bogus', 'status', '')), base);
assert.deepEqual(plain(m.move(null, pinned, 'clock', 'metrics', '')), base);
assert.deepEqual(plain(m.move(null, pinned, 'controls', 'status', 'tray')).status[0], 'controls');

console.log('bar items: ok');
