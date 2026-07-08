import argparse
import socket
import contextlib
import selectors
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib import parse as urlparse


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.send_response(200)
        self.end_headers()
        print(self.headers)
        length = self.headers.get('content-length', None)
        if length is None:
            print(self.rfile.read())
        else:
            print(self.rfile.read(int(length)))


    def do_GET(self):
        message = b'authorization stuff should be in the url bar.'
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', len(message))
        self.end_headers()
        self.wfile.write(message)
        for attr in ['command', 'path', 'version', 'headers', 'client_address']:
            print(attr, getattr(self, attr, None))

        splits = urlparse.urlsplit(self.path)
        print(splits)
        queries = urlparse.parse_qs(splits.query)
        for k, vals in queries.items():
            print(k, vals)
        print(urlparse.parse_qsl(splits.query))

def run():
    p = argparse.ArgumentParser()
    p.add_argument('-p', '--port', type=int, default=8080)
    args = p.parse_args()
    with contextlib.ExitStack() as stack:
        server = HTTPServer(('localhost', args.port), Handler)
        server.timeout = 60
        server.handle_request()


if __name__ == '__main__':
    run()
