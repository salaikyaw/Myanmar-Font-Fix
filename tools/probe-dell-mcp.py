import concurrent.futures, json, sys, os, urllib.request, urllib.error

host = sys.argv[1] if len(sys.argv)>1 else '192.168.1.4'
names = ['core','coding','automation','collaboration','data','research','cloud','system','trading','searx']
def probe(item):
    port, name = item
    url=f'http://{host}:{port}/mcp'
    headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
    token=os.environ.get('MCP_GATEWAY_AUTH_TOKEN')
    if not token and os.name=='nt':
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER,'Environment') as key:
                token=winreg.QueryValueEx(key,'MCP_GATEWAY_AUTH_TOKEN')[0]
        except FileNotFoundError: pass
    if token: headers['Authorization']='Bearer '+token
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    def send(body):
        req=urllib.request.Request(url, json.dumps(body).encode(), headers)
        with opener.open(req,timeout=20) as r:
            session=r.headers.get('Mcp-Session-Id')
            if session: headers['Mcp-Session-Id']=session
            if r.status==202: return {}
            if 'text/event-stream' in r.headers.get('Content-Type',''):
                for line in r:
                    if line.startswith(b'data:'):
                        data=json.loads(line[5:])
                        if data.get('id')==body.get('id'): return data
            else: return json.load(r)
        raise RuntimeError('No JSON-RPC response')
    try:
        init=send({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'repair-verifier','version':'1'}}})
        if 'error' in init: raise RuntimeError('initialize JSON-RPC error')
        headers['MCP-Protocol-Version']=init['result']['protocolVersion']
        send({'jsonrpc':'2.0','method':'notifications/initialized'})
        tools=[]; cursor=None
        for n in range(20):
            reply=send({'jsonrpc':'2.0','id':n+2,'method':'tools/list','params':({'cursor':cursor} if cursor else {})})
            if 'error' in reply: raise RuntimeError('tools/list JSON-RPC error')
            tools.extend(t['name'] for t in reply['result'].get('tools',[]))
            cursor=reply['result'].get('nextCursor')
            if not cursor: break
        result={'gateway':name,'port':port,'ok':bool(tools),'tools':len(tools)}
        if '--names' in sys.argv: result['names']=tools
        if '--call' in sys.argv and name=='core' and 'fetch' in tools:
            called=send({'jsonrpc':'2.0','id':100,'method':'tools/call','params':{'name':'fetch','arguments':{'url':'https://example.com','max_length':100}}})
            result['fetch_call_ok']='error' not in called and not called.get('result',{}).get('isError',False)
        checks={
            'coding':('resolve-library-id',{'libraryName':'python','query':'Python official documentation'}),
            'research':('resolve-library-id',{'libraryName':'python','query':'Python official documentation'}),
            'cloud':('search_cloudflare_documentation',{'query':'Workers getting started'}),
            'system':('list_allowed_directories',{})}
        if '--call' in sys.argv and name in checks:
            tool,args=checks[name]
            if tool in tools:
                called=send({'jsonrpc':'2.0','id':101,'method':'tools/call','params':{'name':tool,'arguments':args}})
                result['read_only_call_ok']='error' not in called and not called.get('result',{}).get('isError',False)
        return result
    except Exception as e:
        return {'gateway':name,'port':port,'ok':False,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
    for result in pool.map(probe,enumerate(names,8812)):
        print(json.dumps(result),flush=True)
