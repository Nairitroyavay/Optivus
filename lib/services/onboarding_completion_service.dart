import 'package:optivus/models/coach_models.dart';
import 'package:optivus/models/goal_models.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/notification_preferences.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';

class OnboardingCompletionService {
  const OnboardingCompletionService._();

  static OnboardingCompletionBundle buildBundle(OnboardingDraft draft) {
    final now = DateTime.now();
    final preview = draft.buildFinalPreview();
    final baseItems = draft.baseTimeline.blocks
        .where((block) => !block.needsTimeConfirmation)
        .toList();

    // We rebuild routine items per day to ensure no hard-block overlaps
    final routineItems = _scheduleRoutineItems(draft, baseItems, preview.items);

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

    return OnboardingCompletionBundle(
      uid: draft.uid,
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
      warnings: preview.warnings,
      duplicateSystemKeysMerged: preview.duplicateSystemKeysSkipped,
    );
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
    if (base.skinCareProductPhotoAssetId?.trim().isNotEmpty == true ||
        base.skinCareProductPhotoR2Key?.trim().isNotEmpty == true ||
        base.skinCareProductPhotoStatus?.trim().isNotEmpty == true) {
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

  static List<RoutineItem> _scheduleRoutineItems(
    OnboardingDraft draft,
    List<TimelineBlockDraft> baseBlocks,
    List<FinalTimelineItem> previewItems,
  ) {
    // Generate base routines
    final scheduled = baseBlocks.map((b) {
      final blockType = _routineBlockTypeForDraft(b.blockType);
      return RoutineItem(
        id: b.id,
        userId: draft.uid,
        title: b.title,
        startMinute: b.startMinute,
        endMinute: b.endMinute,
        crossesMidnight: b.crossesMidnight,
        endsNextDay: b.endsNextDay,
        repeatDays: b.repeatDays,
        blockType: blockType,
        category: _categoryForTimelineSource(b.section, blockType),
        source: RoutineSource.onboarding,
        priority: _priorityForBlockType(blockType),
        hardBlock: blockType == RoutineBlockType.hardBlock,
        location: b.location,
        mealCategory: b.mealCategory,
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

    for (final flex in flexibleItems) {
      final blockType = switch (flex.blockType) {
        TimelineBlockDraft.softBlockKey => RoutineBlockType.softBlock,
        TimelineBlockDraft.checkInKey => RoutineBlockType.checkIn,
        'money_task' => RoutineBlockType.moneyTask,
        _ => RoutineBlockType.flexibleTask,
      };

      // Ensure no overlap per day
      var placedAnyDay = false;
      final successfulDays = <int>[];
      var currentStartMinute = flex.startMinute;

      for (final day in flex.repeatDays) {
        final duration = flex.durationMinutes;
        var start = currentStartMinute;
        var moved = true;

        // Scan for conflicts on this specific day
        while (moved && start + duration <= 24 * 60) {
          moved = false;
          for (final existing in scheduled) {
            if (!existing.repeatDays.contains(day)) continue;
            // Basic overlap check
            final eStart = existing.startMinute;
            final eEnd =
                existing.crossesMidnight ||
                    existing.endsNextDay ||
                    existing.endMinute <= eStart
                ? (24 * 60) + existing.endMinute
                : existing.endMinute;

            final overlaps = start < eEnd && (start + duration) > eStart;
            if (overlaps) {
              start = eEnd + 10; // Push 10 minutes past the existing block
              moved = true;
            }
          }
        }

        if (start + duration <= 24 * 60) {
          currentStartMinute = start;
          successfulDays.add(day);
          placedAnyDay = true;
        }
      }

      if (placedAnyDay) {
        scheduled.add(
          RoutineItem(
            id: flex.id,
            userId: draft.uid,
            title: flex.title,
            startMinute: currentStartMinute,
            endMinute: currentStartMinute + flex.durationMinutes,
            repeatDays: successfulDays, // Only repeat on days we could fit it
            blockType: blockType,
            category: _categoryForTimelineSource(flex.source, blockType),
            source: RoutineSource.onboarding,
            priority: _priorityForBlockType(blockType),
            hardBlock: blockType == RoutineBlockType.hardBlock,
            notes: flex.source,
          ),
        );
      } else {
        // Fallback: Add as a tiny unscheduled suggestion (0 duration)
        scheduled.add(
          RoutineItem(
            id: flex.id,
            userId: draft.uid,
            title: '[Tiny] ${flex.title}',
            startMinute: 0,
            endMinute: 0,
            repeatDays: flex.repeatDays,
            blockType: RoutineBlockType.flexibleTask,
            category: _categoryForTimelineSource(
              flex.source,
              RoutineBlockType.flexibleTask,
            ),
            source: RoutineSource.onboarding,
            priority: RoutinePriority.goodToDo,
            notes: 'Unscheduled fallback due to schedule overflow',
          ),
        );
      }
    }

    return scheduled;
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
    return {
      'uid': draft.uid,
      'schemaVersion': OnboardingCompletionBundle.schemaVersion,
      'createdAt': draft.createdAt?.toIso8601String() ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'source': OnboardingDraft.sourceOnboarding,
      'onboardingCompleted': true,
      'onboardingStep': OnboardingDraft.lastStepIndex,
      'lifeRole': draft.lifeRole.lifeRole ?? '',
      'workingExtra': draft.lifeRole.workType,
      'businessMode': draft.lifeRole.businessMode,
      'exerciseLevel': draft.lifeRole.exerciseLevel ?? '',
      'waterIntake': draft.lifeRole.waterIntake ?? '',
      'stressLevel': draft.lifeRole.stressLevel ?? '',
      'sleepQuality': draft.lifeRole.sleepQuality ?? '',
      'ageRange': draft.bodyBasics.ageRange ?? '',
      'height': draft.bodyBasics.heightCm ?? 0.0,
      'weight': draft.bodyBasics.weightKg ?? 0.0,
      'gender': draft.bodyBasics.gender ?? '',
      'bmiEstimate': draft.bodyBasics.bmiEstimate ?? 0.0,
      'calorieEstimate': draft.bodyBasics.calorieEstimate ?? 0.0,
      'proteinEstimate': draft.bodyBasics.proteinEstimate ?? 0.0,
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
