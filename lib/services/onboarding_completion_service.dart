import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:optivus/features/routine/domain/conflict_policy.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/habit_system_onboarding_projection.dart';
import 'package:optivus/services/onboarding_run_identity.dart';
import 'package:optivus/services/routine_onboarding_event_projector.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/services/session_destination_resolver.dart';

enum Step14InvalidArea { profile, schedule, eating, skinCare, habits, goals }

sealed class Step14BundleBuildResult {
  const Step14BundleBuildResult();
}

class Step14BundleBuildSuccess extends Step14BundleBuildResult {
  final OnboardingCompletionBundle bundle;
  const Step14BundleBuildSuccess(this.bundle);
}

class Step14BundleBuildInvalid extends Step14BundleBuildResult {
  final Step14InvalidArea area;
  final int returnToStep;
  final String diagnosticCode;

  const Step14BundleBuildInvalid({
    required this.area,
    required this.returnToStep,
    required this.diagnosticCode,
  });
}

class Step14BundleBuildCorrupt extends Step14BundleBuildResult {
  final RecoverableError error;
  const Step14BundleBuildCorrupt(this.error);
}

enum OnboardingRecoveryTier {
  verifiedBundleFound,
  rebuiltFromVerifiedDraft,
  partialDraftResume,
  missingSetup,
  corruptDraft,
  migrationRequired,
  ownerMismatch;

  @Deprecated('Use verifiedBundleFound')
  static const tier1BundleFound = verifiedBundleFound;
  @Deprecated('Use rebuiltFromVerifiedDraft')
  static const tier2RebuiltFromDraft = rebuiltFromVerifiedDraft;
  @Deprecated('Completion synthesis was removed; use missingSetup')
  static const tier3Synthesized = missingSetup;
  @Deprecated('Use missingSetup')
  static const tier4ResetRequired = missingSetup;
}

class OnboardingCompletionResult {
  final OnboardingRecoveryTier tier;
  final OnboardingCompletionBundle? bundle;
  final OnboardingDraft? draft;
  final String? failureCode;

  const OnboardingCompletionResult({
    required this.tier,
    this.bundle,
    this.draft,
    this.failureCode,
  });

  bool get hasBundle => bundle != null;
}

class OnboardingCompletionService {
  const OnboardingCompletionService._();

  static bool bundleMatchesFinalDraft({
    required String uid,
    required OnboardingDraft draft,
    required OnboardingCompletionBundle bundle,
  }) {
    if (!isDurablyFinalOnboardingDraft(draft) ||
        uid.trim().isEmpty ||
        draft.uid != uid ||
        bundle.uid != uid ||
        bundle.version != OnboardingCompletionBundle.schemaVersion ||
        bundle.sourceFingerprint != draft.effectiveSourceFingerprint ||
        bundle.draftRevision != draft.revision) {
      return false;
    }
    return matchesOnboardingRunIdentity(
      runId: bundle.runId,
      ownerUid: uid,
      sourceFingerprint: draft.effectiveSourceFingerprint,
      draftRevision: draft.revision,
    );
  }

