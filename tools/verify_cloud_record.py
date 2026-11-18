"""Independent authenticated REST read of the test's original real document."""
import json,requests,datetime,pathlib
c=json.load(open('/tmp/science-signal-test.secret.json'))
config=json.load(open('android/app/google-services.json'))
project=config['project_info']['project_id'];key=config['client'][0]['api_key'][0]['current_key']
r=requests.post('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',params={'key':key},json={'email':c['EMAIL_A'],'password':c['PASSWORD_A'],'returnSecureToken':True},timeout=20);r.raise_for_status()
auth=r.json();assert auth['localId']==c['ROUND_UID']
path=f"users/{auth['localId']}/attempts/{c['ROUND_ID']}"
r=requests.get(f'https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/{path}',headers={'Authorization':'Bearer '+auth['idToken']},timeout=20);r.raise_for_status()
body=r.json();assert len(body['fields'])==6
result={'observed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project':project,'document_path':path,'method':'Authenticated owner REST GET, supplementary to Flutter Source.server evidence','http_status':r.status_code,'document':body}
pathlib.Path('docs/evidence/server-record.json').write_text(json.dumps(result,indent=2))
print('Independent authenticated server GET: 200; exact six fields; original document exists.')
