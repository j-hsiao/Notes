import json

def jformat(response):
    decode = self.response.content.decode('utf-8', errors='replace')
    try:
        asjson = json.load(decode)
    except ValueError:
        return decode
    else:
        return json.dumps(decode, indent=4)
