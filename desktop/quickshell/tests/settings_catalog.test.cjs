const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(__dirname + '/../bar/SettingsCatalog.js', 'utf8').replace('.pragma library', ''), context);
for (const [query, section] of [['gap', 'panels'], ['микрофон', 'audio'], ['wi-fi', 'network'], ['обои', 'themes'], ['update', 'system'], ['record', 'modes']]) {
  assert.ok(context.search(query).some(p => p.id === section), query);
}
assert.equal(context.target('gap'), 'Between tiled windows');
assert.ok(context.search('font').some(p => p.id === 'panels'));
assert.ok(context.search('геометрия').some(p => p.id === 'panels'));
assert.equal(context.target('font size'), 'Font size (pt)');
assert.equal(context.target('шрифт'), 'UI font');
assert.equal(context.target('radius'), 'UI metrics');
assert.ok(context.pages.every(p => context.groups.includes(p.group)), 'every page has a sidebar group');
assert.equal(context.search('unsupported setting').length, 0);
assert.equal(context.page('not-a-page').id, 'network');
assert.ok(!context.pages.some(p => ['quick', 'overview', 'clipboard'].includes(p.id)), 'tools are not settings pages');
assert.equal(context.matches('mic', 'audio').map(i => i.target).join(), 'Microphone');
assert.ok(context.search('bluetooth').some(p => p.id === 'network'), 'item words find their page');
assert.equal(context.matches('radius', 'panels')[0].title, 'UI metrics');
assert.equal(context.matches('', 'audio').length, 0);
assert.ok(context.matches('a', 'network').length <= 3);
console.log('Settings catalog: item matches, English/Russian search, targets and safe fallback passed');
