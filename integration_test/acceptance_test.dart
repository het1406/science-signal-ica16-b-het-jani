import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:science_signal_ica16_b/main.dart' as app;
import 'package:science_signal_ica16_b/cloud.dart';
import 'package:science_signal_ica16_b/controller.dart';
import 'package:science_signal_ica16_b/quiz.dart';

const emailA = String.fromEnvironment('EMAIL_A');
const passA = String.fromEnvironment('PASSWORD_A');
const emailB = String.fromEnvironment('EMAIL_B');
const passB = String.fromEnvironment('PASSWORD_B');
void evidence(String id, String detail) {
  // Contains no credentials or tokens. Document paths are intentional evidence.
  debugPrint(
    'EVIDENCE ${DateTime.now().toUtc().toIso8601String()} $id $detail',
  );
}

bool surfaceConverted = false;
Future<void> screenshot(WidgetTester tester, String name) async {
  await tester.pump();
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  if (!surfaceConverted) {
    await binding.convertFlutterSurfaceToImage();
    surfaceConverted = true;
  }
  await tester.pump();
  final bytes = await binding.takeScreenshot(name);
  // Android private app storage, retrieved with adb run-as after the test.
  final dir = Directory(
    '/data/data/edu.gsu.hetjani.science_signal_ica16_b/files',
  );
  await dir.create(recursive: true);
  await File('${dir.path}/$name.png').writeAsBytes(bytes);
}

