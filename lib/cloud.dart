import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Map<String, dynamic> fixedPayload(int score) => Map.unmodifiable({
  'schemaVersion': 1,
  'variant': 'B',
  'categoryId': 17,
  'questionCount': 5,
  'correctCount': score,
});
bool matchesPayload(Map<String, dynamic>? data, Map<String, dynamic> fixed) =>
    data != null &&
    data.length == 6 &&
    data.containsKey('submittedAt') &&
    fixed.entries.every(
      (e) =>
          data[e.key] == e.value &&
          data[e.key].runtimeType == e.value.runtimeType,
    );

class AttemptRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  AttemptRepository(this.db, this.auth);
  bool injectFirstVerificationDenial = false;
  bool _denialArmed = false;
  DocumentReference<Map<String, dynamic>> newRound(String uid) =>
      db.collection('users').doc(uid).collection('attempts').doc();
  void requireOwner(String uid) {
    if (auth.currentUser?.uid != uid) {
      throw FirebaseException(
        plugin: 'science-signal',
        code: 'unauthenticated',
        message: 'Account changed. Sign in as the original account to recover.',
      );
    }
  }

  Future<void> createOnce(
    DocumentReference<Map<String, dynamic>> ref,
    String uid,
    Map<String, dynamic> fixed,
  ) async {
    requireOwner(uid);
    await db.runTransaction(
      (transaction) async {
        // Retry-safe: only a read, a comparison, and a conditional create.
        final existing = await transaction.get(ref);
        if (existing.exists) {
          if (!matchesPayload(existing.data(), fixed)) {
            throw StateError(
              'Round ID collision: existing score differs. Record preserved.',
            );
          }
        } else {
          transaction.set(ref, {
            ...fixed,
            'submittedAt': FieldValue.serverTimestamp(),
          });
        }
      },
      maxAttempts: 3,
      timeout: const Duration(seconds: 25),
    );
    if (kDebugMode && injectFirstVerificationDenial) _denialArmed = true;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> verify(
    DocumentReference<Map<String, dynamic>> ref,
    String uid,
    Map<String, dynamic> fixed,
  ) async {
    requireOwner(uid);
    if (kDebugMode && _denialArmed && injectFirstVerificationDenial) {
      _denialArmed = false;
      injectFirstVerificationDenial = false;
      throw FirebaseException(
        plugin: 'science-signal-dev-hook',
        code: 'permission-denied',
        message:
            'Injected first verification failure after acknowledged transaction.',
      );
    }
    final snapshot = await ref.get(const GetOptions(source: Source.server));
    requireOwner(uid);
    if (!snapshot.exists ||
        snapshot.id != ref.id ||
        !matchesPayload(snapshot.data(), fixed) ||
        snapshot.data()?['submittedAt'] is! Timestamp ||
        snapshot.metadata.hasPendingWrites ||
        snapshot.metadata.isFromCache) {
      throw StateError(
        'Server record did not match the frozen round. Verification unavailable.',
      );
    }
    return snapshot;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> history(String uid) async {
    requireOwner(uid);
    final result = await db
        .collection('users')
        .doc(uid)
        .collection('attempts')
        .orderBy('submittedAt', descending: true)
        .limit(20)
        .get(const GetOptions(source: Source.server));
    requireOwner(uid);
    return result;
  }
}
