import argparse
import json
import mimetypes
import os

import requests

class Auth(object):
    def __init__(self, f):
        with open(f, 'r') as f:
            self.data = json.load(f)

    def __call__(self, headers):
        headers['Authorization'] = str(self)
        return headers

    def __str__(self):
        return 'Bearer ' + self.data['access_token']

def upload_simple(args):
    auth = Auth(args.auth)
    if args.mime is None:
        args.mime, encoding = mimetypes.guess_type(args.file)
        if args.mime is None:
            raise ValueError('Unknown mime for {}'.format(args.file))
    with open(args.file, 'rb') as f:
        response = requests.post(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=media',
            headers=auth({'Content-Type': args.mime}),
            data=f.read())

    print(response)
    try:
        result = response.json()
    except Exception:
        print(response.content)
    else:
        print(json.dumps(result, indent=4))
        return result

def upload_multi(args):
    auth = Auth(args.auth)
    if args.mime is None:
        args.mime, encoding = mimetypes.guess_type(args.file)
        if args.mime is None:
            raise ValueError('Unknown mime for {}'.format(args.file))
    if args.oname is None:
        args.oname = os.path.basename(args.file)

    metadata = {
        'name': args.oname,
        'mimeType': args.mime,
    }

    with open(args.file, 'rb') as f:
        response = requests.post(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
            files=(
                ('Metadata', ('metadata.json', json.dumps(metadata), 'application/json')),
                ('Media', (args.oname, f, args.mime)),
            ),
            headers=auth({})
        )
    print(response)
    try:
        result = response.json()
    except Exception:
        print(response.content)
    else:
        print(json.dumps(result, indent=4))
        return result

def upload_resumable(args):
    pass


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('auth', help='json containing access token')
    p.add_argument('file', help='file to upload')
    p.add_argument('oname', help='target name', nargs='?')
    p.add_argument('-m', '--mime', help='mimetype')
    args = p.parse_args()
    upload_multi(args)
