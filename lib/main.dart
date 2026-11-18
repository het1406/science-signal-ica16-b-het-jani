import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'cloud.dart';
import 'controller.dart';
import 'quiz.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ScienceSignal());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Firebase could not initialize. Check configuration and restart.',
            ),
          ),
        ),
      ),
    );
  }
}

class ScienceSignal extends StatelessWidget {
  const ScienceSignal({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Science Signal',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF82E4C5),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1521),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(100, 52)),
      ),
    ),
    home: const SignalHome(),
  );
}

class SignalHome extends StatefulWidget {
  const SignalHome({super.key});
  @override
  State<SignalHome> createState() => _SignalHomeState();
}

class _SignalHomeState extends State<SignalHome> {
  late final SignalController c;
  final email = TextEditingController(),
      password = TextEditingController(),
      round = TextEditingController();
  bool signingIn = false;
  String authError = '';
  @override
  void initState() {
    super.initState();
    final auth = FirebaseAuth.instance;
    c = SignalController(
      auth,
      AttemptRepository(FirebaseFirestore.instance, auth),
      ScienceApi(),
    );
    c.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(refresh);
    c.dispose();
    email.dispose();
    password.dispose();
    round.dispose();
    super.dispose();
  }

  Future<void> authenticate({bool create = false}) async {
    if (signingIn) return;
    setState(() {
      signingIn = true;
      authError = '';
    });
    try {
      if (create) {
        await c.auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await c.auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      password.clear();
    } on FirebaseAuthException catch (e) {
      c.phase = Phase.authError;
      authError = switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Email or password is incorrect.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Use a stronger password (at least six characters).',
        'email-already-in-use' =>
          'This account already exists. Sign in instead.',
        'network-request-failed' =>
          'Cannot reach authentication. Check your connection.',
        _ => 'Authentication unavailable (${e.code}). Please try again.',
      };
    } finally {
      if (mounted) setState(() => signingIn = false);
    }
  }

