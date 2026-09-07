import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/state/auth_generation.dart';
import 'skin_care_action_bridge.dart';
import 'skin_care_flow_state.dart';

/// Snapshot of reversible Plan A draft fields taken before entering edit mode.
@immutable
class PlanASnapshot {
  final String? ownerUid;
  final int authGeneration;
  final String? productNames;
  final List<SkinCareDetectedProduct> reviewedProducts;
  final String? skinType;
  final List<String> problems;
  final String? budget;
  final String? preference;
  final int desiredApplicationsPerDay;
  final List<String> specialCareNotes;
  final List<SkinCareProductRecommendationDraft> productRecommendations;
  final List<String> selectedProductNames;
  final List<String> suggestedProducts;
  final String? recommendationFingerprint;
  final String? routineFingerprint;
  final String? recommendationCountryCode;
  final String? recommendationCurrencyCode;

  const PlanASnapshot({
    this.ownerUid,
    this.authGeneration = 0,
    this.productNames,
    this.reviewedProducts = const [],
    this.skinType,
    this.problems = const [],
    this.budget,
    this.preference,
    this.desiredApplicationsPerDay = 2,
    this.specialCareNotes = const [],
    this.productRecommendations = const [],
    this.selectedProductNames = const [],
    this.suggestedProducts = const [],
    this.recommendationFingerprint,
    this.routineFingerprint,
    this.recommendationCountryCode,
    this.recommendationCurrencyCode,
  });

  factory PlanASnapshot.fromBaseTimeline(
    BaseTimelineDraft base, {
    String? ownerUid,
    int authGeneration = 0,
  }) {
    return PlanASnapshot(
      ownerUid: ownerUid,
      authGeneration: authGeneration,
      productNames: base.skinCareProductNames,
      reviewedProducts: List.unmodifiable(base.skinCareReviewedProducts),
      skinType: base.skinCareSkinType,
      problems: List.unmodifiable(base.skinCareProblems),
      budget: base.skinCareBudget,
      preference: base.skinCarePreference,
      desiredApplicationsPerDay: base.skinCareDesiredApplicationsPerDay,
      specialCareNotes: List.unmodifiable(base.skinCareSpecialCareNotes),
      productRecommendations: List.unmodifiable(
        base.skinCareProductRecommendations,
      ),
      selectedProductNames: List.unmodifiable(
        base.skinCareSelectedProductNames,
      ),
      suggestedProducts: List.unmodifiable(base.skinCareSuggestedProducts),
      recommendationFingerprint: base.skinCareRecommendationFingerprint,
      routineFingerprint: base.skinCareRoutineFingerprint,
      recommendationCountryCode: base.skinCareRecommendationCountryCode,
      recommendationCurrencyCode: base.skinCareRecommendationCurrencyCode,
    );
  }

  BaseTimelineDraft restoreOnto(BaseTimelineDraft base) {
    return base.copyWith(
      skinCareProductNames: productNames,
      clearSkinCareProductNames: productNames == null,
      skinCareReviewedProducts: reviewedProducts,
      clearSkinCareReviewedProducts: reviewedProducts.isEmpty,
      skinCareSkinType: skinType,
      clearSkinCareSkinType: skinType == null,
      skinCareProblems: problems,
      clearSkinCareProblems: problems.isEmpty,
      skinCareBudget: budget,
      clearSkinCareBudget: budget == null,
      skinCarePreference: preference,
      clearSkinCarePreference: preference == null,
      skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
      skinCareSpecialCareNotes: specialCareNotes,
      skinCareProductRecommendations: productRecommendations,
      clearSkinCareProductRecommendations: productRecommendations.isEmpty,
      skinCareSelectedProductNames: selectedProductNames,
      clearSkinCareSelectedProductNames: selectedProductNames.isEmpty,
      skinCareSuggestedProducts: suggestedProducts,
      clearSkinCareSuggestedProducts: suggestedProducts.isEmpty,
      skinCareRecommendationFingerprint: recommendationFingerprint,
      clearSkinCareRecommendationFingerprint: recommendationFingerprint == null,
      skinCareRoutineFingerprint: routineFingerprint,
      clearSkinCareRoutineFingerprint: routineFingerprint == null,
      skinCareRecommendationCountryCode: recommendationCountryCode,
      clearSkinCareRecommendationCountryCode: recommendationCountryCode == null,
      skinCareRecommendationCurrencyCode: recommendationCurrencyCode,
      clearSkinCareRecommendationCurrencyCode:
          recommendationCurrencyCode == null,
    );
  }
}

