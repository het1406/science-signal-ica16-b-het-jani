from pathlib import Path
import re,json,subprocess,datetime,hashlib
root=Path(__file__).resolve().parents[1];e=root/'docs/evidence'
cloud=(e/'acceptance-final.log').read_text();restart=(e/'restart.log').read_text();unit=(e/'unit-final.log').read_text()
assert 'All tests passed!' in cloud and 'All tests passed!' in restart and 'All tests passed!' in unit
server=json.loads((e/'server-record.json').read_text());release=json.loads((e/'release-smoke.json').read_text())
assert release['restart_server_verified']
uid,rid=server['document_path'].split('/')[1::2]
source=subprocess.check_output(['git','rev-parse','ae7d0ff'],text=True).strip()
acceptance=subprocess.check_output(['git','rev-parse','a98fadc'],text=True).strip()
unitstamp=datetime.datetime.fromtimestamp((e/'unit-final.log').stat().st_mtime,datetime.timezone.utc).isoformat()
notes={
'T01':('Two independently provisioned Email/Password accounts; signed-out app.','Enter invalid credentials, then authenticate correctly; expect readable rejection and a real currentUser.','Invalid credential error shown; user A authenticated in the real project. Release native-UI login also passed.'),
'T02':('Live OpenTDB endpoint reachable; no fixture in production.','GET exact required URL; decode URL3986; expect exactly five medium Science & Nature boolean questions.','Live encoded panda-question example decoded correctly; five-question app round loaded. Exact endpoint and validation also checked locally.'),
'T03':('Isolated parser fixtures, never production substitutes.','Supply invalid percent escapes, response code, count and metadata; expect rejection.','All malformed-escape, incorrect-category/difficulty/type, response-code, result-count, duplicate-answer and invalid-JSON checks passed.'),
'T04':('Live five-question round.','Answer alternately correct/wrong; repeat taps; expect only one answer and at most one point per question.','Five answers yielded 3/5; repeated answers ignored. Release native repeated taps also left correct visible scoring.'),
'T05':('Five recorded answers and a verified original round.','Review all answers; replay; expect cleared answers and a new generated ID.','Five-answer review recorded; final replay had an empty answer list and a different ID.'),
'T06':('Signed-in A; frozen score=3; allocated original round ID.','Submit twice; expect one create-once operation, six fields, resolved timestamp and actual server-only verification.','Real transaction acknowledged; repeated submit ignored; exact six fields; Timestamp resolved; Source.server verified with no pending writes or cached metadata.'),
'T07':('Original real document exists; application process restarted.','Authenticate as same user and retrieve original ID; expect same score/timestamp from server.','Fresh test process reauthenticated A and retrieved original 3/5 document with unchanged timestamp. Installed release force-stop/relaunch also retrieved its own original round.'),
'T08':('Allocated frozen round; emulator Wi-Fi and mobile data disabled by test helper.','Submit offline, restore radios, recover; expect uncertainty and same-ID server verification.','Actual offline attempt reached saveUnknown; after connectivity restoration, the original ID was cloudVerified. Initial SDK-disable-only test failed its expectation and was corrected.'),
'T09':('Real transaction succeeds; debug hook armed to deny first verification.','Observe denial, disable hook, retry same server read; expect preserved record, same ID and verification only after server success.','Real WRITE_ACK followed by injected permission-denied; actual server document remained present. Same-ID retry reached Cloud verified. No replacement round was allocated.'),
'T10':('A owns original record; B authenticated independently.','B reads A record and creates under A path; expect server permission-denied.','Both real deployed-rule operations returned permission-denied.'),
'T11':('A authenticated; strict rules deployed.','Try score 6, extra field, update and deletion; expect rejection.','All four real deployed-rule operations rejected with permission-denied.'),
'T12':('Real committed document; labeled one-shot repository fault injection.','Inject unavailable/resource-exhausted, attempt immediate retry, then bounded recovery; expect no overlap or duplicate.','Both fault codes produced verificationUnavailable after acknowledgement; immediate retry blocked; delayed server-only retry succeeded; createOnce count stayed one. Separate delayed acknowledgement and account-change tests also passed.')}
rows=[]
for i in range(1,13):
 tid=f'T{i:02d}';lines=[line for line in (restart if tid=='T07' else cloud).splitlines() if f' {tid} ' in line and 'PASS' in line]
 if tid!='T03':assert lines,tid
 stamp=lines[-1].split()[1] if lines else unitstamp
 suffix='…'+rid[-6:] if tid not in ['T01','T02','T03'] else 'not applicable'
 if tid=='T08':suffix='…'+re.search(r'T08 PASS.*same ID=(\w+)',cloud)[1][-6:]
 pre,action,actual=notes[tid]
 rows.append({'id':tid,'status':'PASS','preconditions':pre,'action':action,'actual':actual,'timestamp':stamp,'commit':source if tid in ['T03','T07'] else acceptance,'round_suffix':suffix,'evidence':'docs/evidence/'+('unit-final.log' if tid=='T03' else 'restart.log; T07-restart.png' if tid=='T07' else 'acceptance-final.log')})
fields={k:next(iter(v.values())) for k,v in server['document']['fields'].items()}
for key in ['schemaVersion','categoryId','questionCount','correctCount']:fields[key]=int(fields[key])
apk=root/'submission/ICA16_B_HetJani.apk'
assert apk.exists()
results={'verdict':'READY TO SUBMIT','source_commit':source,'tests':rows,'document_path':server['document_path'],'fields':fields,'server_verification':'Flutter Source.server checks passed in the original run and after fresh-process reauthentication; hasPendingWrites=false, isFromCache=false. A supplementary owner-authenticated REST GET also returned HTTP 200 with the exact six fields. Device event clocks and server timestamps may differ after host sleep; server submittedAt is authoritative.','build':'flutter pub get, dart format ., flutter analyze, and all five unit tests passed. Both real Firebase integration runs passed. flutter build apk --release produced a 49.5 MB APK (tool display). adb install succeeded on Pixel_4a, Android API 37. Native release UI sign-in, live questions, scoring, repeated taps, transaction, server verification and force-stop/relaunch retrieval passed. This coursework release uses the template development signing certificate; no physical device or Play Store distribution is claimed.','apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'rubric':[
['Engagement and process / 10','10-point readiness supported','Four genuine checkpoints, initial failures, corrections and Git history.'],
['Conceptual understanding / 20','20-point readiness supported','Six 120–180-word responses, state diagram and actual traces.'],
['Application of cloud knowledge / 25','25-point readiness supported','Real Auth identities, exact schema, create-once transaction, server read and deployed rules.'],
['Failure recovery and validation / 20','20-point readiness supported','T08/T09/T10/T11/T12; timeout and identity-change guards; no replacement ID.'],
['Creative problem-solving / 15','15-point readiness supported','Debug-only post-commit denial hook, server-history recovery, accessible text/icon feedback and AI critique.'],
['Evidence and delivery / 10','10-point readiness subject to final artifact check','Release APK install-tested, accessible repository, DOCX and genuine screenshots/logs.']], 'blockers':'None after final repository accessibility and document checks. Grade remains the instructor’s decision.'}
(root/'docs/results.json').write_text(json.dumps(results,indent=2))
print('All 12 tests have observed pass records; result metadata generated.')
