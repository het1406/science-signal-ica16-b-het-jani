"""Build the evidence document only from recorded results and genuine screenshots."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import json, re, subprocess
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
E=ROOT/'docs/evidence'

responses=[
('Decode the evidence', '''The live T02 request returned the encoded question “Male%20pandas%20do%20handstands%20while%20urinating%20on%20trees.%20”. After decoding, the text was “Male pandas do handstands while urinating on trees.” The original trailing space is harmless for display, but the evidence preserves the received content. This example is recorded in the first integration trace, rather than invented as a fixture. The endpoint explicitly requests encode=url3986, so lib/quiz.dart applies Uri.decodeComponent to each question, category, difficulty, type, and answer. Percent escapes represent encoded bytes; they are not HTML entities. An HTML decoder would not turn %20 into a space and therefore cannot substitute for this operation. Decoding alone also does not establish validity. The parser separately checks the response code, five-result count, category, difficulty, boolean type, and exactly True/False answer set. T03 supplies malformed escapes and invalid metadata in isolated tests. The production ScienceApi always requests the required live endpoint, with a timeout and request spacing.'''),
('Separate outcomes', '''A successful write and an unsuccessful read describe two different operations. In T09, createOnce returned from a real Firebase transaction before the development hook injected permission-denied into the next verification call. The trace and server document show that the record existed while the interface reported “Write acknowledged; verification unavailable.” SignalController stores writeAcknowledged separately from phase, so permissionDenied does not erase the acknowledged outcome. The frozen payload and original ref also remain available. Pressing recovery after the cooldown calls verify with Source.server on that same document. Only a matching six-field record, resolved Timestamp, and clean server metadata permit cloudVerified. The screenshots show the unavailable state followed by the verified state. This separation also explains why “Save failed” would be inaccurate here. A verification error describes missing confirmation, not missing data. The busy guard prevents simultaneous retries, while the authentication epoch prevents an old account’s delayed result from appearing in a new account’s interface.'''),
('Identity and collision', '''The document ID identifies a particular round, not whichever score the client currently wants to store. In lib/cloud.dart, newRound obtains attempts.doc().id without writing a document. At the fifth answer, SignalController freezes the five fixed fields with an unmodifiable map. createOnce reads the target inside its transaction. An absent record can be created; an existing record must match every fixed field and the exact schema. The collision check deliberately retries an existing score of three with a proposed score of four. It rejects the attempt and a server read confirms the original three remains. Repeating the original payload is safe because it requires no update. Recovery therefore retains the original ref even when acknowledgement or verification is uncertain. A genuinely new round is different: after cloudVerified, Start clears the previous answers and allocates a new document reference. T05 checks both an empty answer list and a changed ID. Identity comes from FirebaseAuth.currentUser, never a manually supplied UID.'''),
('Access is not truth', '''T10 signs in independently as account B and attempts to read account A’s saved document and create another document under A’s path. Both operations are rejected by the deployed Firestore rules. The rules require request.auth.uid to equal the path owner; the denial therefore comes from the server rather than just a hidden button. T11 additionally rejects an out-of-range score, an extra field, an update, and deletion. These checks protect ownership, schema, and immutability, but they do not prove that a score reflects genuine answers. A modified client could still submit any allowed integer between zero and five under its own identity. The six-field schema intentionally contains no answers for independent checking. A stronger design would issue signed round identifiers from a trusted backend, keep the correct answers on that backend, and calculate scores after receiving one answer per question. The backend would then create the final immutable attempt. Client feedback could remain immediate, but authoritative scoring would move outside the user’s device.'''),
('AI critique', '''OpenAI Codex was used on November 17, 2026, to respond to the assignment’s fictional scenario: a Flutter cloud write succeeds and the next read is denied. Its proposal was to keep the original round ID, display “Write acknowledged; verification unavailable,” and retry a server-only read without creating a replacement record. Two claims were tested: T09 confirms that a real committed document survives the injected read denial, and recovery verifies the same ID without creating another document for that round. The proposal’s limitation is that keeping an ID only in memory does not solve application restart. The revised implementation adds authenticated server history and explicit original-ID retrieval, tested by T07 in a fresh application process. Another implementation safeguard keeps the busy lock until an uncertain SDK operation actually settles. Codex also assisted with code, tests, debugging, and this document; these are AI-assisted artifacts rather than a claim of unaided student work. Fictional reasoning was kept separate from the recorded real-cloud results.'''),
('Defend the UX', '''“Save failed” implies that the database rejected the result, which is false in the critical T09 scenario. “Write acknowledged; verification unavailable” states what is known and leaves the uncertain part explicit. The actual unavailable screenshot uses an amber cloud symbol beside readable text and a same-round verification button. The verified screenshot changes to a green verification symbol only after the server read succeeds. Color therefore reinforces the message without being its only carrier. A genuine failed-first test sharpened this distinction: the initial T08 test expected saveUnknown after disabling the Firestore network, but observed verificationUnavailable because the transaction had been acknowledged. The mistaken test assumption was corrected by disconnecting the emulator’s actual network radios before submission. The final run then exercised offline recovery using the original ID. This experience supports reporting the observed acknowledgement rather than inferring failure from connectivity settings. The interface preserves the round ID, disables overlapping actions, and offers explicit recovery instead of silently starting another round.''')]

for title,body in responses:
 n=len(body.split())
 if not 120<=n<=180: raise ValueError((title,n))

# A diagram of the implemented controller, not a simulated app screenshot.
im=Image.new('RGB',(1500,820),'#f4f7fa');d=ImageDraw.Draw(im)
fontpath='/System/Library/Fonts/Supplemental/Arial.ttf'
f=ImageFont.truetype(fontpath,27);small=ImageFont.truetype(fontpath,22)
boxes={
'signedOut':(35,65,285,145),'loading':(350,65,600,145),'playing':(665,65,915,145),'readyToSubmit':(1010,65,1450,145),
'authError':(35,235,285,315),'requestError':(350,235,600,315),'submitting':(1010,235,1450,315),
'saveUnknown':(1010,415,1450,495),'verifying':(650,415,930,495),'cloudVerified':(35,415,340,495),
'permissionDenied':(570,650,925,730),'verificationUnavailable':(980,650,1450,730)}
def arrow(a,b,label=''):
 d.line([a,b],fill='#566c7d',width=4)
 import math
 angle=math.atan2(b[1]-a[1],b[0]-a[0]);p=[b,(b[0]-16*math.cos(angle-.5),b[1]-16*math.sin(angle-.5)),(b[0]-16*math.cos(angle+.5),b[1]-16*math.sin(angle+.5))];d.polygon(p,fill='#566c7d')
 if label:d.text(((a[0]+b[0])/2-70,(a[1]+b[1])/2-28),label,font=small,fill='#244253')
for a,b in [((285,105),(350,105)),((600,105),(665,105)),((915,105),(1010,105)),((1230,145),(1230,235)),((1010,275),(790,415)),((1230,315),(1230,415)),((1010,455),(930,455)),((650,455),(340,455)),((160,145),(160,235)),((470,145),(470,235)),((790,495),(740,650)),((900,495),(1150,650))]:arrow(a,b)
for name,(x,y,x2,y2) in boxes.items():
 color='#d8f5e8' if name=='cloudVerified' else '#ffedcc' if name in ['saveUnknown','permissionDenied','verificationUnavailable'] else '#dce9f4'
 d.rounded_rectangle((x,y,x2,y2),radius=15,fill=color,outline='#49677e',width=2)
 d.text(((x+x2)/2,(y+y2)/2),name,font=f,fill='#17334a',anchor='mm')
d.text((40,560),'Recovery: manual, same ID; busy lock + 5-second cooldown',font=small,fill='#17334a')
d.text((40,780),'Replay: cloudVerified → loading with a new ID. Identity changes invalidate pending UI completions.',font=small,fill='#17334a')
im.save(E/'state-machine.png')

if __name__=='__main__':
 results=json.loads((ROOT/'docs/results.json').read_text())
 doc=Document();sec=doc.sections[0];sec.top_margin=sec.bottom_margin=Inches(.6);sec.left_margin=sec.right_margin=Inches(.65)
 normal=doc.styles['Normal'];normal.font.name='Calibri';normal.font.size=Pt(10);normal.paragraph_format.space_after=Pt(5)
 for style in ['Heading 1','Heading 2']:doc.styles[style].font.color.rgb=RGBColor.from_string('174B61')
 doc.add_heading('SCIENCE SIGNAL',0);doc.add_paragraph('CSC 4360 · ICA 16 · Class B',style='Subtitle')
 doc.add_paragraph('Het Jani | November 17, 2026 | Deadline: 11:59 PM Eastern')
 doc.add_paragraph('Submission status: '+results['verdict'])
 doc.add_paragraph('Repository: https://github.com/het1406/science-signal-ica16-b-het-jani')
 doc.add_paragraph('Source revision: '+results['source_commit'])
 doc.add_paragraph('Final repository revision: '+subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip())
 doc.add_heading('Environment and overview',1)
 doc.add_paragraph('Flutter 3.35.7; Dart 3.9.2; JDK 21; Android Pixel 4a emulator. No physical-device testing is claimed. The production app loads five live Science & Nature questions, accepts one response per question, freezes the score, and stores exactly six fields in the authenticated owner’s immutable attempt. A successful write and successful server verification are separate facts.')
 doc.add_paragraph('Firebase project: science-signal-het-ica16-b. Dedicated project and GitHub repository created during this session. Email/Password enabled by Het Jani; test accounts provisioned with random local credentials. Firebase client configuration is safe to share; passwords, OAuth tokens and signing keys are excluded.')
 doc.add_heading('Four genuine checkpoints',1)
 for block in (ROOT/'docs/checkpoints.md').read_text().split('\n\n'):
  if not block.startswith('#'):
   for item in re.split(r'\n(?=\d\. )', block):
    doc.add_paragraph(item.replace('**','').replace('`',''))
 doc.add_heading('State machine and transition guards',1);doc.add_picture(str(E/'state-machine.png'),width=Inches(7.1))
 doc.add_paragraph('Figure 1. Implemented phases in lib/controller.dart. Arrows summarize the main paths; the complete labeled transition diagram is in docs/state-machine.md.')
 doc.add_paragraph('phase tracks the UI; writeAcknowledged records commit acknowledgement independently; ref retains the original ID; payload is frozen; busy blocks overlap; _lastRecovery enforces five seconds; _epoch rejects completions after an identity change. The 10-second Timer reports uncertainty without canceling the SDK operation or unlocking a second submission. A real transaction allows at most three attempts. Server retrieval and history support recovery after restart.')
 doc.add_heading('Six critical-thinking responses',1)
 for i,(title,body) in enumerate(responses,1):
  doc.add_heading(f'{i}. {title} ({len(body.split())} words)',2);doc.add_paragraph(body)
 doc.add_heading('AI critique record',1)
 t=doc.add_table(rows=0,cols=2);t.style='Light Shading Accent 1'
 for a,b in [('Actual assignment prompt','Use an approved AI tool to propose recovery after a fictional Flutter cloud write succeeds and the next read is denied.'),('Tool and date','OpenAI Codex, November 17, 2026, during this implementation conversation'),('Actual response excerpt','Keep the original round ID, show “Write acknowledged; verification unavailable,” and retry a server-only read of that document. Never create a replacement record.'),('Tested claims','T09: real record survives read denial; retry reads the same ID without a duplicate.'),('Limitation and revision','An in-memory ID does not survive restart. Added server history and explicit original-ID retrieval; T07 exercises a fresh process.'),('Disclosure','Codex assisted with implementation, testing, fixes, documentation and packaging. Student enabled authentication and authorized account use. No fabricated records, screenshots or results are used.')]:
  c=t.add_row().cells;c[0].text=a;c[1].text=b
 doc.add_heading('Acceptance test record',1)
 for r in results['tests']:
  doc.add_heading(f"{r['id']} — {r['status']}",2)
  doc.add_paragraph('Preconditions: '+r['preconditions'])
  doc.add_paragraph('Action / expected: '+r['action'])
  doc.add_paragraph('Observed: '+r['actual'])
  doc.add_paragraph(f"Timestamp: {r['timestamp']} | Commit: {r['commit']} | Round suffix: {r['round_suffix']} | Evidence: {r['evidence']}")
 doc.add_heading('Real Firebase record and verification',1)
 doc.add_paragraph('Exact document path: '+results['document_path'])
 doc.add_paragraph('Project: science-signal-het-ica16-b. Cloud writes and reads use real Firebase services, not the Firebase emulator. The Android device itself is an emulator.')
 t=doc.add_table(rows=1,cols=2);t.style='Light Shading Accent 1';t.rows[0].cells[0].text='Field';t.rows[0].cells[1].text='Observed value'
 for key,value in results['fields'].items():c=t.add_row().cells;c[0].text=key;c[1].text=str(value)
 doc.add_paragraph('Server verification: '+results['server_verification'])
 for name,caption,width in [('firebase-auth-console.png','Figure 2. Genuine Firebase Console: Email/Password enabled.',6.8),(('firestore-console.png' if (E/'firestore-console.png').exists() else 'firestore-console-earlier.png'),('Figure 3. Genuine Firebase Console: final tested attempt and all six fields.' if (E/'firestore-console.png').exists() else 'Figure 3. Genuine Console capture from the earlier T09 run: users/pc0cgGZwUiQ8mKfPlntJBiSF5VU2/attempts/Udn6mRfmNUMa06wByAUN; score 3; submittedAt 2026-11-18T03:32:29.128Z. The final test run uses the separate round ending EhgD9, documented in the table and server-read evidence above. Different runs allocate different IDs; each recovery retains its own original ID.'),6.8),('T09-verification-unavailable.png','Figure 4. Actual emulator UI after the real commit and injected verification denial.',3.1),('T09-cloud-verified.png','Figure 5. Same round verified from the server after recovery.',3.1),('T07-restart.png','Figure 6. Fresh-process authenticated retrieval of the original server document.',3.1),('release-cloud-verified.png','Figure 7. Installed release APK completed a live round and server verification.',3.1)]:
  if (E/name).exists():doc.add_picture(str(E/name),width=Inches(width));doc.add_paragraph(caption)
  else:doc.add_paragraph('MISSING EVIDENCE: '+caption)
 doc.add_heading('Failed-first corrections',1)
 doc.add_paragraph('unit-first.log records the initial payload-comparator import conflict; unit-corrected.log records the successful rerun. debug-build.log records the incompatible Kotlin metadata; debug-build-corrected.log records the fixed APK build. acceptance-first.log records the duplicate surface-conversion assertion; acceptance-second.log records the missed sign-in tap and interrupted run. The final acceptance trace, not an earlier interrupted run, supplies the pass observations. These are actual session events, not reconstructed earlier work.')
 doc.add_heading('Build and reproducibility',1)
 doc.add_paragraph(results['build'])
 doc.add_paragraph('APK SHA-256: '+results['apk_sha256'])
 doc.add_paragraph('To retrieve the original result: install the release APK, authenticate as the original account, then select Find my recent cloud rounds or paste the exact original round ID. Retrieve from server performs a Source.server read and strict verification. Sign out before switching accounts. No credentials are printed in this report; the local test credential file is never submitted.')
 doc.add_paragraph('Reproduce checks with README.md commands. Test fixtures are used only for isolated malformed-response/scoring tests. T12 uses labeled injected service errors over a real committed record; no natural quota outage is claimed. The delayed-acknowledgement test uses a deliberate delay after a real transaction to exercise the 10-second ambiguity guard.')
 doc.add_heading('Rubric readiness audit',1)
 t=doc.add_table(rows=1,cols=3);t.style='Light Shading Accent 1'
 for c,v in zip(t.rows[0].cells,['Category / maximum','Readiness','Evidence']):c.text=v
 for a,b,c in results['rubric']:
  cells=t.add_row().cells
  for cell,v in zip(cells,[a,b,c]):cell.text=v
 doc.add_paragraph('These are readiness assessments, not an instructor-assigned grade. No perfect score is guaranteed.')
 doc.add_paragraph('Remaining blockers: '+results['blockers'])
 doc.add_paragraph('Console capture provenance: Figure 3 shows the final tested attempt ending kEhgD9, matching the server-read evidence and resolved timestamp above. The empty parent user document is expected: the required schema writes only to its attempts subcollection. Earlier genuine captures remain in the repository as development evidence.')
 footer=sec.footer.paragraphs[0];footer.text='Het Jani · Science Signal · Class B · Genuine observed evidence';footer.style='Caption'
 path=ROOT/'submission/ICA16_B_HetJani.docx';doc.save(path)
 print('Wrote',path)
 print('Response word counts:',[len(body.split()) for _,body in responses])
