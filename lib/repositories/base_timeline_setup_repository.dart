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
  final Map<String, StreamController<BaseTimelineSetup?>> _controllers = {};
  final OnboardingRepository? _onboardingRepo;

  FakeBaseTimelineSetupRepository({OnboardingRepository? onboardingRepo})
    : _onboardingRepo = onboardingRepo;

  @override
  Future<BaseTimelineSetup> fetchSetup(String uid) async {
    final existing = _setups[uid];
    if (existing != null) {
      final rawPath = existing.skinCareSetupPath;
      final hasLegacySkinCarePath =
          rawPath == 'has_products' || rawPath == 'no_products';
      if (existing.schemaVersion < BaseTimelineSetup.currentSchemaVersion ||
          hasLegacySkinCarePath) {
        final sourceResult = await _fetchOnboardingSource(uid, _onboardingRepo);
        if (sourceResult.readFailed) return existing;
        final migrated = migrateBaseTimelineSetupIfNeeded(
          existing: existing,
          onboardingSource: sourceResult.setup,
          hasLegacySkinCarePath: hasLegacySkinCarePath,
        );
        await saveSetup(uid, migrated);
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
    await saveSetup(uid, initial);
    return initial;
  }

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup setup) async {
    setup.validateForOwner(uid);
    _setups[uid] = setup;
    _controllers[uid]?.add(setup);
  }

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) async* {
    yield _setups[uid];
    final controller = _controllers.putIfAbsent(
      uid,
      () => StreamController<BaseTimelineSetup?>.broadcast(),
    );
    yield* controller.stream;
  }

  /// Seeds in-memory setup directly without validation, useful for simulating legacy database documents.
  void seedSetup(BaseTimelineSetup setup) {
    _setups[setup.uid] = setup;
  }
}

/// Pure policy governing whether a Firestore document snapshot represents
/// canonical durable state for Base Timeline.
///
/// Local pending writes (latency-compensated local mutations before server ack)
/// MUST NOT be published as canonical Base Timeline state.
/// Normal committed cache snapshots (`isFromCache: true, hasPendingWrites: false`)
/// represent durable data previously written or synced, so they ARE accepted.
bool shouldPublishBaseTimelineSnapshot({
  required bool exists,
  required bool hasPendingWrites,
  bool isFromCache = false,
}) {
  if (!exists) return false;
  if (hasPendingWrites) return false;
  return true;
}

/// Pure policy governing whether a remote snapshot may update the canonical
/// state in [BaseTimelineSetupNotifier].
///
/// Invariants:
/// 1. A live stream snapshot must never move canonical frontend state backwards
///    (`remote.revision < current.revision -> false`).
/// 2. If `remote.revision == current.revision`:
///    - If remote has a higher schemaVersion (schema migration), accept it.
///    - If remote has equivalent content, accept it.
///    - If remote differs unexpectedly from a known committed in-memory state,
///      handle conservatively and do not regress in-memory state.
/// 3. If `remote.revision > current.revision`, accept it.
bool shouldPublishRemoteSetup({
  required BaseTimelineSetup? current,
  required BaseTimelineSetup remote,
}) {
  if (current == null) return true;
  if (remote.revision < current.revision) return false;
  if (remote.revision == current.revision) {
    if (remote.schemaVersion > current.schemaVersion) return true;
    if (current.schemaVersion > remote.schemaVersion) return false;
    if (_areBaseTimelineSetupsEquivalent(current, remote)) return true;
    // Differing data with same revision and schemaVersion: do not overwrite in-memory committed setup
    return false;
  }
  return true;
}

bool _areBaseTimelineSetupsEquivalent(
  BaseTimelineSetup a,
  BaseTimelineSetup b,
) {
  if (identical(a, b)) return true;
  if (a.uid != b.uid) return false;
  if (a.revision != b.revision) return false;
  if (a.schemaVersion != b.schemaVersion) return false;
  final mapA = a.toMap()..remove('updatedAt');
  final mapB = b.toMap()..remove('updatedAt');
  return _deepEqualsMaps(mapA, mapB);
}

bool _deepEqualsMaps(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    final valA = a[key];
    final valB = b[key];
    if (valA is Map && valB is Map) {
      if (!_deepEqualsMaps(
        Map<String, dynamic>.from(valA),
        Map<String, dynamic>.from(valB),
      )) {
        return false;
      }
    } else if (valA is List && valB is List) {
      if (!_deepEqualsLists(valA, valB)) return false;
    } else if (valA != valB) {
      return false;
    }
  }
  return true;
}

