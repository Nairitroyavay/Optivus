import 'dart:math';

import 'package:optivus/features/onboarding/onboarding_step_id.dart';
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

    UploadedAsset? getValidAssetForExactId(String? assetId, String? r2Key) {
      if (assetId == null || assetId.trim().isEmpty) return null;
      final normalizedId = assetId.trim();
      final restored =
          restoredUploads.forAssetId(normalizedId) ??
          restoredUploads.assetsByPurpose.values
              .where((entry) => entry.asset.assetId == normalizedId)
              .firstOrNull;
      if (restored == null) return null;
      final asset = restored.asset;
      if (asset.ownerUid == ownerUid &&
          asset.status == UploadedAssetStatus.uploaded &&
          uploadedAssetHasLegitimateIdentityForSlot(
            asset: asset,
            uid: ownerUid,
            purpose: asset.purpose,
            expectedSourceFeature: UploadSourceFeature.onboarding,
          ) &&
          (r2Key == null ||
              r2Key.trim().isEmpty ||
              asset.r2Key == r2Key.trim())) {
        return asset;
      }
      return null;
    }

    UploadedAsset? rawExactAsset(String? assetId) {
      final id = assetId?.trim() ?? '';
      if (id.isEmpty) return null;
      return restoredUploads.exactLookupAssetsById[id] ??
          restoredUploads.forAssetId(id)?.asset ??
          restoredUploads.assetsByPurpose.values
              .where((entry) => entry.asset.assetId == id)
              .map((entry) => entry.asset)
              .firstOrNull;
    }

    String? exactAssetIntegrityCode({
      required String codePrefix,
      required String? assetId,
      required String? r2Key,
      required Set<UploadedAssetPurpose> allowedPurposes,
    }) {
      final raw = rawExactAsset(assetId);
      if (raw == null || raw.status == UploadedAssetStatus.deleted) return null;
      if (raw.ownerUid != ownerUid) return '${codePrefix}_owner_mismatch';
      if (raw.status != UploadedAssetStatus.uploaded) {
        return '${codePrefix}_status_invalid';
      }
      if (!allowedPurposes.contains(raw.purpose)) {
        return '${codePrefix}_purpose_mismatch';
      }
      if (!uploadedAssetHasLegitimateIdentityForSlot(
        asset: raw,
        uid: ownerUid,
        purpose: raw.purpose,
        expectedSourceFeature: UploadSourceFeature.onboarding,
      )) {
        return '${codePrefix}_identity_invalid';
      }
      final expectedKey = r2Key?.trim() ?? '';
      if (expectedKey.isEmpty || raw.r2Key != expectedKey) {
        return '${codePrefix}_r2_key_mismatch';
      }
      return null;
    }

    OnboardingUploadSourceReconciliationResult integrityFailure(
      String reasonCode,
    ) {
      return OnboardingUploadSourceReconciliationResult(
        reconciledDraft: draft,
        changed: false,
        reasonCodes: [reasonCode],
        integrityFailure: true,
      );
    }

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
      final classIntegrity = exactAssetIntegrityCode(
        codePrefix: 'step4_class_source',
        assetId: classLogicalId,
        r2Key: classLogicalKey,
        allowedPurposes: const {
          UploadedAssetPurpose.classTimetable,
          UploadedAssetPurpose.workSchedule,
        },
      );
      if (classIntegrity != null) return integrityFailure(classIntegrity);
      final exactClassAsset = getValidAssetForExactId(
        classLogicalId,
        classLogicalKey,
      );
      final matchingClassAsset = exactClassAsset;
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

        // The persisted exact identity is authoritative. A newer upload is
        // only adopted by an explicit user replacement write.
        currentBaseTimeline = currentBaseTimeline.copyWith(
          clearClassLogicalAsset: true,
        );
      }
    }

    if (workRequired) {
      final workLogicalId = currentBaseTimeline.workLogicalAssetId;
      final workLogicalKey = currentBaseTimeline.workLogicalAssetR2Key;

      final hasWorkAiBlocks = currentBlocks.any(
        (b) => b.section == 'job_work_business' && b.source == 'ai_import',
      );
      final workIntegrity = exactAssetIntegrityCode(
        codePrefix: 'step4_work_source',
        assetId: workLogicalId,
        r2Key: workLogicalKey,
        allowedPurposes: const {
          UploadedAssetPurpose.classTimetable,
          UploadedAssetPurpose.workSchedule,
        },
      );
      if (workIntegrity != null) return integrityFailure(workIntegrity);
      final exactWorkAsset = getValidAssetForExactId(
        workLogicalId,
        workLogicalKey,
      );
      final matchingWorkAsset = exactWorkAsset;
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

        currentBaseTimeline = currentBaseTimeline.copyWith(
          clearWorkLogicalAsset: true,
        );
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

      final eatingIntegrity = exactAssetIntegrityCode(
        codePrefix: 'step5_eating_source',
        assetId: eatingImport?.uploadedAssetId,
        r2Key: eatingImport?.uploadedAssetR2Key,
        allowedPurposes: const {UploadedAssetPurpose.eatingMenu},
      );
      if (eatingIntegrity != null) return integrityFailure(eatingIntegrity);

      final exactEatingAsset = getValidAssetForExactId(
        eatingImport?.uploadedAssetId,
        eatingImport?.uploadedAssetR2Key,
      );
      final effectiveEatingAsset = exactEatingAsset;
      final hasCurrentEatingAsset = effectiveEatingAsset != null;
      final importMatchesCurrentAsset =
          hasCurrentEatingAsset &&
          eatingImport != null &&
          uploadedSourceIdentityMatches(
            assetId: eatingImport.uploadedAssetId,
            r2Key: eatingImport.uploadedAssetR2Key,
            asset: effectiveEatingAsset,
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
              effectiveEatingAsset.assetId,
              effectiveEatingAsset.r2Key,
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
    if (currentBaseTimeline.skinCareSetupPath == 'has_products') {
      final productAssetId = currentBaseTimeline.skinCareProductPhotoAssetId;
      final productR2Key = currentBaseTimeline.skinCareProductPhotoR2Key;
      final hasPhotoUsed =
          productAssetId?.trim().isNotEmpty == true ||
          productR2Key?.trim().isNotEmpty == true;

      final productIntegrity = exactAssetIntegrityCode(
        codePrefix: 'step7_product_source',
        assetId: productAssetId,
        r2Key: productR2Key,
        allowedPurposes: const {
          UploadedAssetPurpose.skinProducts,
          UploadedAssetPurpose.skinCare,
        },
      );
      if (productIntegrity != null) return integrityFailure(productIntegrity);

      final exactProductAsset = getValidAssetForExactId(
        productAssetId,
        productR2Key,
      );
      final effectiveProductAsset = exactProductAsset;

      if (hasPhotoUsed) {
        final matchesRestored =
            effectiveProductAsset != null &&
            uploadedSourceIdentityMatches(
              assetId: productAssetId,
              r2Key: productR2Key,
              asset: effectiveProductAsset,
            );
        if (!matchesRestored) {
          step7Affected = true;
          reasonCodes.add('step7_product_source_stale');
          currentBlocks.removeWhere((b) => b.section == 'skin_care');
          currentBaseTimeline = currentBaseTimeline.copyWith(
            clearSkinCareProductPhoto: true,
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

      final faceIntegrity = exactAssetIntegrityCode(
        codePrefix: 'step7_face_source',
        assetId: faceAssetId,
        r2Key: faceR2Key,
        allowedPurposes: const {
          UploadedAssetPurpose.skinFace,
          UploadedAssetPurpose.skinCare,
        },
      );
      if (faceIntegrity != null) return integrityFailure(faceIntegrity);

      final exactFaceAsset = getValidAssetForExactId(faceAssetId, faceR2Key);
      final effectiveFaceAsset = exactFaceAsset;

      if (hasFacePhotoUsed) {
        final matchesRestored =
            effectiveFaceAsset != null &&
            uploadedSourceIdentityMatches(
              assetId: faceAssetId,
              r2Key: faceR2Key,
              asset: effectiveFaceAsset,
            );
        if (!matchesRestored) {
          step7Affected = true;
          reasonCodes.add('step7_face_source_stale');
          currentBlocks.removeWhere((b) => b.section == 'skin_care');
          currentBaseTimeline = currentBaseTimeline.copyWith(
            clearSkinCareFacePhoto: true,
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

    final classJobStep = OnboardingStepId.classesJob.index;
    final eatingStep = OnboardingStepId.eating.index;
    final skinCareStep = OnboardingStepId.skinCare.index;
    final todayReadyStep = OnboardingStepId.todayReady.index;
    int? earliestAffectedStep;

    if (step4Affected) {
      stepCompleted[classJobStep] = false;
      stepDirty[classJobStep] = true;
      earliestAffectedStep = classJobStep;
    }

    if (step5Affected) {
      stepCompleted[eatingStep] = false;
      stepDirty[eatingStep] = true;
      earliestAffectedStep = min(
        earliestAffectedStep ?? eatingStep,
        eatingStep,
      );
    }

    if (step7Affected) {
      stepCompleted[skinCareStep] = false;
      stepDirty[skinCareStep] = true;
      earliestAffectedStep = min(
        earliestAffectedStep ?? skinCareStep,
        skinCareStep,
      );
    }

    // Downstream Step 14 (final preview/bundle) requires revalidation.
    if (step4Affected || step5Affected || step7Affected) {
      stepCompleted[todayReadyStep] = false;
      stepDirty[todayReadyStep] = true;
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
