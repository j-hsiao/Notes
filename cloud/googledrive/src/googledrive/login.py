"""Google oauth2 access tokens."""
import argparse
import contextlib
import functools
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import platform
import requests
import selectors
import sys
from urllib import parse as urlparse
import uuid
import webbrowser
import tkinter as tk

from .util.auth import Auth
from .util import command
from .util.pkce import PKCE
from .util import winsockstdin
from .util.response import jformat
from .googledrive import py_googledrive


class LocalAuthServer(HTTPServer):
    class HandlerClass(BaseHTTPRequestHandler):
        def __init__(self, q, *args, **kwargs):
            self.__q = q
            super(LocalAuthServer.HandlerClass, self).__init__(*args, **kwargs)

        def do_GET(self):
            path = urlparse.urlsplit(self.path)
            qs = urlparse.parse_qsl(path.query)
            self.__q.append(path.query)
            for name, val in qs:
                if name == 'code':
                    self.send_response(200)
                    self.send_header('Connection', 'close')
                    self.send_header('Content-Type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(b'Authorization Successful! You can close this tab.')
                    return
                elif name == 'error':
                    self.send_error(401, None, 'authorization failed: {}'.format(path.query))
                    return
            self.send_error(400, None, 'no recognized querystrings: {}'.format(self.path))
    def __init__(self, address=('localhost', 0)):
        self.__queryq = []
        super(LocalAuthServer, self).__init__(address, functools.partial(self.HandlerClass, self.__queryq))

    def port(self):
        return self.socket.getsockname()[1]

    def qs(self):
        try:
            return self.__queryq[0]
        except IndexError:
            return ''

@py_googledrive
class Token(command.Command):
    def __init__(self):
        self.parser = p = self.get_parser()
        p.add_argument('-o', '--output', help='save access token to a file.')

    def __call__(self, args):
        auth = getattr(args, 'auth', None)
        if auth:
            if args.output:
                with open(args.output, 'w') as f:
                    json.dump(auth.data, f)
            else:
                print(auth)
            return True
        return False

@py_googledrive
class Login(command.Command):
    def __init__(self):
        self.parser = p = self.get_parser()
        p.add_argument('app', help='app json file.', nargs='?')
        p.add_argument('-v', '--verbose', action='store_true')
        p.add_argument(
            '-s', '--scopes', nargs='*',
            default=['https://www.googleapis.com/auth/drive.file'], help='required scopes')

    def _find_default_app(self):
        print('Searching for google app info...')
        checkdirs = list(filter(None, ('.', os.environ.get('HOME'))))
        for dname in checkdirs:
            candidate = os.path.join(dname, '.googleapp')
            print('  searching for', candidate)
            if os.path.isfile(candidate):
                print('    found')
                return candidate
        for dname in checkdirs:
            candidates = [k for k in os.listdir(dname) if 'googleapp' in k.lower()]
            if candidates:
                print('  found:', candidates[0])
                return os.path.join(dname, candidates[0])
        raise ValueError('No app info found.')

    def _get_qs(self, appdata, query, verbose):
        with contextlib.ExitStack() as stack:
            server = stack.enter_context(LocalAuthServer())
            query['redirect_uri'] = 'http://localhost:{}'.format(server.port())
            url = '?'.join([
                appdata.get('auth_uri', 'https://accounts.google.com/o/oauth2/auth'),
                urlparse.urlencode(query)])
            print('If browser fails, copy url, authorize, and paste redirected url:')
            print(url)
            print('redirected url: ', end='', flush=True)
            r = tk.Tk()
            r.withdraw()
            r.call('clipboard', 'clear')
            r.call('clipboard', 'append', url)
            r.update()
            stack.callback(r.destroy)
            webbrowser.open(url)
            sel = stack.enter_context(selectors.DefaultSelector())
            sel.register(server, selectors.EVENT_READ)
            stack.callback(sel.unregister, server)
            sel.register(sys.stdin, selectors.EVENT_READ)
            stack.callback(sel.unregister, sys.stdin)
            while 1:
                for key, mask in sel.select(1):
                    if verbose:
                        print('selected!:', key, key.fileobj)
                    if key.fileobj is server:
                        server.handle_request()
                        if verbose:
                            print('query string from localhost:', server.qs())
                        return server.qs()
                    else:
                        if verbose:
                            print('reading a line...')
                        inp = sys.stdin.readline().rstrip()
                        if verbose:
                            print('Got stdin response:', inp)
                        result = urlparse.urlsplit(inp).query
                        if verbose:
                            print('result from stdin', result)
                        return result

    def __call__(self, args):
        if args.app is None:
            args.app = self._find_default_app()
        with open(args.app, 'r') as f:
            appdata = json.load(f)
        pkce = PKCE()
        for apptype, settings in appdata.items():
            print(apptype)
            q = {
                'client_id': settings['client_id'],
                'response_type': 'code',
                'scope': ' '.join(args.scopes),
                'state': uuid.uuid4().hex
            }
            pkce.challenge(q)
            rawqs = self._get_qs(settings, q, args.verbose)
            if not rawqs:
                print('No query string detected.')
                return False
            req = [
                ('client_id', settings['client_id']),
                ('client_secret', settings['client_secret']),
                ('grant_type', 'authorization_code'),
                ('redirect_uri', q['redirect_uri']),
            ]
            pkce.verify(req)
            for name, val in urlparse.parse_qsl(rawqs):
                if name == 'code':
                    req.append((name, val))
                elif name == 'state':
                    if val != q['state']:
                        print('State does not match!')
                        print('  original:', q['state'])
                        print('  current :', val)
                        return False
            if req[-1][0] != 'code':
                print('authorization code not found.')
                return False
            response = requests.post(
                settings.get('token_uri', 'https://oauth2.googleapis.com/token'),
                data=req)
            print(response)
            print(jformat(response))
            if response.status_code == 200:
                args.auth = Auth(response.json())
                return True
            return False

# def add_auth_code(req, rawqs, state=None):
#     if not rawqs:
#         return False
#     ok = False
#     for name, val in urlparse.parse_qsl(rawqs):
#         if name == 'code':
#             req.append((name, val))
#             ok = True
#         elif name == 'state' and state is not None:
#             if val != state:
#                 print('State does not match!')
#                 print('  original:', state)
#                 print('  current :', val)
#                 return False
#             else:
#                 print('verified state')
#     return ok

# def authorize(args):
#     if args.json is None:
#         for dname in (os.environ.get('HOME', None), os.path.dirname(__file__), '.'):
#             if dname:
#                 name = os.path.join(dname, '.googleapp.json')
#                 if os.path.isfile(name):
#                     args.json = name
#                     break
#         else:
#             raise ValueError('Need google app json file.')
#     with open(args.json, 'r') as f:
#         data = json.load(f)
#     for apptype, settings in data.items():
#         print(apptype)
#         if apptype not in ('web', 'installed'):
#             print('  unsupported')
#         pkce = PKCE(args.pkce)#
#         q = {'client_id': settings['client_id']}
#         q['response_type'] = 'code'
#         q['scope'] = ' '.join(args.scopes)
#         q['state'] = uuid.uuid4().hex
#         pkce.challenge(q)#
#         rawqs = None
#         with contextlib.ExitStack() as stack:
#             server = stack.enter_context(LocalAuthServer())
#             q['redirect_uri'] = 'http://localhost:{}'.format(server.port())
#             url = '?'.join([
#                 settings.get('auth_uri', 'https://accounts.google.com/o/oauth2/auth'),
#                 urlparse.urlencode(q)])

#             # webbrowser.open returns a bool
#             # however, this bool is only whether the process started
#             # not whether it succeeded
#             # Example: call xdg-open successfully => return True
#             # even if there are no browsers to open the url (failed)
#             # so always just take both...
#             print('If browser fails, copy url, authorize, and paste redirected url:')
#             print(url)
#             print('redirected url: ', end='', flush=True)
#             r = tk.Tk()
#             r.withdraw()
#             r.call('clipboard', 'clear')
#             r.call('clipboard', 'append', url)
#             r.update()
#             stack.callback(r.destroy)
#             # It seems if browser is before tk, then the url never gets copied
#             # to the clipboard... not sure why
#             webbrowser.open(url)
#             sel = stack.enter_context(selectors.DefaultSelector())
#             sel.register(server, selectors.EVENT_READ)
#             stack.callback(sel.unregister, server)
#             if platform.system() == 'Windows':
#                 r, w = socket.socketpair()
#                 def check(sock):
#                     sock.sendall(input().encode('utf-8'))
#                 t = threading.Thread(target=check, args=[w])
#                 t.daemon = True
#                 t.start()
#                 f = r.makefile('r')
#                 sel.register(r, selectors.EVENT_READ)
#                 stack.callback(sel.unregister, r)
#                 stack.callback(r.close)
#                 stack.callback(w.close)
#             else:
#                 sel.register(sys.stdin, selectors.EVENT_READ)
#                 stack.callback(sel.unregister, sys.stdin)
#                 f = sys.stdin
#             while rawqs is None:
#                 r.update()
#                 for key, mask in sel.select(1):
#                     if key.fileobj is server:
#                         server.handle_request()
#                         rawqs = server.qs()
#                         iters = 60
#                     else:
#                         rawqs = urlparse.urlsplit(input()).query
#                         iters = 60
#         if not rawqs:
#             print('Did not receive any authorization.')
#             return
#         req = [
#             ('client_id', settings['client_id']),
#             ('client_secret', settings['client_secret']),
#             ('grant_type', 'authorization_code'),
#             ('redirect_uri', q['redirect_uri']),
#         ]
#         pkce.verify(req)
#         add_auth_code(req, rawqs, q['state'])
#         response = requests.post(settings.get('token_uri', 'https://oauth2.googleapis.com/token'), data=req)
#         if response.status_code == 200:
#             try:
#                 result = response.json()
#             except Exception:
#                 print('Not json')
#                 print(response.content)
#                 return
#             else:
#                 if args.out:
#                     with open(args.out, 'wb') as f:
#                         f.write(response.content)
#                 return result
#         else:
#             print('Failed to get access token:', response)
#             try:
#                 jresponse = response.json()
#             except Exception:
#                 print(response.content)
#             else:
#                 print(json.dumps(jresponse, indent=4))

# if __name__ == '__main__':
#     p = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
#     p.add_argument('json', help='json file containing saved google client json info, needs client_id, client_secret, optionally auth_uri, token_uri.', nargs='?')
#     p.add_argument('-p', '--pkce', action='store_true', help='add pkce challenge and verifier fields.')
#     p.add_argument('-s', '--scopes', nargs='*', default=['https://www.googleapis.com/auth/drive.file'], help='the desired scopes (permissions) to request.')
#     p.add_argument('-o', '--out', help='output json access token file', default='accessgoogle.json')
#     p.add_argument('-r', '--revoke', action='store_true', help='revoke access token in `json`.  json should be --out of a previous run.')
#     args = p.parse_args()
#     if args.revoke:
#         revoke(args.json)
#     else:
#         result = authorize(args)
