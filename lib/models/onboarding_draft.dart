import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/upload_source_identity.dart';
import 'package:crypto/crypto.dart';
import 'package:optivus/features/routine/domain/conflict_policy.dart';
import 'package:optivus/models/conflict_acceptance.dart';
import 'package:optivus/models/skin_care_product_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/nutrition_target_service.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';

enum PersistedOnboardingStepLayout { legacy12, current15, ambiguous }

class OnboardingDraft {
  static const int schemaVersion = 3;
  static const String sourceOnboarding = 'onboarding';
  static const int _legacyStepCount = 12;
  static const int stepCount = 15;
  static const int lastStepIndex = stepCount - 1;

  final String uid;
  final int storedSchemaVersion;
  final int currentStep;
  final List<bool> stepCompleted;
  final List<bool> stepDirty;
  final List<bool> stepLoading;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool onboardingCompleted;
  final int revision;
  final String sourceFingerprint;
  final String timezoneId;

  final bool welcomeSaved;
  final bool patiencePledgeAccepted;
  final String? patiencePledgeText;
  final LifeRoleDraft lifeRole;
  final BodyBasicsDraft bodyBasics;
  final BaseTimelineDraft baseTimeline;
  final bool badHabitsNotNow;
  final List<BadHabitDraft> badHabits;
  final bool goodHabitsNotNow;
  final List<GoodHabitDraft> goodHabits;
  final List<IdentityGoalDraft> identityGoals;
  final CoachSetupDraft coachSetup;
  final String? slipUpHandling;
  final NotificationSetupDraft notifications;
  final FinalTimelinePreview? finalPreview;

  const OnboardingDraft({
    this.uid = '',
    this.storedSchemaVersion = schemaVersion,
    this.currentStep = 0,
    this.stepCompleted = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    this.stepDirty = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    this.stepLoading = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    this.createdAt,
    this.updatedAt,
    this.onboardingCompleted = false,
    this.revision = 1,
    this.sourceFingerprint = '',
    this.timezoneId = 'UTC',
    this.welcomeSaved = false,
    this.patiencePledgeAccepted = false,
    this.patiencePledgeText,
    this.lifeRole = const LifeRoleDraft(),
    this.bodyBasics = const BodyBasicsDraft(),
    this.baseTimeline = const BaseTimelineDraft(),
    this.badHabitsNotNow = false,
    this.badHabits = const [],
    this.goodHabitsNotNow = false,
    this.goodHabits = const [],
    this.identityGoals = const [],
    this.coachSetup = const CoachSetupDraft(),
    this.slipUpHandling,
    this.notifications = const NotificationSetupDraft(),
    this.finalPreview,
  });