Future<void> setDeviceNetwork(bool online) async {
  final dir = '/data/data/edu.gsu.hetjani.science_signal_ica16_b/files';
  final name = online ? 'online' : 'offline';
  await File('$dir/$name.request').writeAsString(name);
  final ack = File('$dir/$name.ack');
  for (var i = 0; i < 40 && !await ack.exists(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  if (!await ack.exists()) {
    throw StateError(
      'Start tools/collect_emulator_evidence.py to control emulator radios.',
    );
  }
  await Future<void>.delayed(const Duration(seconds: 2));
}

class FaultRepository extends AttemptRepository {
  String? fault;
  Duration delay = Duration.zero;
  int creates = 0;
  FaultRepository(super.db, super.auth);
  @override
  Future<void> createOnce(
    DocumentReference<Map<String, dynamic>> ref,
    String uid,
    Map<String, dynamic> fixed,
  ) async {
    creates++;
    await super.createOnce(ref, uid, fixed);
    await Future<void>.delayed(delay);
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> verify(
    DocumentReference<Map<String, dynamic>> ref,
    String uid,
    Map<String, dynamic> fixed,
  ) async {
    final code = fault;
    fault = null;
    if (code != null) {
      throw FirebaseException(plugin: 'acceptance-injection', code: code);
    }
    return super.verify(ref, uid, fixed);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'T01–T12 real Firebase Class B acceptance',
    (tester) async {
      expect(
        emailA.isNotEmpty && passA.isNotEmpty && emailB.isNotEmpty,
        true,
        reason: 'Supply local --dart-define-from-file credentials.',
      );
      await app.main();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      final auth = FirebaseAuth.instance, db = FirebaseFirestore.instance;
      expect(Firebase.app().options.projectId, 'science-signal-het-ica16-b');
      await auth.signOut();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await tester.enterText(find.byKey(const Key('email')), emailA);
      await tester.enterText(
        find.byKey(const Key('password')),
        'deliberately-invalid-password',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      // Native authentication finishes asynchronously.
      for (
        var i = 0;
        i < 40 &&
            find.text('Email or password is incorrect.').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      // Invoke the same UI handler after setting its controller. The API 37
      // native IME can deliver a stale editing value during synthetic re-entry.
      final dynamic loginState = tester.state(find.byType(app.SignalHome));
      loginState.password.text = passA;
      await loginState.authenticate();
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNotNull);
      final uid = auth.currentUser!.uid;
      evidence(
        'T01',
        'PASS invalid credentials displayed; real user A authenticated; project=${Firebase.app().options.projectId}',
      );
      await screenshot(tester, 'T01-authenticated');

      final dynamic state = tester.state(find.byType(app.SignalHome));
      final SignalController c = state.c as SignalController;
      // Capture a genuine encoded example, then respect the API rate limit.
      final response = await http
          .get(Uri.parse(scienceUrl))
          .timeout(const Duration(seconds: 10));
      expect(response.statusCode, 200);
      final questions = parseQuestions(response.body);
      final encoded =
          (jsonDecode(response.body)['results'] as List).first['question'];
      evidence(
        'T02',
        'PASS live exact endpoint; encoded=$encoded decoded=${questions.first.text} count=${questions.length}',
      );
      await Future<void>.delayed(const Duration(seconds: 6));
      await c.start();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      expect(c.phase, Phase.playing);
      await screenshot(tester, 'T02-live-quiz');
      final id = c.ref!.id;
      for (var i = 0; i < 5; i++) {
        final correct = c.quiz!.questions[i].correct;
        c.answer(i.isEven ? correct : !correct);
        c.answer(!correct);
        c.answer(correct);
        expect(c.quiz!.answers.length, i + 1);
        c.next();
      }
      expect(c.quiz!.score, 3);
      expect(c.phase, Phase.readyToSubmit);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      evidence(
        'T04',
        'PASS alternating answers score=3; repeated taps ignored',
      );
      evidence('T05', 'PASS five answers reviewed; fresh replay checked below');
      await screenshot(tester, 'T05-review');
      c.repository.injectFirstVerificationDenial = true;
      final submission = c.submit();
      await c.submit(); // Guard against repeated save taps.
      await submission;
      expect(c.phase, Phase.permissionDenied);
      expect(c.writeAcknowledged, true);
      expect(c.ref!.id, id);
      expect(
        c.message,
        startsWith('Write acknowledged; verification unavailable.'),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      // Scroll to the actual recovery status before the screenshot.
      await tester.ensureVisible(find.byKey(const Key('cloud-status')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await screenshot(tester, 'T09-verification-unavailable');
      final stored = await c.ref!.get(const GetOptions(source: Source.server));
      expect(stored.exists, true);
      expect(stored.data()!['submittedAt'], isA<Timestamp>());
      evidence(
        'T09',
        'WRITE_ACK then injected permission-denied; path=${c.ref!.path}; document still exists; score=3; pending=${stored.metadata.hasPendingWrites}; cache=${stored.metadata.isFromCache}',
      );
      await Future<void>.delayed(const Duration(seconds: 6));
      await c.submit(verifyOnly: true);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      expect(c.phase, Phase.cloudVerified);
      expect(c.ref!.id, id);
      final all = await c.repository.history(uid);
      expect(all.docs.where((d) => d.id == id).length, 1);
      evidence(
        'T06',
        'PASS create-once; double submit ignored; exact fields=${stored.data()!.keys.join(",")}; timestamp=${c.submittedAt!.toDate().toUtc().toIso8601String()}; serverOnly=true',
      );
      evidence(
        'T09',
        'PASS recovery same ID=$id; no duplicate; Cloud verified',
      );
      await tester.ensureVisible(find.byKey(const Key('cloud-status')));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await screenshot(tester, 'T09-cloud-verified');
      await expectLater(
        c.repository.createOnce(c.ref!, uid, fixedPayload(4)),
        throwsStateError,
      );
      expect(
        (await c.ref!.get(
          const GetOptions(source: Source.server),
        )).data()!['correctCount'],
        3,
      );
      evidence(
        'COLLISION',
        'PASS same ID different score rejected; original preserved',
      );

      final originalRef = c.ref!;
      await auth.signInWithEmailAndPassword(email: emailB, password: passB);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      expect(auth.currentUser!.uid, isNot(uid));
      Future<void> denied(Future<dynamic> operation) async => expectLater(
        operation,
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await denied(originalRef.get(const GetOptions(source: Source.server)));
      await denied(
        db.collection('users').doc(uid).collection('attempts').doc().set({
          ...fixedPayload(1),
          'submittedAt': FieldValue.serverTimestamp(),
        }),
      );
      evidence(
        'T10',
        'PASS independently authenticated B denied read AND create under A',
      );
      await auth.signInWithEmailAndPassword(email: emailA, password: passA);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      for (final invalid in [
        {...fixedPayload(6), 'submittedAt': FieldValue.serverTimestamp()},
        {
          ...fixedPayload(2),
          'submittedAt': FieldValue.serverTimestamp(),
          'extra': true,
        },
      ]) {
        await denied(c.repository.newRound(uid).set(invalid));
      }
      await denied(originalRef.update({'correctCount': 4}));
      await denied(originalRef.delete());
      evidence(
        'T11',
        'PASS deployed rules reject score 6, extra field, update, delete',
      );

      // Controller fault recovery over a real, previously committed document.
      for (final code in ['unavailable', 'resource-exhausted']) {
        final repo = FaultRepository(db, auth)..fault = code;
        final ctrl = SignalController(auth, repo, ScienceApi());
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 15),
        );
        ctrl.owner = uid;
        ctrl.ref = originalRef;
        ctrl.payload = fixedPayload(3);
        ctrl.phase = Phase.readyToSubmit;
        await ctrl.submit();
        expect(ctrl.phase, Phase.verificationUnavailable);
        expect(ctrl.writeAcknowledged, true);
        await ctrl.submit(
          verifyOnly: true,
        ); // immediate retry is bounded by cooldown
        expect(ctrl.phase, Phase.verificationUnavailable);
        await Future<void>.delayed(const Duration(seconds: 6));
        await ctrl.submit(verifyOnly: true);
        expect(ctrl.phase, Phase.cloudVerified);
        expect(repo.creates, 1);
        evidence(
          'T12',
          'PASS injected $code after real transaction; immediate retry blocked; same-ID server recovery; creates=${repo.creates}',
        );
        ctrl.dispose();
      }
      final offline = SignalController(
        auth,
        AttemptRepository(db, auth),
        ScienceApi(),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      offline.owner = uid;
      offline.ref = offline.repository.newRound(uid);
      offline.payload = fixedPayload(2);
      offline.phase = Phase.readyToSubmit;
      final offlineId = offline.ref!.id;
      await setDeviceNetwork(false);
      await offline.submit();
      expect(offline.phase, Phase.saveUnknown);
      expect(offline.ref!.id, offlineId);
      await setDeviceNetwork(true);
      await Future<void>.delayed(const Duration(seconds: 6));
      await offline.submit();
      expect(offline.phase, Phase.cloudVerified);
      expect(offline.ref!.id, offlineId);
      evidence(
        'T08',
        'PASS emulator radios disabled; unknown/unavailable write; recovery same ID=$offlineId',
      );
      offline.dispose();

      final slowRepo = FaultRepository(db, auth)
        ..delay = const Duration(seconds: 12);
      final slow = SignalController(auth, slowRepo, ScienceApi());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      slow.owner = uid;
      slow.ref = originalRef;
      slow.payload = fixedPayload(3);
      slow.phase = Phase.readyToSubmit;
      final pending = slow.submit();
      await Future<void>.delayed(const Duration(seconds: 11));
      expect(slow.phase, Phase.saveUnknown);
      expect(slow.busy, true);
      await slow.submit();
      expect(slowRepo.creates, 1);
      await pending;
      expect(slow.phase, Phase.cloudVerified);
      evidence(
        'TIMEOUT',
        'PASS real transaction with delayed acknowledgment; 10-second UI unknown state retains busy lock; eventual server verification',
      );
      slow.dispose();

      final changingRepo = FaultRepository(db, auth)
        ..delay = const Duration(seconds: 3);
      final changing = SignalController(auth, changingRepo, ScienceApi());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      changing.owner = uid;
      changing.ref = originalRef;
      changing.payload = fixedPayload(3);
      changing.phase = Phase.readyToSubmit;
      final changingFuture = changing.submit();
      await auth.signInWithEmailAndPassword(email: emailB, password: passB);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await changingFuture;
      expect(changing.phase, Phase.signedOut);
      expect(changing.ref, isNull);
      evidence('AUTH_CHANGE', 'PASS stale A completion cannot update B UI');
      changing.dispose();
      await auth.signInWithEmailAndPassword(email: emailA, password: passA);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await c.retrieve(id);
      expect(c.phase, Phase.cloudVerified);
      await c.start();
      expect(c.phase, Phase.playing);
      expect(c.ref!.id, isNot(id));
      expect(c.quiz!.answers, isEmpty);
      evidence('T05', 'PASS replay clears answers and allocates a new ID');
      // Save restart coordinates in app-private storage for the second process.
      await File(
        '/data/data/edu.gsu.hetjani.science_signal_ica16_b/files/restart.json',
      ).writeAsString(jsonEncode({'id': id, 'uid': uid}));
      await Future<void>.delayed(const Duration(seconds: 4));
      evidence(
        'SUITE',
        'PASS; T03 is covered by isolated malformed-response tests; T07 requires the separate restart run.',
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
