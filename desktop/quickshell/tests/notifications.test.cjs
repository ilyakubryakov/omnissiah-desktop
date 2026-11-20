// node quickshell/tests/notifications.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const n = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../bar/NotificationLogic.js'), 'utf8').replace('.pragma library', ''), n);

const item = (id, app, summary) => ({ id, app_name: app, summary });
const current = [item(9, 'Slack', 'New message in bots')];
const history = [item(9, 'Slack', 'New message in bots'), item(7, 'Slack', 'New message in bots'), item(8, 'Telegram', 'Chat'), item(3, 'Slack', 'New message in bots')];
const groups = n.groups(current, history);
assert.deepEqual(Array.from(groups, g => [g.notification.id, g.count, g.live]), [[9, 3, true], [8, 1, false]]);
assert.deepEqual(Array.from(groups[0].ids), ['9', '7', '3']);
assert.equal(n.groups([], []).length, 0);

const rules = [{ app: 'Slack', summary: '', tier: 'quiet' }, { app: 'Slack', summary: 'Mention', tier: 'important' }];
assert.equal(n.ruleTier(rules, 'Slack', ''), 'quiet');
assert.equal(n.ruleTier(rules, 'Slack', 'Mention'), 'important');
assert.equal(n.ruleTier(rules, 'Slack', 'Other'), 'normal');
assert.equal(n.tierLabel('normal'), '');
console.log('Notifications: repeat folding, live state and rule scopes passed');
assert.deepEqual(Array.from(n.links('<a href="https://example.org/?a=1&amp;b=2">link</a> javascript:bad https://example.org/?a=1&amp;b=2')), ['https://example.org/?a=1&b=2']);
assert.equal(n.verificationCode('Security code', 'Your code is 123456'), '123456');
assert.equal(n.verificationCode('Invoice', '123456'), '');
assert.equal(n.plainText('<b>Hello</b> &amp; goodbye'), 'Hello & goodbye');
