import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class OnboardingRepository {
  Future<OnboardingDraft?> fetchDraft(String uid);
  Future<void> saveDraft(OnboardingDraft draft);
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle);
  Future<void> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  });
}

class FakeOnboardingRepository implements OnboardingRepository {
  final Map<String, OnboardingDraft> _drafts = {};
  final Map<String, OnboardingCompletionBundle> _bundles = {};

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    return _drafts[uid];
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _drafts[draft.uid] = draft;
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    _bundles[bundle.uid] = bundle;
  }

  @override
  Future<void> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    await saveDraft(finalDraft);
    await saveCompletionBundle(bundle);
  }

  OnboardingCompletionBundle? savedCompletionBundle(String uid) {
    return _bundles[uid];
  }
}

class FirestoreOnboardingRepository implements OnboardingRepository {
  final FirebaseFirestore _firestore;

  FirestoreOnboardingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.onboardingDraft(uid))
        .get();
    final data = doc.data();
    return data == null ? null : OnboardingDraft.fromMap(data);
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) {
    return _firestore
        .doc(FirestoreUserPaths.onboardingDraft(draft.uid))
        .set(draft.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) {
    return _firestore
        .doc(FirestoreUserPaths.onboardingCompletionBundle(bundle.uid))
        .set(bundle.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) {
    if (finalDraft.uid != bundle.uid) {
      throw ArgumentError('Final draft and completion bundle uid mismatch.');
    }

    final batch = _firestore.batch();
    final uid = finalDraft.uid;
    batch.set(
      _firestore.doc(FirestoreUserPaths.onboardingDraft(uid)),
      finalDraft.toMap(),
    );
    batch.set(
      _firestore.doc(FirestoreUserPaths.onboardingCompletionBundle(uid)),
      bundle.toMap(),
    );
    batch.set(
      _firestore.doc(FirestoreUserPaths.profile(uid)),
      bundle.userProfilePatch,
      SetOptions(merge: true),
    );
    return batch.commit();
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  if (OptivusBackendConfig.useFirebase) {
    return FirestoreOnboardingRepository();
  }
  return FakeOnboardingRepository();
});