  static Future<OnboardingCompletionResult> recoverCompletionState({
    required String uid,
    required OnboardingRepository onboardingRepository,
    required ProfileRepository profileRepository,
    RoutineRepository? routineRepository,
  }) async {
    final bundle = await onboardingRepository.fetchCompletionBundle(uid);
    if (bundle != null && bundle.uid != uid) {
      return OnboardingCompletionResult(
        tier: OnboardingRecoveryTier.ownerMismatch,
        failureCode: 'completion_bundle_owner_mismatch',
      );
    }
    if (bundle != null) {
      if (bundle.version != OnboardingCompletionBundle.schemaVersion ||
          bundle.sourceFingerprint.length != 64 ||
          bundle.draftRevision < 1) {
        return OnboardingCompletionResult(
          tier: OnboardingRecoveryTier.migrationRequired,
          bundle: bundle,
          failureCode: 'completion_bundle_schema_migration_required',
        );
      }
      return OnboardingCompletionResult(
        tier: OnboardingRecoveryTier.verifiedBundleFound,
        bundle: bundle,
      );
    }

    final draft = await onboardingRepository.fetchDraft(uid);
    if (draft != null && draft.uid != uid) {
      return OnboardingCompletionResult(
        tier: OnboardingRecoveryTier.ownerMismatch,
        draft: draft,
        failureCode: 'onboarding_draft_owner_mismatch',
      );
    }
    if (draft != null && draft.onboardingCompleted) {
      final isVerifiedComplete =
          draft.currentStep == OnboardingDraft.lastStepIndex &&
          draft.stepCompleted.length == OnboardingDraft.stepCount &&
          draft.stepCompleted.every((value) => value) &&
          draft.revision >= 1 &&
          draft.effectiveSourceFingerprint.length == 64;
      if (!isVerifiedComplete) {
        return OnboardingCompletionResult(
          tier: OnboardingRecoveryTier.corruptDraft,
          draft: draft,
          failureCode: 'completed_draft_failed_verification',
        );
      }
      final rebuilt = buildBundle(draft);
      await onboardingRepository.saveCompletionBundle(rebuilt);
      final readback = await onboardingRepository.fetchCompletionBundle(uid);
      if (readback == null ||
          readback.uid != uid ||
          readback.sourceFingerprint != rebuilt.sourceFingerprint ||
          readback.draftRevision != draft.revision ||
          readback.version != OnboardingCompletionBundle.schemaVersion) {
        return OnboardingCompletionResult(
          tier: OnboardingRecoveryTier.corruptDraft,
          draft: draft,
          failureCode: 'rebuilt_bundle_readback_failed',
        );
      }
      return OnboardingCompletionResult(
        tier: OnboardingRecoveryTier.rebuiltFromVerifiedDraft,
        bundle: readback,
        draft: draft,
      );
    }
    if (draft != null) {
      return OnboardingCompletionResult(
        tier: OnboardingRecoveryTier.partialDraftResume,
        draft: draft,
      );
    }

    return const OnboardingCompletionResult(
      tier: OnboardingRecoveryTier.missingSetup,
      failureCode: 'onboarding_draft_missing',
    );
  }

  static Step14BundleBuildResult projectBundleResult(OnboardingDraft draft) {
    if (draft.baseTimeline.skinCareSetupPath != null ||
        draft.baseTimeline.blocks.any((b) => b.section == 'skin_care')) {
      final skinErr = draft.baseTimeline.validateSkinCareSetup(draft.uid);
      if (skinErr != null) {
        return const Step14BundleBuildInvalid(
          area: Step14InvalidArea.skinCare,
          returnToStep: 7,
          diagnosticCode: 'skin_care_incomplete',
        );
      }
    }
    try {
      final bundle = buildBundle(draft);
      return Step14BundleBuildSuccess(bundle);
    } catch (e) {
      return Step14BundleBuildCorrupt(
        RecoverableError(
          category: RecoverableErrorCategory.recoveryRequired,
          publicMessage:
              'We found an issue with your setup data. Let\'s restore your progress.',
          severity: RecoverableErrorSeverity.warning,
          isBlocking: true,
          retryAction: RecoverableRetryAction.returnToStep,
          retrySafe: true,
          diagnosticCode: 'bundle_build_failed: $e',
        ),
      );
    }
  }

