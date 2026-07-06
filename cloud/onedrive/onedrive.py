import requests
from urllib import parse as urlparse
import uuid
import hashlib
import base64

# abraunegg onedrive dir sync thing.
# I think the id can be used here, and from reading docs, it seems
# like the data will only go to the redirect_uri, so even if I don't trust
# their code, there ?should? be no problem using this client id.
CLIENT_ID = 'd50ca740-c83f-4d1b-b616-12c519384f0c'


def get_auth_code(
    target='https://login.microsoftonline.com',
    tenant='common',
    redirect_uri=None,
    client_id=CLIENT_ID,
    response_type='code',
    scope='Files.ReadWrite',
    response_mode='fragment',
    prompt='login',
    version=2.0,
):
    split = urlparse.urlsplit(target)

    if redirect_uri is None:
        redirect_uri = split._replace(
            path='{}/oauth2/nativeclient'.format(tenant),
            query='', fragment='',
        ).geturl()
    # the example says it must be 43 characters long
    verify = base64.urlsafe_b64encode(uuid.uuid4().hex[:32].encode()).rstrip(b'=')
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verify).digest()).rstrip(b'=').decode()
    querystr = dict(
        response_type=response_type,
        redirect_uri=redirect_uri,
        client_id=client_id,
        scope=scope,
        response_mode=response_mode,
        prompt=prompt,
        code_challenge=challenge,
        code_challenge_method='S256',
    )
    requesturl = split._replace(
        query=urlparse.urlencode(querystr),
        path='/{}/oauth2{}/authorize'.format(tenant, '/v{}'.format(version) if version else ''),
        fragment=''
    ).geturl()
    return requesturl, verify


url, veri = get_auth_code()
print(url)
print(veri)

# open url in browser
# login
# it'd go to the corresponding link
# ...