@immutable
class SkinCareFlowStateHolder {
  final SkinCareFlowState state;
  final int epoch;
  final String? activeError;
  final PlanASnapshot? planASnapshot;
  final SkinCareFlowState? generationOrigin;
  final String? ownerUid;
  final int authGeneration;

  const SkinCareFlowStateHolder({
    required this.state,
    required this.epoch,
    this.activeError,
    this.planASnapshot,
    this.generationOrigin,
    this.ownerUid,
    this.authGeneration = 0,
  });

  SkinCareFlowStateHolder copyWith({
    SkinCareFlowState? state,
    int? epoch,
    String? activeError,
    bool clearError = false,
    PlanASnapshot? planASnapshot,
    bool clearSnapshot = false,
    SkinCareFlowState? generationOrigin,
    bool clearGenerationOrigin = false,
    String? ownerUid,
    bool clearOwner = false,
    int? authGeneration,
  }) {
    return SkinCareFlowStateHolder(
      state: state ?? this.state,
      epoch: epoch ?? this.epoch,
      activeError: clearError ? null : (activeError ?? this.activeError),
      planASnapshot: clearSnapshot
          ? null
          : (planASnapshot ?? this.planASnapshot),
      generationOrigin: clearGenerationOrigin
          ? null
          : (generationOrigin ?? this.generationOrigin),
      ownerUid: clearOwner ? null : (ownerUid ?? this.ownerUid),
      authGeneration: authGeneration ?? this.authGeneration,
    );
  }
}

/// Coordinates explicit flow state, request epochs, Plan A snapshots,
/// and deterministic Back navigation for Step 7.
class SkinCareFlowController extends StateNotifier<SkinCareFlowStateHolder> {
  final Ref ref;

  SkinCareFlowController(this.ref)
    : super(
        const SkinCareFlowStateHolder(
          state: SkinCareFlowState.choice,
          epoch: 0,
        ),
      );

  /// Synchronizes current state from the durable draft.
  void syncFromDraft(
    BaseTimelineDraft base,
    String uid, {
    int authGeneration = 0,
  }) {
    final ownerChanged =
        state.ownerUid != null &&
        (state.ownerUid != uid || state.authGeneration != authGeneration);

    if (ownerChanged) {
      ref.read(step7ActionBridgeProvider.notifier).clearAll();
      final derived = deriveSkinCareFlowState(base, uid);
      state = SkinCareFlowStateHolder(
        state: derived,
        epoch: state.epoch + 1,
        ownerUid: uid,
        authGeneration: authGeneration,
      );
      return;
    }

    if (state.ownerUid == null) {
      state = state.copyWith(ownerUid: uid, authGeneration: authGeneration);
    }

    // If currently editing or generating for the same user & session, preserve state.
    if (state.state.isEditing || state.state.isGenerating) return;

    final derived = deriveSkinCareFlowState(base, uid);
    if (state.state != derived) {
      state = state.copyWith(
        state: derived,
        epoch: state.epoch + 1,
        ownerUid: uid,
        authGeneration: authGeneration,
        clearError: true,
      );
    }
  }

