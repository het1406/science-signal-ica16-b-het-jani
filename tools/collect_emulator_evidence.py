"""Collect actual app screenshots from debug private storage during tests."""
import subprocess,pathlib,time,json
adb='/Users/hetjani/Library/Android/sdk/platform-tools/adb'
package='edu.gsu.hetjani.science_signal_ica16_b'
end=time.monotonic()+900
out=pathlib.Path('docs/evidence');out.mkdir(exist_ok=True)
seen=set()
while time.monotonic()<end:
 r=subprocess.run([adb,'shell','run-as',package,'ls','files'],capture_output=True,text=True)
 for name in r.stdout.splitlines():
  if name in seen or not (name.endswith('.png') or name=='restart.json'):continue
  b=subprocess.run([adb,'exec-out','run-as',package,'cat','files/'+name],capture_output=True)
  if b.returncode:continue
  if name.endswith('.png') and b.stdout.startswith(b'\x89PNG'):
   (out/name).write_bytes(b.stdout);seen.add(name);print('Captured',name,flush=True)
  elif name=='restart.json':
   try:
    d=json.loads(b.stdout);p=pathlib.Path('/tmp/science-signal-test.secret.json');c=json.loads(p.read_text());c.update(ROUND_ID=d['id'],ROUND_UID=d['uid']);p.write_text(json.dumps(c));seen.add(name);print('Saved restart coordinates privately.',flush=True)
   except (ValueError,KeyError):pass
 time.sleep(1)
