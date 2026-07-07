import argparse
import socket
import contextlib
import selectors

def run():
    p = argparse.ArgumentParser()
    p.add_argument('-p', '--port', type=int, default=80)
    args = p.parse_args()

    with contextlib.ExitStack() as stack:
        L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        stack.callback(L.close)
        L.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        L.bind(('localhost', args.port))
        sel = selectors.DefaultSelector()
        stack.callback(sel.close)
        sel.register(L.fileno(), selectors.EVENT_READ)
        stack.callback(sel.unregister, L.fileno())
        L.listen(1)
        s, a = L.accept()
        print(s.recv(5))


if __name__ == '__main__':
    run()
