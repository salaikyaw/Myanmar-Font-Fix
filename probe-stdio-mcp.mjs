import { spawn } from 'node:child_process';

const [command, ...args] = process.argv.slice(2);
if (!command) throw new Error('Usage: node probe-stdio-mcp.mjs <command> [args...]');
const child = spawn(command, args, { shell: false, windowsHide: true, env: process.env });
let stdout = '';
let stderr = '';
let initialized = false;
let listed = false;

const finish = (code, result) => {
  console.log(JSON.stringify({ command, args, ...result, stderr: stderr.slice(-3000) }, null, 2));
  child.kill();
  process.exitCode = code;
};

child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
child.stdout.on('data', (chunk) => {
  stdout += chunk.toString();
  let newline;
  while ((newline = stdout.indexOf('\n')) !== -1) {
    const line = stdout.slice(0, newline).trim();
    stdout = stdout.slice(newline + 1);
    if (!line) continue;
    let message;
    try { message = JSON.parse(line); } catch { continue; }
    if (message.id === 1 && message.result && !initialized) {
      initialized = true;
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} }) + '\n');
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} }) + '\n');
    } else if (message.id === 2 && message.result && !listed) {
      listed = true;
      finish(0, { initialize: 'PASS', toolsList: 'PASS', toolCount: message.result.tools?.length ?? 0 });
    } else if (message.error) {
      finish(1, { initialize: initialized ? 'PASS' : 'FAIL', toolsList: 'FAIL', error: message.error.message });
    }
  }
});
child.on('error', (error) => finish(1, { initialize: 'FAIL', toolsList: 'FAIL', error: error.message }));
child.on('exit', (code) => {
  if (!listed) finish(1, { initialize: initialized ? 'PASS' : 'FAIL', toolsList: 'FAIL', error: `process exited ${code}` });
});
child.stdin.write(JSON.stringify({
  jsonrpc: '2.0', id: 1, method: 'initialize',
  params: { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'stdio-probe', version: '1.0' } }
}) + '\n');
setTimeout(() => {
  if (!listed) finish(1, { initialize: initialized ? 'PASS' : 'TIMEOUT', toolsList: 'TIMEOUT' });
}, 60000).unref();
