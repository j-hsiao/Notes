"""Simple server to test certificates."""
import socket
import ssl
import argparse
import traceback


body = '''
<!DOCTYPE html>
<head>
</head>
<body>
    <h1>Hello!</h1>
    <p>This is a paragraph.</p>
</body>
'''

response = '\r\n'.join((
    'HTTP/1.0 200 OK',
    f'Content-Length: {len(body)}',
    '',
    body
))


def server(sock):
    while 1:
        try:
            client, addr = sock.accept()
        except Exception:
            traceback.print_exc()
        except KeyboardInterrupt:
            return
        else:
            try:
                f = client.makefile('rw')
                try:
                    print('Got connection from', addr)
                    req = f.readline().strip()
                    print('requested:', req)
                    if req.lower().startswith('get'):
                        if req.split(None, 3)[1].strip() == '/':
                            f.write(response)
                            f.flush()
                        else:
                            f.write(r'HTTP/1.0 404 NOT FOUND\r\n\r\nnot found...')
                    else:
                        f.write(r'HTTP/1.0 403 FORBIDDEN\r\n\r\nFORBIDDEN!!')
                finally:
                    try:
                        f.flush()
                        f.close()
                    except:
                        traceback.print_exc()
            finally:
                client.close()

def run(ip, port, cert, key):
    L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    L.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    L.bind((ip, port))
    L.listen(5)
    print('bound to:', L.getsockname())
    try:
        if cert and key:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert, key)
            server(context.wrap_socket(L, server_side=True))
        else:
            server(L)
    finally:
        L.close()

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('bind', default='localhost', help='iface[:port], if no port, use random port.', nargs='?')
    p.add_argument('-c', '--cert', help='signed server certificate')
    p.add_argument('-k', '--key', help='server key')
    args = p.parse_args()

    if ':' in args.bind:
        ip, port = args.bind.rsplit(':', 1)
    else:
        port = 0
        ip = args.bind
    run(ip, int(port), args.cert, args.key)
