#!/usr/bin/env python
"""Testing bitbucket OAuth and access tokens...

sidenote on shebang:
    using py instead of python seems to cause some kind of
    infinite loop or something...

To use this as GIT_ASKPASS:
    1. install gittok (stores/manages files with "tokens")
    2. Create an oauth token
    3. gittok -a name_of_oauth_token, enter "<key>:<secret>" as token,
        enter the password
    4. This will use gittok to retrieve the key:secret via gittok,
        send a request to get the access token, and then finally print
        the access token back to git

OAuth access tokens are created on workspaces

OAuth works by:
1. Use key/secret to ask for an access token
    method 1:
        https://bitbucket.org/site/oauth2/authorize?client_id=${key}&response_type=token
        requires interaction: click grant
        it will redirect to the callback site with postfix:
            #access_token=REgkbnvsPNN_KVKp2j9zHKGiY9A08ObhMRscsfXZd8LLh--lsV53qn52VYefOZQnC4QAJkgRhuE3P-xT4TRVD5-B8CwVWspj4FJMvsC37ufN76Wdq_f4rRPr
            &scopes=repository%3Adelete+repository%3Awrite
            &expires_in=7200
            &token_type=bearer
    method 2:
        requires interaction: click grant
        https://bitbucket.org/site/oauth2/authorize?client_id=${key}&response_type=code
        redirects to callback site with postfix:
            ?code=3TDD5KaATGHNrdLQDm
        use the code:
            curl -X POST -u "client_id:secret" \
              https://bitbucket.org/site/oauth2/access_token \
              -d grant_type=authorization_code -d code={code}
    method 3: (requires private oauth consumer)
        no interaction needed
        post to https://bitbucket.org/site/oauth2/access_token
            headers:
                Authorization: Basic "base64-encoded key:secret"
            data:
                grant_type: client_credentials
2. receive the token/authorization:
    response is json:
    {
        "scopes": "repository:delete repository:write",
        "access_token": "the access token",
        "expires_in": 7200,
        "token_type": "bearer",
        "state": "client_credentials",
        "refresh_token": "b4c9eBBwbd3DnG3NQZ"
    }
3. use username: "x-token-auth", password: the access token
"""
from __future__ import print_function
import argparse
import base64
import requests
import subprocess as sp
import sys

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('prompt')
    args = p.parse_args()
    if 'password' in args.prompt.lower():
        print('prompt has password', file=sys.stderr)
        p = sp.Popen(['gittok', args.prompt], stdout=sp.PIPE)
        print('waiting on gittok...', file=sys.stderr)
        o, e = p.communicate()
        if p.returncode == 0:
            auth = base64.b64encode(o.splitlines()[0])
            response = requests.post(
                'https://bitbucket.org/site/oauth2/access_token',
                data=dict(grant_type='client_credentials'),
                headers=dict(Authorization=' '.join(('Basic', auth.decode('utf-8'))))
            )
            if response.status_code == 200:
                print(response.json()['access_token'])
                sys.exit(0)
            else:
                print(response.content)
        sys.exit(1)
    else:
        print(args.prompt, file=sys.stderr)
        inp = input if sys.version_info.major > 2 else raw_input
        print(inp())
