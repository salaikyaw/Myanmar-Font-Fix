"""Authenticated, fixed-upstream MCP relay. No request/body logging.
Uses verified HTTPS via the MCP egress proxy; never forwards gateway auth upstream.
"""
import http.server, os, hmac, urllib.request, urllib.error
TOKEN=os.environ.get('MCP_GATEWAY_AUTH_TOKEN','')
if not TOKEN: raise SystemExit('Missing gateway authentication token')
opener=urllib.request.build_opener(urllib.request.ProxyHandler({'https':'http://127.0.0.1:1083'}))
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_POST(self):
        if self.path!='/mcp': return self.send_error(404)
        if not hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+TOKEN): return self.send_error(401)
        try:
            length=int(self.headers.get('Content-Length','0'))
            if length<0 or length>4*1024*1024: return self.send_error(413)
            data=self.rfile.read(length)
            headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
            for name in ['Mcp-Session-Id','MCP-Protocol-Version']:
                if self.headers.get(name): headers[name]=self.headers[name]
            api=os.environ.get('CONTEXT7_API_KEY')
            if api: headers['CONTEXT7_API_KEY']=api
            req=urllib.request.Request('https://mcp.context7.com/mcp',data,headers,method='POST')
            try: response=opener.open(req,timeout=45)
            except urllib.error.HTTPError as e: response=e
            with response:
                body=response.read(16*1024*1024)
                self.send_response(response.status)
                for name in ['Content-Type','Mcp-Session-Id','MCP-Protocol-Version','Retry-After']:
                    if response.headers.get(name): self.send_header(name,response.headers[name])
                self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
        except (OSError,ValueError): self.send_error(502,'Upstream unavailable')
http.server.ThreadingHTTPServer(('0.0.0.0',8817),Handler).serve_forever()
