import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:science_signal_ica16_b/main.dart' as app;
import 'package:science_signal_ica16_b/controller.dart';
import 'acceptance_test.dart' show evidence, screenshot;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('T07 new process retrieves original server document', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    const saved = {
      'id': String.fromEnvironment('ROUND_ID'),
      'uid': String.fromEnvironment('ROUND_UID'),
    };
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: const String.fromEnvironment('EMAIL_A'),
      password: const String.fromEnvironment('PASSWORD_A'),
    );
    await tester.pumpAndSettle();
    expect(auth.currentUser!.uid, saved['uid']);
    final dynamic state = tester.state(find.byType(app.SignalHome));
    final SignalController c = state.c as SignalController;
    await c.retrieve(saved['id'] as String);
    await tester.pumpAndSettle();
    expect(c.phase, Phase.cloudVerified);
    expect(c.payload!['correctCount'], 3);
    expect(c.ref!.id, saved['id']);
    expect(c.submittedAt, isNotNull);
    await tester.ensureVisible(find.byKey(const Key('cloud-status')));
    await tester.pumpAndSettle();
    await screenshot(tester, 'T07-restart');
    await Future<void>.delayed(const Duration(seconds: 4));
    evidence(
      'T07',
      'PASS new application process; same user reauthenticated; original path=${c.ref!.path}; score=3; server-only verified; timestamp=${c.submittedAt!.toDate().toUtc().toIso8601String()}',
    );
  });
}
