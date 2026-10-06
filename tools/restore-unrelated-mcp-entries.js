const fs = require('fs');
const restores = [
  ['C:/Users/salai/AppData/Roaming/Jan/data/mcp_config.json', 'C:/SK_AI/backups/jan-config/20260908-before-removing-browser-mcps/mcp_config.json', 'mcpServers', 'Jan Browser MCP'],
  ['C:/Users/salai/.config/opencode/opencode.json', 'C:/SK_AI/backups/opencode-config/20260908-before-removing-generic-browser-mcps/opencode.json', 'mcp', 'mcp-chrome'],
];
for (const [file, backup, group, name] of restores) {
  const current = JSON.parse(fs.readFileSync(file, 'utf8'));
  const previous = JSON.parse(fs.readFileSync(backup, 'utf8'));
  if (current[group] && !Object.hasOwn(current[group], name) && previous[group]?.[name]) {
    current[group][name] = previous[group][name];
    fs.writeFileSync(file + '.sk-restored', JSON.stringify(current, null, 2) + '\n');
    fs.renameSync(file + '.sk-restored', file);
    console.log('Restored unrelated entry: ' + name);
  }
}
