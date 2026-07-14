import json
import os

class Auth(object):
    def __init__(self, f):
        if isinstance(f, str):
            if os.path.exists(f):
                with open(f, 'r') as f:
                    self.data = json.load(f)
            else:
                self.data = {'access_token': f}
        elif hasattr(f, 'read'):
            self.data = json.load(f)
        elif isinstance(f, Auth):
            self.data = f.data.copy()
        elif isinstance(f, dict):
            self.data = f.copy()
        elif f is None:
            self.data = {}
        else:
            raise ValueError('Bad value for Auth(): {}'.format(f))
        try:
            self.bearer = 'Bearer ' + self.data['access_token']
        except:
            self.bearer = ''

    def revoked(self):
        self.bearer = ''

    def __getitem__(self, k):
        return self.data[k]

    def __bool__(self):
        return bool(self.bearer)

    def __call__(self, headers):
        """Add `Authorization` header to dict of headers."""
        if self.bearer:
            headers['Authorization'] = self.bearer
        return headers

    def __str__(self):
        return self.bearer
