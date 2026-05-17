import io
import re
import socket
import subprocess as sp

def localip(flags=('broadcast', 'multicast')):
    flags='(?:{},?)*'.format('|'.join(flags).join(('(?:', ')')))
    device = re.compile(r'[0-9]: (?P<name>\S+): <[^>]*' + flags + '[^>]*>', re.IGNORECASE)

    inet = re.compile(r'^\s+inet (?P<addr>(?:\d{1,3}\.?){4,4})')
    inet6 = re.compile(r'^\s+inet6 (?P<addr>(?:[0-9a-fA-F]{0,4}:?){1,8})')

    lines = sp.check_output(['ip', 'a'])
    info = []
    indent = []
    for line in lines.decode('utf-8', errors='replace').splitlines():
        mt = device.match(line)
        if mt:
            info.append({'name': mt.group('name'), 'addrs': {}})
            continue
        mt = inet.match(line)
        if mt:
            info[-1]['addrs']['inet'] = mt.group('addr')
        mt = inet6.match(line)
        if mt:
            info[-1]['addrs']['inet6'] = mt.group('addr')
    return info

def receive(out, host=None, port=0):
    L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    if host is None:
        candidates = []
        ips = localip()
        for info in ips:
            for iface, addr in info['addrs'].items():
                if addr.startswith('192.168.'):
                    candidates.append(addr)
        if len(candidates) > 1:
            for info in ips:
                print(info['name'])
                for iface, addr in info['addrs'].items():
                    print('  ', iface, addr)
            raise ValueError('Ambiguous host.')
        elif candidates:
            host = candidates[0]
        else:
            host = '127.0.0.1'
    try:
        L.bind((host, 0))
        print(L.getsockname())
        L.listen(1)
        s, a = L.accept()
        buf = bytearray(io.DEFAULT_BUFFER_SIZE)
        view = memoryview(buf)
        with open(out, 'wb') as f:
            amt = s.recv_into(buf)
            while amt:
                f.write(view[:amt])
                amt = s.recv_into(buf)
    finally:
        L.close()

def send(fname, addr):
    if isinstance(addr, str):
        host, port = addr.rsplit(':', 1)
        addr = (host, int(port))
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.connect(addr)
        buf = bytearray(io.DEFAULT_BUFFER_SIZE)
        view = memoryview(buf)
        with open(fname, 'rb') as f:
            amt = f.readinto(view)
            while amt:
                s.sendall(view[:amt])
                amt = f.readinto(view)
    finally:
        s.close()

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('src')
    p.add_argument('dst', nargs='?')
    args = p.parse_args()
    if args.dst:
        send(args.src, args.dst)
    else:
        receive(args.src)
