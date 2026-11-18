from pathlib import Path
exec(Path('tools/release_smoke.py').read_text().split('ns=nodes();fields=')[0])
try:
 for radio in ['wifi','data']:adb('shell','svc',radio,'disable')
 click('Play a new round');wait('Questions unavailable.',seconds=35);shot('release-network-error');record('PASS release APK: actual offline API request shows readable network error and manual Retry questions control')
finally:
 for radio in ['wifi','data']:adb('shell','svc',radio,'enable')
time.sleep(3);click('Retry questions');wait('QUESTION 1 OF 5');shot('release-network-recovered');record('PASS release APK: manual retry after network restoration loads a live five-question round')
p=E/'release-smoke.json';d=json.loads(p.read_text());d['network_failure_recovery_verified']=True;d['events']+=events;p.write_text(json.dumps(d,indent=2))