  Widget panel(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget gap() => const SizedBox(height: 20);
  @override
  Widget build(BuildContext context) {
    final user = c.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SCIENCE SIGNAL'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: c.busy ? null : () => c.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'A LITTLE CURIOSITY. A CLEARER SIGNAL.',
                    style: TextStyle(
                      color: Color(0xFF82E4C5),
                      letterSpacing: 1.5,
                      fontSize: 11,
                    ),
                  ),
                  gap(),
                  Text(
                    user == null
                        ? 'Test your world.\nKeep your discoveries.'
                        : 'Five questions.\nOne new discovery.',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SCIENCE & NATURE  /  MEDIUM  /  TRUE OR FALSE',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                  gap(),
                  if (user == null)
                    panel([
                      const Text(
                        'Welcome to the lab',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      gap(),
                      TextField(
                        controller: email,
                        key: const Key('email'),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      gap(),
                      TextField(
                        controller: password,
                        key: const Key('password'),
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      gap(),
                      if (authError.isNotEmpty)
                        Text(
                          authError,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      FilledButton(
                        onPressed: signingIn ? null : () => authenticate(),
                        child: Text(signingIn ? 'Signing in…' : 'Sign in'),
                      ),
                      TextButton(
                        onPressed: signingIn
                            ? null
                            : () => authenticate(create: true),
                        child: const Text('Create an account'),
                      ),
                    ])
                  else ...[
                    if (c.phase == Phase.signedOut)
                      panel([
                        Text(c.message),
                        gap(),
                        FilledButton(
                          onPressed: c.busy ? null : c.start,
                          child: const Text('Start a science round'),
                        ),
                        gap(),
                        const Text(
                          'Recover an earlier round',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: round,
                          decoration: const InputDecoration(
                            labelText: 'Original round ID',
                          ),
                        ),
                        TextButton(
                          onPressed: c.busy
                              ? null
                              : () => c.retrieve(round.text.trim()),
                          child: const Text('Retrieve from server'),
                        ),
                        TextButton(
                          onPressed: c.busy ? null : history,
                          child: const Text('Find my recent cloud rounds'),
                        ),
                      ]),
                    if (c.phase == Phase.loading)
                      panel([
                        const LinearProgressIndicator(),
                        gap(),
                        Text(c.message),
                      ]),
                    if (c.phase == Phase.requestError)
                      panel([
                        const Icon(Icons.wifi_off, size: 40),
                        gap(),
                        Text(c.message),
                        gap(),
                        FilledButton(
                          onPressed: c.busy ? null : c.start,
                          child: const Text('Retry questions'),
                        ),
                      ]),
                    if (c.phase == Phase.playing) quizPanel(),
                    if (c.payload != null) resultsPanel(),
                  ],
                  gap(),
                  const Text(
                    'CLASS B · CSC 4360 · HET JANI',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget quizPanel() {
    final q = c.quiz!;
    final question = q.questions[q.index];
    return panel([
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('QUESTION ${q.index + 1} OF 5'),
          Text('${q.score} correct'),
        ],
      ),
      gap(),
      LinearProgressIndicator(value: (q.index + 1) / 5),
      gap(),
      Text(question.text, style: const TextStyle(fontSize: 25, height: 1.4)),
      gap(),
      Row(
        children: [
          for (final value in [true, false])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: FilledButton.tonal(
                  onPressed: q.answered ? null : () => c.answer(value),
                  child: Text(value ? 'True' : 'False'),
                ),
              ),
            ),
        ],
      ),
      if (q.answered) ...[
        gap(),
        Text(
          q.answers[q.index] == question.correct
              ? '✓ Correct — nice discovery.'
              : '✕ Not quite. Correct answer: ${question.correct ? "True" : "False"}.',
          style: TextStyle(
            color: q.answers[q.index] == question.correct
                ? const Color(0xFF82E4C5)
                : Colors.orangeAccent,
          ),
        ),
      ],
      gap(),
      FilledButton(
        onPressed: q.answered ? c.next : null,
        child: Text(q.index == 4 ? 'Review my round' : 'Continue'),
      ),
    ]);
  }

  Widget resultsPanel() => panel([
    Text(
      '${c.payload!['correctCount']} / 5',
      style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
    ),
    const Text('Your science signal', style: TextStyle(fontSize: 20)),
    gap(),
    if (c.quiz != null) ...[
      for (var i = 0; i < 5; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${i + 1}. ${c.quiz!.questions[i].text}\nYou: ${c.quiz!.answers[i] ? "True" : "False"} · Correct: ${c.quiz!.questions[i].correct ? "True" : "False"}',
          ),
        ),
    ],
    if (c.busy) const LinearProgressIndicator(),
    gap(),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          c.phase == Phase.cloudVerified
              ? Icons.verified
              : Icons.cloud_outlined,
          color: c.phase == Phase.cloudVerified
              ? const Color(0xFF82E4C5)
              : Colors.orangeAccent,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            c.message,
            key: const Key('cloud-status'),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    ),
    gap(),
    SelectableText('Round: ${c.ref!.id}', style: const TextStyle(fontSize: 12)),
    TextButton(
      onPressed: () => Clipboard.setData(ClipboardData(text: c.ref!.id)),
      child: const Text('Copy round ID'),
    ),
    if (c.submittedAt != null)
      Text(
        'Server timestamp: ${c.submittedAt!.toDate().toUtc().toIso8601String()}',
        style: const TextStyle(fontSize: 12),
      ),
    if (c.phase == Phase.readyToSubmit) ...[
      if (kDebugMode)
        SwitchListTile(
          title: const Text('QA: deny first verification'),
          value: c.repository.injectFirstVerificationDenial,
          onChanged: (value) => setState(
            () => c.repository.injectFirstVerificationDenial = value,
          ),
        ),
      FilledButton(
        onPressed: c.busy ? null : c.submit,
        child: const Text('Save to my cloud'),
      ),
    ],
    if ([
      Phase.saveUnknown,
      Phase.permissionDenied,
      Phase.verificationUnavailable,
    ].contains(c.phase))
      FilledButton(
        onPressed: c.busy
            ? null
            : () => c.submit(verifyOnly: c.writeAcknowledged),
        child: Text(
          c.writeAcknowledged
              ? 'Retry server verification'
              : 'Recover same round',
        ),
      ),
    if (c.phase == Phase.cloudVerified)
      FilledButton(
        onPressed: c.busy ? null : c.start,
        child: const Text('Play a new round'),
      ),
  ]);
  Future<void> history() async {
    final uid = c.auth.currentUser!.uid;
    try {
      final result = await c.repository.history(uid);
      if (!mounted || c.auth.currentUser?.uid != uid) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your server records'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: result.docs
                  .map(
                    (doc) => ListTile(
                      title: Text('${doc.data()['correctCount']} / 5'),
                      subtitle: Text(doc.id),
                      onTap: () {
                        Navigator.pop(context);
                        c.retrieve(doc.id);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Server history unavailable. Try again when connected.',
            ),
          ),
        );
      }
    }
  }
}
