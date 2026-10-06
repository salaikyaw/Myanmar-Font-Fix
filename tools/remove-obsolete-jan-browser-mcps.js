const fs = require('fs');

const configPath = 'C:\\Users\\salai\\AppData\\Roaming\\Jan\\data\\mcp_config.json';
const names = ['browsermcp', 'Jan Browser MCP'];

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
if (!config.mcpServers || typeof config.mcpServers !== 'object') {
  throw new Error('Jan mcpServers object is missing.');
}

let removed = 0;
for (const name of names) {
  if (Object.prototype.hasOwnProperty.call(config.mcpServers, name)) {
    delete config.mcpServers[name];
    removed += 1;
  }
}

const temporaryPath = `${configPath}.sk-new`;
fs.writeFileSync(temporaryPath, `${JSON.stringify(config, null, 2)}\n`, 'utf8');
JSON.parse(fs.readFileSync(temporaryPath, 'utf8'));
fs.renameSync(temporaryPath, configPath);
console.log(`REMOVED_JAN_BROWSER_MCPS=${removed}`);
