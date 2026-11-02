const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../bar/MinimizedLogic.js'), 'utf8').replace('.pragma library', ''), m);

const apps = {
  'google-chrome': { startupClass: '' },
  'com.google.Chrome': { startupClass: 'google-chrome' },
  'org.telegram.desktop': { startupClass: '' },
  'md.obsidian.Obsidian': { startupClass: '' },
  'org.kde.dolphin': { startupClass: '' },
  'thunderbird': { startupClass: 'thunderbird' },
};
const win = (address, cls, ws, focus) => ({ address, class: cls, workspace: ws === 'min' ? { id: -99, name: 'special:minimized' } : { id: ws, name: String(ws) }, focusHistoryID: focus });

const index = m.classIndex(apps);
assert.equal(m.appId(win('0x1', 'google-chrome', 1, 0), index), 'google-chrome');
assert.equal(m.appId(win('0x2', 'obsidian', 1, 0), index), 'md.obsidian.Obsidian');
assert.equal(m.appId(win('0x3', 'wfica', 1, 0), index), 'class:wfica');
assert.equal(m.matches('com.google.Chrome', win('0x1', 'google-chrome', 1, 0), apps), true);
assert.equal(m.matches('google-chrome', win('0x1', 'google-chrome', 1, 0), apps), true);
assert.equal(m.matches('org.kde.dolphin', win('0x1', 'google-chrome', 1, 0), apps), false);
assert.equal(m.matches('class:wfica', win('0x3', 'Wfica', 1, 0), apps), true);
assert.equal(m.matches('constructor', win('0x4', '', 1, 0), apps), false);

let state = m.updateOrder({}, 0, [win('0xa', 'kitty', 'min', 5), win('0xb', 'kitty', 'min', 2)]);
assert.deepEqual({ ...state.order }, { '0xa': 1, '0xb': 2 });
state = m.updateOrder(state.order, state.sequence, [win('0xb', 'kitty', 'min', 2), win('0xc', 'kitty', 'min', 0)]);
assert.deepEqual({ ...state.order }, { '0xb': 2, '0xc': 3 });
assert.equal(state.sequence, 3);

const minimized = [win('0xc', 'org.telegram.desktop', 'min', 1), win('0xa', 'wfica', 'min', 3), win('0xb', 'org.telegram.desktop', 'min', 2), win('0xd', 'google-chrome', 'min', 0)];
const order = { '0xa': 1, '0xb': 2, '0xc': 3, '0xd': 4 };
assert.deepEqual(Array.from(m.extraIds(minimized, ['com.google.Chrome'], apps, order)), ['class:wfica', 'org.telegram.desktop']);

assert.equal(m.pick([win('0x1', 'kitty', 'min', 0), win('0x2', 'kitty', 2, 4), win('0x3', 'kitty', 1, 1)], {}).address, '0x3');
assert.equal(m.pick([win('0x1', 'kitty', 'min', 0), win('0x2', 'kitty', 'min', 3)], { '0x1': 1, '0x2': 2 }).address, '0x2');
assert.equal(m.pick([], {}), null);

const unread = { telegram: 4, slack: 0, slack_dot: true, mail: 120 };
assert.equal(m.badge('org.telegram.desktop', unread), '4');
assert.equal(m.badge('slack', unread), 'dot');
assert.equal(m.badge('thunderbird', unread), '99+');
assert.equal(m.badge('kitty', unread), '');
assert.equal(m.badge('slack', { slack: 3, slack_dot: true }), '3');
assert.equal(m.badge('org.telegram.desktop', {}), '');
console.log('Minimized: class matching, minimize order, temporary icons, click choice and badges passed');
