import 'package:optivus/models/onboarding_draft.dart';

/// Explicit deterministic UI states for Onboarding Step 7 (Skin Care).
enum SkinCareFlowState {
  choice,
  hasProductsInput,
  hasProductsPhotoReview,
  hasProductsGenerating,
  hasProductsReview,
  hasProductsEditing,
  noProductsInput,
  noProductsFindingProducts,
  noProductsProductSelection,
  noProductsGeneratingRoutine,
  noProductsReview,
  noProductsEditing,
  skipped;

  bool get isReview =>
      this == SkinCareFlowState.hasProductsReview ||
      this == SkinCareFlowState.noProductsReview;

  bool get isEditing =>
      this == SkinCareFlowState.hasProductsEditing ||
      this == SkinCareFlowState.noProductsEditing;

  bool get isGenerating =>
      this == SkinCareFlowState.hasProductsGenerating ||
      this == SkinCareFlowState.noProductsFindingProducts ||
      this == SkinCareFlowState.noProductsGeneratingRoutine;

  bool get isHasProducts =>
      this == SkinCareFlowState.hasProductsInput ||
      this == SkinCareFlowState.hasProductsPhotoReview ||
      this == SkinCareFlowState.hasProductsGenerating ||
      this == SkinCareFlowState.hasProductsReview ||
      this == SkinCareFlowState.hasProductsEditing;

  bool get isNoProducts =>
      this == SkinCareFlowState.noProductsInput ||
      this == SkinCareFlowState.noProductsFindingProducts ||
      this == SkinCareFlowState.noProductsProductSelection ||
      this == SkinCareFlowState.noProductsGeneratingRoutine ||
      this == SkinCareFlowState.noProductsReview ||
      this == SkinCareFlowState.noProductsEditing;
}

/// Pure state derivation function that deterministically reconstructs the
/// appropriate [SkinCareFlowState] from persisted [BaseTimelineDraft].
SkinCareFlowState deriveSkinCareFlowState(BaseTimelineDraft base, String uid) {
  if (base.skinCareSkipped || base.skinCareSetupPath == 'skip') {
    return SkinCareFlowState.skipped;
  }

  if (base.skinCareSetupStep <= 0 ||
      (base.skinCareSetupPath != 'has_products' &&
          base.skinCareSetupPath != 'no_products')) {
    return SkinCareFlowState.choice;
  }

  final hasRoutineBlocks = base.blocks.any((b) => b.section == 'skin_care');

  if (base.skinCareSetupPath == 'has_products') {
    if (hasRoutineBlocks) {
      return SkinCareFlowState.hasProductsReview;
    }
    final hasPhoto =
        base.skinCareProductPhotoAssetId != null &&
        base.skinCareProductPhotoAssetId!.trim().isNotEmpty;
    final needsLabelReview = hasPhoto && base.skinCareReviewedProducts.isEmpty;
    if (needsLabelReview) {
      return SkinCareFlowState.hasProductsPhotoReview;
    }
    return SkinCareFlowState.hasProductsInput;
  }

  if (base.skinCareSetupPath == 'no_products') {
    if (hasRoutineBlocks) {
      return SkinCareFlowState.noProductsReview;
    }
    final hasCurrentRecs =
        base.skinCareProductRecommendations.isNotEmpty &&
        base.skinCareRecommendationFingerprint != null &&
        base.skinCareRecommendationFingerprint ==
            base.computeSkinCareRecommendationFingerprint();
    if (hasCurrentRecs) {
      return SkinCareFlowState.noProductsProductSelection;
    }
    return SkinCareFlowState.noProductsInput;
  }

  return SkinCareFlowState.choice;
}
