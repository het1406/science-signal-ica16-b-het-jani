"""Archive test output after removing local test credentials and token-like values."""
from pathlib import Path
import json,re
secrets=json.loads(Path('/tmp/science-signal-test.secret.json').read_text())
for source,name in [('first','acceptance-first'),('second','acceptance-second'),('third','acceptance-third'),('fourth','acceptance-fourth'),('fifth','acceptance-fifth'),('sixth','acceptance-offline-first'),('final','acceptance-final')]:
 p=Path('/tmp/science-acceptance-'+source+'.log')
 if not p.exists():continue
 text=p.read_text()
 for key,value in secrets.items():
  if key.startswith(('EMAIL','PASSWORD')):text=text.replace(value,'[REDACTED '+key+']')
 text=re.sub(r'Bearer\s+[A-Za-z0-9._-]+','Bearer [REDACTED]',text)
 Path('docs/evidence/'+name+'.log').write_text(text)
p=Path('/tmp/science-restart.log');Path('docs/evidence/restart.log').write_text(p.read_text())
print('Archived genuine run logs; test credentials redacted.')