  /// Transition to an explicit flow state.
  void transitionTo(SkinCareFlowState nextState, {String? error}) {
    if (state.state == nextState && state.activeError == error) return;
    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      activeError: error,
      clearError: error == null,
    );
  }

  /// Begins editing an existing retained routine (Plan A).
  void startEditing(BaseTimelineDraft base) {
    final authState = ref.read(authProvider);
    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = authState.user?.uid ?? draft.uid;
    final authGen = ref.read(authGenerationProvider);

    final nextState = base.skinCareSetupPath == 'no_products'
        ? SkinCareFlowState.noProductsEditing
        : SkinCareFlowState.hasProductsEditing;
    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      ownerUid: uid,
      authGeneration: authGen,
      planASnapshot: PlanASnapshot.fromBaseTimeline(
        base,
        ownerUid: uid,
        authGeneration: authGen,
      ),
      clearError: true,
    );
  }

  /// Begins generation and bumps epoch.
  void startGeneration(SkinCareFlowState generatingState) {
    final authState = ref.read(authProvider);
    final draft = ref.read(mockOnboardingProvider).draft;
    final uid = authState.user?.uid ?? draft.uid;
    final authGen = ref.read(authGenerationProvider);

    state = state.copyWith(
      state: generatingState,
      epoch: state.epoch + 1,
      ownerUid: uid,
      authGeneration: authGen,
      generationOrigin: state.state.isGenerating
          ? state.generationOrigin
          : state.state,
      clearError: true,
    );
  }

  /// Completes an active generation operation based on origin and operation type.
  ///
  /// For rebuild/edit intermediate generations (finding products, photo analysis),
  /// keeps the editor open ([noProductsEditing] or [hasProductsEditing]) with new
  /// data available, preserving the Plan A snapshot.
  ///
  /// For routine generation commits ([isRoutineCommit] == true), atomically replaces
  /// the routine, returns to review ([hasProductsReview] or [noProductsReview]),
  /// and clears the Plan A snapshot.
  void completeGeneration({
    bool isRoutineCommit = false,
    BaseTimelineDraft? updatedBase,
  }) {
    final origin = state.generationOrigin;
    SkinCareFlowState nextState;

    if (isRoutineCommit) {
      nextState =
          (updatedBase?.skinCareSetupPath == 'no_products' ||
              state.state.isNoProducts)
          ? SkinCareFlowState.noProductsReview
          : SkinCareFlowState.hasProductsReview;

      state = state.copyWith(
        state: nextState,
        epoch: state.epoch + 1,
        clearSnapshot: true,
        clearGenerationOrigin: true,
        clearError: true,
      );
      ref.read(step7ActionBridgeProvider.notifier).clearAll();
      return;
    }

    // Intermediate generation success (finding products or photo analysis)
    if (origin == SkinCareFlowState.noProductsEditing) {
      nextState = SkinCareFlowState.noProductsEditing;
    } else if (origin == SkinCareFlowState.hasProductsEditing) {
      nextState = SkinCareFlowState.hasProductsEditing;
    } else if (state.state == SkinCareFlowState.noProductsFindingProducts) {
      nextState = SkinCareFlowState.noProductsProductSelection;
    } else if (state.state == SkinCareFlowState.hasProductsGenerating) {
      nextState = SkinCareFlowState.hasProductsInput;
    } else {
      nextState = origin ?? state.state;
    }

    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      clearGenerationOrigin: true,
      clearError: true,
    );
  }

  /// Handles generation failure by returning to origin and recording error.
  void failGeneration(String error) {
    final origin = state.generationOrigin;
    final fallback = switch (state.state) {
      SkinCareFlowState.hasProductsGenerating =>
        (state.planASnapshot != null)
            ? SkinCareFlowState.hasProductsEditing
            : SkinCareFlowState.hasProductsInput,
      SkinCareFlowState.noProductsFindingProducts =>
        SkinCareFlowState.noProductsInput,
      SkinCareFlowState.noProductsGeneratingRoutine =>
        (state.planASnapshot != null)
            ? SkinCareFlowState.noProductsEditing
            : SkinCareFlowState.noProductsProductSelection,
      _ => state.state,
    };
    final nextState = origin ?? fallback;
    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      activeError: error,
      clearGenerationOrigin: true,
    );
  }

  void _updateBase(BaseTimelineDraft Function(BaseTimelineDraft base) update) {
    ref
        .read(mockOnboardingProvider.notifier)
        .updateDraft(
          (draft) => draft.copyWith(
            baseTimeline: update(draft.baseTimeline),
            clearFinalPreview: true,
          ),
        );
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepDirty(onboardingSkinCareStepIndex, true);
  }

  /// Cancels editing and restores Plan A snapshot onto the draft if session is valid.
  void cancelEditing() {
    final currentDraft = ref.read(mockOnboardingProvider).draft;
    final authState = ref.read(authProvider);
    final currentUid = authState.user?.uid ?? currentDraft.uid;
    final currentAuthGen = ref.read(authGenerationProvider);

    final snapshot = state.planASnapshot;
    final canRestore =
        snapshot != null &&
        (snapshot.ownerUid == null || snapshot.ownerUid == currentUid) &&
        (snapshot.authGeneration == currentAuthGen) &&
        (state.ownerUid == null || state.ownerUid == currentUid) &&
        (state.authGeneration == currentAuthGen);

    if (canRestore) {
      _updateBase((base) => snapshot.restoreOnto(base));
      final nextState = state.state == SkinCareFlowState.noProductsEditing
          ? SkinCareFlowState.noProductsReview
          : SkinCareFlowState.hasProductsReview;
      state = state.copyWith(
        state: nextState,
        epoch: state.epoch + 1,
        clearSnapshot: true,
        clearGenerationOrigin: true,
        clearError: true,
      );
    } else {
      // Discard mismatched/stale snapshot without applying to new user/session
      ref.read(step7ActionBridgeProvider.notifier).clearAll();
      final derived = deriveSkinCareFlowState(
        currentDraft.baseTimeline,
        currentUid,
      );
      state = SkinCareFlowStateHolder(
        state: derived,
        epoch: state.epoch + 1,
        ownerUid: currentUid,
        authGeneration: currentAuthGen,
      );
    }

    // Clear any custom footer action so shell regains Next Step ownership.
    ref.read(step7ActionBridgeProvider.notifier).clearAll();
  }

  /// Commits successful Plan B rebuild and returns to review.
  void commitRebuildSuccess(BaseTimelineDraft updatedBase) {
    completeGeneration(isRoutineCommit: true, updatedBase: updatedBase);
  }

  /// Current epoch of the flow controller.
  int get currentEpoch => state.epoch;

  /// Current flow state.
  SkinCareFlowState get currentFlowState => state.state;

  /// True if Step 7 can handle an internal Back button press.
  bool get canHandleBack {
    return state.state != SkinCareFlowState.choice;
  }

  /// Handles internal Back button deterministically.
  /// Returns true if handled internally, or false if the shell should handle it.
  bool handleBack() {
    switch (state.state) {
      case SkinCareFlowState.choice:
        return false;

      case SkinCareFlowState.hasProductsEditing:
      case SkinCareFlowState.noProductsEditing:
        cancelEditing();
        return true;

      case SkinCareFlowState.hasProductsReview:
      case SkinCareFlowState.noProductsReview:
        // Transition back to choice, preserving Plan A blocks.
        _updateBase((base) => base.copyWith(skinCareSetupStep: 0));
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        transitionTo(SkinCareFlowState.choice);
        return true;

      case SkinCareFlowState.noProductsProductSelection:
        // Back from product recommendations goes back to skin details form.
        transitionTo(SkinCareFlowState.noProductsInput);
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        return true;

      case SkinCareFlowState.hasProductsPhotoReview:
        transitionTo(SkinCareFlowState.hasProductsInput);
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        return true;

      case SkinCareFlowState.hasProductsInput:
      case SkinCareFlowState.noProductsInput:
        _updateBase((base) => base.copyWith(skinCareSetupStep: 0));
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        transitionTo(SkinCareFlowState.choice);
        return true;

      case SkinCareFlowState.skipped:
        _updateBase(
          (base) => base.copyWith(
            skinCareSetupStep: 0,
            skinCareSkipped: false,
            clearSkinCareSetupPath: true,
          ),
        );
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        transitionTo(SkinCareFlowState.choice);
        return true;

      case SkinCareFlowState.hasProductsGenerating:
      case SkinCareFlowState.noProductsFindingProducts:
      case SkinCareFlowState.noProductsGeneratingRoutine:
        final origin = state.generationOrigin;
        final fallback = state.state == SkinCareFlowState.hasProductsGenerating
            ? ((state.planASnapshot != null)
                  ? SkinCareFlowState.hasProductsEditing
                  : SkinCareFlowState.hasProductsInput)
            : ((state.planASnapshot != null)
                  ? SkinCareFlowState.noProductsEditing
                  : SkinCareFlowState.noProductsInput);
        final target = origin ?? fallback;
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        state = state.copyWith(
          state: target,
          epoch: state.epoch + 1,
          clearGenerationOrigin: true,
          clearError: true,
        );
        return true;
    }
  }
}

