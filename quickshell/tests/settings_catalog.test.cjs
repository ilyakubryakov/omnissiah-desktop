const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/../bar/SettingsCatalog.js', 'utf8').replace('.pragma library', ''), context);
for (const [query, section] of [['gap', 'panels'], ['микрофон', 'audio'], ['tailscale', 'network'], ['обои', 'themes'], ['backup', 'system'], ['record', 'modes']]) {
  assert.ok(context.search(query).some(p => p.id === section), query);
}
assert.equal(context.target('gap'), 'Between tiled windows');
assert.equal(context.search('unsupported setting').length, 0);
assert.equal(context.page('not-a-page').id, 'quick');
console.log('Settings catalog: English/Russian search, targets and safe fallback passed');
