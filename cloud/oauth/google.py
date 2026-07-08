import argparse
import json
from urllib import parse as urlparse
import requests
import uuid



def authorize(fname):
    with open(fname, 'r') as f:
        data = json.load(f)
    for apptype, settings in data.items():
        print(apptype)
        if apptype == 'web':
            q = {'client_id': settings['client_id']}
            q['redirect_uri'] = settings['redirect_uris'][0]
            q['response_type'] = 'code'
            q['scope'] = 'https://www.googleapis.com/auth/drive.file'
            q['state'] = uuid.uuid4().hex
            url = '?'.join([settings['auth_uri'], urlparse.urlencode(q)])
            # TODO
            # bind a server to accept redirect, probably localhost
            # TODO
            # use browser whatever to start a browser with this url
            # TODO
            # modify the redirect_uri to use the bound server
            print(' ', url)

            redirected = input('redirect> ')
            qs = urlparse.parse_qsl(urlparse.urlsplit(redirected).query)
            req = [
                ('client_id', settings['client_id']),
                ('client_secret', settings['client_secret']),
                ('grant_type', 'authorization_code'),
                ('redirected_uri', settings['redirect_uris'][0]),
            ]
            for name, val in qs:
                if name == 'code':
                    req.append((name, val))
                elif name == 'state':
                    if val != q['state']:
                        print('State does not match!')
                        print('original:', q['state'])
                        print('current :', val)
            response = requests.post(settings['token_uri'], data=req)
            print('response:', response)
            print('code', response.status_code)
            try:
                jresponse = response.json()
            except Exception:
                print('content:', response.content)
            else:
                print(json.dumps(jresponse, indent=4))
        else:
            print('  unsupported')

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('json')
    args = p.parse_args()
    authorize(args.json)
