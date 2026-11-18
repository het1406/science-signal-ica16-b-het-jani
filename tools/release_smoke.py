"""Exercise the installed release APK through Android UI, never logging credentials."""
import subprocess,xml.etree.ElementTree as ET,json,time,re,pathlib,datetime
ADB='/Users/hetjani/Library/Android/sdk/platform-tools/adb'
PKG='edu.gsu.hetjani.science_signal_ica16_b'
E=pathlib.Path('docs/evidence');credentials=json.load(open('/tmp/science-signal-test.secret.json'))
events=[]
def adb(*args):
 r=subprocess.run([ADB,*args],capture_output=True,timeout=35)
 if r.returncode:raise RuntimeError('Android command failed: '+args[0])
 return r.stdout

def nodes():
 adb('shell','uiautomator','dump','/sdcard/science-ui.xml')
 return list(ET.fromstring(adb('exec-out','cat','/sdcard/science-ui.xml')).iter('node'))
def label(n):return n.get('content-desc') or n.get('text') or ''
def tap(n):
 p=list(map(int,re.findall(r'\d+',n.get('bounds'))));adb('shell','input','tap',str((p[0]+p[2])//2),str((p[1]+p[3])//2));time.sleep(.5)
def click(text):
 for _ in range(5):
  ns=nodes();found=[n for n in ns if (label(n)==text or (re.fullmatch(r'[A-Za-z0-9]{20}',text) and text in label(n))) and n.get('enabled')=='true']
  if found:tap(found[0]);return
  adb('shell','input','swipe','900','1850','900','650','400');time.sleep(.5)
 raise AssertionError('Visible control not found: '+text)
def wait(text,seconds=35):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  ns=nodes()
  if any(text in (label(n)+' '+n.get('hint','')) for n in ns):return ns
  time.sleep(.7)
 raise AssertionError('Timed out waiting for: '+text)
def shot(name):
 (E/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
def record(message):
 stamp=datetime.datetime.now(datetime.timezone.utc).isoformat();events.append({'timestamp':stamp,'observed':message});print(message,flush=True)

ns=nodes();fields=[n for n in ns if n.get('class')=='android.widget.EditText'];assert len(fields)==2
# A fresh installation has empty fields. Input is read privately and is not echoed.
tap(fields[0]);adb('shell','input','text',credentials['EMAIL_A']);time.sleep(1);adb('shell','input','keyevent','4')
ns=nodes();fields=[n for n in ns if n.get('class')=='android.widget.EditText'];tap(fields[1]);adb('shell','input','text',credentials['PASSWORD_A']);time.sleep(1);adb('shell','input','keyevent','4')
click('Sign in');wait('Start a science round');record('PASS release APK: real Email/Password sign-in through native UI');shot('release-authenticated')
click('Start a science round');wait('QUESTION 1 OF 5');record('PASS release APK: live internet questions loaded')
score=0
for i in range(5):
 wait(f'QUESTION {i+1} OF 5');click('True')
 ns=nodes();feedback='\n'.join(label(n) for n in ns)
 if '✓ Correct' in feedback:score+=1
 else:assert 'Not quite' in feedback
 # A repeated native tap on the disabled True button cannot record a second answer.
 for n in ns:
  if label(n)=='True':tap(n);break
 click('Review my round' if i==4 else 'Continue')
ns=wait('Your science signal');assert any(f'{score} / 5' in (label(n)+' '+n.get('hint','')) for n in ns)
record(f'PASS release APK: five answers, repeated taps ignored, visible score={score}/5')
click('Save to my cloud');ns=wait('Cloud verified');record('PASS release APK: transaction acknowledged and actual server verification displayed')
# Bring round ID, timestamp and verification into the screenshot.
adb('shell','input','swipe','900','1850','900','600','500');time.sleep(.5);ns=nodes();shot('release-cloud-verified')
rounds=[label(n).removeprefix('Round: ') for n in ns if label(n).startswith('Round: ')]
assert len(rounds)==1
rid=rounds[0];record('Release round suffix: …'+rid[-6:])
# Force stop and relaunch the same installed release binary.
adb('shell','am','force-stop',PKG);adb('shell','am','start','-n',PKG+'/.MainActivity');wait('Find my recent cloud rounds');click('Find my recent cloud rounds');wait(rid);click(rid);ns=wait('Cloud verified');shot('release-restart');record('PASS release APK: force-stop/relaunch and server retrieval of same round')
result={'mode':'release','device':'Pixel_4a emulator Android API 37','physical_device':False,'events':events,'round_id':rid,'score':score,'restart_server_verified':True}
(E/'release-smoke.json').write_text(json.dumps(result,indent=2))