  static OnboardingCompletionBundle buildBundle(OnboardingDraft draft) {
    final skinCareIsSkipped =
        draft.baseTimeline.skinCareSkipped ||
        draft.baseTimeline.skinCareSetupPath == 'skip';
    final baseItems = mergeOverlappingEatingBlocks(
      draft.baseTimeline.blocks
          .where(
            (block) =>
                !block.needsTimeConfirmation &&
                !(skinCareIsSkipped && block.section == 'skin_care'),
          )
          .toList(),
    );
    final mergedTimeline = draft.baseTimeline.copyWith(blocks: baseItems);

    if (draft.baseTimeline.skinCareSetupPath != null) {
      final skinCareErr = mergedTimeline.validateSkinCareSetup(draft.uid);
      if (skinCareErr != null) {
        throw StateError(skinCareErr);
      }
    }
    if (draft.baseTimeline.eatingSetupPath != null ||
        draft.baseTimeline.eatingMode != null ||
        draft.baseTimeline.shouldPlanMeals != null) {
      final targets = draft.canonicalNutritionTargets();
      final eatingErr = mergedTimeline.validateEatingSetup(
        targets: targets,
        generationInputs: draft.canonicalEatingGenerationInputs(
          targets: targets,
        ),
      );
      if (eatingErr != null) {
        throw StateError(eatingErr);
      }
    }
    final now = DateTime.now();
    final preview = draft.buildFinalPreview();

    // We rebuild routine items per day to ensure no hard-block overlaps
    final schedule = _scheduleRoutineItems(draft, baseItems, preview.items);
    final routineItems = schedule.items;

    final badHabitCheckIns = _badHabitCheckIns(draft, routineItems);
    final goals = _goalModels(draft, routineItems);
    final totalDailySpend = draft.badHabits.fold<double>(
      0,
      (sum, habit) => sum + habit.dailySpend,
    );
    final moneyGoal = totalDailySpend > 0
        ? MoneyGoal(
            id: 'money-onboarding-${draft.uid}',
            dailyTarget: totalDailySpend.clamp(10, 100000).toDouble(),
            currentLevelAmount: totalDailySpend.clamp(10, 100000).toDouble(),
            nextLevelAmount: (totalDailySpend * 2).clamp(25, 100000).toDouble(),
          )
        : null;

    final initialBundle = OnboardingCompletionBundle(
      uid: draft.uid,
      runId: stableOnboardingRunId(
        ownerUid: draft.uid,
        sourceFingerprint: draft.effectiveSourceFingerprint,
        draftRevision: draft.revision,
      ),
      createdAt: now,
      updatedAt: now,
      userProfilePatch: _userProfilePatch(draft),
      baseTimelineBlocks: baseItems,
      finalTimelineItems: preview.items,
      routineItemsForApp: routineItems,
      goodHabitTemplates: _goodHabitTemplates(draft),
      badHabitCheckIns: badHabitCheckIns,
      identityGoalSystems: goals,
      notificationPreferences: _notificationPreferences(draft),
      coachPreferences: _coachPreferences(draft),
      moneyGoal: moneyGoal,
      uploadedAssetReferences: _uploadedAssetReferences(draft),
      warnings: [...preview.warnings, ...schedule.warnings],
      duplicateSystemKeysMerged: preview.duplicateSystemKeysSkipped,
      sourceFingerprint: draft.effectiveSourceFingerprint,
      draftRevision: draft.revision,
      unscheduledRoutineSuggestions: schedule.unscheduledSuggestions,
    );
    final routinePlan = RoutineOnboardingProjection.build(initialBundle);
    final habitSystems = HabitSystemOnboardingProjection.build(
      initialBundle,
      routinePlan.items,
      now: now,
    );
    final acceptedSourceIds = <String>{
      ...routineItems.map((item) => item.id),
      ...initialBundle.goodHabitTemplates.map((item) => item.id),
      ...badHabitCheckIns.map((item) => item.id),
      ...goals.map((item) => item.id),
    }.toList()..sort();
    final generatedSourceIds = <String>{
      ...routinePlan.items.map((item) => item.id),
      ...habitSystems.map((item) => item.systemId),
    }.toList()..sort();
    return initialBundle.copyWithContractMetadata(
      expectedRoutineIds: routinePlan.items.map((item) => item.id).toList(),
      expectedHistoryIds: const RoutineOnboardingEventProjector()
          .computeExpectedEventIds(initialBundle),
      expectedHabitIds: habitSystems.map((item) => item.systemId).toList(),
      acceptedSourceIds: acceptedSourceIds,
      generatedSourceIds: generatedSourceIds,
      expectedAcceptanceIds: const [],
    );
  }

  // ignore: unused_element
  static List<ConflictAcceptance> _canonicalSourceAcceptances(
    OnboardingDraft draft,
  ) {
    final owner = draft.uid;
    if (owner.isEmpty) return const [];
    final accepted = <ConflictAcceptance>[];
    for (final source in draft.baseTimeline.conflictAcceptances) {
      if (!source.isActive) continue;
      final first = draft.baseTimeline.blockById(source.firstSourceBlockId);
      final second = draft.baseTimeline.blockById(source.secondSourceBlockId);
      if (first == null || second == null) continue;
      final firstDescriptor = timelineScheduleDescriptor(
        first,
        ownerUid: owner,
        timezoneId: draft.timezoneId,
      );
      final secondDescriptor = timelineScheduleDescriptor(
        second,
        ownerUid: owner,
        timezoneId: draft.timezoneId,
      );
      final decision = ConflictPolicy.classify(
        firstDescriptor,
        secondDescriptor,
      );
      if (!decision.canKeepBoth || decision.type.name != source.conflictType) {
        continue;
      }
      accepted.add(
        ConflictAcceptance.create(
          ownerUid: owner,
          first: firstDescriptor,
          second: secondDescriptor,
          conflictType: decision.type.name,
          scope: source.scope,
          applicableWeekdays: source.applicableWeekdays,
          timezoneId: draft.timezoneId,
          acceptedFrom: source.acceptedFrom,
          dateKey: source.dateKey,
          acceptedAt: source.acceptedAt,
        ),
      );
    }
    accepted.sort((a, b) => a.acceptanceId.compareTo(b.acceptanceId));
    return accepted;
  }

