const fs = require('fs');

const configPath = 'C:\\Users\\salai\\.config\\opencode\\opencode.json';
const names = [
  'browser-control-familyitsharing',
  'browser-control-usalaikyaw',
  'browser-control-salaisystem',
  'browser-control-tandj41125',
  'browser-control-salaikyawnaing94',
  'browsermcp',
  'mcp-chrome',
];

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
if (!config.mcp || typeof config.mcp !== 'object') {
  throw new Error('OpenCode top-level mcp object is missing.');
}

let removed = 0;
for (const name of names) {
  if (Object.prototype.hasOwnProperty.call(config.mcp, name)) {
    delete config.mcp[name];
    removed += 1;
  }
}

const temporaryPath = `${configPath}.sk-new`;
fs.writeFileSync(temporaryPath, `${JSON.stringify(config, null, 2)}\n`, 'utf8');
JSON.parse(fs.readFileSync(temporaryPath, 'utf8'));
fs.renameSync(temporaryPath, configPath);
console.log(`REMOVED_BROWSER_PROFILES=${removed}`);
