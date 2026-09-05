import 'dart:math';

import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/upload_source_identity.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/upload_state.dart';

/// Auditable result of reconciling a reconstructed [OnboardingDraft] against
/// the successfully hydrated [RestoredUploadsState] for a given owner UID.
class OnboardingUploadSourceReconciliationResult {
  final OnboardingDraft reconciledDraft;
  final bool changed;
  final int? earliestAffectedStep;
  final List<String> reasonCodes;
  final bool integrityFailure;

  const OnboardingUploadSourceReconciliationResult({
    required this.reconciledDraft,
    required this.changed,
    this.earliestAffectedStep,
    this.reasonCodes = const [],
    this.integrityFailure = false,
  });
}

/// Pure, deterministic service that reconciles an onboarding draft against
/// durable restored upload metadata.
///
/// This service performs no network I/O, widget access, or async mutations.
/// Its sole responsibility is verifying that photo-backed timeline blocks and
/// pending imports match current durable uploaded assets.
class OnboardingUploadSourceReconciler {
  const OnboardingUploadSourceReconciler();

  static OnboardingUploadSourceReconciliationResult reconcile({
    required String ownerUid,
    required OnboardingDraft draft,
    required RestoredUploadsState restoredUploads,
  }) {
    if (ownerUid.trim().isEmpty) {
      return OnboardingUploadSourceReconciliationResult(
        reconciledDraft: draft,
        changed: false,
        reasonCodes: const ['empty_owner_uid'],
        integrityFailure: true,
      );
    }

    if (draft.uid.trim().isNotEmpty && draft.uid != ownerUid) {
      return OnboardingUploadSourceReconciliationResult(
        reconciledDraft: draft,
        changed: false,
        reasonCodes: const ['draft_owner_mismatch'],
        integrityFailure: true,
      );
    }

    if (restoredUploads.uid != null &&
        restoredUploads.uid!.trim().isNotEmpty &&
        restoredUploads.uid != ownerUid) {
      return OnboardingUploadSourceReconciliationResult(
        reconciledDraft: draft,
        changed: false,
        reasonCodes: const ['restored_uploads_owner_mismatch'],
        integrityFailure: true,
      );
    }

    UploadedAsset? getValidDurableAsset(UploadedAssetPurpose purpose) {
      final restored = restoredUploads.forPurpose(purpose);
      if (restored == null) return null;
      final asset = restored.asset;
      if (uploadedAssetIsDurablyUploadedForSlot(
        asset: asset,
        uid: ownerUid,
        purpose: purpose,
      )) {
        return asset;
      }
      return null;
    }

    final currentClassAsset = getValidDurableAsset(
      UploadedAssetPurpose.classTimetable,
    );
    final currentWorkAsset = getValidDurableAsset(
      UploadedAssetPurpose.workSchedule,
    );
    final currentEatingAsset = getValidDurableAsset(
      UploadedAssetPurpose.eatingMenu,
    );

    final reasonCodes = <String>[];
    var step4Affected = false;
    var step5Affected = false;

    final lifeRoleKey = draft.lifeRole.lifeRole;
    final classesRequired =
        lifeRoleKey == LifeRoleDraft.studentKey ||
        lifeRoleKey == LifeRoleDraft.studentWorkingKey;
    final workRequired =
        lifeRoleKey == LifeRoleDraft.workingKey ||
        lifeRoleKey == LifeRoleDraft.studentWorkingKey ||
        lifeRoleKey == LifeRoleDraft.businessKey;

    var currentBaseTimeline = draft.baseTimeline;
    var currentBlocks = List<TimelineBlockDraft>.from(
      currentBaseTimeline.blocks,
    );
    var currentImports = List<PendingFutureImportDraft>.from(
      currentBaseTimeline.pendingFutureImports,
    );

    final hasPhotoBackedStep4Or5Or7State =
        (classesRequired &&
            (currentBlocks.any(
                  (b) => b.section == 'classes' && b.source == 'ai_import',
                ) ||
                (currentBaseTimeline.classLogicalAssetId != null &&
                    currentBaseTimeline.classLogicalAssetId!
                        .trim()
                        .isNotEmpty))) ||
        (workRequired &&
            (currentBlocks.any(
                  (b) =>
                      b.section == 'job_work_business' &&
                      b.source == 'ai_import',
                ) ||
                (currentBaseTimeline.workLogicalAssetId != null &&
                    currentBaseTimeline.workLogicalAssetId!
                        .trim()
                        .isNotEmpty))) ||
        (currentBaseTimeline.eatingSetupPath == 'has_routine' &&
            (currentBlocks.any(
                  (b) => b.section == 'eating' && b.source == 'ai_import',
                ) ||
                currentBaseTimeline.latestImportForSection('Eating') !=
                    null)) ||
        (currentBaseTimeline.skinCareSetupPath == 'has_products' &&
            currentBaseTimeline.skinCareProductPhotoAssetId
                    ?.trim()
                    .isNotEmpty ==
                true) ||
        (currentBaseTimeline.skinCareSetupPath == 'no_products' &&
            currentBaseTimeline.skinCareFacePhotoAssetId?.trim().isNotEmpty ==
                true);

    if (restoredUploads.errorMessage != null &&
        restoredUploads.errorMessage!.trim().isNotEmpty &&
        hasPhotoBackedStep4Or5Or7State) {
      return OnboardingUploadSourceReconciliationResult(
        reconciledDraft: draft,
        changed: false,
        reasonCodes: const ['restored_uploads_error'],
        integrityFailure: true,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 4 RECONCILIATION: Classes & Work
    // -------------------------------------------------------------------------
    if (classesRequired) {
      final classLogicalId = currentBaseTimeline.classLogicalAssetId;
      final classLogicalKey = currentBaseTimeline.classLogicalAssetR2Key;

      final hasClassAiBlocks = currentBlocks.any(
        (b) => b.section == 'classes' && b.source == 'ai_import',
      );
      final matchingClassAsset = [currentClassAsset, currentWorkAsset]
          .whereType<UploadedAsset>()
          .where(
            (asset) => uploadedSourceIdentityMatches(
              assetId: classLogicalId,
              r2Key: classLogicalKey,
              asset: asset,
            ),
          )
          .firstOrNull;
      final classBlocksMatch =
          !hasClassAiBlocks ||
          currentBlocks
              .where((b) => b.section == 'classes' && b.source == 'ai_import')
              .every(
                (block) => provenanceContainsExactUploadIdentity(
                  block.provenanceSourceIds,
                  matchingClassAsset?.assetId,
                  matchingClassAsset?.r2Key,
                ),
              );
      final isClassLogicalSourceCurrent =
          matchingClassAsset != null && classBlocksMatch;

      if (!isClassLogicalSourceCurrent &&
          (hasClassAiBlocks ||
              (classLogicalId != null && classLogicalId.trim().isNotEmpty))) {
        step4Affected = true;
        reasonCodes.add('step4_class_source_stale');

        currentBlocks.removeWhere(
          (b) => b.section == 'classes' && b.source == 'ai_import',
        );

        currentImports.removeWhere(
          (entry) =>
              entry.section == 'Classes' || entry.section == 'Class Timetable',
        );

        // Preserve logical mapping intent if ancestry can be determined safely.
        final wasSwappedToWorkSlot =
            classLogicalKey != null &&
            classLogicalKey.contains('/work_schedule/');
        if (wasSwappedToWorkSlot && currentWorkAsset != null) {
          currentBaseTimeline = currentBaseTimeline.copyWith(
            classLogicalAssetId: currentWorkAsset.assetId,
            classLogicalAssetR2Key: currentWorkAsset.r2Key,
          );
        } else if (!wasSwappedToWorkSlot && currentClassAsset != null) {
          currentBaseTimeline = currentBaseTimeline.copyWith(
            classLogicalAssetId: currentClassAsset.assetId,
            classLogicalAssetR2Key: currentClassAsset.r2Key,
          );
        } else {
          currentBaseTimeline = currentBaseTimeline.copyWith(
            clearClassLogicalAsset: true,
          );
        }
      }
    }

    if (workRequired) {
      final workLogicalId = currentBaseTimeline.workLogicalAssetId;
      final workLogicalKey = currentBaseTimeline.workLogicalAssetR2Key;

      final hasWorkAiBlocks = currentBlocks.any(
        (b) => b.section == 'job_work_business' && b.source == 'ai_import',
      );
      final matchingWorkAsset = [currentWorkAsset, currentClassAsset]
          .whereType<UploadedAsset>()
          .where(
            (asset) => uploadedSourceIdentityMatches(
              assetId: workLogicalId,
              r2Key: workLogicalKey,
              asset: asset,
            ),
          )
          .firstOrNull;
      final workBlocksMatch =
          !hasWorkAiBlocks ||
          currentBlocks
              .where(
                (b) =>
                    b.section == 'job_work_business' && b.source == 'ai_import',
              )
              .every(
                (block) => provenanceContainsExactUploadIdentity(
                  block.provenanceSourceIds,
                  matchingWorkAsset?.assetId,
                  matchingWorkAsset?.r2Key,
                ),
              );
      final isWorkLogicalSourceCurrent =
          matchingWorkAsset != null && workBlocksMatch;

      if (!isWorkLogicalSourceCurrent &&
          (hasWorkAiBlocks ||
              (workLogicalId != null && workLogicalId.trim().isNotEmpty))) {
        step4Affected = true;
        reasonCodes.add('step4_work_source_stale');

        currentBlocks.removeWhere(
          (b) => b.section == 'job_work_business' && b.source == 'ai_import',
        );

        currentImports.removeWhere(
          (entry) =>
              entry.section == 'Work' ||
              entry.section == 'Work Schedule' ||
              entry.section == 'Job / Work / Business',
        );

        final wasSwappedToClassSlot =
            workLogicalKey != null &&
            workLogicalKey.contains('/class_timetable/');
        if (wasSwappedToClassSlot && currentClassAsset != null) {
          currentBaseTimeline = currentBaseTimeline.copyWith(
            workLogicalAssetId: currentClassAsset.assetId,
            workLogicalAssetR2Key: currentClassAsset.r2Key,
          );
        } else if (!wasSwappedToClassSlot && currentWorkAsset != null) {
          currentBaseTimeline = currentBaseTimeline.copyWith(
            workLogicalAssetId: currentWorkAsset.assetId,
            workLogicalAssetR2Key: currentWorkAsset.r2Key,
          );
        } else {
          currentBaseTimeline = currentBaseTimeline.copyWith(
            clearWorkLogicalAsset: true,
          );
        }
      }
    }

    // -------------------------------------------------------------------------
    // STEP 5 RECONCILIATION: Eating Setup (has_routine path)
    // -------------------------------------------------------------------------
    if (currentBaseTimeline.eatingSetupPath == 'has_routine') {
      final eatingImport = currentBaseTimeline.latestImportForSection('Eating');
      final eatingAiBlocks = currentBlocks.where(
        (b) => b.section == 'eating' && b.source == 'ai_import',
      );

      final hasCurrentEatingAsset = currentEatingAsset != null;
      final importMatchesCurrentAsset =
          hasCurrentEatingAsset &&
          eatingImport != null &&
          uploadedSourceIdentityMatches(
            assetId: eatingImport.uploadedAssetId,
            r2Key: eatingImport.uploadedAssetR2Key,
            asset: currentEatingAsset,
          );

      bool allEatingBlocksMatchCurrentAsset = true;
      if (eatingAiBlocks.isNotEmpty) {
        if (!hasCurrentEatingAsset) {
          allEatingBlocksMatchCurrentAsset = false;
        } else {
          for (final block in eatingAiBlocks) {
            final provenance = block.provenanceSourceIds;
            if (!provenanceContainsExactUploadIdentity(
              provenance,
              currentEatingAsset.assetId,
              currentEatingAsset.r2Key,
            )) {
              allEatingBlocksMatchCurrentAsset = false;
              break;
            }
          }
        }
      }

      final eatingSetupIsCurrent =
          importMatchesCurrentAsset && allEatingBlocksMatchCurrentAsset;

      if (!eatingSetupIsCurrent &&
          (eatingAiBlocks.isNotEmpty || eatingImport != null)) {
        step5Affected = true;
        reasonCodes.add('step5_eating_source_stale');

        currentBlocks.removeWhere(
          (b) => b.section == 'eating' && b.source == 'ai_import',
        );

        currentImports.removeWhere((entry) => entry.section == 'Eating');

        // The durable upload is tracked by RestoredUploadsState. A photo import
        // is only created after AI extraction actually succeeds for that asset.
      }
    }

    // -------------------------------------------------------------------------
    // STEP 7 RECONCILIATION: Skin Care Setup
    // -------------------------------------------------------------------------
    var step7Affected = false;
    var currentSkinProductsAsset = getValidDurableAsset(
      UploadedAssetPurpose.skinProducts,
    );
    var currentSkinFaceAsset = getValidDurableAsset(
      UploadedAssetPurpose.skinFace,
    );

    // Legacy objects only satisfy an established, exactly matching active slot.
    // Modern generations always win; a legacy object is never adopted anew.
    final legacy = restoredUploads
        .forPurpose(UploadedAssetPurpose.skinCare)
        ?.asset;
    if (legacy != null &&
        legacySkinCareUploadHasOwnedExactIdentity(
          assetId: legacy.assetId,
          ownerUid: legacy.ownerUid,
          r2Key: legacy.r2Key,
          status: legacy.status,
          uid: ownerUid,
        )) {
      if (currentBaseTimeline.skinCareSetupPath == 'has_products' &&
          uploadedSourceIdentityMatches(
            assetId: currentBaseTimeline.skinCareProductPhotoAssetId,
            r2Key: currentBaseTimeline.skinCareProductPhotoR2Key,
            asset: legacy,
          )) {
        currentSkinProductsAsset ??= legacy;
      } else if (currentBaseTimeline.skinCareSetupPath == 'no_products' &&
          uploadedSourceIdentityMatches(
            assetId: currentBaseTimeline.skinCareFacePhotoAssetId,
            r2Key: currentBaseTimeline.skinCareFacePhotoR2Key,
            asset: legacy,
          )) {
        currentSkinFaceAsset ??= legacy;
      }
    }

    if (currentBaseTimeline.skinCareSetupPath == 'has_products') {
      final productAssetId = currentBaseTimeline.skinCareProductPhotoAssetId;
      final productR2Key = currentBaseTimeline.skinCareProductPhotoR2Key;
      final hasPhotoUsed =
          productAssetId?.trim().isNotEmpty == true ||
          productR2Key?.trim().isNotEmpty == true;

      if (hasPhotoUsed || currentSkinProductsAsset != null) {
        final matchesRestored =
            currentSkinProductsAsset != null &&
            uploadedSourceIdentityMatches(
              assetId: productAssetId,
              r2Key: productR2Key,
              asset: currentSkinProductsAsset,
            );
        if (!matchesRestored) {
          step7Affected = true;
          reasonCodes.add('step7_product_source_stale');
          currentBlocks.removeWhere((b) => b.section == 'skin_care');
          currentBaseTimeline = currentBaseTimeline.copyWith(
            skinCareProductPhotoAssetId: currentSkinProductsAsset?.assetId,
            skinCareProductPhotoR2Key: currentSkinProductsAsset?.r2Key,
            skinCareProductPhotoStatus:
                currentSkinProductsAsset?.status.wireName,
            skinCareProductPhotoCreatedAt: currentSkinProductsAsset?.createdAt,
            skinCareProductPhotoUpdatedAt: currentSkinProductsAsset?.updatedAt,
            clearSkinCareProductPhoto: currentSkinProductsAsset == null,
            clearSkinCareReviewedProducts: true,
            clearSkinCareSuggestedProducts: true,
            skinCareSpecialCareNotes: const [],
            clearSkinCareRoutineFingerprint: true,
          );
        }
      }
    } else if (currentBaseTimeline.skinCareSetupPath == 'no_products') {
      final faceAssetId = currentBaseTimeline.skinCareFacePhotoAssetId;
      final faceR2Key = currentBaseTimeline.skinCareFacePhotoR2Key;
      final hasFacePhotoUsed =
          faceAssetId?.trim().isNotEmpty == true ||
          faceR2Key?.trim().isNotEmpty == true;

      if (hasFacePhotoUsed || currentSkinFaceAsset != null) {
        final matchesRestored =
            currentSkinFaceAsset != null &&
            uploadedSourceIdentityMatches(
              assetId: faceAssetId,
              r2Key: faceR2Key,
              asset: currentSkinFaceAsset,
            );
        if (!matchesRestored) {
          step7Affected = true;
          reasonCodes.add('step7_face_source_stale');
          currentBlocks.removeWhere((b) => b.section == 'skin_care');
          currentBaseTimeline = currentBaseTimeline.copyWith(
            skinCareFacePhotoAssetId: currentSkinFaceAsset?.assetId,
            skinCareFacePhotoR2Key: currentSkinFaceAsset?.r2Key,
            skinCareFacePhotoStatus: currentSkinFaceAsset?.status.wireName,
            skinCareFacePhotoCreatedAt: currentSkinFaceAsset?.createdAt,
            skinCareFacePhotoUpdatedAt: currentSkinFaceAsset?.updatedAt,
            clearSkinCareFacePhoto: currentSkinFaceAsset == null,
            clearSkinCareSuggestedProducts: true,
            skinCareSpecialCareNotes: const [],
            clearSkinCareRecommendationFingerprint: true,
            clearSkinCareRoutineFingerprint: true,
            clearSkinCareProductRecommendations: true,
            clearSkinCareSelectedProductNames: true,
          );
        }
      }
    }

    if (!step4Affected && !step5Affected && !step7Affected) {
      return OnboardingUploadSourceReconciliationResult(
        reconciledDraft: draft,
        changed: false,
        reasonCodes: const [],
        integrityFailure: false,
      );
    }

    currentBaseTimeline = currentBaseTimeline.copyWith(
      blocks: currentBlocks,
      pendingFutureImports: currentImports,
    );

    final stepCompleted = List<bool>.from(draft.stepCompleted);
    final stepDirty = List<bool>.from(draft.stepDirty);

    int? earliestAffectedStep;

    if (step4Affected) {
      stepCompleted[4] = false;
      stepDirty[4] = true;
      earliestAffectedStep = 4;
    }

    if (step5Affected) {
      stepCompleted[5] = false;
      stepDirty[5] = true;
      earliestAffectedStep = min(earliestAffectedStep ?? 5, 5);
    }

    if (step7Affected) {
      stepCompleted[7] = false;
      stepDirty[7] = true;
      earliestAffectedStep = min(earliestAffectedStep ?? 7, 7);
    }

    // Downstream Step 14 (final preview/bundle) requires revalidation.
    if (step4Affected || step5Affected || step7Affected) {
      stepCompleted[14] = false;
      stepDirty[14] = true;
    }

    final nextCurrentStep = earliestAffectedStep != null
        ? min(draft.currentStep, earliestAffectedStep)
        : draft.currentStep;

    final reconciledDraft = draft.copyWith(
      currentStep: nextCurrentStep,
      stepCompleted: stepCompleted,
      stepDirty: stepDirty,
      baseTimeline: currentBaseTimeline,
    );

    return OnboardingUploadSourceReconciliationResult(
      reconciledDraft: reconciledDraft,
      changed: true,
      earliestAffectedStep: earliestAffectedStep,
      reasonCodes: reasonCodes,
      integrityFailure: false,
    );
  }
}