  static List<OnboardingUploadedAssetReference> _uploadedAssetReferences(
    OnboardingDraft draft,
  ) {
    final references = <OnboardingUploadedAssetReference>[];
    final seen = <String>{};

    void addReference(OnboardingUploadedAssetReference reference) {
      final assetId = reference.uploadedAssetId?.trim().toLowerCase() ?? '';
      final r2Key = reference.uploadedAssetR2Key?.trim().toLowerCase() ?? '';
      final key = assetId.isNotEmpty || r2Key.isNotEmpty
          ? 'asset:$assetId|$r2Key'
          : [
              reference.id.trim().toLowerCase(),
              reference.section.trim().toLowerCase(),
              reference.mode.trim().toLowerCase(),
            ].join('\u001f');
      if (!seen.add(key)) return;
      references.add(reference);
    }

    final base = draft.baseTimeline;
    bool currentSkinUpload({
      required UploadedAssetPurpose purpose,
      required String? assetId,
      required String? r2Key,
      required String? status,
    }) {
      final id = assetId?.trim() ?? '';
      final key = r2Key?.trim() ?? '';
      final parsedStatus = uploadedAssetStatusFromString(status);
      return uploadedAssetFieldsAreDurablyUploadedForSlot(
            assetId: id,
            ownerUid: draft.uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            purpose: purpose,
            r2Key: key,
            status: parsedStatus,
            uid: draft.uid,
            expectedPurpose: purpose,
          ) ||
          legacySkinCareUploadHasOwnedExactIdentity(
            assetId: id,
            ownerUid: draft.uid,
            r2Key: key,
            status: parsedStatus,
            uid: draft.uid,
          );
    }

    if (!base.skinCareSkipped &&
        base.skinCareSetupPath == 'has_products' &&
        currentSkinUpload(
          purpose: UploadedAssetPurpose.skinProducts,
          assetId: base.skinCareProductPhotoAssetId,
          r2Key: base.skinCareProductPhotoR2Key,
          status: base.skinCareProductPhotoStatus,
        )) {
      final fallbackCreatedAt = draft.createdAt ?? DateTime.now();
      final fallbackUpdatedAt = draft.updatedAt ?? fallbackCreatedAt;

      final createdAt = base.skinCareProductPhotoCreatedAt ?? fallbackCreatedAt;
      final updatedAt = base.skinCareProductPhotoUpdatedAt ?? fallbackUpdatedAt;
      addReference(
        OnboardingUploadedAssetReference(
          id: base.skinCareProductPhotoAssetId?.trim().isNotEmpty == true
              ? base.skinCareProductPhotoAssetId!.trim()
              : 'skin_care_product_photo',
          section: 'skin_care',
          mode: 'has_products',
          uploadedAssetId: base.skinCareProductPhotoAssetId,
          uploadedAssetR2Key: base.skinCareProductPhotoR2Key,
          uploadedAssetStatus: base.skinCareProductPhotoStatus,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }
    if (!base.skinCareSkipped &&
        base.skinCareSetupPath == 'no_products' &&
        currentSkinUpload(
          purpose: UploadedAssetPurpose.skinFace,
          assetId: base.skinCareFacePhotoAssetId,
          r2Key: base.skinCareFacePhotoR2Key,
          status: base.skinCareFacePhotoStatus,
        )) {
      final fallbackCreatedAt = draft.createdAt ?? DateTime.now();
      final fallbackUpdatedAt = draft.updatedAt ?? fallbackCreatedAt;
      addReference(
        OnboardingUploadedAssetReference(
          id: base.skinCareFacePhotoAssetId?.trim().isNotEmpty == true
              ? base.skinCareFacePhotoAssetId!.trim()
              : 'skin_care_face_photo',
          section: 'skin_care',
          mode: 'no_products',
          uploadedAssetId: base.skinCareFacePhotoAssetId,
          uploadedAssetR2Key: base.skinCareFacePhotoR2Key,
          uploadedAssetStatus: base.skinCareFacePhotoStatus,
          createdAt: base.skinCareFacePhotoCreatedAt ?? fallbackCreatedAt,
          updatedAt: base.skinCareFacePhotoUpdatedAt ?? fallbackUpdatedAt,
        ),
      );
    }

    for (final entry in base.pendingFutureImports) {
      if (entry.uploadedAssetId == null &&
          entry.uploadedAssetR2Key == null &&
          entry.uploadedAssetStatus == null) {
        continue;
      }
      addReference(
        OnboardingUploadedAssetReference(
          id: entry.id,
          section: entry.section,
          mode: entry.mode,
          uploadedAssetId: entry.uploadedAssetId,
          uploadedAssetR2Key: entry.uploadedAssetR2Key,
          uploadedAssetStatus: entry.uploadedAssetStatus,
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
        ),
      );
    }

    return references;
  }

  static _RoutineScheduleBuildResult _scheduleRoutineItems(
    OnboardingDraft draft,
    List<TimelineBlockDraft> baseBlocks,
    List<FinalTimelineItem> previewItems,
  ) {
    // Generate base routines
    final scheduled = baseBlocks.map((b) {
      final blockType = _routineBlockTypeForDraft(b.blockType);
      final isOvernight =
          b.crossesMidnight || b.endsNextDay || b.endMinute <= b.startMinute;
      return RoutineItem(
        id: b.id,
        userId: draft.uid,
        title: b.title,
        startMinute: b.startMinute,
        endMinute: b.endMinute,
        crossesMidnight: isOvernight,
        endsNextDay: isOvernight,
        repeatDays: b.repeatDays,
        blockType: blockType,
        category:
            b.id == BaseTimelineDraft.fixedSleepId ||
                b.title.trim().toLowerCase() == 'sleep'
            ? RoutineCategory.sleep
            : _categoryForTimelineSource(b.section, blockType),
        source: RoutineSource.onboarding,
        priority: _priorityForBlockType(blockType),
        hardBlock: blockType == RoutineBlockType.hardBlock,
        location: b.location,
        mealCategory: b.mealCategory,
        mealSlot: b.mealSlot,
        dishes: b.dishes,
        caloriesEstimate: b.calories,
        proteinEstimate: b.protein,
        steps: b.skincareSteps.isNotEmpty
            ? b.skincareSteps
            : b.skincareProducts,
        skincareProducts: b.skincareProducts,
      );
    }).toList();

    // Group the preview items by priority / flexible status
    // Hard blocks are already added. Now we place flexible tasks carefully.
    final flexibleItems = previewItems
        .where(
          (i) =>
              i.blockType != TimelineBlockDraft.hardBlockKey &&
              !baseBlocks.any((b) => b.id == i.id),
        )
        .toList();

    final unscheduled = <UnscheduledRoutineSuggestion>[];
    final warnings = <String>[];
    for (final flex in flexibleItems) {
      final blockType = switch (flex.blockType) {
        TimelineBlockDraft.softBlockKey => RoutineBlockType.softBlock,
        TimelineBlockDraft.checkInKey => RoutineBlockType.checkIn,
        'money_task' => RoutineBlockType.moneyTask,
        _ => RoutineBlockType.flexibleTask,
      };

      final duration = flex.durationMinutes;
      final requestedDays =
          (flex.repeatDays.isEmpty
                ? <int>[1, 2, 3, 4, 5, 6, 7]
                : flex.repeatDays.toSet().toList())
            ..sort();
      final daysByStartMinute = <int, List<int>>{};
      final failedDays = <int>[];
      for (final day in requestedDays) {
        final start = _firstAvailableStart(
          requestedStart: flex.startMinute,
          duration: duration,
          day: day,
          scheduled: scheduled,
        );
        if (start == null) {
          failedDays.add(day);
        } else {
          daysByStartMinute.putIfAbsent(start, () => []).add(day);
        }
      }

      for (final entry in daysByStartMinute.entries) {
        final days = entry.value..sort();
        final startMinute = entry.key;
        final unchanged =
            daysByStartMinute.length == 1 &&
            failedDays.isEmpty &&
            startMinute == flex.startMinute &&
            days.join(',') == requestedDays.join(',');
        scheduled.add(
          RoutineItem(
            id: unchanged
                ? flex.id
                : _scheduleVariantId(
                    flex.id,
                    startMinute: startMinute,
                    duration: duration,
                    repeatDays: days,
                  ),
            userId: draft.uid,
            title: flex.title,
            startMinute: startMinute,
            endMinute: startMinute + duration,
            repeatDays: days,
            blockType: blockType,
            category: _categoryForTimelineSource(flex.source, blockType),
            source: RoutineSource.onboarding,
            priority: _priorityForBlockType(blockType),
            hardBlock: blockType == RoutineBlockType.hardBlock,
            notes: flex.source,
          ),
        );
        if (startMinute != flex.startMinute) {
          warnings.add(
            '${flex.title} needs review: ${_weekdayList(days)} was placed at '
            '${_minuteLabel(startMinute)} instead of ${_minuteLabel(flex.startMinute)}.',
          );
        }
      }
      if (failedDays.isNotEmpty) {
        final digest = sha256.convert(
          utf8.encode(
            'unscheduled-v1\u001f${draft.uid}\u001f${flex.id}\u001f${failedDays.join(',')}',
          ),
        );
        unscheduled.add(
          UnscheduledRoutineSuggestion(
            id: 'uns_${digest.toString().substring(0, 32)}',
            sourceItemId: flex.id,
            title: flex.title,
            reason: 'no_available_time',
            repeatDays: failedDays,
            durationMinutes: duration,
          ),
        );
        warnings.add(
          '${flex.title} is unscheduled on ${_weekdayList(failedDays)}. Choose a time in Routine.',
        );
      }
    }

    return _RoutineScheduleBuildResult(
      items: scheduled,
      unscheduledSuggestions: unscheduled,
      warnings: warnings,
    );
  }

  static int? _firstAvailableStart({
    required int requestedStart,
    required int duration,
    required int day,
    required List<RoutineItem> scheduled,
  }) {
    if (duration <= 0 || duration > 24 * 60) return null;
    final intervals = <({int start, int end})>[];
    final previousDay = day == 1 ? 7 : day - 1;
    for (final item in scheduled) {
      final overnight =
          item.crossesMidnight ||
          item.endsNextDay ||
          item.endMinute <= item.startMinute;
      if (item.repeatDays.contains(day)) {
        intervals.add((
          start: item.startMinute,
          end: overnight ? 24 * 60 : item.endMinute,
        ));
      }
      if (overnight && item.repeatDays.contains(previousDay)) {
        intervals.add((start: 0, end: item.endMinute));
      }
    }
    intervals.sort((a, b) => a.start.compareTo(b.start));
    var start = requestedStart.clamp(0, 1439);
    while (start + duration <= 24 * 60) {
      ({int start, int end})? overlap;
      for (final interval in intervals) {
        if (start < interval.end && start + duration > interval.start) {
          overlap = interval;
          break;
        }
      }
      if (overlap == null) return start;
      start = overlap.end + 10;
    }
    return null;
  }

  static String _scheduleVariantId(
    String sourceId, {
    required int startMinute,
    required int duration,
    required List<int> repeatDays,
  }) {
    final digest = sha256.convert(
      utf8.encode(
        'schedule-variant-v1\u001f$sourceId\u001f$startMinute\u001f$duration\u001f${repeatDays.join(',')}',
      ),
    );
    return 'sv_${digest.toString().substring(0, 32)}';
  }

  static String _weekdayList(List<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((day) => names[day - 1]).join(', ');
  }

  static String _minuteLabel(int minute) {
    final hour = minute ~/ 60;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${(minute % 60).toString().padLeft(2, '0')} $suffix';
  }

  static RoutineBlockType _routineBlockTypeForDraft(String blockType) {
    return switch (blockType) {
      TimelineBlockDraft.hardBlockKey => RoutineBlockType.hardBlock,
      TimelineBlockDraft.checkInKey => RoutineBlockType.checkIn,
      'money_task' => RoutineBlockType.moneyTask,
      TimelineBlockDraft.flexibleTaskKey => RoutineBlockType.flexibleTask,
      _ => RoutineBlockType.softBlock,
    };
  }

  static RoutineCategory _categoryForTimelineSource(
    String source,
    RoutineBlockType blockType,
  ) {
    return switch (source) {
      'classes' => RoutineCategory.classBlock,
      'job_work_business' => RoutineCategory.job,
      'eating' => RoutineCategory.eating,
      'skin_care' => RoutineCategory.skinCare,
      'good_habit' || 'merged_habit_system' => RoutineCategory.habit,
      'identity_system' => RoutineCategory.identity,
      'bad_habit_check_in' => RoutineCategory.badHabit,
      'money' || 'money_task' => RoutineCategory.finance,
      'fixed' => RoutineCategory.fixed,
      _ =>
        blockType == RoutineBlockType.checkIn
            ? RoutineCategory.health
            : RoutineCategory.fixed,
    };
  }

  static RoutinePriority _priorityForBlockType(RoutineBlockType blockType) {
    return blockType == RoutineBlockType.hardBlock ||
            blockType == RoutineBlockType.moneyTask ||
            blockType == RoutineBlockType.checkIn
        ? RoutinePriority.mustDo
        : RoutinePriority.goodToDo;
  }

  static Map<String, dynamic> _userProfilePatch(OnboardingDraft draft) {
    final now = DateTime.now();
    final targets = draft.canonicalNutritionTargets();
    return {
      'uid': draft.uid,
      'schemaVersion': 1,
      'createdAt': draft.createdAt?.toIso8601String() ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'onboardingInputCompleted': true,
      'onboardingProjectionStatus': 'pending',
      'onboardingCompleted': false,
      'onboardingStep': OnboardingDraft.lastStepIndex,
      'lifeRole': draft.lifeRole.lifeRole ?? '',
      if (draft.lifeRole.workType != null)
        'workingExtra': draft.lifeRole.workType,
      if (draft.lifeRole.businessMode != null)
        'businessMode': draft.lifeRole.businessMode,
      'exerciseLevel': draft.lifeRole.exerciseLevel ?? '',
      'waterIntake': draft.lifeRole.waterIntake ?? '',
      'stressLevel': draft.lifeRole.stressLevel ?? '',
      'sleepQuality': draft.lifeRole.sleepQuality ?? '',
      'ageRange': draft.bodyBasics.ageRange ?? '',
      if (draft.bodyBasics.heightCm != null)
        'height': draft.bodyBasics.heightCm,
      if (draft.bodyBasics.weightKg != null)
        'weight': draft.bodyBasics.weightKg,
      'gender': draft.bodyBasics.gender ?? '',
      if (targets.bmi != null)
        'bmiEstimate': targets.bmi
      else if (draft.bodyBasics.bmiEstimate != null)
        'bmiEstimate': draft.bodyBasics.bmiEstimate,
      if (targets.estimatedMaintenanceCalories != null)
        'calorieEstimate': targets.estimatedMaintenanceCalories!.toDouble()
      else if (draft.bodyBasics.calorieEstimate != null)
        'calorieEstimate': draft.bodyBasics.calorieEstimate,
      if (targets.proteinTarget != null)
        'proteinEstimate': targets.proteinTarget
      else if (draft.bodyBasics.proteinEstimate != null)
        'proteinEstimate': draft.bodyBasics.proteinEstimate,
      'coachName': _coachName(draft),
      'coachStyle': draft.coachSetup.coachStyle ?? '',
      'slipUpStyle': draft.slipUpHandling ?? '',
    };
  }

  static List<GoodHabitTemplateBundle> _goodHabitTemplates(
    OnboardingDraft draft,
  ) {
    return draft.goodHabits.map((habit) {
      final systemKey =
          OnboardingDraft.systemKeyForGoodHabit(habit) ??
          'habit_${habit.habitKey}';
      return GoodHabitTemplateBundle(
        id: 'template-${habit.id}',
        systemKey: systemKey,
        title: habit.displayTitle,
        durationMinutes: habit.durationMinutes,
        frequency: habit.frequency,
        bestTime: habit.bestTime,
        priority: habit.priority,
        repeatDays: habit.repeatDays,
      );
    }).toList();
  }

  static List<BadHabitCheckInBundle> _badHabitCheckIns(
    OnboardingDraft draft,
    List<RoutineItem> routineItems,
  ) {
    return draft.badHabits.map((habit) {
      RoutineItem? linkedRoutine;
      for (final item in routineItems) {
        if (item.id == 'bad-check-${habit.id}' || item.id.contains(habit.id)) {
          linkedRoutine = item;
          break;
        }
      }
      return BadHabitCheckInBundle(
        id: 'check-${habit.id}',
        habitKey: habit.habitKey,
        displayName: habit.displayName,
        dailySpend: habit.dailySpend,
        lostTimeMinutes: habit.lostTimeMinutes,
        badHabitCheckInEnabled: habit.badHabitCheckInEnabled,
        moneySavedTrackerEnabled: habit.moneySavedTrackerEnabled,
        linkedRoutineItemId: linkedRoutine?.id,
      );
    }).toList();
  }

  static List<GoalModel> _goalModels(
    OnboardingDraft draft,
    List<RoutineItem> routineItems,
  ) {
    return draft.identityGoals.map((goal) {
      final systemKeys = goal.systemKeys.map(_canonicalSystemKey).toSet();
      final systems = systemKeys.map((systemKey) {
        final linkedRoutineIds = routineItems
            .where((item) => _routineMatchesSystem(item, systemKey))
            .map((item) => item.id)
            .toList();
        return GoalSystem(
          id: 'system-${goal.goalKey}-$systemKey',
          description: identitySystemTitle(systemKey),
          linkedRoutineTaskIds: linkedRoutineIds,
        );
      }).toList();

      return GoalModel(
        id: 'goal-${goal.goalKey}',
        identityTitle: goal.displayName,
        purposeStatement: 'Build daily proof for ${goal.displayName}.',
        progressPercent: 0,
        systems: systems,
        streakDays: 0,
        dailyProof: GoalProof(
          id: 'proof-${goal.goalKey}',
          title: '${goal.displayName} daily proof',
          tinyVersion: _tinyProof(goal),
          normalVersion: _normalProof(goal),
          strongVersion: _strongProof(goal),
        ),
      );
    }).toList();
  }

  static String _canonicalSystemKey(String key) {
    return switch (key) {
      'five_words_daily' || 'weekly_revision' => 'language_practice',
      _ => key,
    };
  }

  static bool _routineMatchesSystem(RoutineItem item, String systemKey) {
    final text = '${item.id} ${item.title}'.toLowerCase();
    final normalizedKey = systemKey.replaceAll('_', ' ');
    if (text.contains(systemKey.toLowerCase())) return true;
    if (text.contains(normalizedKey.toLowerCase())) return true;
    return switch (systemKey) {
      'workout' => text.contains('gym') || text.contains('workout'),
      'language_practice' || 'five_words_daily' => text.contains('language'),
      'meditation' => text.contains('meditation'),
      'journaling' => text.contains('journal'),
      'business_work' => text.contains('business'),
      'protein_meal_reminder' =>
        text.contains('protein') ||
            text.contains('breakfast') ||
            text.contains('lunch') ||
            text.contains('dinner'),
      'bad_habit_money_saved' || 'save_10_day' =>
        text.contains('money') ||
            text.contains('saved') ||
            text.contains('check-in'),
      _ => false,
    };
  }

  static NotificationPreferences _notificationPreferences(
    OnboardingDraft draft,
  ) {
    return NotificationPreferences(
      morningStart: draft.notifications.morningStartReminder,
      nextTask: draft.notifications.nextTaskReminder,
      eating: draft.notifications.eatingReminder,
      badHabitCheckIn: draft.notifications.badHabitCheckInReminder,
      savings: draft.notifications.savingsReminder,
      nightReflection: draft.notifications.nightReflectionReminder,
      intensity: switch (draft.notifications.reminderIntensity) {
        'low' => NotificationIntensity.low,
        'high' => NotificationIntensity.high,
        _ => NotificationIntensity.medium,
      },
    );
  }

  static CoachPreferences _coachPreferences(OnboardingDraft draft) {
    return CoachPreferences(
      name: _coachName(draft),
      style: _displayKey(draft.coachSetup.coachStyle ?? 'supportive'),
    );
  }

  static String _coachName(OnboardingDraft draft) {
    final custom = draft.coachSetup.customCoachName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final selected = draft.coachSetup.coachName?.trim();
    return selected == null || selected.isEmpty ? 'Coach' : selected;
  }

  static String _tinyProof(IdentityGoalDraft goal) {
    if (goal.systemKeys.contains('language_practice')) {
      return 'Learn 1 word or review one flashcard';
    }
    if (goal.systemKeys.contains('workout')) return '5 push-ups or 2 minutes';
    if (goal.systemKeys.contains('meditation')) return '2 calm breaths';
    if (goal.systemKeys.contains('business_work')) return 'Open the project';
    return 'One tiny proof action';
  }

  static String _normalProof(IdentityGoalDraft goal) {
    if (goal.systemKeys.contains('language_practice')) {
      return '10 minutes language practice';
    }
    if (goal.systemKeys.contains('workout')) return 'Complete workout block';
    if (goal.systemKeys.contains('meditation')) return '10 minutes meditation';
    if (goal.systemKeys.contains('business_work')) return '30 minutes business';
    return 'Complete one planned system';
  }

  static String _strongProof(IdentityGoalDraft goal) {
    if (goal.systemKeys.contains('language_practice')) {
      return '30 minutes language practice and revision';
    }
    if (goal.systemKeys.contains('workout')) return 'Full workout plus stretch';
    if (goal.systemKeys.contains('meditation')) {
      return '30 minutes meditation and journaling';
    }
    if (goal.systemKeys.contains('business_work')) {
      return '90 minutes deep business work';
    }
    return 'Complete the strong version of the system';
  }

  static String _displayKey(String key) {
    return key
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class _RoutineScheduleBuildResult {
  const _RoutineScheduleBuildResult({
    required this.items,
    required this.unscheduledSuggestions,
    required this.warnings,
  });

  final List<RoutineItem> items;
  final List<UnscheduledRoutineSuggestion> unscheduledSuggestions;
  final List<String> warnings;
}
