"""Create two dedicated test accounts. Credentials stay in a mode-0600 local file.
Run only against the student's project. Never add the output file to Git.
"""
import json, os, pathlib, secrets, requests
config = json.load(open('android/app/google-services.json'))
key = config['client'][0]['api_key'][0]['current_key']
path = pathlib.Path('/tmp/science-signal-test.secret.json')
if path.exists():
    print('Existing local test credentials retained.'); raise SystemExit(0)
values = {}
for label in ['A','B']:
    email = f'science-{label.lower()}-{secrets.token_hex(4)}@example.test'
    password = secrets.token_urlsafe(24)
    r = requests.post('https://identitytoolkit.googleapis.com/v1/accounts:signUp', params={'key':key}, json={'email':email,'password':password,'returnSecureToken':True},timeout=20)
    if r.status_code != 200:
        raise SystemExit('Account setup blocked: '+r.json().get('error',{}).get('message','unknown'))
    values['EMAIL_'+label] = email; values['PASSWORD_'+label] = password
fd=os.open(path, os.O_WRONLY|os.O_CREAT|os.O_EXCL, 0o600)
with os.fdopen(fd,'w') as f: json.dump(values,f)
print('Two dedicated Firebase accounts created. Local credentials stored securely; no secrets printed.')
