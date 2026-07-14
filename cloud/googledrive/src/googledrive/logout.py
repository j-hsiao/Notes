import json
import os
import requests
from .util.command import Command
from .util.response import jformat
from .util.auth import Auth
from .googledrive import py_googledrive


@py_googledrive
class Logout(Command):
    def __init__(self):
        self.parser = p = self.get_parser()
        p.add_argument('auth', nargs='?', help='auth json or access token.', type=Auth)

    def __call__(self, args):
        auth = args.auth
        if not auth:
            print('Not logged in.')
            return True
        response = getattr(args, 'session', requests).post(
            'https://oauth2.googleapis.com/revoke?'
            + urlparse.urlencode([('token', auth['access_token'])]))
        print(response)
        print(jformat(response))
        auth.revoked()
        return response.status_code == 200
