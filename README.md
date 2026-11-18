# Science Signal — CSC 4360 ICA 16, Class B

**Het Jani** · Flutter Android · Firebase project `science-signal-het-ica16-b`

Five live Science & Nature true/false questions, authenticated immutable attempts, and explicit server verification. The app never treats a failed verification read as proof that a write failed.

## Run

Tested toolchain: Flutter 3.35.7 / Dart 3.9.2; JDK 21; Android SDK. FlutterFire versions are pinned for this toolchain; the latest Firebase Auth Android SDK required newer Kotlin metadata and failed the first build.

```sh
flutter pub get
flutter run
```

Firebase's client configuration is included (it is not an administrator credential). Email/password is enabled. Create an account from the sign-in screen or use your own locally held test credentials. The app obtains identity from Firebase Authentication, never from a typed UID.

## Validation and builds

```sh
dart format .
flutter analyze
flutter test
python3 tools/provision_test_accounts.py
# In a separate terminal, start tools/collect_emulator_evidence.py for screenshots and device-radio control.
flutter test integration_test/acceptance_test.dart -d emulator-5554 --dart-define-from-file=/tmp/science-signal-test.secret.json
flutter test integration_test/restart_test.dart -d emulator-5554 --dart-define-from-file=/tmp/science-signal-test.secret.json
flutter build apk --release
```

The provisioning script creates two dedicated test accounts only in the configured project. It stores random credentials in a mode-0600 local `/tmp` file. Do not publish that file or an integration-test APK. Release builds do not include test credentials. The coursework release is optimized release mode and uses the local development signing certificate from the Flutter template. It is installable but is not configured for Play Store distribution. Signing keys and passwords are excluded from source.

## Exact storage contract

`users/{FirebaseAuth.currentUser.uid}/attempts/{roundId}` stores exactly:

| Field | Value |
|---|---|
| schemaVersion | integer 1 |
| variant | string B |
| categoryId | integer 17 |
| questionCount | integer 5 |
| correctCount | integer 0–5 |
| submittedAt | server timestamp |

`AttemptRepository.newRound` generates a document ID without a write. `createOnce` reads inside a bounded transaction, creates only when absent, accepts identical fixed data, and rejects collisions. `verify` uses `Source.server`, validates the exact six fields, resolved timestamp, document ID, pending-write metadata, and cache metadata. Rules permit only authenticated owners to read/create and deny updates/deletes and unmatched paths.

## Recovery and restart

Copy the round ID on the result screen. Acknowledged writes with unreadable results display **Write acknowledged; verification unavailable.** Use **Retry server verification** to read the same ID. Unknown acknowledgements use a create-once recovery transaction for that same ID. The 10-second UI deadline does not cancel a transaction or unlock overlapping submissions; late results remain bound to the initiating account. Manual cloud retries are separated by five seconds. The transaction has at most three SDK attempts.

Close and reopen the app, sign in as the same account, and use **Find my recent cloud rounds**, or paste the original round ID into **Retrieve from server**. Both paths consult the server; matching the original result requires a second full document verification. No local score database or preferences act as cloud proof.

The debug-only **QA: deny first verification** switch injects one permission-denied error after a successful real transaction. It disables itself on injection. Retry then performs the actual server-only read. The switch and injection are disabled in release builds. Other fault injection in integration tests is explicitly labeled simulated; it does not replace real-cloud T06/T07/T09/T10/T11 evidence.

## Source map

- `lib/quiz.dart`: exact OpenTDB endpoint, 10-second HTTP timeout, 5-second request spacing, strict URL3986 validation, single-answer scoring.
- `lib/cloud.dart`: immutable schema, transaction, server-only verification, development hook.
- `lib/controller.dart`: phase, owner/epoch guards, frozen payload, busy lock, write acknowledgement and recovery.
- `lib/main.dart`: authentication, quiz/review, recovery UX and server history.
- `firestore.rules`: deployed authorization and validation.
- `test/quiz_test.dart`: isolated malformed-data and scoring checks.
- `integration_test/`: real Firebase acceptance and fresh-process restart tests.
- `docs/`: checkpoints, evidence, six responses and final audit.

## AI assistance and limits

OpenAI Codex assisted with implementation, testing, debugging, documentation, and packaging on November 17, 2026. The account owner supplied authorization and enabled Authentication. No claim of unaided student authorship is made. Test results distinguish observed passes from blocked requirements. See the evidence document for the actual trace and limitations. This client-side score is ownership-protected, not cheat-proof; a trusted scoring backend is needed for score integrity.

## References

- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Firestore security rule behavior](https://firebase.google.com/docs/rules/rules-behavior)
- [Firestore data validation](https://firebase.google.com/docs/rules/data-validation)
- [Firebase API keys](https://firebase.google.com/docs/projects/api-keys)

Test trace timestamps come from the emulator clock; the emulator paused during host sleep. The resolved Firestore server timestamp is authoritative and can differ from device event timestamps.
