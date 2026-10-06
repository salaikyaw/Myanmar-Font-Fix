const fs = require('fs');

const configPath = 'C:\\Users\\salai\\.config\\opencode\\opencode.json';
const names = [
  'browser-control-familyitsharing',
  'browser-control-usalaikyaw',
  'browser-control-salaisystem',
  'browser-control-tandj41125',
  'browser-control-salaikyawnaing94',
];

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
if (!config.mcp || typeof config.mcp !== 'object') {
  throw new Error('OpenCode top-level mcp object is missing.');
}

let changed = 0;
for (const name of names) {
  const entry = config.mcp[name];
  if (!entry) throw new Error(`MCP entry is missing: ${name}`);
  if (entry.type !== 'local') throw new Error(`Unexpected MCP type for ${name}`);

  if (typeof entry.command === 'string') {
    const args = Array.isArray(entry.args) ? entry.args : [];
    entry.command = [entry.command, ...args];
    delete entry.args;
    changed += 1;
  }
  if (entry.env && !entry.environment) {
    entry.environment = entry.env;
    delete entry.env;
    changed += 1;
  }
}

const temporaryPath = `${configPath}.sk-new`;
fs.writeFileSync(temporaryPath, `${JSON.stringify(config, null, 2)}\n`, 'utf8');
JSON.parse(fs.readFileSync(temporaryPath, 'utf8'));
fs.renameSync(temporaryPath, configPath);
console.log(`UPDATED_ENTRIES=${names.length}`);
console.log(`STRUCTURAL_CHANGES=${changed}`);
