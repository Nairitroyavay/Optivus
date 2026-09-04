import 'dart:math';

import 'package:optivus/models/onboarding_draft.dart';
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

    final hasPhotoBackedStep4Or5State =
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
                currentBaseTimeline.latestImportForSection('Eating') != null));

    if (restoredUploads.errorMessage != null &&
        restoredUploads.errorMessage!.trim().isNotEmpty &&
        hasPhotoBackedStep4Or5State) {
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

      final isMatchingClassSlot =
          currentClassAsset != null &&
          ((classLogicalId != null &&
                  classLogicalId == currentClassAsset.assetId) ||
              (classLogicalKey != null &&
                  classLogicalKey == currentClassAsset.r2Key));

      final isMatchingWorkSlotSwapped =
          currentWorkAsset != null &&
          ((classLogicalId != null &&
                  classLogicalId == currentWorkAsset.assetId) ||
              (classLogicalKey != null &&
                  classLogicalKey == currentWorkAsset.r2Key));

      final isClassLogicalSourceCurrent =
          isMatchingClassSlot || isMatchingWorkSlotSwapped;

      final hasClassAiBlocks = currentBlocks.any(
        (b) => b.section == 'classes' && b.source == 'ai_import',
      );

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

      final isMatchingWorkSlot =
          currentWorkAsset != null &&
          ((workLogicalId != null &&
                  workLogicalId == currentWorkAsset.assetId) ||
              (workLogicalKey != null &&
                  workLogicalKey == currentWorkAsset.r2Key));

      final isMatchingClassSlotSwapped =
          currentClassAsset != null &&
          ((workLogicalId != null &&
                  workLogicalId == currentClassAsset.assetId) ||
              (workLogicalKey != null &&
                  workLogicalKey == currentClassAsset.r2Key));

      final isWorkLogicalSourceCurrent =
          isMatchingWorkSlot || isMatchingClassSlotSwapped;

      final hasWorkAiBlocks = currentBlocks.any(
        (b) => b.section == 'job_work_business' && b.source == 'ai_import',
      );

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
          (eatingImport.uploadedAssetId == currentEatingAsset.assetId ||
              eatingImport.uploadedAssetR2Key == currentEatingAsset.r2Key);

      bool allEatingBlocksMatchCurrentAsset = true;
      if (eatingAiBlocks.isNotEmpty) {
        if (!hasCurrentEatingAsset) {
          allEatingBlocksMatchCurrentAsset = false;
        } else {
          for (final block in eatingAiBlocks) {
            final provenance = block.provenanceSourceIds;
            if (provenance.isEmpty ||
                (!provenance.contains(currentEatingAsset.assetId) &&
                    !provenance.contains(currentEatingAsset.r2Key))) {
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

        if (hasCurrentEatingAsset) {
          currentImports.add(
            PendingFutureImportDraft(
              id: 'eating_photo_ai',
              section: 'Eating',
              mode: 'Photo AI',
              createdAt: DateTime.now(),
              uploadedAssetId: currentEatingAsset.assetId,
              uploadedAssetR2Key: currentEatingAsset.r2Key,
              uploadedAssetStatus: 'uploaded',
              status: PendingFutureImportDraft.appliedStatus,
            ),
          );
        }
      }
    }

    if (!step4Affected && !step5Affected) {
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

    // Downstream Step 14 (final preview/bundle) requires revalidation.
    if (step4Affected || step5Affected) {
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
