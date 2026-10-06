"""Restricted HTTP CONNECT bridge to the existing local SSH SOCKS tunnel.
TLS is end-to-end; this process neither decrypts nor logs request contents.
"""
import http.server, socket, socketserver, select, struct, urllib.parse, threading, ipaddress

def exact(sock,n):
    data=b''
    while len(data)<n:
        chunk=sock.recv(n-len(data))
        if not chunk: raise OSError('SOCKS EOF')
        data+=chunk
    return data

def upstream(host,port):
    s=socket.create_connection(('127.0.0.1',1082),timeout=15)
    try:
        s.sendall(b'\x05\x01\x00')
        if exact(s,2)!=b'\x05\x00': raise OSError('SOCKS authentication failed')
        h=host.encode('idna')
        if not 0<len(h)<256: raise ValueError('Invalid host')
        s.sendall(b'\x05\x01\x00\x03'+bytes([len(h)])+h+struct.pack('!H',port))
        reply=exact(s,4)
        if reply[1]!=0: raise OSError('SOCKS connect failed')
        size={1:4,4:16}.get(reply[3])
        if reply[3]==3: size=exact(s,1)[0]
        if size is None: raise OSError('Invalid SOCKS response')
        exact(s,size+2)
        return s
    except Exception:
        s.close(); raise

class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*args): pass
    def handle_one_request(self):
        ip=ipaddress.ip_address(self.client_address[0])
        if not (ip.is_loopback or ip in ipaddress.ip_network('172.17.0.0/16')):
            self.close_connection=True; return
        self.connection.settimeout(30)
        return super().handle_one_request()
    def relay(self,s):
        with s:
            while True:
                ready,_,_=select.select([self.connection,s],[],[],90)
                if not ready: return
                for src in ready:
                    data=src.recv(65536)
                    if not data: return
                    (s if src is self.connection else self.connection).sendall(data)
    def do_CONNECT(self):
        try:
            target=urllib.parse.urlsplit('//'+self.path)
            if target.port!=443: return self.send_error(403)
            s=upstream(target.hostname,443)
            self.send_response(200); self.end_headers(); self.wfile.flush()
            self.close_connection=True
            self.relay(s)
        except (OSError,ValueError):
            self.close_connection=True
    def do_GET(self):
        try:
            target=urllib.parse.urlsplit(self.path)
            if target.scheme!='http' or (target.port or 80)!=80: return self.send_error(403)
            s=upstream(target.hostname,80)
            path=urllib.parse.urlunsplit(('', '', target.path or '/',target.query,''))
            lines=[f'{self.command} {path} HTTP/1.1']
            lines += [f'{k}: {v}' for k,v in self.headers.items() if k.lower() not in ('proxy-authorization','proxy-connection','connection')]
            lines+=['Connection: close','','']
            s.sendall('\r\n'.join(lines).encode('latin-1'))
            length=int(self.headers.get('Content-Length','0'))
            if length: s.sendall(self.rfile.read(length))
            self.close_connection=True
            self.relay(s)
        except (OSError,ValueError): self.close_connection=True
    do_HEAD=do_GET

class Server(socketserver.ThreadingMixIn,http.server.HTTPServer):
    daemon_threads=True

servers=[Server((addr,1083),Handler) for addr in ('127.0.0.1','172.17.0.1')]
for server in servers[:-1]: threading.Thread(target=server.serve_forever,daemon=True).start()
servers[-1].serve_forever()