final skinCareFlowControllerProvider =
    StateNotifierProvider<SkinCareFlowController, SkinCareFlowStateHolder>((
      ref,
    ) {
      final controller = SkinCareFlowController(ref);

      ref.listen(mockOnboardingProvider, (previous, next) {
        final authState = ref.read(authProvider);
        final authGen = ref.read(authGenerationProvider);
        controller.syncFromDraft(
          next.draft.baseTimeline,
          authState.user?.uid ?? next.draft.uid,
          authGeneration: authGen,
        );
      });

      ref.listen(authGenerationProvider, (previous, next) {
        final authState = ref.read(authProvider);
        final draft = ref.read(mockOnboardingProvider).draft;
        controller.syncFromDraft(
          draft.baseTimeline,
          authState.user?.uid ?? draft.uid,
          authGeneration: next,
        );
      });

      ref.listen(authProvider, (previous, next) {
        final authGen = ref.read(authGenerationProvider);
        final draft = ref.read(mockOnboardingProvider).draft;
        controller.syncFromDraft(
          draft.baseTimeline,
          next.user?.uid ?? draft.uid,
          authGeneration: authGen,
        );
      });

      final initialDraft = ref.read(mockOnboardingProvider).draft;
      final authState = ref.read(authProvider);
      final initialAuthGen = ref.read(authGenerationProvider);
      controller.syncFromDraft(
        initialDraft.baseTimeline,
        authState.user?.uid ?? initialDraft.uid,
        authGeneration: initialAuthGen,
      );

      return controller;
    });
