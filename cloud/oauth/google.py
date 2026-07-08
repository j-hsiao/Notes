"""Google oauth2 access tokens."""
import argparse
import base64
import functools
import hashlib
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import requests
from urllib import parse as urlparse
import uuid
import webbrowser

class PKCE(object):
    def __init__(self, method='S256'):
        if isinstance(method, bool):
            method = 'S256'
        self.code_challenge_method = method
        if method is None:
            return
        verifier = base64.urlsafe_b64encode(uuid.uuid4().hex.encode()).rstrip(b'=')
        self.code_verifier = verifier.decode()
        if method == 'S256':
            self.code_challenge = base64.urlsafe_b64encode(
                hashlib.sha256(verifier).digest()).rstrip(b'=').decode()
        elif method == 'plain':
            self.code_challenge = self.code_verifier
        else:
            raise ValueError('Invalid PKCE method {}'.format(method))


    def challenge(self, item):
        if self.code_challenge_method is None:
            return
        if isinstance(item, dict):
            item['code_challenge'] = self.code_challenge
            item['code_challenge_method'] = self.code_challenge_method
        elif isinstance(item, list):
            item.extend([
                ('code_challenge', self.code_challenge),
                ('code_challenge_method', self.code_challenge_method),
            ])
        else:
            raise ValueError('Can only add challenge to dict or list.')
    def verify(self, item):
        if self.code_challenge_method is None:
            return
        if isinstance(item, dict):
            item['code_verifier'] = self.code_verifier
        elif isinstance(item, list):
            item.extend([
                ('code_verifier', self.code_verifier),
            ])
        else:
            raise ValueError('Can only add challenge to dict or list.')

class Handler(BaseHTTPRequestHandler):
    def __init__(self, q, *args, **kwargs):
        self.__q = q
        super(Handler, self).__init__(*args, **kwargs)

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
                self.wfile.write(b'authorized, you can close this tab.')
                return
            elif name == 'error':
                self.send_error(401, None, 'authorization failed: {}'.format(path.query))
                return
        self.send_error(400, None, 'no recognized querystrings: {}'.format(path.query))

class LocalAuthServer(HTTPServer):
    def __init__(self, address=('localhost', 0)):
        self.__queryq = []
        super(LocalAuthServer, self).__init__(address, functools.partial(Handler, self.__queryq))

    def port(self):
        return self.socket.getsockname()[1]

    def qs(self):
        try:
            return self.__queryq[0]
        except IndexError:
            return None


def add_auth_code(req, rawqs, state=None):
    if not rawqs:
        return False
    ok = False
    for name, val in urlparse.parse_qsl(rawqs):
        if name == 'code':
            req.append((name, val))
            ok = True
        elif name == 'state' and state is not None:
            if val != state:
                print('State does not match!')
                print('  original:', state)
                print('  current :', val)
                return False
            else:
                print('verified state')
    return ok

def revoke(j):
    with open(j, 'r') as f:
        data = json.load(f)
    response = requests.post(
        'https://oauth2.googleapis.com/revoke?'
        + urlparse.urlencode([('token', data['access_token'])])
    )
    if response.status_code == 200:
        print('revoked')
    else:
        print('failed')
    print(response)
    print(response.content)



def authorize(args):
    with open(args.json, 'r') as f:
        data = json.load(f)
    for apptype, settings in data.items():
        print(apptype)
        if apptype == 'web':
            pkce = PKCE(args.pkce)#
            q = {'client_id': settings['client_id']}
            q['response_type'] = 'code'
            q['scope'] = ' '.join(args.scopes)
            q['state'] = uuid.uuid4().hex
            pkce.challenge(q)#
            with LocalAuthServer() as server:
                q['redirect_uri'] = 'http://localhost:{}'.format(server.port())
                url = '?'.join([settings['auth_uri'], urlparse.urlencode(q)])
                if webbrowser.open(url):
                    server.timeout = 60
                    server.handle_request()
                    rawqs = server.qs()
                else:
                    print('go to this url to provide authorization:')
                    print(url)
                    rawqs = urlparse.urlsplit(
                        input('redirect url after authentication> ')).query
            if not rawqs:
                print('Did not receive any authorization.')
                return
            req = [
                ('client_id', settings['client_id']),
                ('client_secret', settings['client_secret']),
                ('grant_type', 'authorization_code'),
                ('redirect_uri', q['redirect_uri']),
            ]
            pkce.verify(req)
            add_auth_code(req, rawqs, q['state'])
            response = requests.post(settings['token_uri'], data=req)
            if response.status_code == 200:
                try:
                    result = response.json()
                except Exception:
                    print('Not json')
                    print(response.content)
                    return
                else:
                    if args.out:
                        with open(args.out, 'wb') as f:
                            f.write(response.content)
                    return result
            else:
                print('Failed to get access token:', response)
                try:
                    jresponse = response.json()
                except Exception:
                    print(response.content)
                else:
                    print(json.dumps(jresponse, indent=4))
        else:
            print('  unsupported')

if __name__ == '__main__':
    p = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    p.add_argument('json', help='json file containing [client info|an access token to revoke].')
    p.add_argument('-p', '--pkce', action='store_true', help='add pkce challenge and verifier fields.')
    p.add_argument('-s', '--scopes', nargs='*', default=['https://www.googleapis.com/auth/drive.file'], help='the desired scopes (permissions) to request.')
    p.add_argument('-o', '--out', help='output json access token file', default='accessgoogle.json')
    p.add_argument('-r', '--revoke', action='store_true', help='`json` conatins an access token to revoke.')
    args = p.parse_args()
    if args.revoke:
        revoke(args.json)
    else:
        result = authorize(args)
