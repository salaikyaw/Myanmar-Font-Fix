"""Bounded, read-only MCP initialization test; never prints response content."""
import json, subprocess, selectors, time, sys
name=sys.argv[1]
p=subprocess.Popen(['docker','run','--rm','-i','--network','bridge',
    '-e','HTTPS_PROXY=http://172.17.0.1:1083',
    '-e','HTTP_PROXY=http://172.17.0.1:1083',
    'mcp-remote-egress:local',name], stdin=subprocess.PIPE,
    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
def send(obj):
    p.stdin.write(json.dumps(dict(jsonrpc='2.0',**obj))+'\n');p.stdin.flush()
sel=selectors.DefaultSelector();sel.register(p.stdout,selectors.EVENT_READ)
try:
    send(dict(id=1,method='initialize',params=dict(protocolVersion='2024-11-05',
        capabilities={},clientInfo=dict(name='egress-verifier',version='1'))))
    deadline=time.monotonic()+55
    passed=False
    while time.monotonic()<deadline:
        if not sel.select(1):
            if p.poll() is not None: break
            continue
        line=p.stdout.readline()
        if not line: break
        obj=json.loads(line)
        if obj.get('id')==1:
            if 'error' in obj: break
            send(dict(method='notifications/initialized'))
            send(dict(id=2,method='tools/list',params={}))
        if obj.get('id')==2:
            names=[x['name'] for x in obj.get('result',{}).get('tools',[])]
            passed=bool(names)
            print(json.dumps(dict(adapter=name,ok=passed,tools=names)),flush=True)
            break
    if not passed: print(json.dumps(dict(adapter=name,ok=False)),flush=True)
finally:
    p.stdin.close()
    try:p.wait(timeout=5)
    except subprocess.TimeoutExpired:p.terminate();p.wait(timeout=5)
sys.exit(0 if passed else 1)