  factory OnboardingDraft.fromMap(Map<String, dynamic> map) {
    final persistedStepLayout = _detectPersistedStepLayout(map);
    return OnboardingDraft(
      uid: map['uid'] as String? ?? '',
      storedSchemaVersion:
          (map['schemaVersion'] as num?)?.toInt() ?? schemaVersion,
      currentStep: _readCurrentStepIndex(
        _readStoredStepIndex(map['currentStep']),
        persistedStepLayout: persistedStepLayout,
      ),
      stepCompleted: _readStepBoolList(
        map['stepCompleted'],
        persistedStepLayout: persistedStepLayout,
      ),
      stepDirty: _readStepBoolList(
        map['stepDirty'],
        persistedStepLayout: persistedStepLayout,
      ),
      stepLoading: _readStepBoolList(
        map['stepLoading'],
        persistedStepLayout: persistedStepLayout,
      ),
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      revision: (map['revision'] as num?)?.toInt() ?? 1,
      sourceFingerprint: map['sourceFingerprint'] as String? ?? '',
      timezoneId: map['timezoneId'] as String? ?? 'UTC',
      welcomeSaved: map['welcomeSaved'] as bool? ?? false,
      patiencePledgeAccepted: map['patiencePledgeAccepted'] as bool? ?? false,
      patiencePledgeText: map['patiencePledgeText'] as String?,
      lifeRole: map['lifeRole'] is Map
          ? LifeRoleDraft.fromMap(
              Map<String, dynamic>.from(map['lifeRole'] as Map),
            )
          : const LifeRoleDraft(),
      bodyBasics: map['bodyBasics'] is Map
          ? BodyBasicsDraft.fromMap(
              Map<String, dynamic>.from(map['bodyBasics'] as Map),
            )
          : const BodyBasicsDraft(),
      baseTimeline: map['baseTimeline'] is Map
          ? BaseTimelineDraft.fromMap(
              Map<String, dynamic>.from(map['baseTimeline'] as Map),
            )
          : const BaseTimelineDraft(),
      badHabitsNotNow: map['badHabitsNotNow'] as bool? ?? false,
      badHabits: _readList(
        map['badHabits'],
        (value) => BadHabitDraft.fromMap(value),
      ),
      goodHabitsNotNow: map['goodHabitsNotNow'] as bool? ?? false,
      goodHabits: _readList(
        map['goodHabits'],
        (value) => GoodHabitDraft.fromMap(value),
      ),
      identityGoals: _readList(
        map['identityGoals'],
        (value) => IdentityGoalDraft.fromMap(value),
      ),
      coachSetup: map['coachSetup'] is Map
          ? CoachSetupDraft.fromMap(
              Map<String, dynamic>.from(map['coachSetup'] as Map),
            )
          : const CoachSetupDraft(),
      slipUpHandling: map['slipUpHandling'] as String?,
      notifications: map['notifications'] is Map
          ? NotificationSetupDraft.fromMap(
              Map<String, dynamic>.from(map['notifications'] as Map),
            )
          : const NotificationSetupDraft(),
      finalPreview: map['finalPreview'] is Map
          ? FinalTimelinePreview.fromMap(
              Map<String, dynamic>.from(map['finalPreview'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'schemaVersion': schemaVersion,
      'source': sourceOnboarding,
      'revision': revision,
      'timezoneId': timezoneId,
      'currentStep': currentStep,
      'stepCompleted': stepCompleted,
      'stepDirty': stepDirty,
      'stepLoading': stepLoading,
      if (createdAt != null) 'createdAt': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toIso8601String(),
      'onboardingCompleted': onboardingCompleted,
      'welcomeSaved': welcomeSaved,
      'patiencePledgeAccepted': patiencePledgeAccepted,
      if (patiencePledgeText != null) 'patiencePledgeText': patiencePledgeText,
      'lifeRole': lifeRole.toMap(),
      'bodyBasics': bodyBasics.toMap(),
      'baseTimeline': baseTimeline.toMap(),
      'badHabitsNotNow': badHabitsNotNow,
      'badHabits': badHabits.map((habit) => habit.toMap()).toList(),
      'goodHabitsNotNow': goodHabitsNotNow,
      'goodHabits': goodHabits.map((habit) => habit.toMap()).toList(),
      'identityGoals': identityGoals.map((goal) => goal.toMap()).toList(),
      'coachSetup': coachSetup.toMap(),
      if (slipUpHandling != null) 'slipUpHandling': slipUpHandling,
      'notifications': notifications.toMap(),
      if (finalPreview != null) 'finalPreview': finalPreview?.toMap(),
    };
    map['sourceFingerprint'] = sourceFingerprint.trim().isNotEmpty
        ? sourceFingerprint
        : _fingerprintDraftMap(map);
    return map;
  }

  String get effectiveSourceFingerprint =>
      toMap()['sourceFingerprint'] as String;

  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    return map;
  }

  OnboardingDraft copyWith({
    String? uid,
    int? storedSchemaVersion,
    int? currentStep,
    List<bool>? stepCompleted,
    List<bool>? stepDirty,
    List<bool>? stepLoading,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? onboardingCompleted,
    int? revision,
    String? sourceFingerprint,
    String? timezoneId,
    bool? welcomeSaved,
    bool? patiencePledgeAccepted,
    String? patiencePledgeText,
    LifeRoleDraft? lifeRole,
    BodyBasicsDraft? bodyBasics,
    BaseTimelineDraft? baseTimeline,
    bool? badHabitsNotNow,
    List<BadHabitDraft>? badHabits,
    bool? goodHabitsNotNow,
    List<GoodHabitDraft>? goodHabits,
    List<IdentityGoalDraft>? identityGoals,
    CoachSetupDraft? coachSetup,
    String? slipUpHandling,
    NotificationSetupDraft? notifications,
    FinalTimelinePreview? finalPreview,
    bool clearPatiencePledgeText = false,
    bool clearSlipUpHandling = false,
    bool clearFinalPreview = false,
    bool incrementRevision = true,
  }) {
    return OnboardingDraft(
      uid: uid ?? this.uid,
      storedSchemaVersion: storedSchemaVersion ?? this.storedSchemaVersion,
      currentStep: (currentStep ?? this.currentStep)
          .clamp(0, lastStepIndex)
          .toInt(),
      stepCompleted: _normalizeBoolList(
        stepCompleted ?? this.stepCompleted,
        stepCount,
      ),
      stepDirty: _normalizeBoolList(stepDirty ?? this.stepDirty, stepCount),
      stepLoading: _normalizeBoolList(
        stepLoading ?? this.stepLoading,
        stepCount,
      ),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      revision:
          revision ?? (incrementRevision ? this.revision + 1 : this.revision),
      sourceFingerprint:
          sourceFingerprint ??
          (incrementRevision ? '' : this.sourceFingerprint),
      timezoneId: timezoneId ?? this.timezoneId,
      welcomeSaved: welcomeSaved ?? this.welcomeSaved,
      patiencePledgeAccepted:
          patiencePledgeAccepted ?? this.patiencePledgeAccepted,
      patiencePledgeText: clearPatiencePledgeText
          ? null
          : (patiencePledgeText ?? this.patiencePledgeText),
      lifeRole: lifeRole ?? this.lifeRole,
      bodyBasics: bodyBasics ?? this.bodyBasics,
      baseTimeline: baseTimeline ?? this.baseTimeline,
      badHabitsNotNow: badHabitsNotNow ?? this.badHabitsNotNow,
      badHabits: badHabits ?? this.badHabits,
      goodHabitsNotNow: goodHabitsNotNow ?? this.goodHabitsNotNow,
      goodHabits: goodHabits ?? this.goodHabits,
      identityGoals: identityGoals ?? this.identityGoals,
      coachSetup: coachSetup ?? this.coachSetup,
      slipUpHandling: clearSlipUpHandling
          ? null
          : (slipUpHandling ?? this.slipUpHandling),
      notifications: notifications ?? this.notifications,
      finalPreview: clearFinalPreview
          ? null
          : (finalPreview ?? this.finalPreview),
    );
  }

  NutritionTargets canonicalNutritionTargets() {
    return const NutritionTargetService().calculate(
      weightKg: bodyBasics.weightKg,
      heightCm: bodyBasics.heightCm,
      ageRange: bodyBasics.ageRange,
      gender: bodyBasics.gender,
      exerciseLevel: lifeRole.exerciseLevel,
      lifeRole: lifeRole.lifeRole,
      bodyGoal: baseTimeline.mealPlanningGoal,
    );
  }

  EatingGenerationInputs canonicalEatingGenerationInputs({
    NutritionTargets? targets,
  }) {
    return EatingGenerationInputs.fromDraft(
      this,
      targets: targets ?? canonicalNutritionTargets(),
    );
  }

  String? validateStep(int step, List<bool> completedSteps) {
    switch (OnboardingStepId.fromIndex(step)) {
      case OnboardingStepId.welcome:
        return null;
      case OnboardingStepId.patience:
        return patiencePledgeAccepted
            ? null
            : 'Please read and commit to the Patience Pledge to proceed.';
      case OnboardingStepId.roleLifestyle:
        return lifeRole.validate();
      case OnboardingStepId.bodyBasics:
        return bodyBasics.validate();
      case OnboardingStepId.classesJob:
        return baseTimeline.validateClassesAndWorkForRole(lifeRole.lifeRole);
      case OnboardingStepId.eating:
        final targets = canonicalNutritionTargets();
        return baseTimeline.validateEatingSetup(
          targets: targets,
          generationInputs: canonicalEatingGenerationInputs(targets: targets),
        );
      case OnboardingStepId.fixedSchedule:
        return baseTimeline.validateFixedSchedule();
      case OnboardingStepId.skinCare:
        return baseTimeline.validateSkinCareSetup(uid);
      case OnboardingStepId.badHabits:
        return badHabitsNotNow || badHabits.isNotEmpty
            ? null
            : 'Choose Not now or select at least one bad habit.';
      case OnboardingStepId.goodHabits:
        return goodHabitsNotNow || goodHabits.isNotEmpty
            ? null
            : 'Choose Not now or select at least one good habit.';
      case OnboardingStepId.identityGoals:
        return identityGoals.isNotEmpty
            ? null
            : 'Select at least one long-term identity goal.';
      case OnboardingStepId.coachSetup:
        return coachSetup.validate();
      case OnboardingStepId.slipUp:
        return slipUpHandling == null
            ? 'Choose a slip-up handling style.'
            : null;
      case OnboardingStepId.notifications:
        return notifications.validate();
      case OnboardingStepId.todayReady:
        if (!completedSteps.take(lastStepIndex).every((done) => done)) {
          return 'Complete and save all previous onboarding steps first.';
        }
        if (baseTimeline.skinCareSetupPath != null ||
            baseTimeline.blocks.any((b) => b.section == 'skin_care')) {
          final skinCareErr = baseTimeline.validateSkinCareSetup(uid);
          if (skinCareErr != null) return skinCareErr;
        }
        if (baseTimeline.eatingSetupPath != null ||
            baseTimeline.eatingMode != null ||
            baseTimeline.shouldPlanMeals != null) {
          final targets = canonicalNutritionTargets();
          final eatingErr = baseTimeline.validateEatingSetup(
            targets: targets,
            generationInputs: canonicalEatingGenerationInputs(targets: targets),
          );
          if (eatingErr != null) return eatingErr;
        }
        final preview = buildFinalPreview();
        if (preview.blockingWarnings.isNotEmpty) {
          return preview.blockingWarnings.first;
        }
        return null;
      case null:
        return null;
    }
  }

  FinalTimelinePreview buildFinalPreview() {
    final warnings = <String>[];

    final baseItems = baseTimeline.blocks
        .where((block) => !block.needsTimeConfirmation)
        .where(
          (block) =>
              !(baseTimeline.skinCareSkipped && block.section == 'skin_care'),
        )
        .map(FinalTimelineItem.fromTimelineBlock)
        .toList();
    final occupiedItems = <FinalTimelineItem>[...baseItems];
    final systemItems = _mergedSystemItems(occupiedItems);
    final goodHabitItems = _standaloneGoodHabitItems(occupiedItems);
    final badHabitItems = _badHabitCheckIns(occupiedItems);

    final items = [
      ...baseItems,
      ...systemItems,
      ...goodHabitItems,
      ...badHabitItems,
    ]..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    warnings.addAll(_finalTimelineConflictWarnings(items));
    warnings.addAll(_capacityWarnings(items));

    return FinalTimelinePreview(
      items: items,
      warnings: warnings,
      duplicateSystemKeysSkipped: skippedDuplicateSystemKeys(),
    );
  }

  /// Overlaps that the canonical policy says must be edited or accepted before
  /// onboarding can finish.
  List<TimelineConflictDraft> timelineConflictsRequiringAcceptance() {
    return baseTimeline
        .detectConflicts(
          ownerUid: uid.isEmpty ? 'local-onboarding-owner' : uid,
          timezoneId: timezoneId,
          revision: revision,
        )
        .where((conflict) => conflict.isBlocking)
        .toList(growable: false);
  }

  OnboardingDraft acceptTimelineConflictGroup({
    required TimelineConflictDraft conflict,
    required List<int> weekdays,
    required String timezoneId,
    DateTime? acceptedAt,
  }) {
    final first = baseTimeline.blockById(conflict.firstBlockId);
    final second = baseTimeline.blockById(conflict.secondBlockId);
    if (first == null || second == null) return this;
    final owner = uid.isEmpty ? 'local-onboarding-owner' : uid;
    final firstDescriptor = timelineScheduleDescriptor(
      first,
      ownerUid: owner,
      timezoneId: timezoneId,
    );
    final secondDescriptor = timelineScheduleDescriptor(
      second,
      ownerUid: owner,
      timezoneId: timezoneId,
    );
    final decision = ConflictPolicy.classify(firstDescriptor, secondDescriptor);
    if (!decision.canKeepBoth) return this;

    final validDays = weekdays.where((d) => d >= 1 && d <= 7).toSet().toList()
      ..sort();
    if (validDays.isEmpty) {
      final pair = {first.id, second.id};
      final now = acceptedAt ?? DateTime.now();
      return copyWith(
        timezoneId: timezoneId,
        baseTimeline: baseTimeline.copyWith(
          conflictAcceptances: [
            for (final current in baseTimeline.conflictAcceptances)
              if (current.isActive &&
                  current.sourceBlockIds.length == pair.length &&
                  current.sourceBlockIds.containsAll(pair))
                current.invalidated('revokedInReview', at: now)
              else
                current,
          ],
        ),
      );
    }

    final acceptance = ConflictAcceptance.create(
      ownerUid: owner,
      first: firstDescriptor,
      second: secondDescriptor,
      conflictType: conflict.conflictType,
      scope: ConflictAcceptanceScope.recurringWeekdays,
      applicableWeekdays: validDays,
      timezoneId: timezoneId,
      acceptedFrom: ConflictAcceptanceOrigin.onboarding,
      acceptedAt: acceptedAt,
    );
    return copyWith(
      timezoneId: timezoneId,
      baseTimeline: baseTimeline.acceptCanonicalConflict(acceptance),
    );
  }

  List<FinalTimelineItem> _standaloneGoodHabitItems(
    List<FinalTimelineItem> occupiedItems,
  ) {
    final items = <FinalTimelineItem>[];
    var cursor = 6 * 60;

    for (final habit in goodHabits.where(
      (habit) => systemKeyForGoodHabit(habit) == null,
    )) {
      final duration = habit.durationMinutes;
      cursor = _nextFreeStart(
        _preferredStartMinute(habit.bestTime, fallback: cursor),
        duration,
        occupiedItems,
        habit.repeatDays,
      );
      final item = FinalTimelineItem(
        id: 'good-${habit.id}',
        title: habit.displayTitle,
        source: 'good_habit',
        startMinute: cursor,
        endMinute: cursor + duration,
        repeatDays: habit.repeatDays,
        blockType: habit.priority == GoodHabitDraft.mustDoPriority
            ? TimelineBlockDraft.flexibleTaskKey
            : TimelineBlockDraft.softBlockKey,
      );
      cursor += duration + 15;
      items.add(item);
      occupiedItems.add(item);
    }
    return items;
  }

  List<FinalTimelineItem> _badHabitCheckIns(
    List<FinalTimelineItem> occupiedItems,
  ) {
    if (badHabitsNotNow || badHabits.isEmpty) return const [];
    final items = <FinalTimelineItem>[];
    var cursor = 20 * 60;

    for (final habit in badHabits) {
      cursor = _nextFreeStart(cursor, 5, occupiedItems, const [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
      final item = FinalTimelineItem(
        id: 'bad-check-${habit.id}',
        title: '${habit.displayName} check-in',
        source: 'bad_habit_check_in',
        startMinute: cursor,
        endMinute: cursor + 5,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.checkInKey,
      );
      cursor += 10;
      items.add(item);
      occupiedItems.add(item);
    }
    return items;
  }

  List<FinalTimelineItem> _mergedSystemItems(
    List<FinalTimelineItem> occupiedItems,
  ) {
    final selectedSystemKeys = _dedupedIdentitySystemKeys();
    final goodHabitBySystemKey = _goodHabitBySystemKey();
    final items = <FinalTimelineItem>[];
    var cursor = 7 * 60;
    for (final systemKey in selectedSystemKeys) {
      final habit = goodHabitBySystemKey[systemKey];
      final duration =
          habit?.durationMinutes ?? _defaultSystemDuration(systemKey);
      final repeatDays = habit?.repeatDays ?? const [1, 2, 3, 4, 5, 6, 7];
      final priority = habit?.priority ?? GoodHabitDraft.mustDoPriority;
      cursor = _nextFreeStart(
        _preferredStartMinute(habit?.bestTime ?? 'anytime', fallback: cursor),
        duration,
        occupiedItems,
        repeatDays,
      );
      final title = identitySystemTitle(systemKey);
      final item = FinalTimelineItem(
        id: 'identity-$systemKey',
        title: title,
        source: habit == null ? 'identity_system' : 'merged_habit_system',
        startMinute: cursor,
        endMinute: (cursor + duration).clamp(0, 24 * 60),
        repeatDays: repeatDays,
        blockType: priority == GoodHabitDraft.mustDoPriority
            ? TimelineBlockDraft.flexibleTaskKey
            : TimelineBlockDraft.softBlockKey,
      );
      cursor += duration + 15;
      items.add(item);
      occupiedItems.add(item);
    }
    return items;
  }

  Map<String, GoodHabitDraft> _goodHabitBySystemKey() {
    final mapped = <String, GoodHabitDraft>{};
    for (final habit in goodHabits) {
      final systemKey = systemKeyForGoodHabit(habit);
      if (systemKey == null) continue;
      final existing = mapped[systemKey];
      if (existing == null ||
          habit.priority == GoodHabitDraft.mustDoPriority ||
          habit.durationMinutes > existing.durationMinutes) {
        mapped[systemKey] = habit;
      }
    }
    return mapped;
  }

  List<String> _dedupedIdentitySystemKeys() {
    final keys = <String>{};
    for (final habit in goodHabits) {
      final systemKey = systemKeyForGoodHabit(habit);
      if (systemKey != null) keys.add(_canonicalSystemKey(systemKey));
    }
    if (badHabits.any((habit) => habit.dailySpend > 0)) {
      keys.add('bad_habit_money_saved');
    }
    for (final goal in identityGoals) {
      keys.addAll(goal.systemKeys.map(_canonicalSystemKey));
    }
    return keys.toList();
  }

  List<String> skippedDuplicateSystemKeys() {
    final raw = <String>[];
    for (final habit in goodHabits) {
      final systemKey = systemKeyForGoodHabit(habit);
      if (systemKey != null) raw.add(_canonicalSystemKey(systemKey));
    }
    if (badHabits.any((habit) => habit.dailySpend > 0)) {
      raw.add('bad_habit_money_saved');
    }
    for (final goal in identityGoals) {
      raw.addAll(goal.systemKeys.map(_canonicalSystemKey));
    }

    final seen = <String>{};
    final duplicates = <String>{};
    for (final key in raw) {
      if (!seen.add(key)) duplicates.add(key);
    }
    return duplicates.toList();
  }

  static String? systemKeyForGoodHabit(GoodHabitDraft habit) {
    if (habit.habitKey == GoodHabitDraft.gymKey) return 'workout';
    if (habit.habitKey == GoodHabitDraft.meditationKey) return 'meditation';
    if (habit.habitKey == GoodHabitDraft.journalingKey) return 'journaling';
    if (habit.habitKey == GoodHabitDraft.languageLearningKey ||
        habit.subtypeKey == 'language') {
      return 'language_practice';
    }
    if (habit.subtypeKey == 'business_skill') return 'business_work';
    return null;
  }

  static String _canonicalSystemKey(String key) {
    return switch (key) {
      'five_words_daily' || 'weekly_revision' => 'language_practice',
      _ => key,
    };
  }

  static int _defaultSystemDuration(String systemKey) {
    return switch (systemKey) {
      'workout' => 30,
      'business_work' => 30,
      'language_practice' => 10,
      'meditation' => 10,
      'journaling' => 10,
      'bad_habit_money_saved' => 5,
      _ => 10,
    };
  }

  static int _preferredStartMinute(String bestTime, {required int fallback}) {
    return switch (bestTime) {
      'morning' => 7 * 60,
      'afternoon' => 13 * 60,
      'evening' => 18 * 60,
      'night' => 21 * 60,
      _ => fallback,
    };
  }

  List<String> _finalTimelineConflictWarnings(List<FinalTimelineItem> items) {
    final warnings = <String>[];
    final seen = <String>{};
    final baseBlockIds = baseTimeline.blocks.map((block) => block.id).toSet();
    for (var i = 0; i < items.length; i++) {
      final first = items[i];
      for (var j = i + 1; j < items.length; j++) {
        final second = items[j];
        // Base-timeline conflicts were already classified above. Rechecking
        // them here produced two differently worded warnings for one overlap.
        if (baseBlockIds.contains(first.id) &&
            baseBlockIds.contains(second.id)) {
          continue;
        }
        for (final firstWindow in _windowsForFinalItem(first)) {
          for (final secondWindow in _windowsForFinalItem(second)) {
            if (firstWindow.day != secondWindow.day) continue;
            final overlaps =
                firstWindow.startMinute < secondWindow.endMinute &&
                firstWindow.endMinute > secondWindow.startMinute;
            if (!overlaps) continue;
            final key =
                '${first.id}:${second.id}:${firstWindow.day}:${firstWindow.startMinute}';
            if (!seen.add(key)) continue;
            final hardConflict =
                first.blockType == TimelineBlockDraft.hardBlockKey &&
                second.blockType == TimelineBlockDraft.hardBlockKey;
            warnings.add(
              hardConflict
                  ? 'Resolve or accept the final hard conflict between ${first.title} and ${second.title}.'
                  : 'Schedule overlap: ${first.title} and ${second.title}. Tiny-version fallback may be needed.',
            );
          }
        }
      }
    }
    return warnings;
  }

  static List<String> _capacityWarnings(List<FinalTimelineItem> items) {
    final warnings = <String>[];
    for (var day = 1; day <= 7; day++) {
      final hardMinutes = items
          .where(
            (item) =>
                item.repeatDays.contains(day) &&
                item.blockType == TimelineBlockDraft.hardBlockKey,
          )
          .fold<int>(0, (total, item) => total + item.durationMinutes);
      final flexibleMinutes = items
          .where(
            (item) =>
                item.repeatDays.contains(day) &&
                item.blockType != TimelineBlockDraft.hardBlockKey,
          )
          .fold<int>(0, (total, item) => total + item.durationMinutes);
      final freeMinutes = (24 * 60 - hardMinutes).clamp(0, 24 * 60);
      if (flexibleMinutes > freeMinutes) {
        warnings.add(
          'Day $day does not have enough free time. Use tiny versions for flexible habits or edit hard blocks.',
        );
        break;
      }
    }
    return warnings;
  }

  static int _nextFreeStart(
    int desiredStart,
    int duration,
    List<FinalTimelineItem> blockedWindows,
    List<int> repeatDays,
  ) {
    var start = desiredStart;
    var moved = true;
    while (moved && start + duration <= 23 * 60) {
      moved = false;
      for (final block in blockedWindows) {
        for (final window in _windowsForFinalItem(block)) {
          if (!repeatDays.contains(window.day)) continue;
          final overlaps =
              start < window.endMinute && start + duration > window.startMinute;
          if (overlaps) {
            start = window.endMinute + 10;
            moved = true;
          }
        }
      }
    }
    return start;
  }

  static List<_TimelineWindowDraft> _windowsForFinalItem(
    FinalTimelineItem item,
  ) {
    final windows = <_TimelineWindowDraft>[];
    final crossesMidnight =
        item.crossesMidnight || item.endMinute <= item.startMinute;
    for (final day in item.repeatDays) {
      if (crossesMidnight) {
        windows.add(
          _TimelineWindowDraft(
            day: day,
            startMinute: item.startMinute,
            endMinute: 24 * 60,
          ),
        );
        windows.add(
          _TimelineWindowDraft(
            day: day == 7 ? 1 : day + 1,
            startMinute: 0,
            endMinute: item.endMinute,
          ),
        );
      } else {
        windows.add(
          _TimelineWindowDraft(
            day: day,
            startMinute: item.startMinute,
            endMinute: item.endMinute,
          ),
        );
      }
    }
    return windows;
  }

  static List<bool> _normalizeBoolList(List<bool> value, int length) {
    if (value.length == length) return List<bool>.from(value);
    return List<bool>.generate(
      length,
      (index) => index < value.length ? value[index] : false,
    );
  }

  static PersistedOnboardingStepLayout _detectPersistedStepLayout(
    Map<String, dynamic> map,
  ) {
    final version = (map['schemaVersion'] as num?)?.toInt();
    final lengths = <int>[
      for (final key in const ['stepCompleted', 'stepDirty', 'stepLoading'])
        if (map[key] is List) (map[key] as List).length,
    ];
    final hasCurrentVector = lengths.contains(stepCount);
    final hasLegacyVector = lengths.contains(_legacyStepCount);

    // A mixed 15/12 document is conflicting. Preserve current numeric meaning
    // and pad vectors rather than aggressively shifting progression.
    if (hasCurrentVector && hasLegacyVector) {
      return PersistedOnboardingStepLayout.ambiguous;
    }
    if (hasCurrentVector) return PersistedOnboardingStepLayout.current15;

    // Current-schema short vectors are partial/corrupt current vectors.
    if (version != null && version >= schemaVersion) {
      return PersistedOnboardingStepLayout.current15;
    }
    if (hasLegacyVector) return PersistedOnboardingStepLayout.legacy12;

    // Schema v1 is the only explicit historical data-schema evidence that a
    // partial vector belongs to the 12-page topology. Schema v2 already
    // existed with the current 15-page product layout.
    if (version != null &&
        version <= 1 &&
        lengths.any((length) => length > 0)) {
      return PersistedOnboardingStepLayout.legacy12;
    }
    return PersistedOnboardingStepLayout.ambiguous;
  }

  static int _readCurrentStepIndex(
    int storedStep, {
    required PersistedOnboardingStepLayout persistedStepLayout,
  }) {
    if (persistedStepLayout != PersistedOnboardingStepLayout.legacy12) {
      return storedStep.clamp(0, lastStepIndex).toInt();
    }
    return (legacyOnboardingIndexToCurrentStepId(storedStep) ??
            OnboardingStepId.welcome)
        .index;
  }

  static int _readStoredStepIndex(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static List<bool> _readStepBoolList(
    dynamic value, {
    required PersistedOnboardingStepLayout persistedStepLayout,
  }) {
    final raw = value is List
        ? value.map((e) => e == true).toList(growable: false)
        : <bool>[];
    if (persistedStepLayout == PersistedOnboardingStepLayout.legacy12) {
      return _migrateLegacyStepBoolList(raw);
    }
    return _normalizeBoolList(raw, stepCount);
  }

  static List<bool> _migrateLegacyStepBoolList(List<bool> legacy) {
    bool old(int index) => index >= 0 && index < legacy.length && legacy[index];
    final migrated = List<bool>.filled(stepCount, false);
    for (
      var legacyIndex = 0;
      legacyIndex < legacy.length && legacyIndex < _legacyStepCount;
      legacyIndex++
    ) {
      final currentId = legacyOnboardingIndexToCurrentStepId(legacyIndex);
      if (currentId != null) migrated[currentId.index] = old(legacyIndex);
    }
    // The old combined Base Timeline completion covers each page created by
    // its split. Resume validation remains the final monotonic authority.
    final baseTimelineComplete = old(4);
    migrated[OnboardingStepId.eating.index] = baseTimelineComplete;
    migrated[OnboardingStepId.fixedSchedule.index] = baseTimelineComplete;
    migrated[OnboardingStepId.skinCare.index] = baseTimelineComplete;
    return migrated;
  }

  static List<T> _readList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().map(mapper).toList();
    }
    return [];
  }
}

class LifeRoleDraft {
  static const studentKey = 'student';
  static const workingKey = 'working';
  static const studentWorkingKey = 'student_working';
  static const businessKey = 'business';
  static const notStudentNotWorkingKey = 'not_student_not_working';

  final String? lifeRole;
  final String? workType;
  final String? businessMode;
  final String? exerciseLevel;
  final String? waterIntake;
  final String? stressLevel;
  final String? sleepQuality;

  const LifeRoleDraft({
    this.lifeRole,
    this.workType,
    this.businessMode,
    this.exerciseLevel,
    this.waterIntake,
    this.stressLevel,
    this.sleepQuality,
  });

  factory LifeRoleDraft.fromMap(Map<String, dynamic> map) {
    return LifeRoleDraft(
      lifeRole: map['lifeRole'] as String?,
      workType: map['workType'] as String?,
      businessMode: map['businessMode'] as String?,
      exerciseLevel: NutritionTargetService.normalizeExerciseLevel(
        map['exerciseLevel'] as String?,
      ),
      waterIntake: map['waterIntake'] as String?,
      stressLevel: map['stressLevel'] as String?,
      sleepQuality: map['sleepQuality'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'lifeRole': lifeRole,
    'workType': workType,
    'businessMode': businessMode,
    'exerciseLevel': exerciseLevel,
    'waterIntake': waterIntake,
    'stressLevel': stressLevel,
    'sleepQuality': sleepQuality,
  };

  LifeRoleDraft copyWith({
    String? lifeRole,
    String? workType,
    String? businessMode,
    String? exerciseLevel,
    String? waterIntake,
    String? stressLevel,
    String? sleepQuality,
    bool clearWorkType = false,
    bool clearBusinessMode = false,
  }) {
    return LifeRoleDraft(
      lifeRole: lifeRole ?? this.lifeRole,
      workType: clearWorkType ? null : (workType ?? this.workType),
      businessMode: clearBusinessMode
          ? null
          : (businessMode ?? this.businessMode),
      exerciseLevel: exerciseLevel ?? this.exerciseLevel,
      waterIntake: waterIntake ?? this.waterIntake,
      stressLevel: stressLevel ?? this.stressLevel,
      sleepQuality: sleepQuality ?? this.sleepQuality,
    );
  }

  bool get needsWorkType =>
      lifeRole == workingKey || lifeRole == studentWorkingKey;

  bool get needsBusinessMode => lifeRole == businessKey;

  bool get classesEnabled =>
      lifeRole == studentKey || lifeRole == studentWorkingKey;

  bool get jobEnabled =>
      lifeRole == workingKey ||
      lifeRole == studentWorkingKey ||
      lifeRole == businessKey;

  String? validate() {
    if (lifeRole == null) return 'Please select a lifestyle role.';
    if (needsWorkType && workType == null) {
      return 'Please select your work type.';
    }
    if (needsBusinessMode && businessMode == null) {
      return 'Please select your business schedule mode.';
    }
    if (exerciseLevel == null) return 'Please select your exercise level.';
    if (waterIntake == null) return 'Please select your water intake.';
    if (stressLevel == null) return 'Please select your stress level.';
    if (sleepQuality == null) return 'Please select your sleep quality.';
    return null;
  }
}

class BodyBasicsDraft {
  final String? ageRange;
  final double? heightCm;
  final double? weightKg;
  final String? gender;
  final double? bmiEstimate;
  final double? calorieEstimate;
  final double? proteinEstimate;
  final bool bodyDataCompleted;

  const BodyBasicsDraft({
    this.ageRange,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.bmiEstimate,
    this.calorieEstimate,
    this.proteinEstimate,
    this.bodyDataCompleted = false,
  });

  factory BodyBasicsDraft.fromMap(Map<String, dynamic> map) {
    return BodyBasicsDraft(
      ageRange: map['ageRange'] as String?,
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      gender: map['gender'] as String?,
      bmiEstimate: (map['bmiEstimate'] as num?)?.toDouble(),
      calorieEstimate: (map['calorieEstimate'] as num?)?.toDouble(),
      proteinEstimate: (map['proteinEstimate'] as num?)?.toDouble(),
      bodyDataCompleted: map['bodyDataCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'ageRange': ageRange,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'gender': gender,
    'bmiEstimate': bmiEstimate,
    'calorieEstimate': calorieEstimate,
    'proteinEstimate': proteinEstimate,
    'bodyDataCompleted': bodyDataCompleted,
  };

  BodyBasicsDraft copyWith({
    String? ageRange,
    double? heightCm,
    double? weightKg,
    String? gender,
    double? bmiEstimate,
    double? calorieEstimate,
    double? proteinEstimate,
    bool? bodyDataCompleted,
    bool clearBmiEstimate = false,
    bool clearCalorieEstimate = false,
    bool clearProteinEstimate = false,
  }) {
    return BodyBasicsDraft(
      ageRange: ageRange ?? this.ageRange,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
      bmiEstimate: clearBmiEstimate ? null : (bmiEstimate ?? this.bmiEstimate),
      calorieEstimate: clearCalorieEstimate
          ? null
          : (calorieEstimate ?? this.calorieEstimate),
      proteinEstimate: clearProteinEstimate
          ? null
          : (proteinEstimate ?? this.proteinEstimate),
      bodyDataCompleted: bodyDataCompleted ?? this.bodyDataCompleted,
    );
  }

  BodyBasicsDraft withEstimates() {
    final height = heightCm;
    final weight = weightKg;
    if (height == null ||
        weight == null ||
        height < 120.0 ||
        height > 220.0 ||
        weight < 40.0 ||
        weight > 150.0) {
      return copyWith(
        bodyDataCompleted: false,
        clearBmiEstimate: true,
        clearCalorieEstimate: true,
        clearProteinEstimate: true,
      );
    }
    final meters = height / 100.0;
    final bmi = weight / (meters * meters);
    return copyWith(
      bmiEstimate: double.parse(bmi.toStringAsFixed(1)),
      clearCalorieEstimate: true,
      bodyDataCompleted:
          ageRange != null &&
          gender != null &&
          height >= 120.0 &&
          height <= 220.0 &&
          weight >= 40.0 &&
          weight <= 150.0,
    );
  }

  String? validate() {
    if (ageRange == null) return 'Please select your age range.';
    if (heightCm == null || heightCm! < 120.0 || heightCm! > 220.0) {
      return 'Height must be between 120 cm and 220 cm.';
    }
    if (weightKg == null || weightKg! < 40.0 || weightKg! > 150.0) {
      return 'Weight must be between 40 kg and 150 kg.';
    }
    if (gender == null) return 'Please select your gender.';
    return null;
  }
}

String normalizeSkinCareSelectionKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String normalizeSkinCareProductCategory(String value) {
  final key = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return switch (key) {
    'face wash' || 'facewash' || 'cleansing gel' || 'cleanser' => 'cleanser',
    'moisturiser' ||
    'moisturizer' ||
    'moisturizing cream' ||
    'moisturising cream' => 'moisturizer',
    'sun screen' ||
    'sunblock' ||
    'sun protection' ||
    'spf' ||
    'sunscreen' => 'sunscreen',
    _ => key.replaceAll(' ', '_'),
  };
}

class SkinCareProductRecommendationDraft {
  final String name;
  final String brand;
  final String category;
  final String estimatedPrice;
  final String currencyCode;
  final String reason;

  const SkinCareProductRecommendationDraft({
    required this.name,
    this.brand = '',
    this.category = '',
    this.estimatedPrice = '',
    this.currencyCode = '',
    this.reason = '',
  });

  factory SkinCareProductRecommendationDraft.fromMap(Map<String, dynamic> map) {
    return SkinCareProductRecommendationDraft(
      name: map['name']?.toString().trim() ?? '',
      brand: map['brand']?.toString().trim() ?? '',
      category: map['category']?.toString().trim() ?? '',
      estimatedPrice: map['estimatedPrice']?.toString().trim() ?? '',
      currencyCode: map['currencyCode']?.toString().trim() ?? '',
      reason: map['reason']?.toString().trim() ?? '',
    );
  }

  String get displayName {
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }
    return '$brand $name';
  }

  String get selectionKey => normalizeSkinCareSelectionKey(displayName);

  String get canonicalCategory => normalizeSkinCareProductCategory(category);

  Map<String, dynamic> toMap() => {
    'name': name,
    'brand': brand,
    'category': category,
    'estimatedPrice': estimatedPrice,
    'currencyCode': currencyCode,
    'reason': reason,
  };
}

class BaseTimelineDraft {
  static const fixedSleepId = 'fixed-sleep';
  static const fixedBathId = 'fixed-bath';

  final List<TimelineBlockDraft> blocks;
  final int classJobSetupStep;
  final int eatingSetupStep;
  final int fixedScheduleSetupStep;
  final int skinCareSetupStep;
  final String? businessMode;
  final int? workDurationMinutes;
  final String? workBestTime;
  final String? workPriority;
  final String? eatingSetupPath;
  final String? eatingMode;
  final bool? shouldPlanMeals;
  final String? mealPlanningGoal;
  final String? foodType;
  final String? foodStyleCustomText;
  final String? mealBudget;
  final String? cookingAbility;
  final int? mealsPerDay;
  final int? breakfastMinute;
  final int? lunchMinute;
  final int? dinnerMinute;
  final int? snackMinute;
  final int? extraSnackMinute;
  final String? skinCareSetupPath;
  final String? skinCareProductNames;
  final String? skinCareProductPhotoAssetId;
  final String? skinCareProductPhotoR2Key;
  final String? skinCareProductPhotoStatus;
  final DateTime? skinCareProductPhotoCreatedAt;
  final DateTime? skinCareProductPhotoUpdatedAt;
  final String? skinCareFacePhotoAssetId;
  final String? skinCareFacePhotoR2Key;
  final String? skinCareFacePhotoStatus;
  final DateTime? skinCareFacePhotoCreatedAt;
  final DateTime? skinCareFacePhotoUpdatedAt;
  final bool skinCareFacePhotoSkipped;
  final String? skinCareSkinType;
  final List<String> skinCareProblems;
  final String? skinCareBudget;
  final String? skinCarePreference;
  final int skinCareDesiredApplicationsPerDay;
  final bool skinCareSkipped;
  final List<PendingFutureImportDraft> pendingFutureImports;
  final List<ConflictAcceptance> conflictAcceptances;

  final String? classLogicalAssetId;
  final String? classLogicalAssetR2Key;
  final String? workLogicalAssetId;
  final String? workLogicalAssetR2Key;

  /// Reader-only compatibility for schema-v2 drafts. New serializers do not
  /// write these schedule-unbound keys.
  final List<String> acceptedConflictKeys;
  final List<String> roleChangeWarnings;
  final List<String> skinCareSpecialCareNotes;
  final List<SkinCareProductRecommendationDraft> skinCareProductRecommendations;
  final List<String> skinCareSelectedProductNames;
  final List<String> skinCareSuggestedProducts;
  final List<SkinCareDetectedProduct> skinCareReviewedProducts;
  final String? skinCareRecommendationFingerprint;
  final String? skinCareRoutineFingerprint;
  final String? skinCareRecommendationCountryCode;
  final String? skinCareRecommendationCurrencyCode;

  static const currentGate2EatingPlanVersion = 2;

  final int? eatingGeneratedPlanVersion;
  final String? eatingGeneratedInputFingerprint;

  const BaseTimelineDraft({
    this.blocks = const [],
    this.classJobSetupStep = 0,
    this.eatingSetupStep = 0,
    this.fixedScheduleSetupStep = 0,
    this.skinCareSetupStep = 0,
    this.businessMode,
    this.workDurationMinutes,
    this.workBestTime,
    this.workPriority,
    this.eatingSetupPath,
    this.eatingMode,
    this.shouldPlanMeals,
    this.mealPlanningGoal,
    this.foodType,
    this.foodStyleCustomText,
    this.mealBudget,
    this.cookingAbility,
    this.mealsPerDay,
    this.breakfastMinute,
    this.lunchMinute,
    this.dinnerMinute,
    this.snackMinute,
    this.extraSnackMinute,
    this.eatingGeneratedPlanVersion,
    this.eatingGeneratedInputFingerprint,
    this.skinCareSetupPath,
    this.skinCareProductNames,
    this.skinCareProductPhotoAssetId,
    this.skinCareProductPhotoR2Key,
    this.skinCareProductPhotoStatus,
    this.skinCareProductPhotoCreatedAt,
    this.skinCareProductPhotoUpdatedAt,
    this.skinCareFacePhotoAssetId,
    this.skinCareFacePhotoR2Key,
    this.skinCareFacePhotoStatus,
    this.skinCareFacePhotoCreatedAt,
    this.skinCareFacePhotoUpdatedAt,
    this.classLogicalAssetId,
    this.classLogicalAssetR2Key,
    this.workLogicalAssetId,
    this.workLogicalAssetR2Key,
    this.skinCareFacePhotoSkipped = false,
    this.skinCareSkinType,
    this.skinCareProblems = const [],
    this.skinCareBudget,
    this.skinCarePreference,
    this.skinCareDesiredApplicationsPerDay = 2,
    this.skinCareSkipped = false,
    this.pendingFutureImports = const [],
    this.conflictAcceptances = const [],
    this.acceptedConflictKeys = const [],
    this.roleChangeWarnings = const [],
    this.skinCareSpecialCareNotes = const [],
    this.skinCareProductRecommendations = const [],
    this.skinCareSelectedProductNames = const [],
    this.skinCareSuggestedProducts = const [],
    this.skinCareReviewedProducts = const [],
    this.skinCareRecommendationFingerprint,
    this.skinCareRoutineFingerprint,
    this.skinCareRecommendationCountryCode,
    this.skinCareRecommendationCurrencyCode,
  });

  factory BaseTimelineDraft.fromMap(Map<String, dynamic> map) {
    return BaseTimelineDraft(
      blocks: _readList(
        map['blocks'],
        (value) => TimelineBlockDraft.fromMap(value),
      ),
      classJobSetupStep: (map['classJobSetupStep'] as num?)?.toInt() ?? 0,
      eatingSetupStep: (map['eatingSetupStep'] as num?)?.toInt() ?? 0,
      fixedScheduleSetupStep:
          (map['fixedScheduleSetupStep'] as num?)?.toInt() ?? 0,
      skinCareSetupStep: (map['skinCareSetupStep'] as num?)?.toInt() ?? 0,
      businessMode: map['businessMode'] as String?,
      workDurationMinutes: (map['workDurationMinutes'] as num?)?.toInt(),
      workBestTime: map['workBestTime'] as String?,
      workPriority: map['workPriority'] as String?,
      eatingSetupPath: map['eatingSetupPath'] as String?,
      eatingMode: map['eatingMode'] as String?,
      shouldPlanMeals: map['shouldPlanMeals'] as bool?,
      mealPlanningGoal: NutritionTargetService.normalizeSupportedGoal(
        map['mealPlanningGoal'] as String?,
      ),
      foodType: map['foodType'] as String?,
      foodStyleCustomText: map['foodStyleCustomText'] as String?,
      mealBudget: map['mealBudget'] as String?,
      cookingAbility: map['cookingAbility'] as String?,
      mealsPerDay: (map['mealsPerDay'] as num?)?.toInt(),
      breakfastMinute: (map['breakfastMinute'] as num?)?.toInt(),
      lunchMinute: (map['lunchMinute'] as num?)?.toInt(),
      dinnerMinute: (map['dinnerMinute'] as num?)?.toInt(),
      snackMinute: (map['snackMinute'] as num?)?.toInt(),
      extraSnackMinute: (map['extraSnackMinute'] as num?)?.toInt(),
      skinCareSetupPath: map['skinCareSetupPath'] as String?,
      skinCareProductNames: map['skinCareProductNames'] as String?,
      skinCareProductPhotoAssetId:
          map['skinCareProductPhotoAssetId'] as String?,
      skinCareProductPhotoR2Key: map['skinCareProductPhotoR2Key'] as String?,
      skinCareProductPhotoStatus: map['skinCareProductPhotoStatus'] as String?,
      skinCareProductPhotoCreatedAt: _readDateTime(
        map['skinCareProductPhotoCreatedAt'],
      ),
      skinCareProductPhotoUpdatedAt: _readDateTime(
        map['skinCareProductPhotoUpdatedAt'],
      ),
      skinCareFacePhotoAssetId: map['skinCareFacePhotoAssetId'] as String?,
      skinCareFacePhotoR2Key: map['skinCareFacePhotoR2Key'] as String?,
      skinCareFacePhotoStatus: map['skinCareFacePhotoStatus'] as String?,
      skinCareFacePhotoCreatedAt: _readDateTime(
        map['skinCareFacePhotoCreatedAt'],
      ),
      skinCareFacePhotoUpdatedAt: _readDateTime(
        map['skinCareFacePhotoUpdatedAt'],
      ),
      skinCareFacePhotoSkipped:
          map['skinCareFacePhotoSkipped'] as bool? ?? false,
      skinCareSkinType: map['skinCareSkinType'] as String?,
      skinCareProblems: _readStringList(map['skinCareProblems']),
      skinCareBudget: map['skinCareBudget'] as String?,
      skinCarePreference: map['skinCarePreference'] as String?,
      skinCareDesiredApplicationsPerDay: _readSkinCareDesiredApplicationsPerDay(
        map['skinCareDesiredApplicationsPerDay'],
      ),
      skinCareSkipped: map['skinCareSkipped'] as bool? ?? false,
      pendingFutureImports: _readPendingFutureImports(
        map['pendingFutureImports'],
      ),
      conflictAcceptances: _readList(
        map['conflictAcceptances'],
        ConflictAcceptance.fromMap,
      ),
      classLogicalAssetId: map['classLogicalAssetId'] as String?,
      classLogicalAssetR2Key: map['classLogicalAssetR2Key'] as String?,
      workLogicalAssetId: map['workLogicalAssetId'] as String?,
      workLogicalAssetR2Key: map['workLogicalAssetR2Key'] as String?,
      acceptedConflictKeys: _readStringList(map['acceptedConflictKeys']),
      roleChangeWarnings: _readStringList(map['roleChangeWarnings']),
      skinCareSpecialCareNotes: _readStringList(
        map['skinCareSpecialCareNotes'],
      ),
      skinCareProductRecommendations: _readList(
        map['skinCareProductRecommendations'],
        SkinCareProductRecommendationDraft.fromMap,
      ),
      skinCareSelectedProductNames: _readStringList(
        map['skinCareSelectedProductNames'],
      ),
      skinCareSuggestedProducts: _readStringList(
        map['skinCareSuggestedProducts'],
      ),
      skinCareRecommendationCountryCode:
          map['skinCareRecommendationCountryCode'] as String?,
      skinCareRecommendationCurrencyCode:
          map['skinCareRecommendationCurrencyCode'] as String?,
      skinCareReviewedProducts: _readList(
        map['skinCareReviewedProducts'],
        SkinCareDetectedProduct.fromMap,
      ),
      skinCareRecommendationFingerprint:
          map['skinCareRecommendationFingerprint'] as String?,
      skinCareRoutineFingerprint: map['skinCareRoutineFingerprint'] as String?,
      eatingGeneratedPlanVersion: map['eatingGeneratedPlanVersion'] as int?,
      eatingGeneratedInputFingerprint:
          map['eatingGeneratedInputFingerprint'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'eatingGeneratedPlanVersion': eatingGeneratedPlanVersion,
    'eatingGeneratedInputFingerprint': eatingGeneratedInputFingerprint,
    'blocks': blocks.map((block) => block.toMap()).toList(),
    'classJobSetupStep': classJobSetupStep,
    'eatingSetupStep': eatingSetupStep,
    'fixedScheduleSetupStep': fixedScheduleSetupStep,
    'skinCareSetupStep': skinCareSetupStep,
    'businessMode': businessMode,
    'workDurationMinutes': workDurationMinutes,
    'workBestTime': workBestTime,
    'workPriority': workPriority,
    'eatingSetupPath': eatingSetupPath,
    'eatingMode': eatingMode,
    'shouldPlanMeals': shouldPlanMeals,
    'mealPlanningGoal': mealPlanningGoal,
    'foodType': foodType,
    'foodStyleCustomText': foodStyleCustomText,
    'mealBudget': mealBudget,
    'cookingAbility': cookingAbility,
    'mealsPerDay': mealsPerDay,
    'breakfastMinute': breakfastMinute,
    'lunchMinute': lunchMinute,
    'dinnerMinute': dinnerMinute,
    'snackMinute': snackMinute,
    'extraSnackMinute': extraSnackMinute,
    'skinCareSetupPath': skinCareSetupPath,
    'skinCareProductNames': skinCareProductNames,
    'skinCareProductPhotoAssetId': skinCareProductPhotoAssetId,
    'skinCareProductPhotoR2Key': skinCareProductPhotoR2Key,
    'skinCareProductPhotoStatus': skinCareProductPhotoStatus,
    'skinCareProductPhotoCreatedAt': skinCareProductPhotoCreatedAt
        ?.toIso8601String(),
    'skinCareProductPhotoUpdatedAt': skinCareProductPhotoUpdatedAt
        ?.toIso8601String(),
    'skinCareFacePhotoAssetId': skinCareFacePhotoAssetId,
    'skinCareFacePhotoR2Key': skinCareFacePhotoR2Key,
    'skinCareFacePhotoStatus': skinCareFacePhotoStatus,
    'skinCareFacePhotoCreatedAt': skinCareFacePhotoCreatedAt?.toIso8601String(),
    'skinCareFacePhotoUpdatedAt': skinCareFacePhotoUpdatedAt?.toIso8601String(),
    'skinCareFacePhotoSkipped': skinCareFacePhotoSkipped,
    'skinCareSkinType': skinCareSkinType,
    'skinCareProblems': skinCareProblems,
    'skinCareBudget': skinCareBudget,
    'skinCarePreference': skinCarePreference,
    'skinCareDesiredApplicationsPerDay': skinCareDesiredApplicationsPerDay,
    'skinCareSkipped': skinCareSkipped,
    'pendingFutureImports': pendingFutureImports
        .map((entry) => entry.toMap())
        .toList(),
    'conflictAcceptances': conflictAcceptances
        .map((acceptance) => acceptance.toMap())
        .toList(),
    'roleChangeWarnings': roleChangeWarnings,
    'skinCareSpecialCareNotes': skinCareSpecialCareNotes,
    'skinCareProductRecommendations': skinCareProductRecommendations
        .map((product) => product.toMap())
        .toList(),
    'skinCareSelectedProductNames': skinCareSelectedProductNames,
    'skinCareSuggestedProducts': skinCareSuggestedProducts,
    'skinCareReviewedProducts': skinCareReviewedProducts
        .map((product) => product.toMap())
        .toList(),
    'skinCareRecommendationFingerprint': skinCareRecommendationFingerprint,
    'skinCareRoutineFingerprint': skinCareRoutineFingerprint,
    'skinCareRecommendationCountryCode': skinCareRecommendationCountryCode,
    'skinCareRecommendationCurrencyCode': skinCareRecommendationCurrencyCode,
    'classLogicalAssetId': classLogicalAssetId,
    'classLogicalAssetR2Key': classLogicalAssetR2Key,
    'workLogicalAssetId': workLogicalAssetId,
    'workLogicalAssetR2Key': workLogicalAssetR2Key,
  };

  BaseTimelineDraft copyWith({
    List<TimelineBlockDraft>? blocks,
    int? classJobSetupStep,
    int? eatingSetupStep,
    int? fixedScheduleSetupStep,
    int? skinCareSetupStep,
    String? businessMode,
    int? workDurationMinutes,
    String? workBestTime,
    String? workPriority,
    String? eatingSetupPath,
    String? eatingMode,
    bool? shouldPlanMeals,
    String? mealPlanningGoal,
    String? foodType,
    String? foodStyleCustomText,
    String? mealBudget,
    String? cookingAbility,
    int? mealsPerDay,
    int? breakfastMinute,
    int? lunchMinute,
    int? dinnerMinute,
    int? snackMinute,
    int? extraSnackMinute,
    String? skinCareSetupPath,
    String? skinCareProductNames,
    String? skinCareProductPhotoAssetId,
    String? skinCareProductPhotoR2Key,
    String? skinCareProductPhotoStatus,
    DateTime? skinCareProductPhotoCreatedAt,
    DateTime? skinCareProductPhotoUpdatedAt,
    String? skinCareFacePhotoAssetId,
    String? skinCareFacePhotoR2Key,
    String? skinCareFacePhotoStatus,
    DateTime? skinCareFacePhotoCreatedAt,
    DateTime? skinCareFacePhotoUpdatedAt,
    bool? skinCareFacePhotoSkipped,
    String? skinCareSkinType,
    List<String>? skinCareProblems,
    String? skinCareBudget,
    String? skinCarePreference,
    int? skinCareDesiredApplicationsPerDay,
    bool? skinCareSkipped,
    List<PendingFutureImportDraft>? pendingFutureImports,
    List<ConflictAcceptance>? conflictAcceptances,
    List<String>? acceptedConflictKeys,
    List<String>? roleChangeWarnings,
    List<String>? skinCareSpecialCareNotes,
    List<SkinCareProductRecommendationDraft>? skinCareProductRecommendations,
    List<String>? skinCareSelectedProductNames,
    List<String>? skinCareSuggestedProducts,
    String? skinCareRecommendationCountryCode,
    String? skinCareRecommendationCurrencyCode,
    List<SkinCareDetectedProduct>? skinCareReviewedProducts,
    String? skinCareRecommendationFingerprint,
    String? skinCareRoutineFingerprint,
    String? classLogicalAssetId,
    String? classLogicalAssetR2Key,
    String? workLogicalAssetId,
    String? workLogicalAssetR2Key,
    int? eatingGeneratedPlanVersion,
    String? eatingGeneratedInputFingerprint,
    bool clearEatingGeneratedPlanVersion = false,
    bool clearEatingGeneratedInputFingerprint = false,
    bool clearClassLogicalAsset = false,
    bool clearWorkLogicalAsset = false,
    bool clearMealPlanning = false,
    bool clearBusinessPlanning = false,
    bool clearRoleChangeWarnings = false,
    bool clearSnackMinute = false,
    bool clearSkinCareProductNames = false,
    bool clearSkinCareProductPhoto = false,
    bool clearSkinCareFacePhoto = false,
    bool clearSkinCareSkinType = false,
    bool clearSkinCareProblems = false,
    bool clearSkinCareBudget = false,
    bool clearSkinCarePreference = false,
    bool clearSkinCareProductRecommendations = false,
    bool clearSkinCareSelectedProductNames = false,
    bool clearSkinCareSuggestedProducts = false,
    bool clearSkinCareRecommendationRegion = false,
    bool clearSkinCareRecommendationCountryCode = false,
    bool clearSkinCareRecommendationCurrencyCode = false,
    bool clearSkinCareReviewedProducts = false,
    bool clearSkinCareRecommendationFingerprint = false,
    bool clearSkinCareRoutineFingerprint = false,
    bool clearSkinCareSetupPath = false,
    bool clearSkinCarePlanning = false,
    bool clearClassData = false,
    bool clearWorkData = false,
  }) {
    return BaseTimelineDraft(
      blocks: blocks ?? this.blocks,
      classJobSetupStep: (classJobSetupStep ?? this.classJobSetupStep)
          .clamp(0, 8)
          .toInt(),
      eatingSetupStep: (eatingSetupStep ?? this.eatingSetupStep)
          .clamp(0, 8)
          .toInt(),
      fixedScheduleSetupStep:
          (fixedScheduleSetupStep ?? this.fixedScheduleSetupStep)
              .clamp(0, 8)
              .toInt(),
      skinCareSetupStep: (skinCareSetupStep ?? this.skinCareSetupStep)
          .clamp(0, 8)
          .toInt(),
      businessMode: clearBusinessPlanning
          ? null
          : (businessMode ?? this.businessMode),
      workDurationMinutes: clearBusinessPlanning
          ? null
          : (workDurationMinutes ?? this.workDurationMinutes),
      workBestTime: clearBusinessPlanning
          ? null
          : (workBestTime ?? this.workBestTime),
      workPriority: clearBusinessPlanning
          ? null
          : (workPriority ?? this.workPriority),
      eatingSetupPath: eatingSetupPath ?? this.eatingSetupPath,
      eatingMode: eatingMode ?? this.eatingMode,
      shouldPlanMeals: clearMealPlanning
          ? null
          : (shouldPlanMeals ?? this.shouldPlanMeals),
      mealPlanningGoal: clearMealPlanning
          ? null
          : (mealPlanningGoal ?? this.mealPlanningGoal),
      foodType: clearMealPlanning ? null : (foodType ?? this.foodType),
      foodStyleCustomText: clearMealPlanning
          ? null
          : (foodStyleCustomText ?? this.foodStyleCustomText),
      mealBudget: clearMealPlanning ? null : (mealBudget ?? this.mealBudget),
      cookingAbility: clearMealPlanning
          ? null
          : (cookingAbility ?? this.cookingAbility),
      mealsPerDay: clearMealPlanning ? null : (mealsPerDay ?? this.mealsPerDay),
      breakfastMinute: clearMealPlanning
          ? null
          : (breakfastMinute ?? this.breakfastMinute),
      lunchMinute: clearMealPlanning ? null : (lunchMinute ?? this.lunchMinute),
      dinnerMinute: clearMealPlanning
          ? null
          : (dinnerMinute ?? this.dinnerMinute),
      snackMinute: clearMealPlanning || clearSnackMinute
          ? null
          : (snackMinute ?? this.snackMinute),
      extraSnackMinute: clearMealPlanning
          ? null
          : (extraSnackMinute ?? this.extraSnackMinute),
      skinCareSetupPath: clearSkinCarePlanning || clearSkinCareSetupPath
          ? null
          : (skinCareSetupPath ?? this.skinCareSetupPath),
      skinCareProductNames: clearSkinCarePlanning || clearSkinCareProductNames
          ? null
          : (skinCareProductNames ?? this.skinCareProductNames),
      skinCareProductPhotoAssetId:
          clearSkinCarePlanning || clearSkinCareProductPhoto
          ? null
          : (skinCareProductPhotoAssetId ?? this.skinCareProductPhotoAssetId),
      skinCareProductPhotoR2Key:
          clearSkinCarePlanning || clearSkinCareProductPhoto
          ? null
          : (skinCareProductPhotoR2Key ?? this.skinCareProductPhotoR2Key),
      skinCareProductPhotoStatus:
          clearSkinCarePlanning || clearSkinCareProductPhoto
          ? null
          : (skinCareProductPhotoStatus ?? this.skinCareProductPhotoStatus),
      skinCareProductPhotoCreatedAt:
          clearSkinCarePlanning || clearSkinCareProductPhoto
          ? null
          : (skinCareProductPhotoCreatedAt ??
                this.skinCareProductPhotoCreatedAt),
      skinCareProductPhotoUpdatedAt:
          clearSkinCarePlanning || clearSkinCareProductPhoto
          ? null
          : (skinCareProductPhotoUpdatedAt ??
                this.skinCareProductPhotoUpdatedAt),
      skinCareFacePhotoAssetId: clearSkinCarePlanning || clearSkinCareFacePhoto
          ? null
          : (skinCareFacePhotoAssetId ?? this.skinCareFacePhotoAssetId),
      skinCareFacePhotoR2Key: clearSkinCarePlanning || clearSkinCareFacePhoto
          ? null
          : (skinCareFacePhotoR2Key ?? this.skinCareFacePhotoR2Key),
      skinCareFacePhotoStatus: clearSkinCarePlanning || clearSkinCareFacePhoto
          ? null
          : (skinCareFacePhotoStatus ?? this.skinCareFacePhotoStatus),
      skinCareFacePhotoCreatedAt:
          clearSkinCarePlanning || clearSkinCareFacePhoto
          ? null
          : (skinCareFacePhotoCreatedAt ?? this.skinCareFacePhotoCreatedAt),
      skinCareFacePhotoUpdatedAt:
          clearSkinCarePlanning || clearSkinCareFacePhoto
          ? null
          : (skinCareFacePhotoUpdatedAt ?? this.skinCareFacePhotoUpdatedAt),
      skinCareFacePhotoSkipped:
          skinCareFacePhotoSkipped ?? this.skinCareFacePhotoSkipped,
      skinCareSkinType: clearSkinCarePlanning || clearSkinCareSkinType
          ? null
          : (skinCareSkinType ?? this.skinCareSkinType),
      skinCareProblems: clearSkinCarePlanning || clearSkinCareProblems
          ? const []
          : (skinCareProblems ?? this.skinCareProblems),
      skinCareBudget: clearSkinCarePlanning || clearSkinCareBudget
          ? null
          : (skinCareBudget ?? this.skinCareBudget),
      skinCarePreference: clearSkinCarePlanning || clearSkinCarePreference
          ? null
          : (skinCarePreference ?? this.skinCarePreference),
      skinCareDesiredApplicationsPerDay: clearSkinCarePlanning
          ? 2
          : _normalizeSkinCareDesiredApplicationsPerDay(
              skinCareDesiredApplicationsPerDay ??
                  this.skinCareDesiredApplicationsPerDay,
            ),
      skinCareSkipped: skinCareSkipped ?? this.skinCareSkipped,
      pendingFutureImports: (clearClassData || clearWorkData)
          ? (pendingFutureImports ?? this.pendingFutureImports)
                .where((entry) {
                  if (clearClassData && entry.section == 'classes') {
                    return false;
                  }
                  if (clearWorkData && entry.section == 'job_work_business') {
                    return false;
                  }
                  return true;
                })
                .toList(growable: false)
          : (pendingFutureImports ?? this.pendingFutureImports),
      conflictAcceptances: conflictAcceptances ?? this.conflictAcceptances,
      acceptedConflictKeys: acceptedConflictKeys ?? this.acceptedConflictKeys,
      roleChangeWarnings: clearRoleChangeWarnings
          ? const []
          : (roleChangeWarnings ?? this.roleChangeWarnings),
      skinCareSpecialCareNotes: clearSkinCarePlanning
          ? const []
          : (skinCareSpecialCareNotes ?? this.skinCareSpecialCareNotes),
      skinCareProductRecommendations:
          clearSkinCarePlanning || clearSkinCareProductRecommendations
          ? const []
          : (skinCareProductRecommendations ??
                this.skinCareProductRecommendations),
      skinCareSelectedProductNames:
          clearSkinCarePlanning || clearSkinCareSelectedProductNames
          ? const []
          : (skinCareSelectedProductNames ?? this.skinCareSelectedProductNames),
      skinCareSuggestedProducts:
          clearSkinCarePlanning || clearSkinCareSuggestedProducts
          ? const []
          : (skinCareSuggestedProducts ?? this.skinCareSuggestedProducts),
      skinCareRecommendationCountryCode:
          clearSkinCarePlanning ||
              clearSkinCareRecommendationRegion ||
              clearSkinCareRecommendationCountryCode
          ? null
          : (skinCareRecommendationCountryCode ??
                this.skinCareRecommendationCountryCode),
      skinCareRecommendationCurrencyCode:
          clearSkinCarePlanning ||
              clearSkinCareRecommendationRegion ||
              clearSkinCareRecommendationCurrencyCode
          ? null
          : (skinCareRecommendationCurrencyCode ??
                this.skinCareRecommendationCurrencyCode),
      skinCareReviewedProducts:
          clearSkinCarePlanning || clearSkinCareReviewedProducts
          ? const []
          : (skinCareReviewedProducts ?? this.skinCareReviewedProducts),
      skinCareRecommendationFingerprint:
          clearSkinCarePlanning || clearSkinCareRecommendationFingerprint
          ? null
          : (skinCareRecommendationFingerprint ??
                this.skinCareRecommendationFingerprint),
      skinCareRoutineFingerprint:
          clearSkinCarePlanning || clearSkinCareRoutineFingerprint
          ? null
          : (skinCareRoutineFingerprint ?? this.skinCareRoutineFingerprint),
      classLogicalAssetId: clearClassData || clearClassLogicalAsset
          ? null
          : (classLogicalAssetId ?? this.classLogicalAssetId),
      classLogicalAssetR2Key: clearClassData || clearClassLogicalAsset
          ? null
          : (classLogicalAssetR2Key ?? this.classLogicalAssetR2Key),
      workLogicalAssetId: clearWorkData || clearWorkLogicalAsset
          ? null
          : (workLogicalAssetId ?? this.workLogicalAssetId),
      workLogicalAssetR2Key: clearWorkData || clearWorkLogicalAsset
          ? null
          : (workLogicalAssetR2Key ?? this.workLogicalAssetR2Key),
      eatingGeneratedPlanVersion: clearEatingGeneratedPlanVersion
          ? null
          : (eatingGeneratedPlanVersion ?? this.eatingGeneratedPlanVersion),
      eatingGeneratedInputFingerprint: clearEatingGeneratedInputFingerprint
          ? null
          : (eatingGeneratedInputFingerprint ??
                this.eatingGeneratedInputFingerprint),
    );
  }

  String computeEatingGeneratedInputFingerprint({
    NutritionTargets? targets,
    EatingGenerationInputs? generationInputs,
  }) {
    if (generationInputs != null) {
      return generationInputs.computeFingerprint();
    }
    return EatingGenerationInputs.fromTimeline(
      this,
      targets: targets,
    ).computeFingerprint();
  }

  EatingGenerationInputs canonicalEatingGenerationInputs({
    NutritionTargets? targets,
    String? lifeRole,
    String? country,
  }) {
    return EatingGenerationInputs.fromTimeline(
      this,
      targets: targets,
      lifeRole: lifeRole,
      country: country,
    );
  }

  BaseTimelineDraft upsertBlock(TimelineBlockDraft block) {
    final exists = blocks.any((item) => item.id == block.id);
    final changed = blocks
        .where((item) => item.id == block.id)
        .any((item) => _scheduleSemanticsChanged(item, block));
    return copyWith(
      blocks: exists
          ? [
              for (final item in blocks)
                if (item.id == block.id) block else item,
            ]
          : [...blocks, block],
      conflictAcceptances: changed
          ? _invalidateAcceptancesForBlock(block.id, reason: 'scheduleEdited')
          : conflictAcceptances,
    );
  }

  static bool _scheduleSemanticsChanged(
    TimelineBlockDraft previous,
    TimelineBlockDraft next,
  ) {
    if (previous.needsTimeConfirmation != next.needsTimeConfirmation) {
      return true;
    }
    return timelineScheduleDescriptor(
          previous,
          ownerUid: 'schedule-comparison-owner',
          timezoneId: 'schedule-comparison-timezone',
        ).scheduleFingerprint !=
        timelineScheduleDescriptor(
          next,
          ownerUid: 'schedule-comparison-owner',
          timezoneId: 'schedule-comparison-timezone',
        ).scheduleFingerprint;
  }

  BaseTimelineDraft deleteBlock(String id) {
    return copyWith(
      blocks: blocks.where((block) => block.id != id).toList(),
      acceptedConflictKeys: acceptedConflictKeys.where((key) {
        final ids = TimelineConflictDraft.blockIdsForKey(key);
        return ids == null || !ids.contains(id);
      }).toList(),
      conflictAcceptances: _invalidateAcceptancesForBlock(
        id,
        reason: 'sourceBlockDeleted',
      ),
    );
  }

  BaseTimelineDraft addPendingImport(String section, String mode) {
    if (mode == 'Manual') return this;
    final entry = PendingFutureImportDraft(
      id: '${section.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${mode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      section: section,
      mode: mode,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (pendingFutureImports.any((item) => item.id == entry.id)) return this;
    return copyWith(pendingFutureImports: [...pendingFutureImports, entry]);
  }

  BaseTimelineDraft upsertPendingImport(PendingFutureImportDraft entry) {
    final exists = pendingFutureImports.any((item) => item.id == entry.id);
    return copyWith(
      pendingFutureImports: exists
          ? [
              for (final item in pendingFutureImports)
                if (item.id == entry.id) entry else item,
            ]
          : [...pendingFutureImports, entry],
    );
  }

  BaseTimelineDraft applyPendingImport(String importId) {
    PendingFutureImportDraft? target;
    for (final entry in pendingFutureImports) {
      if (entry.id == importId) {
        target = entry;
        break;
      }
    }
    if (target == null) return this;
    final appliedBlocks = target.parsedBlocks
        .map((block) => block.copyWith(needsTimeConfirmation: false))
        .toList();
    return copyWith(
      blocks: [...blocks, ...appliedBlocks],
      pendingFutureImports: [
        for (final entry in pendingFutureImports)
          if (entry.id == importId)
            entry.copyWith(status: PendingFutureImportDraft.appliedStatus)
          else
            entry,
      ],
    );
  }

  BaseTimelineDraft acceptConflict(String key) {
    if (acceptedConflictKeys.contains(key)) return this;
    return copyWith(acceptedConflictKeys: [...acceptedConflictKeys, key]);
  }

  BaseTimelineDraft acceptCanonicalConflict(ConflictAcceptance acceptance) {
    if (conflictAcceptances.any(
      (current) =>
          current.acceptanceId == acceptance.acceptanceId && current.isActive,
    )) {
      return this;
    }
    final pair = acceptance.sourceBlockIds;
    final now = acceptance.acceptedAt;
    return copyWith(
      conflictAcceptances: [
        for (final current in conflictAcceptances)
          if (current.isActive &&
              current.sourceBlockIds.length == pair.length &&
              current.sourceBlockIds.containsAll(pair))
            current.invalidated('supersededByCurrentSchedule', at: now)
          else
            current,
        acceptance,
      ],
    );
  }

  TimelineBlockDraft? blockById(String id) {
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  List<ConflictAcceptance> _invalidateAcceptancesForBlock(
    String blockId, {
    required String reason,
  }) {
    return [
      for (final acceptance in conflictAcceptances)
        if (acceptance.isActive && acceptance.sourceBlockIds.contains(blockId))
          acceptance.invalidated(reason)
        else
          acceptance,
    ];
  }

  BaseTimelineDraft withRequiredFixedBlocks() {
    final nextBlocks = [...blocks];
    if (!_hasSleepBlock(nextBlocks)) {
      nextBlocks.add(defaultSleepBlock());
    }
    if (!_hasBathBlock(nextBlocks)) {
      nextBlocks.add(defaultBathBlock());
    }
    return copyWith(blocks: nextBlocks);
  }

  static TimelineBlockDraft defaultSleepBlock() {
    return const TimelineBlockDraft(
      id: fixedSleepId,
      section: 'fixed',
      title: 'Sleep',
      startMinute: 23 * 60 + 30,
      endMinute: 7 * 60,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.hardBlockKey,
      source: OnboardingDraft.sourceOnboarding,
      crossesMidnight: true,
    );
  }

  static TimelineBlockDraft defaultBathBlock() {
    return const TimelineBlockDraft(
      id: fixedBathId,
      section: 'fixed',
      title: 'Bath',
      startMinute: 7 * 60,
      endMinute: 7 * 60 + 30,
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
      blockType: TimelineBlockDraft.hardBlockKey,
      source: OnboardingDraft.sourceOnboarding,
    );
  }

  List<TimelineConflictDraft> detectConflicts({
    String ownerUid = 'local-onboarding-owner',
    String timezoneId = 'UTC',
    int revision = 1,
  }) {
    final conflicts = <TimelineConflictDraft>[];
    for (var i = 0; i < blocks.length; i++) {
      final first = blocks[i];
      if (first.needsTimeConfirmation) continue;
      for (var j = i + 1; j < blocks.length; j++) {
        final second = blocks[j];
        if (second.needsTimeConfirmation) continue;
        for (final firstWindow in _windowsFor(first)) {
          for (final secondWindow in _windowsFor(second)) {
            if (firstWindow.day != secondWindow.day) continue;
            final overlaps =
                firstWindow.startMinute < secondWindow.endMinute &&
                firstWindow.endMinute > secondWindow.startMinute;
            if (!overlaps) continue;
            final key = TimelineConflictDraft.keyFor(
              first.id,
              second.id,
              firstWindow.day,
            );
            final firstDescriptor = timelineScheduleDescriptor(
              first,
              ownerUid: ownerUid,
              timezoneId: timezoneId,
            );
            final secondDescriptor = timelineScheduleDescriptor(
              second,
              ownerUid: ownerUid,
              timezoneId: timezoneId,
            );
            final decision = ConflictPolicy.classify(
              firstDescriptor,
              secondDescriptor,
            );
            final day = DateTime(2024, 1, firstWindow.day);
            final accepted =
                decision.canKeepBoth &&
                conflictAcceptances.any(
                  (acceptance) => acceptance.authorizesSourceDraft(
                    ownerUid: ownerUid,
                    first: firstDescriptor,
                    second: secondDescriptor,
                    conflictType: decision.type.name,
                    day: day,
                    timezoneId: timezoneId,
                  ),
                );
            final hardConflict = decision.blocking;
            conflicts.add(
              TimelineConflictDraft(
                key: key,
                firstBlockId: first.id,
                secondBlockId: second.id,
                firstTitle: first.title,
                secondTitle: second.title,
                day: firstWindow.day,
                isHardConflict: hardConflict,
                accepted: accepted,
                conflictType: decision.type.name,
                blocking: decision.blocking && !accepted,
                canKeepBoth: decision.canKeepBoth && !accepted,
                publicReason: decision.publicReason,
              ),
            );
          }
        }
      }
    }
    return conflicts;
  }

  BaseTimelineInvalidationResult invalidateForRole(String? lifeRole) {
    final classesEnabled =
        lifeRole == LifeRoleDraft.studentKey ||
        lifeRole == LifeRoleDraft.studentWorkingKey;
    final jobEnabled =
        lifeRole == LifeRoleDraft.workingKey ||
        lifeRole == LifeRoleDraft.studentWorkingKey ||
        lifeRole == LifeRoleDraft.businessKey;
    final businessEnabled = lifeRole == LifeRoleDraft.businessKey;

    final removedIds = <String>{};
    final keptBlocks = <TimelineBlockDraft>[];
    var removedClassCount = 0;
    var removedJobCount = 0;

    for (final block in blocks) {
      if (!classesEnabled && block.section == 'classes') {
        removedIds.add(block.id);
        removedClassCount++;
        continue;
      }
      if (!jobEnabled && block.section == 'job_work_business') {
        removedIds.add(block.id);
        removedJobCount++;
        continue;
      }
      keptBlocks.add(block);
    }

    final warnings = <String>[
      if (removedClassCount > 0)
        'Removed $removedClassCount class block${removedClassCount == 1 ? '' : 's'} because Classes are disabled for this role.',
      if (removedJobCount > 0)
        'Removed $removedJobCount job/work block${removedJobCount == 1 ? '' : 's'} because Work is disabled for this role.',
      if (!businessEnabled &&
          (businessMode != null ||
              workBestTime != null ||
              workPriority != null ||
              workDurationMinutes != null))
        'Cleared business schedule settings because this role is not Business.',
    ];

    final nextAcceptedKeys = acceptedConflictKeys.where((key) {
      final ids = TimelineConflictDraft.blockIdsForKey(key);
      return ids == null || ids.every((id) => !removedIds.contains(id));
    }).toList();
    final nextAcceptances = [
      for (final acceptance in conflictAcceptances)
        if (acceptance.isActive &&
            acceptance.sourceBlockIds.any(removedIds.contains))
          acceptance.invalidated('roleChanged')
        else
          acceptance,
    ];

    return BaseTimelineInvalidationResult(
      timeline: copyWith(
        blocks: keptBlocks,
        acceptedConflictKeys: nextAcceptedKeys,
        conflictAcceptances: nextAcceptances,
        roleChangeWarnings: warnings,
        clearBusinessPlanning: !businessEnabled,
        clearClassData: !classesEnabled,
        clearWorkData: !jobEnabled,
      ),
      warnings: warnings,
    );
  }

  String? validateClassesAndWorkForRole(String? lifeRole) {
    final classesRequired =
        lifeRole == LifeRoleDraft.studentKey ||
        lifeRole == LifeRoleDraft.studentWorkingKey;
    final jobRequired =
        lifeRole == LifeRoleDraft.workingKey ||
        lifeRole == LifeRoleDraft.studentWorkingKey ||
        lifeRole == LifeRoleDraft.businessKey;
    if (lifeRole == null) {
      return 'Choose your role before setting classes and work.';
    }
    if (!classesRequired && !jobRequired) return null;
    if (classesRequired &&
        jobRequired &&
        (!_hasConfirmedSection('classes') ||
            !_hasConfirmedSection('job_work_business'))) {
      return 'Generate both class and work schedules first.';
    }
    if (classesRequired) {
      if (!_hasConfirmedSection('classes')) {
        return 'Generate your class timeline first.';
      }
      final classAiBlocks = blocks.where(
        (b) => b.section == 'classes' && b.source == 'ai_import',
      );
      if (classAiBlocks.isNotEmpty) {
        if (classLogicalAssetId == null ||
            classLogicalAssetId!.trim().isEmpty ||
            classLogicalAssetR2Key == null ||
            classLogicalAssetR2Key!.trim().isEmpty) {
          return 'Your class timeline was generated from a previous photo. Please regenerate.';
        }
        for (final block in classAiBlocks) {
          if (!provenanceContainsExactUploadIdentity(
            block.provenanceSourceIds,
            classLogicalAssetId,
            classLogicalAssetR2Key,
          )) {
            return 'Your class timeline was generated from a previous photo. Please regenerate.';
          }
        }
      }
    }
    if (jobRequired) {
      if (!_hasConfirmedSection('job_work_business')) {
        if (lifeRole == LifeRoleDraft.businessKey) {
          return 'Generate your work/business timeline first.';
        }
        return 'Generate your work timeline first.';
      }
      final workAiBlocks = blocks.where(
        (b) => b.section == 'job_work_business' && b.source == 'ai_import',
      );
      if (workAiBlocks.isNotEmpty) {
        if (workLogicalAssetId == null ||
            workLogicalAssetId!.trim().isEmpty ||
            workLogicalAssetR2Key == null ||
            workLogicalAssetR2Key!.trim().isEmpty) {
          return 'Your work timeline was generated from a previous photo. Please regenerate.';
        }
        for (final block in workAiBlocks) {
          if (!provenanceContainsExactUploadIdentity(
            block.provenanceSourceIds,
            workLogicalAssetId,
            workLogicalAssetR2Key,
          )) {
            return 'Your work timeline was generated from a previous photo. Please regenerate.';
          }
        }
      }
    }
    return null;
  }

  String? validateMealScheduleDensity() {
    final eatingBlocks = blocks
        .where((b) => b.section == 'eating' && b.title.trim().isNotEmpty)
        .toList();
    if (eatingBlocks.isEmpty) return null;

    for (int day = 1; day <= 7; day++) {
      final dayMeals = eatingBlocks
          .where((b) => b.repeatDays.isEmpty || b.repeatDays.contains(day))
          .toList();

      if (dayMeals.length > 6) {
        return 'Maximum 6 meals allowed per day.';
      }

      dayMeals.sort((a, b) => a.startMinute.compareTo(b.startMinute));

      for (int i = 0; i < dayMeals.length - 1; i++) {
        final currentStart = dayMeals[i].startMinute;
        final nextStart = dayMeals[i + 1].startMinute;
        if (nextStart - currentStart < 120) {
          return 'Meals must be spaced at least 120 minutes apart.';
        }
      }
    }
    return null;
  }

  String? validateEatingSetup({
    NutritionTargets? targets,
    String? expectedFingerprint,
    EatingGenerationInputs? generationInputs,
  }) {
    if (_hasConfirmedSection('eating')) {
      if (eatingSetupPath == 'has_routine') {
        final eatingImport = latestImportForSection('Eating');
        if (eatingImport == null ||
            !eatingImport.hasUploadedAssetReference ||
            eatingImport.uploadedAssetId == null ||
            eatingImport.uploadedAssetId!.trim().isEmpty ||
            eatingImport.uploadedAssetR2Key == null ||
            eatingImport.uploadedAssetR2Key!.trim().isEmpty) {
          return 'Your meal routine was generated from a previous menu. Generate your meal routine first.';
        }
        final eatingAiBlocks = blocks.where(
          (b) => b.section == 'eating' && b.source == 'ai_import',
        );
        if (eatingAiBlocks.isEmpty) {
          return 'Your meal routine was generated from a previous menu. Generate your meal routine first.';
        }
        for (final block in eatingAiBlocks) {
          if (!provenanceContainsExactUploadIdentity(
            block.provenanceSourceIds,
            eatingImport.uploadedAssetId,
            eatingImport.uploadedAssetR2Key,
          )) {
            return 'Your meal routine was generated from a previous menu. Generate your meal routine first.';
          }
        }
      } else if (eatingSetupPath == 'create') {
        final confirmedEatingBlocks = blocks
            .where((b) => b.section == 'eating' && b.title.trim().isNotEmpty)
            .toList();

        if (confirmedEatingBlocks.isEmpty) {
          return 'Generate your meal routine first.';
        }

        // Source purity: ALL confirmed eating blocks must be ai_generated_meal_setup
        final hasNonGeneratedBlocks = confirmedEatingBlocks.any(
          (b) => b.source != 'ai_generated_meal_setup',
        );
        final generatedBlocks = confirmedEatingBlocks
            .where((b) => b.source == 'ai_generated_meal_setup')
            .toList();

        if (hasNonGeneratedBlocks || generatedBlocks.isEmpty) {
          return 'Your meal routine contains invalid meal items. Generate your meal routine first.';
        }

        // Plan version contract
        final version = eatingGeneratedPlanVersion;
        if (version == null ||
            version < BaseTimelineDraft.currentGate2EatingPlanVersion) {
          return 'Your saved meal plan uses the older weekly format. Please regenerate your meal routine.';
        }
        if (version > BaseTimelineDraft.currentGate2EatingPlanVersion) {
          return 'Your saved meal plan uses an unsupported newer format. Please regenerate your meal routine.';
        }

        if (isLegacyGeneratedEatingPlan(this)) {
          return 'Your saved meal plan uses the older weekly format. Please regenerate your meal routine.';
        }

        // Fingerprint contract: non-null, non-empty, matching expected
        final storedFingerprint = eatingGeneratedInputFingerprint?.trim();
        if (storedFingerprint == null || storedFingerprint.isEmpty) {
          return 'Your saved meal plan is missing generation verification. Generate your meal routine first.';
        }

        final expected =
            expectedFingerprint ??
            generationInputs?.computeFingerprint() ??
            computeEatingGeneratedInputFingerprint(targets: targets);
        if (storedFingerprint != expected) {
          return 'Your meal preferences changed. Generate the updated weekly routine first.';
        }

        final planError = validateGeneratedEatingWeeklyPlan(
          this,
          targets: targets,
        );
        if (planError != null) return planError;
      }
      return validateMealScheduleDensity();
    }
    if (eatingSetupPath == null) {
      return 'Choose how to set up eating.';
    }
    if (eatingSetupPath == 'has_routine') {
      return 'Generate your weekly meal routine first.';
    }
    return 'Generate your meal routine first.';
  }

  String? validateFixedSchedule() {
    final fixedBlocks = blocks.where((b) => b.section == 'fixed').toList();
    final sleep = blocks
        .where((b) => b.id == BaseTimelineDraft.fixedSleepId)
        .toList();
    final bath = blocks
        .where((b) => b.id == BaseTimelineDraft.fixedBathId)
        .toList();

    if (sleep.isEmpty) return 'Set sleep time.';
    if (bath.isEmpty) return 'Set bath time.';

    final sleepBlock = sleep.first;
    if (sleepBlock.startMinute == sleepBlock.endMinute) {
      return 'Sleep and wake time cannot be the same.';
    }

    final bathBlock = bath.first;
    if (bathBlock.endMinute <= bathBlock.startMinute) {
      return 'Bath end time must be after bath start time.';
    }

    if (sleepBlock.section != 'fixed' || bathBlock.section != 'fixed') {
      return 'Fixed blocks must be in the fixed section.';
    }

    for (final fixedBlock in fixedBlocks) {
      if (fixedBlock.id != BaseTimelineDraft.fixedSleepId &&
          fixedBlock.id != BaseTimelineDraft.fixedBathId) {
        if (fixedBlock.title.trim().isEmpty) {
          return 'Fixed block name is required.';
        }
        if (fixedBlock.endMinute <= fixedBlock.startMinute) {
          return 'End time must be after start time.';
        }
      }
      if (fixedBlock.blockType != TimelineBlockDraft.hardBlockKey) {
        return 'Fixed blocks must be non-negotiable.';
      }
      final repeatsEveryDay =
          fixedBlock.repeatDays.toSet().containsAll(const [
            1,
            2,
            3,
            4,
            5,
            6,
            7,
          ]) &&
          fixedBlock.repeatDays.length == 7;
      if (!repeatsEveryDay) {
        return 'Fixed blocks must repeat every day.';
      }
    }
    return null;
  }

  String computeSkinCareRecommendationFingerprint({
    String? countryCode,
    String? currencyCode,
  }) {
    if (skinCareSetupPath != 'no_products') return '';
    final normalizedProblems = _normalizedSkinCareFingerprintList(
      skinCareProblems,
    );
    final canonicalMap = <String, dynamic>{
      'mode': 'no_products',
      'faceAssetId': skinCareFacePhotoAssetId?.trim() ?? '',
      'faceR2Key': skinCareFacePhotoR2Key?.trim() ?? '',
      'skinType': _normalizedSkinCareFingerprintText(skinCareSkinType),
      'problems': normalizedProblems,
      'budget': _normalizedSkinCareFingerprintText(skinCareBudget),
      'preference': _normalizedSkinCareFingerprintText(skinCarePreference),
      'desiredApplicationsPerDay': skinCareDesiredApplicationsPerDay,
      'countryCode': (countryCode ?? skinCareRecommendationCountryCode ?? '')
          .trim()
          .toUpperCase(),
      'currencyCode': (currencyCode ?? skinCareRecommendationCurrencyCode ?? '')
          .trim()
          .toUpperCase(),
    };
    final jsonStr = jsonEncode(canonicalMap);
    return sha256.convert(utf8.encode(jsonStr)).toString();
  }

  String computeSkinCareRoutineFingerprint({
    String? countryCode,
    String? currencyCode,
  }) {
    if (skinCareSetupPath == 'has_products') {
      final canonicalProducts = skinCareReviewedProducts.isNotEmpty
          ? (skinCareReviewedProducts.map((p) => p.toMap()).toList()
              ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))))
          : _normalizedSkinCareFingerprintList(
              (skinCareProductNames ?? '').split(RegExp(r'[\n;,]+')),
            );
      final normalizedProblems = _normalizedSkinCareFingerprintList(
        skinCareProblems,
      );
      final canonicalMap = <String, dynamic>{
        'mode': 'has_products',
        'products': canonicalProducts,
        // Keep the editable projection in the fingerprint as an integrity
        // check. UI writes update this text and the canonical rich list
        // atomically, so a legacy or interrupted split state is always stale.
        'productText': _normalizedSkinCareFingerprintList(
          (skinCareProductNames ?? '').split(RegExp(r'[\n;,]+')),
        ),
        'productPhotoAssetId': skinCareProductPhotoAssetId?.trim() ?? '',
        'productPhotoR2Key': skinCareProductPhotoR2Key?.trim() ?? '',
        'skinType': _normalizedSkinCareFingerprintText(skinCareSkinType),
        'problems': normalizedProblems,
        'budget': _normalizedSkinCareFingerprintText(skinCareBudget),
        'preference': _normalizedSkinCareFingerprintText(skinCarePreference),
        'desiredApplicationsPerDay': skinCareDesiredApplicationsPerDay,
      };
      final jsonStr = jsonEncode(canonicalMap);
      return sha256.convert(utf8.encode(jsonStr)).toString();
    }
    if (skinCareSetupPath == 'no_products') {
      final recFingerprint =
          skinCareRecommendationFingerprint ??
          computeSkinCareRecommendationFingerprint(
            countryCode: countryCode,
            currencyCode: currencyCode,
          );
      final normalizedSelected = _normalizedSkinCareFingerprintList(
        skinCareSelectedProductNames,
      );
      final normalizedProblems = _normalizedSkinCareFingerprintList(
        skinCareProblems,
      );
      final canonicalMap = <String, dynamic>{
        'mode': 'no_products',
        'recFingerprint': recFingerprint,
        'selectedProducts': normalizedSelected,
        'desiredApplicationsPerDay': skinCareDesiredApplicationsPerDay,
        'skinType': _normalizedSkinCareFingerprintText(skinCareSkinType),
        'problems': normalizedProblems,
        'budget': _normalizedSkinCareFingerprintText(skinCareBudget),
        'preference': _normalizedSkinCareFingerprintText(skinCarePreference),
      };
      final jsonStr = jsonEncode(canonicalMap);
      return sha256.convert(utf8.encode(jsonStr)).toString();
    }
    return '';
  }

  /// A saved routine is current only when the same completion checks pass.
  bool isSkinCareRoutineCurrent(String uid) =>
      !skinCareSkipped &&
      skinCareSetupPath != 'skip' &&
      blocks.any((block) => block.section == 'skin_care') &&
      validateSkinCareSetup(uid) == null;

  String? validateSkinCareSetup(String uid) {
    if (skinCareSkipped || skinCareSetupPath == 'skip') return null;
    if (skinCareSetupPath == null) {
      return 'Build skin care routine or skip.';
    }

    final desired = _normalizeSkinCareDesiredApplicationsPerDay(
      skinCareDesiredApplicationsPerDay,
    );

    if (skinCareSetupPath == 'has_products') {
      final hasTyped = skinCareProductNames?.trim().isNotEmpty == true;
      final hasPhoto = _skinUploadFieldsAreCurrent(
        uid: uid,
        purpose: UploadedAssetPurpose.skinProducts,
        assetId: skinCareProductPhotoAssetId,
        r2Key: skinCareProductPhotoR2Key,
        status: skinCareProductPhotoStatus,
      );

      final hasPhotoReference =
          skinCareProductPhotoAssetId?.trim().isNotEmpty == true ||
          skinCareProductPhotoR2Key?.trim().isNotEmpty == true;
      if (hasPhotoReference && !hasPhoto) {
        return 'Your product photo is no longer current. Review your products again.';
      }

      if (!hasTyped && !hasPhoto) {
        return 'Add products or upload a photo to build your routine.';
      }

      if (skinCareReviewedProducts.isEmpty ||
          skinCareReviewedProducts.any((p) => p.displayName.trim().isEmpty)) {
        return 'Review your current products and build routine again.';
      }
      final expectedFingerprint = computeSkinCareRoutineFingerprint();
      if (skinCareRoutineFingerprint != expectedFingerprint ||
          !_skinCareBlocksMatchFingerprint(expectedFingerprint)) {
        return 'Your inputs have changed. Build routine again to update.';
      }

      final msg = _missingSkinCareRoutineMessage(desired);
      if (msg != null) return msg;

      for (final block in blocks.where((b) => b.section == 'skin_care')) {
        final blockErr = onboarding7ValidateEditedSkinCareBlock(this, block);
        if (blockErr != null) return blockErr;
      }

      return null;
    }

    if (skinCareSetupPath == 'no_products') {
      final hasPhoto = _skinUploadFieldsAreCurrent(
        uid: uid,
        purpose: UploadedAssetPurpose.skinFace,
        assetId: skinCareFacePhotoAssetId,
        r2Key: skinCareFacePhotoR2Key,
        status: skinCareFacePhotoStatus,
      );

      if (!hasPhoto) {
        return 'Add a face photo to personalize your product recommendations.';
      }

      if (skinCareSkinType == null ||
          skinCareProblems.isEmpty ||
          skinCareBudget == null) {
        return 'Complete your skin details before finding products.';
      }

      if (skinCareSelectedProductNames.isEmpty) {
        return 'Find and select products before building your routine.';
      }

      final recommendations = <String, SkinCareProductRecommendationDraft>{};
      for (final product in skinCareProductRecommendations) {
        if (product.name.trim().isEmpty ||
            product.brand.trim().isEmpty ||
            product.category.trim().isEmpty ||
            product.estimatedPrice.trim().isEmpty ||
            product.currencyCode.trim().isEmpty ||
            product.reason.trim().isEmpty) {
          continue;
        }
        recommendations[product.selectionKey] = product;
      }
      final categories = <String>{};
      final selectionKeys = skinCareSelectedProductNames
          .map(normalizeSkinCareSelectionKey)
          .toSet();
      for (final key in selectionKeys) {
        final product = recommendations[key];
        if (product == null) {
          return 'Selected products are no longer current. Find and select products again.';
        }
        if (!categories.add(product.canonicalCategory)) {
          return 'Select only one product per category.';
        }
      }
      for (final category in const ['cleanser', 'moisturizer', 'sunscreen']) {
        if (!categories.contains(category)) {
          return 'Select a $category before building your routine.';
        }
      }

      final expectedRecFingerprint = computeSkinCareRecommendationFingerprint();
      if (skinCareRecommendationFingerprint != expectedRecFingerprint) {
        return 'Skin details changed. Find products again to update recommendations.';
      }

      final expectedRoutineFingerprint = computeSkinCareRoutineFingerprint();
      if (skinCareRoutineFingerprint != expectedRoutineFingerprint ||
          !_skinCareBlocksMatchFingerprint(expectedRoutineFingerprint)) {
        return 'Selected products or frequency changed. Build routine again to update.';
      }

      final msg = _missingSkinCareRoutineMessage(desired);
      if (msg != null) return msg;

      for (final block in blocks.where((b) => b.section == 'skin_care')) {
        final blockErr = onboarding7ValidateEditedSkinCareBlock(this, block);
        if (blockErr != null) return blockErr;
      }

      return null;
    }

    return 'Build skin care routine or skip.';
  }

  bool _skinUploadFieldsAreCurrent({
    required String uid,
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
          ownerUid: uid,
          sourceFeature: OnboardingDraft.sourceOnboarding,
          purpose: purpose,
          r2Key: key,
          status: parsedStatus,
          uid: uid,
          expectedPurpose: purpose,
        ) ||
        legacySkinCareUploadHasOwnedExactIdentity(
          assetId: id,
          ownerUid: uid,
          r2Key: key,
          status: parsedStatus,
          uid: uid,
        );
  }

  bool _skinCareBlocksMatchFingerprint(String fingerprint) {
    final token = 'skin-care-generation:$fingerprint';
    final generated = blocks.where((block) => block.section == 'skin_care');
    return generated.isNotEmpty &&
        generated.every((block) => block.provenanceSourceIds.contains(token));
  }

  List<TimelineBlockDraft> confirmedBlocksForSection(String section) {
    return blocks
        .where(
          (block) =>
              block.section == section &&
              !block.needsTimeConfirmation &&
              block.title.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  bool hasConfirmedSection(String section) {
    return _hasConfirmedSection(section);
  }

  bool hasFullDailySkinCareRoutine() {
    final desired = _normalizeSkinCareDesiredApplicationsPerDay(
      skinCareDesiredApplicationsPerDay,
    );
    return _missingSkinCareRoutineMessage(desired) == null;
  }

  String? _missingSkinCareRoutineMessage(int desired) {
    for (final day in const [1, 2, 3, 4, 5, 6, 7]) {
      final count = _skinCareRoutineCountForDay(day);
      if (count < desired) {
        return '${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][day - 1]} has $count of $desired skin-care routines. Add or restore one routine.';
      }
    }
    return null;
  }

  int _skinCareRoutineCountForDay(int day) {
    return blocks
        .where(
          (block) =>
              block.section == 'skin_care' &&
              !block.needsTimeConfirmation &&
              block.title.trim().isNotEmpty &&
              (block.skincareSteps.isNotEmpty ||
                  block.skincareProducts.isNotEmpty) &&
              block.repeatDays.contains(day),
        )
        .length;
  }

  PendingFutureImportDraft? latestImportForSection(String sectionLabel) {
    for (final entry in pendingFutureImports.reversed) {
      if (entry.section == sectionLabel) return entry;
    }
    return null;
  }

  bool sectionNeedsImportReview(String sectionLabel) {
    return pendingFutureImports.reversed.any(
      (entry) =>
          entry.section == sectionLabel &&
          entry.status != PendingFutureImportDraft.appliedStatus &&
          (entry.hasUploadedAssetReference || entry.parsedBlocks.isNotEmpty),
    );
  }

  bool _hasConfirmedSection(String section) {
    return blocks.any(
      (block) =>
          block.section == section &&
          !block.needsTimeConfirmation &&
          block.title.trim().isNotEmpty,
    );
  }

  static bool _hasSleepBlock(List<TimelineBlockDraft> blocks) {
    return blocks.any((block) {
      final title = block.title.toLowerCase();
      return block.section == 'fixed' &&
          !block.needsTimeConfirmation &&
          (block.id == fixedSleepId ||
              title.contains('sleep') ||
              title.contains('bed'));
    });
  }

  static bool _hasBathBlock(List<TimelineBlockDraft> blocks) {
    return blocks.any((block) {
      final title = block.title.toLowerCase();
      return block.section == 'fixed' &&
          !block.needsTimeConfirmation &&
          (block.id == fixedBathId ||
              title.contains('bath') ||
              title.contains('shower'));
    });
  }

  static List<_TimelineWindowDraft> _windowsFor(TimelineBlockDraft block) {
    final windows = <_TimelineWindowDraft>[];
    final crossesMidnight =
        block.crossesMidnight || block.endMinute <= block.startMinute;
    for (final day in block.repeatDays) {
      if (crossesMidnight) {
        windows.add(
          _TimelineWindowDraft(
            day: day,
            startMinute: block.startMinute,
            endMinute: 24 * 60,
          ),
        );
        windows.add(
          _TimelineWindowDraft(
            day: day == 7 ? 1 : day + 1,
            startMinute: 0,
            endMinute: block.endMinute,
          ),
        );
      } else {
        windows.add(
          _TimelineWindowDraft(
            day: day,
            startMinute: block.startMinute,
            endMinute: block.endMinute,
          ),
        );
      }
    }
    return windows;
  }
}

class _TimelineWindowDraft {
  final int day;
  final int startMinute;
  final int endMinute;

  const _TimelineWindowDraft({
    required this.day,
    required this.startMinute,
    required this.endMinute,
  });
}

class BaseTimelineInvalidationResult {
  final BaseTimelineDraft timeline;
  final List<String> warnings;

  const BaseTimelineInvalidationResult({
    required this.timeline,
    required this.warnings,
  });
}

int normalizeMealsPerDay(int? value) {
  final count = value ?? 4;
  if (count <= 3) return 3;
  if (count >= 5) return 5;
  return 4;
}

bool looksLikeNonDishMealToken(String value) {
  final lower = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s/-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (lower.isEmpty || !RegExp(r'[a-z]').hasMatch(lower)) return true;
  if (RegExp(r'\b(meal|part|snack|dish|item)\s*\d+\b').hasMatch(lower)) {
    return true;
  }
  if (RegExp(
    r'\b(breakfast|lunch|dinner|snack)\s+(item|meal|food|dish)\b',
  ).hasMatch(lower)) {
    return true;
  }
  const generic = {
    'breakfast',
    'lunch',
    'brunch',
    'supper',
    'snack',
    'snacks',
    'dinner',
    'extra snack',
    'extra-snack',
    'meal',
    'meals',
    'menu',
    'mess menu',
    'mess item',
    'food',
    'item',
    'items',
    'routine',
  };
  return generic.contains(lower);
}

String normalizeDish(String d) =>
    d.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String mealSignature(List<String> dishes) {
  final normalized =
      dishes.map(normalizeDish).where((d) => d.isNotEmpty).toList()..sort();
  return normalized.join('|');
}

bool isLegacyGeneratedEatingPlan(BaseTimelineDraft base) {
  final eatingBlocks = base.blocks
      .where(
        (b) => b.section == 'eating' && b.source == 'ai_generated_meal_setup',
      )
      .toList();
  if (eatingBlocks.isEmpty) return false;
  if (base.eatingGeneratedPlanVersion != null &&
      base.eatingGeneratedPlanVersion! <
          BaseTimelineDraft.currentGate2EatingPlanVersion) {
    return true;
  }
  return base.eatingGeneratedPlanVersion == null ||
      eatingBlocks.any((b) => b.repeatDays.length > 1) ||
      eatingBlocks.length < 21;
}

String? validateGeneratedEatingWeeklyPlan(
  BaseTimelineDraft base, {
  NutritionTargets? targets,
}) {
  final eatingBlocks = base.blocks
      .where(
        (b) => b.section == 'eating' && b.source == 'ai_generated_meal_setup',
      )
      .toList();

  if (eatingBlocks.isEmpty) {
    return 'Generate your meal routine first.';
  }

  final mealsPerDay = normalizeMealsPerDay(base.mealsPerDay);
  final expectedSlotIds = switch (mealsPerDay) {
    4 => const ['breakfast', 'lunch', 'afternoon_snack', 'dinner'],
    5 => const [
      'breakfast',
      'morning_snack',
      'lunch',
      'afternoon_snack',
      'dinner',
    ],
    _ => const ['breakfast', 'lunch', 'dinner'],
  };

  final expectedCount = 7 * expectedSlotIds.length;
  if (eatingBlocks.length != expectedCount) {
    return 'Generated meal plan is missing required meals for all 7 days.';
  }

  final daySlotCoverage = <String>{};
  for (final block in eatingBlocks) {
    if (block.repeatDays.length != 1) {
      return 'Generated meal plan contains invalid multi-day schedule blocks.';
    }
    final day = block.repeatDays.first;
    if (day < 1 || day > 7) {
      return 'Generated meal plan contains invalid day numbers.';
    }
    final slot = block.mealSlot?.trim().toLowerCase();
    if (slot == null || !expectedSlotIds.contains(slot)) {
      return 'Generated meal plan contains unrecognized meal slots.';
    }
    final key = '$day-$slot';
    if (!daySlotCoverage.add(key)) {
      return 'Generated meal plan contains duplicate meal slots.';
    }
  }

  for (var day = 1; day <= 7; day++) {
    for (final slot in expectedSlotIds) {
      if (!daySlotCoverage.contains('$day-$slot')) {
        return 'Generated meal plan is missing required meals for all 7 days.';
      }
    }
  }

  for (final block in eatingBlocks) {
    final validDishes = block.dishes
        .map((d) => d.trim())
        .where((d) => d.length >= 2 && !looksLikeNonDishMealToken(d))
        .toList();
    if (validDishes.length < 2) {
      return 'Generated meal plan contains meals without specific dishes.';
    }
  }

  for (final block in eatingBlocks) {
    if (block.calories == null ||
        block.calories! <= 0 ||
        block.protein == null ||
        block.protein! <= 0) {
      return 'Generated meal plan is missing nutrition estimates.';
    }
  }

  if (targets != null && targets.hasBodyBasics) {
    final targetCal = targets.targetCalories;
    final targetProt = targets.proteinTarget;

    for (var day = 1; day <= 7; day++) {
      final dayBlocks = eatingBlocks.where((b) => b.repeatDays.first == day);
      final dayCalories = dayBlocks.fold<double>(
        0.0,
        (acc, b) => acc + (b.calories ?? 0.0),
      );
      final dayProtein = dayBlocks.fold<double>(
        0.0,
        (acc, b) => acc + (b.protein ?? 0.0),
      );

      if (targetCal != null && targetCal > 0) {
        final diff = (dayCalories - targetCal).abs() / targetCal;
        if (diff > 0.15) {
          return 'Daily calorie totals deviate significantly from your target.';
        }
      }

      if (targetProt != null && targetProt > 0) {
        final diff = (dayProtein - targetProt).abs() / targetProt;
        if (diff > 0.20) {
          return 'Daily protein totals deviate significantly from your target.';
        }
      }
    }
  }

  // Same-slot diversity across days: all 7 days must have unique dish combinations for each slot
  for (final slot in expectedSlotIds) {
    final distinctDishSets = <String>{};
    for (var day = 1; day <= 7; day++) {
      final block = eatingBlocks.firstWhere(
        (b) =>
            b.repeatDays.first == day &&
            b.mealSlot?.trim().toLowerCase() == slot,
      );
      final signature = mealSignature(block.dishes);
      distinctDishSets.add(signature);
    }
    if (distinctDishSets.length < 7) {
      return 'Generated meal plan lacks weekly variety across days.';
    }
  }

  // Daily menu diversity: all 7 complete day menus must be unique
  final distinctDailyMenus = <String>{};
  for (var day = 1; day <= 7; day++) {
    final dayDishes = <String>[];
    for (final slot in expectedSlotIds) {
      final block = eatingBlocks.firstWhere(
        (b) =>
            b.repeatDays.first == day &&
            b.mealSlot?.trim().toLowerCase() == slot,
      );
      dayDishes.add('$slot:${mealSignature(block.dishes)}');
    }
    distinctDailyMenus.add(dayDishes.join('::'));
  }
  if (distinctDailyMenus.length < 7) {
    return 'Generated meal plan lacks weekly variety across days.';
  }

  return null;
}

class EatingGenerationInputs {
  final int contractVersion;
  final double? heightCm;
  final double? weightKg;
  final int? estimatedAge;
  final String? gender;
  final String? exerciseLevel;
  final String? lifeRole;
  final double? bmi;
  final int? estimatedBmr;
  final int? estimatedMaintenanceCalories;
  final String bodyGoal;
  final String targetMode;
  final int? targetCalories;
  final double? proteinTarget;
  final String? foodType;
  final String? eatingMode;
  final String? foodStyleCustomText;
  final int mealsPerDay;
  final int breakfastMinute;
  final int? morningSnackMinute;
  final int lunchMinute;
  final int? afternoonSnackMinute;
  final int dinnerMinute;
  final String? country;

  const EatingGenerationInputs({
    required this.contractVersion,
    required this.heightCm,
    required this.weightKg,
    required this.estimatedAge,
    required this.gender,
    required this.exerciseLevel,
    required this.lifeRole,
    required this.bmi,
    required this.estimatedBmr,
    required this.estimatedMaintenanceCalories,
    required this.bodyGoal,
    required this.targetMode,
    required this.targetCalories,
    required this.proteinTarget,
    required this.foodType,
    required this.eatingMode,
    required this.foodStyleCustomText,
    required this.mealsPerDay,
    required this.breakfastMinute,
    required this.morningSnackMinute,
    required this.lunchMinute,
    required this.afternoonSnackMinute,
    required this.dinnerMinute,
    required this.country,
  });

  factory EatingGenerationInputs.fromDraft(
    OnboardingDraft draft, {
    NutritionTargets? targets,
  }) {
    final t = targets ?? draft.canonicalNutritionTargets();
    final base = draft.baseTimeline;
    final meals = normalizeMealsPerDay(base.mealsPerDay);
    final goal =
        (base.mealPlanningGoal != null &&
            base.mealPlanningGoal!.trim().isNotEmpty)
        ? base.mealPlanningGoal!
        : t.bodyGoal;
    final targetMode = switch (goal.trim().toLowerCase()) {
      'gain' => 'mild_surplus',
      'lose' => 'mild_deficit',
      _ => 'maintenance',
    };

    return EatingGenerationInputs(
      contractVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
      heightCm: t.heightCm ?? draft.bodyBasics.heightCm,
      weightKg: t.weightKg ?? draft.bodyBasics.weightKg,
      estimatedAge: t.estimatedAge,
      gender: t.gender ?? draft.bodyBasics.gender,
      exerciseLevel: t.exerciseLevel ?? draft.lifeRole.exerciseLevel,
      lifeRole: t.lifeRole ?? draft.lifeRole.lifeRole,
      bmi: t.bmi,
      estimatedBmr: t.estimatedBmr,
      estimatedMaintenanceCalories: t.estimatedMaintenanceCalories,
      bodyGoal: goal,
      targetMode: targetMode,
      targetCalories: t.targetCalories,
      proteinTarget: t.proteinTarget,
      foodType: (base.foodType != null && base.foodType!.trim().isNotEmpty)
          ? base.foodType!.trim().toLowerCase()
          : 'mixed',
      eatingMode:
          (base.eatingMode != null && base.eatingMode!.trim().isNotEmpty)
          ? base.eatingMode!.trim().toLowerCase()
          : 'india',
      foodStyleCustomText: base.foodStyleCustomText,
      mealsPerDay: meals,
      breakfastMinute: base.breakfastMinute ?? 480,
      morningSnackMinute: meals == 5 ? (base.extraSnackMinute ?? 660) : null,
      lunchMinute: base.lunchMinute ?? 780,
      afternoonSnackMinute: (meals == 4 || meals == 5)
          ? (base.snackMinute ?? 1020)
          : null,
      dinnerMinute: base.dinnerMinute ?? 1230,
      country: null,
    );
  }

  factory EatingGenerationInputs.fromTimeline(
    BaseTimelineDraft base, {
    NutritionTargets? targets,
    String? lifeRole,
    String? country,
  }) {
    final t = targets ?? NutritionTargets.empty;
    final meals = normalizeMealsPerDay(base.mealsPerDay);
    final goal =
        (base.mealPlanningGoal != null &&
            base.mealPlanningGoal!.trim().isNotEmpty)
        ? base.mealPlanningGoal!
        : t.bodyGoal;
    final targetMode = switch (goal.trim().toLowerCase()) {
      'gain' => 'mild_surplus',
      'lose' => 'mild_deficit',
      _ => 'maintenance',
    };

    return EatingGenerationInputs(
      contractVersion: BaseTimelineDraft.currentGate2EatingPlanVersion,
      heightCm: t.heightCm,
      weightKg: t.weightKg,
      estimatedAge: t.estimatedAge,
      gender: t.gender,
      exerciseLevel: t.exerciseLevel,
      lifeRole: t.lifeRole ?? lifeRole,
      bmi: t.bmi,
      estimatedBmr: t.estimatedBmr,
      estimatedMaintenanceCalories: t.estimatedMaintenanceCalories,
      bodyGoal: goal,
      targetMode: targetMode,
      targetCalories: t.targetCalories,
      proteinTarget: t.proteinTarget,
      foodType: (base.foodType != null && base.foodType!.trim().isNotEmpty)
          ? base.foodType!.trim().toLowerCase()
          : 'mixed',
      eatingMode:
          (base.eatingMode != null && base.eatingMode!.trim().isNotEmpty)
          ? base.eatingMode!.trim().toLowerCase()
          : 'india',
      foodStyleCustomText: base.foodStyleCustomText,
      mealsPerDay: meals,
      breakfastMinute: base.breakfastMinute ?? 480,
      morningSnackMinute: meals == 5 ? (base.extraSnackMinute ?? 660) : null,
      lunchMinute: base.lunchMinute ?? 780,
      afternoonSnackMinute: (meals == 4 || meals == 5)
          ? (base.snackMinute ?? 1020)
          : null,
      dinnerMinute: base.dinnerMinute ?? 1230,
      country: country,
    );
  }

  EatingGenerationInputs copyWith({
    int? contractVersion,
    double? heightCm,
    double? weightKg,
    int? estimatedAge,
    String? gender,
    String? exerciseLevel,
    String? lifeRole,
    double? bmi,
    int? estimatedBmr,
    int? estimatedMaintenanceCalories,
    String? bodyGoal,
    String? targetMode,
    int? targetCalories,
    double? proteinTarget,
    String? foodType,
    String? eatingMode,
    String? foodStyleCustomText,
    int? mealsPerDay,
    int? breakfastMinute,
    int? morningSnackMinute,
    int? lunchMinute,
    int? afternoonSnackMinute,
    int? dinnerMinute,
    String? country,
  }) {
    return EatingGenerationInputs(
      contractVersion: contractVersion ?? this.contractVersion,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      estimatedAge: estimatedAge ?? this.estimatedAge,
      gender: gender ?? this.gender,
      exerciseLevel: exerciseLevel ?? this.exerciseLevel,
      lifeRole: lifeRole ?? this.lifeRole,
      bmi: bmi ?? this.bmi,
      estimatedBmr: estimatedBmr ?? this.estimatedBmr,
      estimatedMaintenanceCalories:
          estimatedMaintenanceCalories ?? this.estimatedMaintenanceCalories,
      bodyGoal: bodyGoal ?? this.bodyGoal,
      targetMode: targetMode ?? this.targetMode,
      targetCalories: targetCalories ?? this.targetCalories,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      foodType: foodType ?? this.foodType,
      eatingMode: eatingMode ?? this.eatingMode,
      foodStyleCustomText: foodStyleCustomText ?? this.foodStyleCustomText,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      breakfastMinute: breakfastMinute ?? this.breakfastMinute,
      morningSnackMinute: morningSnackMinute ?? this.morningSnackMinute,
      lunchMinute: lunchMinute ?? this.lunchMinute,
      afternoonSnackMinute: afternoonSnackMinute ?? this.afternoonSnackMinute,
      dinnerMinute: dinnerMinute ?? this.dinnerMinute,
      country: country ?? this.country,
    );
  }

  Map<String, dynamic> toWorkerParams() {
    final mealTimes = <String, int>{
      'breakfast': breakfastMinute,
      'morning_snack': ?morningSnackMinute,
      'lunch': lunchMinute,
      'afternoon_snack': ?afternoonSnackMinute,
      'dinner': dinnerMinute,
    };

    return {
      'bodyGoal': bodyGoal,
      'eatingMode': eatingMode,
      'foodType': foodType,
      'foodStyleCustomText': foodStyleCustomText,
      'mealsPerDay': mealsPerDay,
      'targetCalories': targetCalories,
      'proteinTarget': proteinTarget,
      'estimatedBmr': estimatedBmr,
      'breakfastMinute': breakfastMinute,
      'lunchMinute': lunchMinute,
      'dinnerMinute': dinnerMinute,
      'snackMinute': afternoonSnackMinute,
      'extraSnackMinute': morningSnackMinute,
      'mealTimes': mealTimes,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'age': estimatedAge,
      'gender': gender,
      'bmi': bmi,
      'estimatedMaintenanceCalories': estimatedMaintenanceCalories,
      'targetMode': targetMode,
      'lifestyle': lifeRole,
      'country': country,
    };
  }

  String computeFingerprint() {
    final normLifeRole = (lifeRole ?? '').trim().toLowerCase();
    final normExercise = (exerciseLevel ?? '').trim().toLowerCase();
    final normGender = (gender ?? '').trim().toLowerCase();
    final normCountry = (country ?? '').trim().toLowerCase();
    final normGoal = bodyGoal.trim().toLowerCase();
    final normTargetMode = targetMode.trim().toLowerCase();
    final normType = (foodType ?? '').trim().toLowerCase();
    final normMode = (eatingMode ?? '').trim().toLowerCase();
    final normCustom = (foodStyleCustomText ?? '').trim().toLowerCase();

    return 'v$contractVersion'
        '|h:${heightCm != null ? heightCm!.toStringAsFixed(1) : "none"}'
        '|w:${weightKg != null ? weightKg!.toStringAsFixed(1) : "none"}'
        '|age:${estimatedAge ?? "none"}'
        '|gen:$normGender'
        '|ex:$normExercise'
        '|role:$normLifeRole'
        '|bmi:${bmi != null ? bmi!.toStringAsFixed(1) : "none"}'
        '|bmr:${estimatedBmr ?? "none"}'
        '|maint:${estimatedMaintenanceCalories ?? "none"}'
        '|goal:$normGoal'
        '|tmode:$normTargetMode'
        '|cal:${targetCalories?.round() ?? 0}'
        '|prot:${proteinTarget?.round() ?? 0}'
        '|type:$normType'
        '|mode:$normMode'
        '|custom:$normCustom'
        '|meals:$mealsPerDay'
        '|b:$breakfastMinute'
        '|ms:${morningSnackMinute ?? 0}'
        '|l:$lunchMinute'
        '|as:${afternoonSnackMinute ?? 0}'
        '|d:$dinnerMinute'
        '|c:$normCountry';
  }
}

class PendingFutureImportDraft {
  static const pendingStatus = 'pending';
  static const parsedStatus = 'parsed';
  static const needsReviewStatus = 'needs_review';
  static const appliedStatus = 'applied';
  static const errorStatus = 'error';

  final String id;
  final String section;
  final String mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? pastedText;
  final String? uploadPlaceholderPath;
  final String? uploadedAssetId;
  final String? uploadedAssetR2Key;
  final String? uploadedAssetStatus;
  final String? errorMessage;
  final List<TimelineBlockDraft> parsedBlocks;
  final double? confidence;
  final bool userVerified;
  final bool userEdited;

  const PendingFutureImportDraft({
    required this.id,
    required this.section,
    required this.mode,
    required this.createdAt,
    DateTime? updatedAt,
    this.status = pendingStatus,
    this.pastedText,
    this.uploadPlaceholderPath,
    this.uploadedAssetId,
    this.uploadedAssetR2Key,
    this.uploadedAssetStatus,
    this.errorMessage,
    this.parsedBlocks = const [],
    this.confidence,
    this.userVerified = false,
    this.userEdited = false,
  }) : updatedAt = updatedAt ?? createdAt;

  bool get hasUploadedAssetReference {
    final hasStatus = uploadedAssetStatus == 'uploaded';
    return hasStatus ||
        uploadedAssetId?.trim().isNotEmpty == true ||
        uploadedAssetR2Key?.trim().isNotEmpty == true;
  }

  factory PendingFutureImportDraft.fromMap(Map<String, dynamic> map) {
    return PendingFutureImportDraft(
      id: map['id'] as String? ?? '',
      section: map['section'] as String? ?? '',
      mode: map['mode'] as String? ?? '',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDateTime(map['updatedAt']) ??
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: map['status'] as String? ?? pendingStatus,
      pastedText: map['pastedText'] as String?,
      uploadPlaceholderPath: map['uploadPlaceholderPath'] as String?,
      uploadedAssetId: map['uploadedAssetId'] as String?,
      uploadedAssetR2Key: map['uploadedAssetR2Key'] as String?,
      uploadedAssetStatus: map['uploadedAssetStatus'] as String?,
      errorMessage: map['errorMessage'] as String?,
      parsedBlocks: _readList(
        map['parsedBlocks'],
        (value) => TimelineBlockDraft.fromMap(value),
      ),
      confidence: (map['confidence'] as num?)?.toDouble(),
      userVerified: map['userVerified'] as bool? ?? false,
      userEdited: map['userEdited'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'section': section,
    'mode': mode,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status,
    'pastedText': pastedText,
    'uploadPlaceholderPath': uploadPlaceholderPath,
    'uploadedAssetId': uploadedAssetId,
    'uploadedAssetR2Key': uploadedAssetR2Key,
    'uploadedAssetStatus': uploadedAssetStatus,
    'errorMessage': errorMessage,
    'parsedBlocks': parsedBlocks.map((block) => block.toMap()).toList(),
    'confidence': confidence,
    'userVerified': userVerified,
    'userEdited': userEdited,
  };

  PendingFutureImportDraft copyWith({
    String? id,
    String? section,
    String? mode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? pastedText,
    String? uploadPlaceholderPath,
    String? uploadedAssetId,
    String? uploadedAssetR2Key,
    String? uploadedAssetStatus,
    String? errorMessage,
    List<TimelineBlockDraft>? parsedBlocks,
    double? confidence,
    bool? userVerified,
    bool? userEdited,
    bool clearUploadedAssetReference = false,
    bool clearErrorMessage = false,
  }) {
    return PendingFutureImportDraft(
      id: id ?? this.id,
      section: section ?? this.section,
      mode: mode ?? this.mode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      pastedText: pastedText ?? this.pastedText,
      uploadPlaceholderPath:
          uploadPlaceholderPath ?? this.uploadPlaceholderPath,
      uploadedAssetId: clearUploadedAssetReference
          ? null
          : (uploadedAssetId ?? this.uploadedAssetId),
      uploadedAssetR2Key: clearUploadedAssetReference
          ? null
          : (uploadedAssetR2Key ?? this.uploadedAssetR2Key),
      uploadedAssetStatus: clearUploadedAssetReference
          ? null
          : (uploadedAssetStatus ?? this.uploadedAssetStatus),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      parsedBlocks: parsedBlocks ?? this.parsedBlocks,
      confidence: confidence ?? this.confidence,
      userVerified: userVerified ?? this.userVerified,
      userEdited: userEdited ?? this.userEdited,
    );
  }
}

class TimelineBlockDraft {
  static const hardBlockKey = 'hard_block';
  static const softBlockKey = 'soft_block';
  static const flexibleTaskKey = 'flexible_task';
  static const checkInKey = 'check_in';

  final String id;
  final String section;
  final String title;
  final int startMinute;
  final int endMinute;
  final List<int> repeatDays;
  final String? location;
  final String blockType;
  final String source;
  final bool needsTimeConfirmation;
  final bool crossesMidnight;
  final bool endsNextDay;
  final String? mealCategory;
  final String? mealSlot;
  final List<String> dishes;
  final double? calories;
  final double? protein;
  final List<String> skincareProducts;
  final List<String> skincareSteps;
  final List<String> skincareMissingItems;
  final String? skincareSlotLabel;
  final List<String> provenanceSourceIds;

  const TimelineBlockDraft({
    required this.id,
    required this.section,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    required this.repeatDays,
    this.location,
    required this.blockType,
    this.source = 'manual',
    this.needsTimeConfirmation = false,
    this.crossesMidnight = false,
    this.endsNextDay = false,
    this.mealCategory,
    this.mealSlot,
    this.dishes = const [],
    this.calories,
    this.protein,
    this.skincareProducts = const [],
    this.skincareSteps = const [],
    this.skincareMissingItems = const [],
    this.skincareSlotLabel,
    this.provenanceSourceIds = const [],
  });

  factory TimelineBlockDraft.fromMap(Map<String, dynamic> map) {
    return TimelineBlockDraft(
      id: map['id'] as String? ?? '',
      section: map['section'] as String? ?? 'fixed',
      title: map['title'] as String? ?? '',
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      repeatDays: _readIntList(map['repeatDays']),
      location: map['location'] as String?,
      blockType: map['blockType'] as String? ?? softBlockKey,
      source: map['source'] as String? ?? 'manual',
      needsTimeConfirmation: map['needsTimeConfirmation'] as bool? ?? false,
      crossesMidnight: map['crossesMidnight'] as bool? ?? false,
      endsNextDay: map['endsNextDay'] as bool? ?? false,
      mealCategory: map['mealCategory'] as String?,
      mealSlot: map['mealSlot'] as String?,
      dishes: _readStringList(map['dishes']),
      calories: (map['calories'] as num?)?.toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      skincareProducts: _readStringList(map['skincareProducts']),
      skincareSteps: _readStringList(map['skincareSteps']),
      skincareMissingItems: _readStringList(map['skincareMissingItems']),
      skincareSlotLabel: map['skincareSlotLabel'] as String?,
      provenanceSourceIds: _readStringList(map['provenanceSourceIds']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'section': section,
    'title': title,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'repeatDays': repeatDays,
    'location': location,
    'blockType': blockType,
    'source': source,
    'needsTimeConfirmation': needsTimeConfirmation,
    'crossesMidnight': crossesMidnight,
    'endsNextDay': endsNextDay,
    'mealCategory': mealCategory,
    'mealSlot': mealSlot,
    'dishes': dishes,
    'calories': calories,
    'protein': protein,
    'skincareProducts': skincareProducts,
    'skincareSteps': skincareSteps,
    'skincareMissingItems': skincareMissingItems,
    'skincareSlotLabel': skincareSlotLabel,
    'provenanceSourceIds': provenanceSourceIds,
  };

  TimelineBlockDraft copyWith({
    String? id,
    String? section,
    String? title,
    int? startMinute,
    int? endMinute,
    List<int>? repeatDays,
    String? location,
    String? blockType,
    String? source,
    bool? needsTimeConfirmation,
    bool? crossesMidnight,
    bool? endsNextDay,
    String? mealCategory,
    String? mealSlot,
    List<String>? dishes,
    double? calories,
    double? protein,
    List<String>? skincareProducts,
    List<String>? skincareSteps,
    List<String>? skincareMissingItems,
    String? skincareSlotLabel,
    List<String>? provenanceSourceIds,
  }) {
    return TimelineBlockDraft(
      id: id ?? this.id,
      section: section ?? this.section,
      title: title ?? this.title,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      repeatDays: repeatDays ?? this.repeatDays,
      location: location ?? this.location,
      blockType: blockType ?? this.blockType,
      source: source ?? this.source,
      needsTimeConfirmation:
          needsTimeConfirmation ?? this.needsTimeConfirmation,
      crossesMidnight: crossesMidnight ?? this.crossesMidnight,
      endsNextDay: endsNextDay ?? this.endsNextDay,
      mealCategory: mealCategory ?? this.mealCategory,
      mealSlot: mealSlot ?? this.mealSlot,
      dishes: dishes ?? this.dishes,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      skincareProducts: skincareProducts ?? this.skincareProducts,
      skincareSteps: skincareSteps ?? this.skincareSteps,
      skincareMissingItems: skincareMissingItems ?? this.skincareMissingItems,
      skincareSlotLabel: skincareSlotLabel ?? this.skincareSlotLabel,
      provenanceSourceIds: provenanceSourceIds ?? this.provenanceSourceIds,
    );
  }

  int get durationMinutes {
    if (crossesMidnight || endsNextDay || endMinute <= startMinute) {
      return (24 * 60 - startMinute) + endMinute;
    }
    return endMinute - startMinute;
  }
}

ConflictScheduleDescriptor timelineScheduleDescriptor(
  TimelineBlockDraft block, {
  required String ownerUid,
  required String timezoneId,
  String projectionId = '',
  String? projectedItemId,
}) {
  final normalizedTitle = block.title.trim().toLowerCase();
  final category =
      block.id == BaseTimelineDraft.fixedSleepId || normalizedTitle == 'sleep'
      ? ConflictSemanticCategory.sleep
      : switch (block.section) {
          'classes' => ConflictSemanticCategory.classBlock,
          'job_work_business' => ConflictSemanticCategory.job,
          'eating' => ConflictSemanticCategory.meal,
          'fixed' => ConflictSemanticCategory.fixed,
          _ => ConflictSemanticCategory.other,
        };
  final repeatDays = block.repeatDays.toSet().toList()..sort();
  return ConflictScheduleDescriptor(
    ownerUid: ownerUid,
    itemId: projectedItemId ?? block.id,
    sourceItemId: block.id,
    startMinute: block.startMinute,
    endMinute: block.endMinute,
    crossesMidnight: block.crossesMidnight,
    endsNextDay: block.endsNextDay,
    dateKey: '',
    endDateKey: '',
    repeatRule: repeatDays.length == 7 ? 'daily' : 'weekly',
    repeatDays: repeatDays,
    blockType: block.blockType,
    hardBlock: block.blockType == TimelineBlockDraft.hardBlockKey,
    category: category,
    timezoneId: timezoneId,
    source: block.source,
    activeStatus: 'active',
    projectionId: projectionId,
    // Source-draft acceptance is tied to schedule content. The onboarding
    // draft revision also advances for lifecycle-only writes (save/complete),
    // so including it would revoke an unchanged accepted overlap on restart.
    revision: 1,
    schemaVersion: OnboardingDraft.schemaVersion,
  );
}

class TimelineConflictDraft {
  final String key;
  final String firstBlockId;
  final String secondBlockId;
  final String firstTitle;
  final String secondTitle;
  final int day;
  final bool isHardConflict;
  final bool accepted;
  final String conflictType;
  final bool blocking;
  final bool canKeepBoth;
  final String publicReason;

  const TimelineConflictDraft({
    required this.key,
    required this.firstBlockId,
    required this.secondBlockId,
    required this.firstTitle,
    required this.secondTitle,
    required this.day,
    required this.isHardConflict,
    required this.accepted,
    this.conflictType = 'compatibleOverlap',
    bool? blocking,
    this.canKeepBoth = false,
    this.publicReason = '',
  }) : blocking = blocking ?? (isHardConflict && !accepted);

  bool get isBlocking => blocking && !accepted;

  factory TimelineConflictDraft.fromMap(Map<String, dynamic> map) {
    return TimelineConflictDraft(
      key: map['key'] as String? ?? '',
      firstBlockId: map['firstBlockId'] as String? ?? '',
      secondBlockId: map['secondBlockId'] as String? ?? '',
      firstTitle: map['firstTitle'] as String? ?? '',
      secondTitle: map['secondTitle'] as String? ?? '',
      day: (map['day'] as num?)?.toInt() ?? 1,
      isHardConflict: map['isHardConflict'] as bool? ?? false,
      accepted: map['accepted'] as bool? ?? false,
      conflictType: map['conflictType'] as String? ?? 'compatibleOverlap',
      blocking: map['blocking'] as bool?,
      canKeepBoth: map['canKeepBoth'] as bool? ?? false,
      publicReason: map['publicReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'firstBlockId': firstBlockId,
    'secondBlockId': secondBlockId,
    'firstTitle': firstTitle,
    'secondTitle': secondTitle,
    'day': day,
    'isHardConflict': isHardConflict,
    'accepted': accepted,
    'conflictType': conflictType,
    'blocking': blocking,
    'canKeepBoth': canKeepBoth,
    'publicReason': publicReason,
  };

  static String keyFor(String firstId, String secondId, int day) {
    final ids = [firstId, secondId]..sort();
    return '$day|${Uri.encodeComponent(ids[0])}|${Uri.encodeComponent(ids[1])}';
  }

  static Set<String>? blockIdsForKey(String key) {
    final parts = key.split('|');
    if (parts.length == 3) {
      return {Uri.decodeComponent(parts[1]), Uri.decodeComponent(parts[2])};
    }
    final legacyParts = key.split(':');
    if (legacyParts.length >= 3) {
      return {
        legacyParts.sublist(0, legacyParts.length - 1).first,
        legacyParts.sublist(0, legacyParts.length - 1).last,
      };
    }
    return null;
  }
}

class BadHabitDraft {
  final String id;
  final String habitKey;
  final String displayName;
  final double dailySpend;
  final int lostTimeMinutes;
  final bool badHabitCheckInEnabled;
  final bool moneySavedTrackerEnabled;
  final bool relapseCravingAvoidedEnabled;
  final bool comebackSystemEnabled;

  const BadHabitDraft({
    required this.id,
    required this.habitKey,
    required this.displayName,
    this.dailySpend = 0,
    this.lostTimeMinutes = 0,
    this.badHabitCheckInEnabled = true,
    this.moneySavedTrackerEnabled = true,
    this.relapseCravingAvoidedEnabled = true,
    this.comebackSystemEnabled = true,
  });

  factory BadHabitDraft.fromMap(Map<String, dynamic> map) {
    return BadHabitDraft(
      id: map['id'] as String? ?? '',
      habitKey: map['habitKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      dailySpend: (map['dailySpend'] as num?)?.toDouble() ?? 0,
      lostTimeMinutes: (map['lostTimeMinutes'] as num?)?.toInt() ?? 0,
      badHabitCheckInEnabled: map['badHabitCheckInEnabled'] as bool? ?? true,
      moneySavedTrackerEnabled:
          map['moneySavedTrackerEnabled'] as bool? ?? true,
      relapseCravingAvoidedEnabled:
          map['relapseCravingAvoidedEnabled'] as bool? ?? true,
      comebackSystemEnabled: map['comebackSystemEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'habitKey': habitKey,
    'displayName': displayName,
    'dailySpend': dailySpend,
    'lostTimeMinutes': lostTimeMinutes,
    'badHabitCheckInEnabled': badHabitCheckInEnabled,
    'moneySavedTrackerEnabled': moneySavedTrackerEnabled,
    'relapseCravingAvoidedEnabled': relapseCravingAvoidedEnabled,
    'comebackSystemEnabled': comebackSystemEnabled,
  };

  BadHabitDraft copyWith({
    String? id,
    String? habitKey,
    String? displayName,
    double? dailySpend,
    int? lostTimeMinutes,
    bool? badHabitCheckInEnabled,
    bool? moneySavedTrackerEnabled,
    bool? relapseCravingAvoidedEnabled,
    bool? comebackSystemEnabled,
  }) {
    return BadHabitDraft(
      id: id ?? this.id,
      habitKey: habitKey ?? this.habitKey,
      displayName: displayName ?? this.displayName,
      dailySpend: dailySpend ?? this.dailySpend,
      lostTimeMinutes: lostTimeMinutes ?? this.lostTimeMinutes,
      badHabitCheckInEnabled:
          badHabitCheckInEnabled ?? this.badHabitCheckInEnabled,
      moneySavedTrackerEnabled:
          moneySavedTrackerEnabled ?? this.moneySavedTrackerEnabled,
      relapseCravingAvoidedEnabled:
          relapseCravingAvoidedEnabled ?? this.relapseCravingAvoidedEnabled,
      comebackSystemEnabled:
          comebackSystemEnabled ?? this.comebackSystemEnabled,
    );
  }
}

class GoodHabitDraft {
  static const gymKey = 'gym';
  static const skillPracticeKey = 'skill_practice';
  static const readingKey = 'reading';
  static const meditationKey = 'meditation';
  static const journalingKey = 'journaling';
  static const languageLearningKey = 'language_learning';
  static const customKey = 'custom';
  static const mustDoPriority = 'must_do';

  final String id;
  final String habitKey;
  final String displayName;
  final String? subtypeKey;
  final String? customSubtype;
  final int durationMinutes;
  final String frequency;
  final String bestTime;
  final String priority;
  final List<int> repeatDays;

  const GoodHabitDraft({
    required this.id,
    required this.habitKey,
    required this.displayName,
    this.subtypeKey,
    this.customSubtype,
    this.durationMinutes = 15,
    this.frequency = 'daily',
    this.bestTime = 'anytime',
    this.priority = 'good_to_do',
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
  });

  factory GoodHabitDraft.fromMap(Map<String, dynamic> map) {
    return GoodHabitDraft(
      id: map['id'] as String? ?? '',
      habitKey: map['habitKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      subtypeKey: map['subtypeKey'] as String?,
      customSubtype: map['customSubtype'] as String?,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 15,
      frequency: map['frequency'] as String? ?? 'daily',
      bestTime: map['bestTime'] as String? ?? 'anytime',
      priority: map['priority'] as String? ?? 'good_to_do',
      repeatDays: _readIntList(map['repeatDays']),
    );
  }

  String get displayTitle {
    final subtype = customSubtype ?? subtypeKey;
    if (subtype == null || subtype.isEmpty) return displayName;
    return '$displayName - ${subtype.replaceAll('_', ' ')}';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'habitKey': habitKey,
    'displayName': displayName,
    'subtypeKey': subtypeKey,
    'customSubtype': customSubtype,
    'durationMinutes': durationMinutes,
    'frequency': frequency,
    'bestTime': bestTime,
    'priority': priority,
    'repeatDays': repeatDays,
  };

  GoodHabitDraft copyWith({
    String? id,
    String? habitKey,
    String? displayName,
    String? subtypeKey,
    String? customSubtype,
    int? durationMinutes,
    String? frequency,
    String? bestTime,
    String? priority,
    List<int>? repeatDays,
  }) {
    return GoodHabitDraft(
      id: id ?? this.id,
      habitKey: habitKey ?? this.habitKey,
      displayName: displayName ?? this.displayName,
      subtypeKey: subtypeKey ?? this.subtypeKey,
      customSubtype: customSubtype ?? this.customSubtype,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      frequency: frequency ?? this.frequency,
      bestTime: bestTime ?? this.bestTime,
      priority: priority ?? this.priority,
      repeatDays: repeatDays ?? this.repeatDays,
    );
  }
}

class IdentityGoalDraft {
  final String goalKey;
  final String displayName;
  final List<String> systemKeys;

  const IdentityGoalDraft({
    required this.goalKey,
    required this.displayName,
    required this.systemKeys,
  });

  factory IdentityGoalDraft.fromMap(Map<String, dynamic> map) {
    return IdentityGoalDraft(
      goalKey: map['goalKey'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      systemKeys: _readStringList(map['systemKeys']),
    );
  }

  Map<String, dynamic> toMap() => {
    'goalKey': goalKey,
    'displayName': displayName,
    'systemKeys': systemKeys,
  };
}

class CoachSetupDraft {
  final String? coachName;
  final String? customCoachName;
  final String? coachStyle;

  const CoachSetupDraft({
    this.coachName,
    this.customCoachName,
    this.coachStyle,
  });

  factory CoachSetupDraft.fromMap(Map<String, dynamic> map) {
    return CoachSetupDraft(
      coachName: map['coachName'] as String?,
      customCoachName: map['customCoachName'] as String?,
      coachStyle: map['coachStyle'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'coachName': coachName,
    'customCoachName': customCoachName,
    'coachStyle': coachStyle,
  };

  CoachSetupDraft copyWith({
    String? coachName,
    String? customCoachName,
    String? coachStyle,
    bool clearCustomCoachName = false,
  }) {
    return CoachSetupDraft(
      coachName: coachName ?? this.coachName,
      customCoachName: clearCustomCoachName
          ? null
          : (customCoachName ?? this.customCoachName),
      coachStyle: coachStyle ?? this.coachStyle,
    );
  }

  String? validate() {
    if (coachName == null || coachName!.trim().isEmpty) {
      return 'Choose a coach name.';
    }
    if (coachStyle == null) return 'Choose a coach style.';
    return null;
  }
}

class NotificationSetupDraft {
  final bool preferencesConfirmed;
  final bool osPermissionGranted;
  final bool morningStartReminder;
  final bool nextTaskReminder;
  final bool eatingReminder;
  final bool badHabitCheckInReminder;
  final bool savingsReminder;
  final bool nightReflectionReminder;
  final String reminderIntensity;

  const NotificationSetupDraft({
    this.preferencesConfirmed = false,
    this.osPermissionGranted = false,
    this.morningStartReminder = true,
    this.nextTaskReminder = true,
    this.eatingReminder = true,
    this.badHabitCheckInReminder = true,
    this.savingsReminder = false,
    this.nightReflectionReminder = true,
    this.reminderIntensity = 'medium',
  });

  factory NotificationSetupDraft.fromMap(Map<String, dynamic> map) {
    return NotificationSetupDraft(
      preferencesConfirmed: map['preferencesConfirmed'] as bool? ?? false,
      osPermissionGranted: map['osPermissionGranted'] as bool? ?? false,
      morningStartReminder: map['morningStartReminder'] as bool? ?? true,
      nextTaskReminder: map['nextTaskReminder'] as bool? ?? true,
      eatingReminder: map['eatingReminder'] as bool? ?? true,
      badHabitCheckInReminder: map['badHabitCheckInReminder'] as bool? ?? true,
      savingsReminder: map['savingsReminder'] as bool? ?? false,
      nightReflectionReminder: map['nightReflectionReminder'] as bool? ?? true,
      reminderIntensity: map['reminderIntensity'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() => {
    'preferencesConfirmed': preferencesConfirmed,
    'osPermissionGranted': osPermissionGranted,
    'morningStartReminder': morningStartReminder,
    'nextTaskReminder': nextTaskReminder,
    'eatingReminder': eatingReminder,
    'badHabitCheckInReminder': badHabitCheckInReminder,
    'savingsReminder': savingsReminder,
    'nightReflectionReminder': nightReflectionReminder,
    'reminderIntensity': reminderIntensity,
  };

  NotificationSetupDraft copyWith({
    bool? preferencesConfirmed,
    bool? osPermissionGranted,
    bool? morningStartReminder,
    bool? nextTaskReminder,
    bool? eatingReminder,
    bool? badHabitCheckInReminder,
    bool? savingsReminder,
    bool? nightReflectionReminder,
    String? reminderIntensity,
  }) {
    return NotificationSetupDraft(
      preferencesConfirmed: preferencesConfirmed ?? this.preferencesConfirmed,
      osPermissionGranted: osPermissionGranted ?? this.osPermissionGranted,
      morningStartReminder: morningStartReminder ?? this.morningStartReminder,
      nextTaskReminder: nextTaskReminder ?? this.nextTaskReminder,
      eatingReminder: eatingReminder ?? this.eatingReminder,
      badHabitCheckInReminder:
          badHabitCheckInReminder ?? this.badHabitCheckInReminder,
      savingsReminder: savingsReminder ?? this.savingsReminder,
      nightReflectionReminder:
          nightReflectionReminder ?? this.nightReflectionReminder,
      reminderIntensity: reminderIntensity ?? this.reminderIntensity,
    );
  }

  String? validate() {
    if (!const {'low', 'medium', 'high'}.contains(reminderIntensity)) {
      return 'Choose a reminder intensity.';
    }
    if (!preferencesConfirmed) {
      return 'Confirm reminder preferences before permission setup.';
    }
    return null;
  }

  List<String> selectedLabels() {
    return [
      if (morningStartReminder) 'Morning start',
      if (nextTaskReminder) 'Next task',
      if (eatingReminder) 'Eating',
      if (badHabitCheckInReminder) 'Bad habit check-in',
      if (savingsReminder) 'Savings',
      if (nightReflectionReminder) 'Night reflection',
    ];
  }
}

class FinalTimelinePreview {
  final List<FinalTimelineItem> items;
  final List<String> warnings;
  final List<String> duplicateSystemKeysSkipped;

  const FinalTimelinePreview({
    this.items = const [],
    this.warnings = const [],
    this.duplicateSystemKeysSkipped = const [],
  });

  factory FinalTimelinePreview.fromMap(Map<String, dynamic> map) {
    return FinalTimelinePreview(
      items: _readList(
        map['items'],
        (value) => FinalTimelineItem.fromMap(value),
      ),
      warnings: _readStringList(map['warnings']),
      duplicateSystemKeysSkipped: _readStringList(
        map['duplicateSystemKeysSkipped'],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'items': items.map((item) => item.toMap()).toList(),
    'warnings': warnings,
    'duplicateSystemKeysSkipped': duplicateSystemKeysSkipped,
  };

  List<String> get blockingWarnings => warnings
      .where((warning) => warning.startsWith('Resolve or accept'))
      .toList();
}

class FinalTimelineItem {
  final String id;
  final String title;
  final String source;
  final int startMinute;
  final int endMinute;
  final List<int> repeatDays;
  final String blockType;
  final bool crossesMidnight;

  const FinalTimelineItem({
    required this.id,
    required this.title,
    required this.source,
    required this.startMinute,
    required this.endMinute,
    required this.repeatDays,
    required this.blockType,
    this.crossesMidnight = false,
  });

  factory FinalTimelineItem.fromTimelineBlock(TimelineBlockDraft block) {
    return FinalTimelineItem(
      id: block.id,
      title: block.title,
      source: block.section,
      startMinute: block.startMinute,
      endMinute: block.endMinute,
      repeatDays: block.repeatDays,
      blockType: block.blockType,
      crossesMidnight: block.crossesMidnight,
    );
  }

  factory FinalTimelineItem.fromMap(Map<String, dynamic> map) {
    return FinalTimelineItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      source: map['source'] as String? ?? '',
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      repeatDays: _readIntList(map['repeatDays']),
      blockType: map['blockType'] as String? ?? TimelineBlockDraft.softBlockKey,
      crossesMidnight: map['crossesMidnight'] as bool? ?? false,
    );
  }

  int get durationMinutes {
    if (crossesMidnight || endMinute <= startMinute) {
      return (24 * 60 - startMinute) + endMinute;
    }
    return endMinute - startMinute;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'source': source,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'repeatDays': repeatDays,
    'blockType': blockType,
    'crossesMidnight': crossesMidnight,
  };
}

String identitySystemTitle(String key) {
  return switch (key) {
    'save_10_day' => 'Save Rs 10/day',
    'bad_habit_money_saved' => 'Bad-habit money saved',
    'weekly_money_review' => 'Weekly money review',
    'workout' => 'Gym / workout',
    'sleep_routine' => 'Sleep routine',
    'protein_meal_reminder' => 'Protein / meal reminder',
    'non_negotiable_task' => 'One non-negotiable task',
    'wake_sleep_consistency' => 'Wake / sleep consistency',
    'daily_completion_score' => 'Daily completion score',
    'language_practice' => '10 min language practice',
    'five_words_daily' => 'Learn 5 words daily',
    'weekly_revision' => 'Weekly revision',
    'business_work' => '30 min business work',
    'weekly_planning' => 'Weekly planning',
    'project_tracker' => 'Idea / project tracker',
    'meditation' => 'Meditation',
    'journaling' => 'Journaling',
    'doom_scrolling_control' => 'Doom scrolling control',
    _ => key.replaceAll('_', ' '),
  };
}

List<T> _readList<T>(
  Object? value,
  T Function(Map<String, dynamic> value) parser,
) {
  return (value as List?)
          ?.whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList() ??
      <T>[];
}

List<String> _readStringList(Object? value) {
  return (value as List?)?.map((item) => item.toString()).toList() ??
      <String>[];
}

int _readSkinCareDesiredApplicationsPerDay(Object? value) {
  if (value is num) {
    return _normalizeSkinCareDesiredApplicationsPerDay(value.toInt());
  }
  if (value is String) {
    return _normalizeSkinCareDesiredApplicationsPerDay(
      int.tryParse(value.trim()) ?? 2,
    );
  }
  return 2;
}

int _normalizeSkinCareDesiredApplicationsPerDay(int value) {
  if (value <= 2) return 2;
  if (value >= 4) return 4;
  return 3;
}

DateTime? _readDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    return null;
  }
  return null;
}

List<PendingFutureImportDraft> _readPendingFutureImports(Object? value) {
  return (value as List?)?.map((item) {
        if (item is Map) {
          return PendingFutureImportDraft.fromMap(
            Map<String, dynamic>.from(item),
          );
        }
        final raw = item.toString();
        final parts = raw.split(':');
        return PendingFutureImportDraft(
          id: raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_'),
          section: parts.isNotEmpty ? parts.first : 'unknown',
          mode: parts.length > 1 ? parts.sublist(1).join(':') : raw,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList() ??
      <PendingFutureImportDraft>[];
}

List<int> _readIntList(Object? value) {
  final list =
      (value as List?)
          ?.map((item) => (item as num?)?.toInt())
          .whereType<int>()
          .where((day) => day >= 1 && day <= 7)
          .toList() ??
      <int>[];
  return list.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : list;
}

List<TimelineBlockDraft> mergeOverlappingEatingBlocks(
  List<TimelineBlockDraft> blocks,
) {
  if (blocks.isEmpty) return blocks;

  final eatingBlocks = blocks.where((b) => b.section == 'eating').toList();
  final otherBlocks = blocks.where((b) => b.section != 'eating').toList();

  if (eatingBlocks.isEmpty) return blocks;

  eatingBlocks.sort((a, b) {
    final start = a.startMinute.compareTo(b.startMinute);
    return start == 0 ? a.id.compareTo(b.id) : start;
  });

  final mergedEating = <TimelineBlockDraft>[];

  for (final block in eatingBlocks) {
    if (mergedEating.isEmpty) {
      mergedEating.add(block);
      continue;
    }

    final last = mergedEating.last;

    final lastDays = [...last.repeatDays]..sort();
    final blockDays = [...block.repeatDays]..sort();
    final sameDays = lastDays.join(',') == blockDays.join(',');
    final sameMealKind = _mealSemanticKey(last) == _mealSemanticKey(block);
    final bothSameDaySchedules =
        !last.crossesMidnight &&
        !last.endsNextDay &&
        !block.crossesMidnight &&
        !block.endsNextDay;

    if (sameDays &&
        sameMealKind &&
        bothSameDaySchedules &&
        block.startMinute < last.endMinute) {
      final newEndMinute = block.endMinute > last.endMinute
          ? block.endMinute
          : last.endMinute;

      final combinedDishes = <String>[];
      final seenDishes = <String>{};
      for (final dish in [...last.dishes, ...block.dishes]) {
        if (seenDishes.add(dish)) combinedDishes.add(dish);
      }
      final sourceIds = <String>{
        ...(last.provenanceSourceIds.isEmpty
            ? [last.id]
            : last.provenanceSourceIds),
        ...(block.provenanceSourceIds.isEmpty
            ? [block.id]
            : block.provenanceSourceIds),
      }.toList()..sort();
      final digest = sha256.convert(
        utf8.encode(
          [
            'eating-merge-v2',
            sourceIds.join(','),
            last.startMinute,
            newEndMinute,
            lastDays.join(','),
            _mealSemanticKey(last),
          ].join('\u001f'),
        ),
      );

      final newMerged = TimelineBlockDraft(
        id: 'meal_${digest.toString().substring(0, 32)}',
        section: last.section,
        title: last.title,
        startMinute: last.startMinute,
        endMinute: newEndMinute,
        repeatDays: lastDays,
        location: last.location ?? block.location,
        blockType: last.blockType,
        source: last.source,
        needsTimeConfirmation:
            last.needsTimeConfirmation || block.needsTimeConfirmation,
        crossesMidnight: last.crossesMidnight || block.crossesMidnight,
        endsNextDay: last.endsNextDay || block.endsNextDay,
        mealCategory: last.mealCategory ?? block.mealCategory,
        mealSlot: last.mealSlot ?? block.mealSlot,
        dishes: combinedDishes,
        calories: _mergeNutrition(last.calories, block.calories),
        protein: _mergeNutrition(last.protein, block.protein),
        provenanceSourceIds: sourceIds,
      );

      mergedEating[mergedEating.length - 1] = newMerged;
    } else {
      mergedEating.add(block);
    }
  }

  final result = [...otherBlocks, ...mergedEating];
  result.sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return result;
}

String _mealSemanticKey(TimelineBlockDraft block) {
  final slot = block.mealSlot?.trim().toLowerCase() ?? '';
  if (slot.isNotEmpty) return slot;
  final category = block.mealCategory?.trim().toLowerCase() ?? '';
  if (category.isNotEmpty) return category;
  return block.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

double? _mergeNutrition(double? first, double? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first + second;
}

String _fingerprintDraftMap(Map<String, dynamic> map) {
  final identity = Map<String, dynamic>.from(map)
    ..remove('sourceFingerprint')
    ..remove('createdAt')
    ..remove('updatedAt');
  return sha256.convert(utf8.encode(jsonEncode(identity))).toString();
}

String _normalizedSkinCareFingerprintText(String? value) {
  return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

List<String> _normalizedSkinCareFingerprintList(Iterable<String> values) {
  final normalized = values
      .map(_normalizedSkinCareFingerprintText)
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  normalized.sort();
  return normalized;
}
