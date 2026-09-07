import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'skin_care_action_bridge.dart';
import 'skin_care_flow_state.dart';

/// Snapshot of reversible Plan A draft fields taken before entering edit mode.
@immutable
class PlanASnapshot {
  final String? productNames;
  final List<SkinCareDetectedProduct> reviewedProducts;
  final String? skinType;
  final List<String> problems;
  final String? budget;
  final String? preference;
  final int desiredApplicationsPerDay;
  final List<String> selectedProductNames;
  final List<SkinCareProductRecommendationDraft> productRecommendations;
  final String? recommendationFingerprint;
  final String? routineFingerprint;

  const PlanASnapshot({
    this.productNames,
    this.reviewedProducts = const [],
    this.skinType,
    this.problems = const [],
    this.budget,
    this.preference,
    this.desiredApplicationsPerDay = 2,
    this.selectedProductNames = const [],
    this.productRecommendations = const [],
    this.recommendationFingerprint,
    this.routineFingerprint,
  });

  factory PlanASnapshot.fromBaseTimeline(BaseTimelineDraft base) {
    return PlanASnapshot(
      productNames: base.skinCareProductNames,
      reviewedProducts: List.unmodifiable(base.skinCareReviewedProducts),
      skinType: base.skinCareSkinType,
      problems: List.unmodifiable(base.skinCareProblems),
      budget: base.skinCareBudget,
      preference: base.skinCarePreference,
      desiredApplicationsPerDay: base.skinCareDesiredApplicationsPerDay,
      selectedProductNames: List.unmodifiable(
        base.skinCareSelectedProductNames,
      ),
      productRecommendations: List.unmodifiable(
        base.skinCareProductRecommendations,
      ),
      recommendationFingerprint: base.skinCareRecommendationFingerprint,
      routineFingerprint: base.skinCareRoutineFingerprint,
    );
  }

  BaseTimelineDraft restoreOnto(BaseTimelineDraft base) {
    return base.copyWith(
      skinCareProductNames: productNames,
      skinCareReviewedProducts: reviewedProducts,
      skinCareSkinType: skinType,
      skinCareProblems: problems,
      skinCareBudget: budget,
      skinCarePreference: preference,
      skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
      skinCareSelectedProductNames: selectedProductNames,
      skinCareProductRecommendations: productRecommendations,
      skinCareRecommendationFingerprint: recommendationFingerprint,
      skinCareRoutineFingerprint: routineFingerprint,
    );
  }
}

@immutable
class SkinCareFlowStateHolder {
  final SkinCareFlowState state;
  final int epoch;
  final String? activeError;
  final PlanASnapshot? planASnapshot;

  const SkinCareFlowStateHolder({
    required this.state,
    required this.epoch,
    this.activeError,
    this.planASnapshot,
  });

  SkinCareFlowStateHolder copyWith({
    SkinCareFlowState? state,
    int? epoch,
    String? activeError,
    bool clearError = false,
    PlanASnapshot? planASnapshot,
    bool clearSnapshot = false,
  }) {
    return SkinCareFlowStateHolder(
      state: state ?? this.state,
      epoch: epoch ?? this.epoch,
      activeError: clearError ? null : (activeError ?? this.activeError),
      planASnapshot: clearSnapshot
          ? null
          : (planASnapshot ?? this.planASnapshot),
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
  void syncFromDraft(BaseTimelineDraft base, String uid) {
    // If currently editing, preserve the edit state and snapshot.
    if (state.state.isEditing) return;

    final derived = deriveSkinCareFlowState(base, uid);
    if (state.state != derived) {
      state = state.copyWith(
        state: derived,
        epoch: state.epoch + 1,
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
    final nextState = base.skinCareSetupPath == 'no_products'
        ? SkinCareFlowState.noProductsEditing
        : SkinCareFlowState.hasProductsEditing;
    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      planASnapshot: PlanASnapshot.fromBaseTimeline(base),
      clearError: true,
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

  /// Cancels editing and returns to review mode.
  void cancelEditing() {
    final nextState = state.state == SkinCareFlowState.noProductsEditing
        ? SkinCareFlowState.noProductsReview
        : SkinCareFlowState.hasProductsReview;

    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      clearSnapshot: true,
      clearError: true,
    );

    // Clear any custom footer action so shell regains Next Step ownership.
    ref.read(step7ActionBridgeProvider.notifier).clearAll();
  }

  /// Commits successful Plan B rebuild and returns to review.
  void commitRebuildSuccess(BaseTimelineDraft updatedBase) {
    final nextState = updatedBase.skinCareSetupPath == 'no_products'
        ? SkinCareFlowState.noProductsReview
        : SkinCareFlowState.hasProductsReview;

    state = state.copyWith(
      state: nextState,
      epoch: state.epoch + 1,
      clearSnapshot: true,
      clearError: true,
    );

    ref.read(step7ActionBridgeProvider.notifier).clearAll();
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
      case SkinCareFlowState.skipped:
        _updateBase((base) => base.copyWith(skinCareSetupStep: 0));
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        transitionTo(SkinCareFlowState.choice);
        return true;

      case SkinCareFlowState.hasProductsGenerating:
      case SkinCareFlowState.noProductsFindingProducts:
      case SkinCareFlowState.noProductsGeneratingRoutine:
        // Cancel operation by bumping epoch; return to previous input state.
        final target = state.state == SkinCareFlowState.hasProductsGenerating
            ? SkinCareFlowState.hasProductsInput
            : SkinCareFlowState.noProductsInput;
        ref.read(step7ActionBridgeProvider.notifier).clearAll();
        transitionTo(target);
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
        controller.syncFromDraft(
          next.draft.baseTimeline,
          authState.user?.uid ?? next.draft.uid,
        );
      });
      final initialDraft = ref.read(mockOnboardingProvider).draft;
      final authState = ref.read(authProvider);
      controller.syncFromDraft(
        initialDraft.baseTimeline,
        authState.user?.uid ?? initialDraft.uid,
      );
      return controller;
    });
