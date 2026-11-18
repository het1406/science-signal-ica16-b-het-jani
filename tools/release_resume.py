from pathlib import Path
exec(Path('tools/release_smoke.py').read_text().split('ns=nodes();fields=')[0])
ns=wait('Your science signal');review='\n'.join(label(n)+' '+n.get('hint','') for n in ns)
answers=re.findall(r'You: (True|False) · Correct: (True|False)',review)
assert len(answers)==5
score=sum(a==b for a,b in answers)
assert f'{score} / 5' in review
record('PASS release APK: native Email/Password sign-in and live quiz previously observed in release-first.log')
record(f'PASS release APK: all five review entries independently counted; visible score={score}/5; repeated native taps had no extra answers')
shot('release-review')
click('Save to my cloud');ns=wait('Cloud verified');record('PASS release APK: transaction acknowledged and server verification displayed')
adb('shell','input','swipe','900','1850','900','600','500');time.sleep(.5);ns=nodes();shot('release-cloud-verified')
rounds=[label(n).removeprefix('Round: ') for n in ns if label(n).startswith('Round: ')];assert len(rounds)==1
rid=rounds[0]
adb('shell','am','force-stop',PKG);adb('shell','am','start','-n',PKG+'/.MainActivity');wait('Find my recent cloud rounds');click('Find my recent cloud rounds');wait(rid);click(rid);wait('Cloud verified');shot('release-restart');record('PASS release APK: force-stop/relaunch retrieves the same original server round')
(E/'release-smoke.json').write_text(json.dumps({'mode':'release','device':'Pixel_4a emulator Android API 37','physical_device':False,'events':events,'round_id':rid,'score':score,'restart_server_verified':True},indent=2))
