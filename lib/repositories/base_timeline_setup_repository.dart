import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
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
    if (existing != null) {
      if (existing.schemaVersion < BaseTimelineSetup.currentSchemaVersion) {
        final sourceResult = await _fetchOnboardingSource(uid, _onboardingRepo);
        if (sourceResult.readFailed) return existing;
        final migrated = migrateBaseTimelineSetupIfNeeded(
          existing: existing,
          onboardingSource: sourceResult.setup,
        );
        _setups[uid] = migrated;
        _controller.add(migrated);
        return migrated;
      }
      return existing;
    }

    final sourceResult = await _fetchOnboardingSource(uid, _onboardingRepo);
    if (sourceResult.readFailed) {
      throw StateError(
        'Base Timeline setup source read failed; retry before creating empty setup.',
      );
    }
    final initial =
        sourceResult.setup ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
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
  }) : _injectedFirestore = firestore,
       _onboardingRepo = onboardingRepo;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async {
    final docRef = _firestore.doc(FirestoreUserPaths.baseTimelineSetup(uid));
    final doc = await docRef.get();
    final data = doc.data();

    if (doc.exists && data != null) {
      final existing = BaseTimelineSetup.fromMap(data, uid: uid);
      if (existing.schemaVersion < BaseTimelineSetup.currentSchemaVersion) {
        final sourceResult = await _fetchOnboardingSource(uid, _onboardingRepo);
        if (sourceResult.readFailed) return existing;
        final migrated = migrateBaseTimelineSetupIfNeeded(
          existing: existing,
          onboardingSource: sourceResult.setup,
        );
        try {
          await saveSetup(uid, migrated);
        } catch (_) {}
        return migrated;
      }
      return existing;
    }

    final sourceResult = await _fetchOnboardingSource(uid, _onboardingRepo);
    if (sourceResult.readFailed) {
      throw StateError(
        'Base Timeline setup source read failed; retry before creating empty setup.',
      );
    }
    final setup =
        sourceResult.setup ??
        BaseTimelineSetup(uid: uid, updatedAt: DateTime.now());
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
      return ref
          .watch(fakeBackendPolicyProvider)
          .selectBackend(
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

final baseTimelineSetupNotifierProvider =
    StateNotifierProvider<
      BaseTimelineSetupNotifier,
      AsyncValue<BaseTimelineSetup>
    >((ref) {
      final uid = ref.watch(userProfileProvider).uid;
      final repo = ref.watch(baseTimelineSetupRepositoryProvider);
      return BaseTimelineSetupNotifier(repo, uid);
    });

class _OnboardingSourceFetchResult {
  final BaseTimelineSetup? setup;
  final bool readFailed;

  const _OnboardingSourceFetchResult.sourceFound(this.setup)
    : readFailed = false;

  const _OnboardingSourceFetchResult.definitivelyNoSource()
    : setup = null,
      readFailed = false;

  const _OnboardingSourceFetchResult.readFailed()
    : setup = null,
      readFailed = true;
}

Future<_OnboardingSourceFetchResult> _fetchOnboardingSource(
  String uid,
  OnboardingRepository? onboardingRepo,
) async {
  if (onboardingRepo == null) {
    return const _OnboardingSourceFetchResult.definitivelyNoSource();
  }
  try {
    final draft = await onboardingRepo.fetchDraft(uid);
    final bundle = await onboardingRepo.fetchCompletionBundle(uid);
    if (draft != null && bundle != null) {
      final plan = RoutineOnboardingProjection.build(bundle);
      return _OnboardingSourceFetchResult.sourceFound(
        BaseTimelineSetup.fromOnboardingCompletion(
          finalDraft: draft,
          bundle: bundle,
          projectedRoutineItems: plan.items,
        ),
      );
    } else if (draft != null &&
        (draft.baseTimeline.blocks.isNotEmpty ||
            draft.baseTimeline.pendingFutureImports.isNotEmpty ||
            draft.baseTimeline.skinCareProductPhotoAssetId != null)) {
      return _OnboardingSourceFetchResult.sourceFound(
        BaseTimelineSetup.fromOnboardingDraft(uid, draft),
      );
    } else if (bundle != null) {
      final plan = RoutineOnboardingProjection.build(bundle);
      return _OnboardingSourceFetchResult.sourceFound(
        BaseTimelineSetup.fromCompletionBundle(
          uid,
          bundle,
          finalDraft: draft,
          projectedRoutineItems: plan.items,
        ),
      );
    }
  } catch (_) {
    return const _OnboardingSourceFetchResult.readFailed();
  }
  return const _OnboardingSourceFetchResult.definitivelyNoSource();
}

BaseTimelineSetup migrateBaseTimelineSetupIfNeeded({
  required BaseTimelineSetup existing,
  BaseTimelineSetup? onboardingSource,
}) {
  if (existing.schemaVersion >= BaseTimelineSetup.currentSchemaVersion) {
    return existing;
  }

  var migrated = existing.copyWith(
    schemaVersion: BaseTimelineSetup.currentSchemaVersion,
    revision: existing.revision < 1 ? 1 : existing.revision,
  );

  if (onboardingSource != null) {
    final canSafelyBackfillUnconfiguredSections = existing.revision <= 1;

    // Classes: preserve existing runtime edits unconditionally
    final classesConfigured =
        existing.snapshotFor(BaseTimelineSection.classes).configured ||
        existing.classBlocks.isNotEmpty ||
        existing.classRoutineItemIds.isNotEmpty;
    if (canSafelyBackfillUnconfiguredSections &&
        !classesConfigured &&
        onboardingSource.classBlocks.isNotEmpty) {
      migrated = migrated.copyWith(
        classBlocks: onboardingSource.classBlocks,
        classRoutineItemIds: onboardingSource.classRoutineItemIds,
        classLogicalAssetId: onboardingSource.classLogicalAssetId,
        classLogicalAssetR2Key: onboardingSource.classLogicalAssetR2Key,
      );
    }

    // Work: preserve existing runtime edits unconditionally
    final workConfigured =
        existing.snapshotFor(BaseTimelineSection.work).configured ||
        existing.workBlocks.isNotEmpty ||
        existing.workRoutineItemIds.isNotEmpty;
    if (canSafelyBackfillUnconfiguredSections &&
        !workConfigured &&
        onboardingSource.workBlocks.isNotEmpty) {
      migrated = migrated.copyWith(
        workBlocks: onboardingSource.workBlocks,
        workRoutineItemIds: onboardingSource.workRoutineItemIds,
        workLogicalAssetId: onboardingSource.workLogicalAssetId,
        workLogicalAssetR2Key: onboardingSource.workLogicalAssetR2Key,
      );
    }

    // Eating: preserve existing runtime edits unconditionally
    final eatingConfigured =
        existing.snapshotFor(BaseTimelineSection.eating).configured ||
        existing.eatingBlocks.isNotEmpty ||
        existing.eatingRoutineItemIds.isNotEmpty ||
        existing.eatingSetupPath != null;
    if (canSafelyBackfillUnconfiguredSections &&
        !eatingConfigured &&
        (onboardingSource.eatingBlocks.isNotEmpty ||
            onboardingSource.eatingSetupPath != null)) {
      migrated = migrated.copyWith(
        eatingSetupPath: onboardingSource.eatingSetupPath,
        eatingBlocks: onboardingSource.eatingBlocks,
        eatingRoutineItemIds: onboardingSource.eatingRoutineItemIds,
        mealPlanningGoal: onboardingSource.mealPlanningGoal,
        mealsPerDay: onboardingSource.mealsPerDay,
        eatingMode: onboardingSource.eatingMode,
        foodType: onboardingSource.foodType,
        foodStyleCustomText: onboardingSource.foodStyleCustomText,
        mealBudget: onboardingSource.mealBudget,
        cookingAbility: onboardingSource.cookingAbility,
        breakfastMinute: onboardingSource.breakfastMinute,
        lunchMinute: onboardingSource.lunchMinute,
        dinnerMinute: onboardingSource.dinnerMinute,
        snackMinute: onboardingSource.snackMinute,
        extraSnackMinute: onboardingSource.extraSnackMinute,
        targetCalories: onboardingSource.targetCalories,
        targetProtein: onboardingSource.targetProtein,
        eatingPhotoAssetId: onboardingSource.eatingPhotoAssetId,
        eatingPhotoR2Key: onboardingSource.eatingPhotoR2Key,
      );
    }

    // Fixed: preserve existing runtime edits unconditionally
    final fixedConfigured =
        existing.snapshotFor(BaseTimelineSection.fixed).configured ||
        existing.fixedBlocks.isNotEmpty ||
        existing.fixedRoutineItemIds.isNotEmpty;
    if (canSafelyBackfillUnconfiguredSections &&
        !fixedConfigured &&
        onboardingSource.fixedBlocks.isNotEmpty) {
      migrated = migrated.copyWith(
        fixedBlocks: onboardingSource.fixedBlocks,
        fixedRoutineItemIds: onboardingSource.fixedRoutineItemIds,
      );
    }

    // Skin Care: preserve existing runtime edits unconditionally
    final skinCareConfigured =
        existing.snapshotFor(BaseTimelineSection.skinCare).configured ||
        existing.skinCareBlocks.isNotEmpty ||
        existing.skinCareRoutineItemIds.isNotEmpty ||
        existing.skinCareSetupPath != null ||
        existing.skinCareSkipped;
    if (canSafelyBackfillUnconfiguredSections &&
        !skinCareConfigured &&
        (onboardingSource.skinCareBlocks.isNotEmpty ||
            onboardingSource.skinCareSetupPath != null ||
            onboardingSource.skinCareSkipped)) {
      migrated = migrated.copyWith(
        skinCareSetupPath: onboardingSource.skinCareSetupPath,
        skinCareSkipped: onboardingSource.skinCareSkipped,
        skinCareBlocks: onboardingSource.skinCareBlocks,
        skinCareRoutineItemIds: onboardingSource.skinCareRoutineItemIds,
        skinCareProductNames: onboardingSource.skinCareProductNames,
        skinCareProductPhotoAssetId:
            onboardingSource.skinCareProductPhotoAssetId,
        skinCareProductPhotoR2Key: onboardingSource.skinCareProductPhotoR2Key,
        skinCareReviewedProducts: onboardingSource.skinCareReviewedProducts,
        skinCareFacePhotoAssetId: onboardingSource.skinCareFacePhotoAssetId,
        skinCareFacePhotoR2Key: onboardingSource.skinCareFacePhotoR2Key,
        skinCareFacePhotoSkipped: onboardingSource.skinCareFacePhotoSkipped,
        skinCareSkinType: onboardingSource.skinCareSkinType,
        skinCareProblems: onboardingSource.skinCareProblems,
        skinCareBudget: onboardingSource.skinCareBudget,
        skinCarePreference: onboardingSource.skinCarePreference,
        skinCareSelectedProductNames:
            onboardingSource.skinCareSelectedProductNames,
        skinCareProductRecommendations:
            onboardingSource.skinCareProductRecommendations,
        skinCareSpecialCareNotes: onboardingSource.skinCareSpecialCareNotes,
      );
    }
  }

  return migrated;
}
