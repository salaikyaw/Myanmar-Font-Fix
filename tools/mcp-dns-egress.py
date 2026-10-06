"""Loopback DNS UDP-to-TCP relay through the existing authenticated SSH SOCKS.
No query names or packet contents are logged.
"""
import socket, socketserver, struct
def readn(s,n):
    data=b''
    while len(data)<n:
        part=s.recv(n-len(data))
        if not part: raise OSError('EOF')
        data+=part
    return data
class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        data,udp=self.request
        if len(data)<12 or len(data)>4096: return
        try:
            with socket.create_connection(('127.0.0.1',1082),timeout=8) as s:
                s.sendall(b'\x05\x01\x00')
                if readn(s,2)!=b'\x05\x00': return
                s.sendall(b'\x05\x01\x00\x01\x7f\x00\x00\x35\x00\x35')
                r=readn(s,4)
                if r[1]: return
                n=4 if r[3]==1 else 16 if r[3]==4 else readn(s,1)[0]
                readn(s,n+2)
                s.sendall(struct.pack('!H',len(data))+data)
                reply=readn(s,struct.unpack('!H',readn(s,2))[0])
                udp.sendto(reply,self.client_address)
        except OSError: pass
class Server(socketserver.ThreadingMixIn,socketserver.UDPServer):
    daemon_threads=True
Server(('127.0.0.1',5354),Handler).serve_forever()
