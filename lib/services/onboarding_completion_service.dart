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
    final preview = draft.buildFinalPreview();
    final routineItems = preview.items.map(_routineFromFinalItem).toList();
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
          )
        : null;

    return OnboardingCompletionBundle(
      userProfilePatch: _userProfilePatch(draft),
      baseTimelineBlocks: draft.baseTimeline.blocks
          .where((block) => !block.needsTimeConfirmation)
          .toList(),
      finalTimelineItems: preview.items,
      routineItemsForApp: routineItems,
      goodHabitTemplates: _goodHabitTemplates(draft),
      badHabitCheckIns: badHabitCheckIns,
      identityGoalSystems: goals,
      notificationPreferences: _notificationPreferences(draft),
      coachPreferences: _coachPreferences(draft),
      moneyGoal: moneyGoal,
      warnings: preview.warnings,
      duplicateSystemKeysMerged: preview.duplicateSystemKeysSkipped,
    );
  }

  static Map<String, dynamic> _userProfilePatch(OnboardingDraft draft) {
    final now = DateTime.now();
    return {
      'uid': draft.uid,
      'updatedAt': now.toIso8601String(),
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
        if (item.id == 'bad-check-${habit.id}') {
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
      final systems = goal.systemKeys.map((systemKey) {
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

  static RoutineItem _routineFromFinalItem(FinalTimelineItem item) {
    return RoutineItem(
      id: item.id,
      title: item.title,
      startMinute: item.startMinute,
      endMinute: item.endMinute,
      repeatDays: item.repeatDays,
      blockType: switch (item.blockType) {
        TimelineBlockDraft.hardBlockKey => RoutineBlockType.hardBlock,
        TimelineBlockDraft.softBlockKey => RoutineBlockType.softBlock,
        TimelineBlockDraft.checkInKey => RoutineBlockType.checkIn,
        'money_task' => RoutineBlockType.moneyTask,
        _ => RoutineBlockType.flexibleTask,
      },
      notes: item.source,
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
