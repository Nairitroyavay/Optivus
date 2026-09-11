import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/state/app_state.dart';

abstract class BaseTimelineSetupRepository {
  Future<BaseTimelineSetup> fetchSetup(String uid);
  Future<void> saveSetup(String uid, BaseTimelineSetup setup);
  Stream<BaseTimelineSetup?> watchSetup(String uid);
}

class FakeBaseTimelineSetupRepository implements BaseTimelineSetupRepository {
  final Map<String, BaseTimelineSetup> _setups = {};
  final StreamController<BaseTimelineSetup?> _controller =
      StreamController<BaseTimelineSetup?>.broadcast();
  final OnboardingRepository? _onboardingRepo;

  FakeBaseTimelineSetupRepository({OnboardingRepository? onboardingRepo})
      : _onboardingRepo = onboardingRepo;

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async {
    final existing = _setups[uid];
    if (existing != null) return existing;

    // Attempt migration from OnboardingDraft
    if (_onboardingRepo != null) {
      try {
        final draft = await _onboardingRepo.fetchDraft(uid);
        if (draft != null &&
            (draft.baseTimeline.blocks.isNotEmpty ||
                draft.baseTimeline.pendingFutureImports.isNotEmpty ||
                draft.baseTimeline.skinCareProductPhotoAssetId != null)) {
          final setup = BaseTimelineSetup.fromOnboardingDraft(
            uid,
            draft,
          );
          _setups[uid] = setup;
          return setup;
        }

        final bundle = await _onboardingRepo.fetchCompletionBundle(uid);
        if (bundle != null) {
          final setup = BaseTimelineSetup.fromCompletionBundle(
            uid,
            bundle,
          );
          _setups[uid] = setup;
          return setup;
        }
      } catch (_) {}
    }

    final initial = BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
    _setups[uid] = initial;
    return initial;
  }

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup setup) async {
    _setups[uid] = setup;
    _controller.add(setup);
  }

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) {
    return _controller.stream;
  }
}

class FirestoreBaseTimelineSetupRepository
    implements BaseTimelineSetupRepository {
  final FirebaseFirestore? _injectedFirestore;
  final OnboardingRepository? _onboardingRepo;

  FirestoreBaseTimelineSetupRepository({
    FirebaseFirestore? firestore,
    OnboardingRepository? onboardingRepo,
  })  : _injectedFirestore = firestore,
        _onboardingRepo = onboardingRepo;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async {
    final docRef = _firestore.doc(FirestoreUserPaths.baseTimelineSetup(uid));
    final doc = await docRef.get();
    final data = doc.data();

    if (doc.exists && data != null) {
      return BaseTimelineSetup.fromMap(data, uid: uid);
    }

    // Attempt migration from Onboarding
    BaseTimelineSetup? migrated;
    if (_onboardingRepo != null) {
      try {
        final draft = await _onboardingRepo.fetchDraft(uid);
        if (draft != null &&
            (draft.baseTimeline.blocks.isNotEmpty ||
                draft.baseTimeline.pendingFutureImports.isNotEmpty ||
                draft.baseTimeline.skinCareProductPhotoAssetId != null)) {
          migrated = BaseTimelineSetup.fromOnboardingDraft(
            uid,
            draft,
          );
        } else {
          final bundle = await _onboardingRepo.fetchCompletionBundle(uid);
          if (bundle != null) {
            migrated = BaseTimelineSetup.fromCompletionBundle(
              uid,
              bundle,
            );
          }
        }
      } catch (_) {}
    }

    final setup =
        migrated ?? BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
    // Persist migrated setup so subsequent reads hit Firestore directly
    try {
      await saveSetup(uid, setup);
    } catch (_) {}

    return setup;
  }

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup setup) async {
    final docRef = _firestore.doc(FirestoreUserPaths.baseTimelineSetup(uid));
    await docRef.set(setup.toMap(), SetOptions(merge: true));
  }

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) {
    return _firestore
        .doc(FirestoreUserPaths.baseTimelineSetup(uid))
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return BaseTimelineSetup.fromMap(snap.data()!, uid: uid);
    });
  }
}

final baseTimelineSetupRepositoryProvider =
    Provider<BaseTimelineSetupRepository>((ref) {
  return ref.watch(fakeBackendPolicyProvider).selectBackend(
        firebase: () => FirestoreBaseTimelineSetupRepository(
          onboardingRepo: ref.watch(onboardingRepositoryProvider),
        ),
        fake: () => FakeBaseTimelineSetupRepository(
          onboardingRepo: ref.watch(onboardingRepositoryProvider),
        ),
      );
});

class BaseTimelineSetupNotifier
    extends StateNotifier<AsyncValue<BaseTimelineSetup>> {
  final BaseTimelineSetupRepository _repository;
  final String _uid;

  BaseTimelineSetupNotifier(this._repository, this._uid)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (_uid.trim().isEmpty) return;
    try {
      final setup = await _repository.fetchSetup(_uid);
      state = AsyncValue.data(setup);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(BaseTimelineSetup updated) async {
    state = AsyncValue.data(updated);
    await _repository.saveSetup(_uid, updated);
  }

  void updateInMemory(BaseTimelineSetup updated) {
    state = AsyncValue.data(updated);
  }
}

final baseTimelineSetupNotifierProvider = StateNotifierProvider.autoDispose<
    BaseTimelineSetupNotifier, AsyncValue<BaseTimelineSetup>>((ref) {
  final uid = ref.watch(userProfileProvider).uid;
  final repo = ref.watch(baseTimelineSetupRepositoryProvider);
  return BaseTimelineSetupNotifier(repo, uid);
});