bool _deepEqualsLists(List a, List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final elemA = a[i];
    final elemB = b[i];
    if (elemA is Map && elemB is Map) {
      if (!_deepEqualsMaps(
        Map<String, dynamic>.from(elemA),
        Map<String, dynamic>.from(elemB),
      )) {
        return false;
      }
    } else if (elemA is List && elemB is List) {
      if (!_deepEqualsLists(elemA, elemB)) return false;
    } else if (elemA != elemB) {
      return false;
    }
  }
  return true;
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
      final rawSkinCarePath = data['skinCareSetupPath'] as String?;
      final hasLegacySkinCarePath =
          rawSkinCarePath == 'has_products' || rawSkinCarePath == 'no_products';
      final existing = BaseTimelineSetup.fromMap(data, uid: uid);
      if (existing.schemaVersion < BaseTimelineSetup.currentSchemaVersion ||
          hasLegacySkinCarePath) {
        final sourceResult = await _fetchOnboardingSource(uid, _onboardingRepo);
        if (sourceResult.readFailed) return existing;
        final migrated = migrateBaseTimelineSetupIfNeeded(
          existing: existing,
          onboardingSource: sourceResult.setup,
          hasLegacySkinCarePath: hasLegacySkinCarePath,
        );
        await saveSetup(uid, migrated);
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
    // A generated setup is canonical only after this durable write succeeds.
    await saveSetup(uid, setup);

    return setup;
  }

  @override
  Future<void> saveSetup(String uid, BaseTimelineSetup setup) async {
    setup.validateForOwner(uid);
    final docRef = _firestore.doc(FirestoreUserPaths.baseTimelineSetup(uid));
    await docRef.set(setup.toMap());
  }

  @override
  Stream<BaseTimelineSetup?> watchSetup(String uid) {
    return _firestore
        .doc(FirestoreUserPaths.baseTimelineSetup(uid))
        .snapshots(includeMetadataChanges: true)
        .where(
          (snap) => shouldPublishBaseTimelineSnapshot(
            exists: snap.exists,
            hasPendingWrites: snap.metadata.hasPendingWrites,
            isFromCache: snap.metadata.isFromCache,
          ),
        )
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
  StreamSubscription<BaseTimelineSetup?>? _watchSubscription;
  int _loadGeneration = 0;

  String get uid => _uid;

  BaseTimelineSetupNotifier(this._repository, this._uid)
    : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    if (_uid.trim().isEmpty) return;
    final generation = ++_loadGeneration;
    state = const AsyncValue.loading();
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    try {
      final setup = await _repository.fetchSetup(_uid);
      if (!mounted || generation != _loadGeneration) return;
      setup.validateForOwner(_uid);
      final current = state.valueOrNull;
      if (shouldPublishRemoteSetup(current: current, remote: setup)) {
        state = AsyncValue.data(setup);
      }
      _watchSubscription = _repository
          .watchSetup(_uid)
          .listen(
            (remote) {
              if (!mounted || generation != _loadGeneration || remote == null) {
                return;
              }
              try {
                remote.validateForOwner(_uid);
                final current = state.valueOrNull;
                if (!shouldPublishRemoteSetup(
                  current: current,
                  remote: remote,
                )) {
                  return;
                }
                state = AsyncValue.data(remote);
              } catch (error, stackTrace) {
                state = AsyncValue.error(error, stackTrace);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (mounted && generation == _loadGeneration) {
                state = AsyncValue.error(error, stackTrace);
              }
            },
          );
    } catch (e, st) {
      if (!mounted || generation != _loadGeneration) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(BaseTimelineSetup updated) async {
    updated.validateForOwner(_uid);
    await _repository.saveSetup(_uid, updated);
    if (mounted) state = AsyncValue.data(updated);
  }

  /// Publishes state already committed by the atomic Routine + Base Timeline
  /// transaction. Never use this for an uncommitted editor draft.
  void updateInMemory(BaseTimelineSetup updated) {
    updated.validateForOwner(_uid);
    state = AsyncValue.data(updated);
  }

  @override
  void dispose() {
    _loadGeneration++;
    _watchSubscription?.cancel();
    super.dispose();
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
  bool hasLegacySkinCarePath = false,
}) {
  final normalizedExisting = existing.normalizeSkinCareMode();
  final needsSkinCareRewrite =
      hasLegacySkinCarePath ||
      existing.skinCareSetupPath != normalizedExisting.skinCareSetupPath;

  if (existing.schemaVersion >= BaseTimelineSetup.currentSchemaVersion &&
      !needsSkinCareRewrite) {
    return existing;
  }

  var migrated = normalizedExisting.copyWith(
    schemaVersion: BaseTimelineSetup.currentSchemaVersion,
    revision: existing.schemaVersion < BaseTimelineSetup.currentSchemaVersion
        ? (existing.revision < 1 ? 1 : existing.revision)
        : existing.revision + 1,
    updatedAt: DateTime.now(),
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

  return migrated.normalizeSkinCareMode();
}
