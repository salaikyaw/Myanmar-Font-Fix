import socket
import sys
import time

mac = bytes.fromhex(sys.argv[1].replace(':', '').replace('-', ''))
if len(mac) != 6:
    raise ValueError('Expected a six-byte MAC address')
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
    client.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    for _ in range(12):
        client.sendto(b'\xff' * 6 + mac * 16, ('192.168.1.255', 9))
        time.sleep(5)
