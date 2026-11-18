import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'quiz.dart';
import 'cloud.dart';

enum Phase {
  signedOut,
  authError,
  loading,
  requestError,
  playing,
  readyToSubmit,
  submitting,
  verifying,
  cloudVerified,
  saveUnknown,
  permissionDenied,
  verificationUnavailable,
}

class SignalController extends ChangeNotifier {
  final FirebaseAuth auth;
  final AttemptRepository repository;
  final ScienceApi api;
  late final StreamSubscription<User?> _authSubscription;
  Phase phase = Phase.signedOut;
  String message = '';
  String? owner;
  DocumentReference<Map<String, dynamic>>? ref;
  Map<String, dynamic>? payload;
  Quiz? quiz;
  bool busy = false;
  bool writeAcknowledged = false;
  Timestamp? submittedAt;
  int _epoch = 0;
  DateTime? _lastRecovery;
  final List<String> trace = [];
  SignalController(this.auth, this.repository, this.api) {
    _authSubscription = auth.authStateChanges().listen((user) {
      if (owner != user?.uid) {
        _epoch++;
        owner = user?.uid;
        quiz = null;
        ref = null;
        payload = null;
        submittedAt = null;
        writeAcknowledged = false;
        // Pending SDK operations remain locked until they settle.
        _set(
          Phase.signedOut,
          user == null
              ? 'Sign in to start a science round.'
              : 'Ready for a new discovery.',
        );
      }
    });
  }
  void _set(Phase value, String text) {
    phase = value;
    message = text;
    trace.add(
      '${DateTime.now().toUtc().toIso8601String()} ${value.name} $text',
    );
    notifyListeners();
  }

  bool _current(int epoch, String uid) =>
      _epoch == epoch && auth.currentUser?.uid == uid;
  Future<void> start() async {
    if (busy || auth.currentUser == null) return;
    if (ref != null &&
        phase != Phase.cloudVerified &&
        phase != Phase.requestError) {
      return;
    }
    final uid = auth.currentUser!.uid;
    final epoch = _epoch;
    owner = uid;
    busy = true;
    if (phase != Phase.requestError || ref == null) {
      ref = repository.newRound(uid);
    }
    payload = null;
    quiz = null;
    writeAcknowledged = false;
    submittedAt = null;
    _set(Phase.loading, 'Receiving five Science & Nature questions…');
    try {
      final questions = await api.load();
      if (_current(epoch, uid)) {
        quiz = Quiz(questions);
        _set(Phase.playing, 'Choose True or False.');
      }
    } catch (e) {
      if (_current(epoch, uid)) {
        _set(Phase.requestError, 'Questions unavailable. $e');
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void answer(bool value) {
    if (phase != Phase.playing || quiz == null) return;
    quiz!.answer(value);
    notifyListeners();
  }

  void next() {
    if (phase != Phase.playing || quiz?.answered != true) return;
    if (quiz!.complete) {
      payload = fixedPayload(quiz!.score);
      _set(
        Phase.readyToSubmit,
        'Five answers recorded. Review your round, then save it.',
      );
    } else {
      quiz!.next();
      notifyListeners();
    }
  }

  Future<void> submit({bool verifyOnly = false}) async {
    if (busy || ref == null || payload == null || owner == null) return;
    if (![
      Phase.readyToSubmit,
      Phase.saveUnknown,
      Phase.permissionDenied,
      Phase.verificationUnavailable,
    ].contains(phase)) {
      return;
    }
    final now = DateTime.now();
    if (_lastRecovery != null &&
        now.difference(_lastRecovery!) < const Duration(seconds: 5)) {
      message = 'Please wait five seconds before another recovery attempt.';
      notifyListeners();
      return;
    }
    _lastRecovery = now;
    final uid = owner!, epoch = _epoch, round = ref!, fixed = payload!;
    busy = true;
    bool verification = verifyOnly || writeAcknowledged;
    _set(
      verification ? Phase.verifying : Phase.submitting,
      verification
          ? 'Reading this round directly from the server…'
          : 'Saving your frozen score…',
    );
    // A UI deadline does not cancel the SDK future. Keep the lock until it settles.
    final timer = Timer(const Duration(seconds: 10), () {
      if (_current(epoch, uid)) {
        _set(
          writeAcknowledged ? Phase.verificationUnavailable : Phase.saveUnknown,
          writeAcknowledged
              ? 'Write acknowledged; verification unavailable. Still waiting for the server.'
              : 'Save outcome unknown. Still waiting; the original round ID is retained.',
        );
      }
    });
    try {
      if (!verification) {
        await repository.createOnce(round, uid, fixed);
        if (!_current(epoch, uid)) return;
        writeAcknowledged = true;
        verification = true;
        _set(
          Phase.verifying,
          'Write acknowledged. Checking the server record…',
        );
      }
      final snapshot = await repository.verify(round, uid, fixed);
      if (_current(epoch, uid)) {
        submittedAt = snapshot.data()!['submittedAt'] as Timestamp;
        _set(Phase.cloudVerified, 'Cloud verified');
      }
    } catch (e) {
      if (_current(epoch, uid)) {
        final code = e is FirebaseException
            ? e.code
            : e is TimeoutException
            ? 'timeout'
            : 'validation';
        final state = code == 'permission-denied'
            ? Phase.permissionDenied
            : writeAcknowledged || verification
            ? Phase.verificationUnavailable
            : Phase.saveUnknown;
        _set(
          state,
          writeAcknowledged
              ? 'Write acknowledged; verification unavailable. ($code) Retry verification of this same round.'
              : 'Save not confirmed ($code). Recover using the original round ID. $e',
        );
      }
    } finally {
      timer.cancel();
      busy = false;
      notifyListeners();
    }
  }

  Future<void> retrieve(String id) async {
    if (busy ||
        auth.currentUser == null ||
        !RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(id)) {
      return;
    }
    if (ref != null &&
        phase != Phase.cloudVerified &&
        phase != Phase.signedOut) {
      return;
    }
    final uid = auth.currentUser!.uid, epoch = _epoch;
    busy = true;
    _set(Phase.verifying, 'Retrieving original round from the server…');
    final deadline = Timer(const Duration(seconds: 10), () {
      if (_current(epoch, uid)) {
        _set(
          Phase.verifying,
          'Server retrieval is still pending. Waiting for this original round; retries remain locked.',
        );
      }
    });
    try {
      final target = repository.db
          .collection('users')
          .doc(uid)
          .collection('attempts')
          .doc(id);
      final raw = await target.get(const GetOptions(source: Source.server));
      final score = raw.data()?['correctCount'];
      if (score is! int || score < 0 || score > 5) {
        throw StateError('Invalid server score');
      }
      final fixed = fixedPayload(score);
      final verified = await repository.verify(target, uid, fixed);
      if (_current(epoch, uid)) {
        ref = target;
        payload = fixed;
        writeAcknowledged = true;
        quiz = null;
        submittedAt = verified.data()!['submittedAt'] as Timestamp;
        _set(Phase.cloudVerified, 'Cloud verified');
      }
    } catch (e) {
      if (_current(epoch, uid)) {
        _set(Phase.signedOut, 'Retrieval unavailable. $e');
      }
    } finally {
      deadline.cancel();
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
