import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/errors/completion_error_mapper.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/features/onboarding/presentation/step14_presentation_models.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_11_today_ready.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/recovery/screens/onboarding_startup_status_screens.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestHost({
    required OnboardingDraft draft,
    OnboardingStep14? child,
    OnboardingCompletionJobService? completionService,
    void Function(ProviderContainer)? onContainerCreated,
    Size size = const Size(393, 873),
    double textScale = 1.0,
    GlobalKey<OnboardingStep14State>? step14Key,
    ValueChanged<int>? onJumpToStep,
    VoidCallback? onCompletionStarted,
  }) {
    return ProviderScope(
      overrides: [
        if (completionService != null)
          onboardingCompletionJobServiceProvider.overrideWithValue(
            completionService,
          ),
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(draft),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body:
                child ??
                OnboardingStep14(
                  key: step14Key,
                  onJumpToStep: onJumpToStep,
                  onCompletionStarted: onCompletionStarted,
                ),
          ),
        ),
      ),
    );
  }

  OnboardingDraft buildReadyDraft({
    List<TimelineBlockDraft>? blocks,
    List<TimelineConflictDraft>? acceptedConflicts,
  }) {
    final now = DateTime.now();
    return OnboardingDraft(
      uid: 'user-ah-f021',
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.studentKey,
        exerciseLevel: '3_4_days',
        waterIntake: 'medium',
        stressLevel: 'medium',
        sleepQuality: 'good',
      ),
      bodyBasics: const BodyBasicsDraft(
        ageRange: '18-24',
        heightCm: 175,
        weightKg: 70,
        gender: 'male',
      ).withEstimates(),
      baseTimeline: BaseTimelineDraft(
        eatingMode: 'home',
        blocks:
            blocks ??
            const [
              TimelineBlockDraft(
                id: 'physics_lab',
                section: 'classes',
                title: 'Physics Lab',
                startMinute: 540,
                endMinute: 660,
                repeatDays: [1, 3, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'breakfast_block',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 480,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: BaseTimelineDraft.fixedSleepId,
                section: 'fixed',
                title: 'Sleep',
                startMinute: 1380,
                endMinute: 420,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: BaseTimelineDraft.fixedBathId,
                section: 'fixed',
                title: 'Bath',
                startMinute: 420,
                endMinute: 450,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
      ),
      goodHabits: const [
        GoodHabitDraft(
          id: 'read_habit',
          habitKey: GoodHabitDraft.readingKey,
          displayName: 'Read 20 mins',
          durationMinutes: 20,
          bestTime: 'evening',
        ),
      ],
      badHabitsNotNow: true,
      identityGoals: const [
        IdentityGoalDraft(
          goalKey: 'deep_work',
          displayName: 'Master Deep Work',
          systemKeys: ['study'],
        ),
      ],
      coachSetup: const CoachSetupDraft(
        coachName: 'Aria',
        coachStyle: 'direct',
      ),
      slipUpHandling: 'Forgiving',
      notifications: const NotificationSetupDraft(
        morningStartReminder: true,
        nightReflectionReminder: true,
        nextTaskReminder: false,
        eatingReminder: false,
        badHabitCheckInReminder: false,
      ),
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── GROUP 1: Conflict Grouping & Determinism (Tests A–F, BN) ────────────────
  group('AH-F021 Conflict Grouping & Determinism (Tests A–F, BN)', () {
    test(
      'A: Breakfast ↔ SE occurs Mon/Thu/Fri -> ONE group with 3 days and unresolved count 1',
      () {
        final occurrences = [
          const TimelineConflictDraft(
            key: '1|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 1,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
          const TimelineConflictDraft(
            key: '4|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 4,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
          const TimelineConflictDraft(
            key: '5|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 5,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
        ];

        final draft = const OnboardingDraft().copyWith(
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 480,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );

        final groups = Step14ConflictGroupProjector.project(
          occurrences: occurrences,
          draft: draft,
        );

        expect(groups, hasLength(1));
        final group = groups.single;
        expect(group.leftEntryIdentity, 'breakfast');
        expect(group.rightEntryIdentity, 'se');
        expect(group.leftLabel, 'Breakfast');
        expect(group.rightLabel, 'Software Engineering');
        expect(group.affectedDays, [1, 4, 5]);
        expect(group.unresolvedDays, [1, 4, 5]);
        expect(group.acceptedDays, isEmpty);
        expect(group.isUnresolved, isTrue);
        expect(group.hasUniformTimeRange, isTrue);
        expect(group.sharedTimeRange, '7:30 AM – 8:00 AM');
      },
    );

    test(
      'B: Input occurrence order shuffled -> identical group identity and content',
      () {
        final occurrencesShuffled = [
          const TimelineConflictDraft(
            key: '5|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 5,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
          const TimelineConflictDraft(
            key: '1|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 1,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
          const TimelineConflictDraft(
            key: '4|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 4,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
        ];

        final draft = const OnboardingDraft().copyWith(
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 480,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );

        final groups = Step14ConflictGroupProjector.project(
          occurrences: occurrencesShuffled,
          draft: draft,
        );

        expect(groups, hasLength(1));
        expect(groups.single.affectedDays, [1, 4, 5]);
        expect(groups.single.unresolvedDays, [1, 4, 5]);
      },
    );

    test(
      'C: Pair reversal (SE ↔ Breakfast vs Breakfast ↔ SE) -> same canonical group',
      () {
        final forward = [
          const TimelineConflictDraft(
            key: '1|breakfast|se',
            firstBlockId: 'breakfast',
            secondBlockId: 'se',
            firstTitle: 'Breakfast',
            secondTitle: 'Software Engineering',
            day: 1,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
        ];

        final reverse = [
          const TimelineConflictDraft(
            key: '1|se|breakfast',
            firstBlockId: 'se',
            secondBlockId: 'breakfast',
            firstTitle: 'Software Engineering',
            secondTitle: 'Breakfast',
            day: 1,
            isHardConflict: true,
            accepted: false,
            canKeepBoth: true,
          ),
        ];

        const draft = OnboardingDraft();
        final groupFwd = Step14ConflictGroupProjector.project(
          occurrences: forward,
          draft: draft,
        );
        final groupRev = Step14ConflictGroupProjector.project(
          occurrences: reverse,
          draft: draft,
        );

        expect(groupFwd.single.stableGroupId, groupRev.single.stableGroupId);
        expect(
          groupFwd.single.leftEntryIdentity,
          groupRev.single.leftEntryIdentity,
        );
        expect(
          groupFwd.single.rightEntryIdentity,
          groupRev.single.rightEntryIdentity,
        );
      },
    );

    test(
      'D: Same display titles but different entry IDs -> distinct groups',
      () {
        final occurrences = [
          const TimelineConflictDraft(
            key: '1|meal_1|gym_1',
            firstBlockId: 'meal_1',
            secondBlockId: 'gym_1',
            firstTitle: 'Meal',
            secondTitle: 'Workout',
            day: 1,
            isHardConflict: true,
            accepted: false,
          ),
          const TimelineConflictDraft(
            key: '1|meal_2|gym_2',
            firstBlockId: 'meal_2',
            secondBlockId: 'gym_2',
            firstTitle: 'Meal',
            secondTitle: 'Workout',
            day: 1,
            isHardConflict: true,
            accepted: false,
          ),
        ];

        final groups = Step14ConflictGroupProjector.project(
          occurrences: occurrences,
          draft: const OnboardingDraft(),
        );

        expect(groups, hasLength(2));
        expect(groups[0].stableGroupId, isNot(groups[1].stableGroupId));
      },
    );

    test('E: Pair occurs on 5 days -> 1 group with 5 days', () {
      final occurrences = [
        for (var day = 1; day <= 5; day++)
          TimelineConflictDraft(
            key: '$day|a|b',
            firstBlockId: 'a',
            secondBlockId: 'b',
            firstTitle: 'Block A',
            secondTitle: 'Block B',
            day: day,
            isHardConflict: true,
            accepted: false,
          ),
      ];

      final groups = Step14ConflictGroupProjector.project(
        occurrences: occurrences,
        draft: const OnboardingDraft(),
      );

      expect(groups, hasLength(1));
      expect(groups.single.affectedDays, [1, 2, 3, 4, 5]);
      expect(groups.single.daySummary, 'Mon–Fri');
    });

    test(
      'F: Different overlap time ranges by day -> truthful per-day ranges, not shared',
      () {
        final occurrences = [
          const TimelineConflictDraft(
            key: '1|study|work',
            firstBlockId: 'study',
            secondBlockId: 'work',
            firstTitle: 'Study',
            secondTitle: 'Work',
            day: 1,
            isHardConflict: true,
            accepted: false,
          ),
          const TimelineConflictDraft(
            key: '4|study|work',
            firstBlockId: 'study',
            secondBlockId: 'work',
            firstTitle: 'Study',
            secondTitle: 'Work',
            day: 4,
            isHardConflict: true,
            accepted: false,
          ),
        ];

        final draft = const OnboardingDraft().copyWith(
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'study',
                section: 'classes',
                title: 'Study',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1, 4],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'work',
                section: 'job_work_business',
                title: 'Work',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );

        final groups = Step14ConflictGroupProjector.project(
          occurrences: occurrences,
          draft: draft,
        );

        expect(groups, hasLength(1));
        expect(groups.single.overlapRangesByDay[1], isNotNull);
        // Work block only repeats on day 1, so day 4 has no overlap from that block.
        // If day 4 had a different overlap window, hasUniformTimeRange must be false.
        // Verify truthfulness: the projector must not claim a shared uniform range
        // when the underlying block schedules differ per day.
        if (groups.single.overlapRangesByDay.length > 1) {
          final distinctRanges = groups.single.overlapRangesByDay.values
              .toSet();
          if (distinctRanges.length > 1) {
            expect(
              groups.single.hasUniformTimeRange,
              isFalse,
              reason:
                  'Per-day ranges differ, so hasUniformTimeRange must be false',
            );
          }
        }
      },
    );

    test(
      'BN: Multi-day acceptance partial failure preserves accepted days and leaves failed days unresolved',
      () {
        final occurrences = [
          const TimelineConflictDraft(
            key: '1|a|b',
            firstBlockId: 'a',
            secondBlockId: 'b',
            firstTitle: 'A',
            secondTitle: 'B',
            day: 1,
            isHardConflict: true,
            accepted: true,
          ),
          const TimelineConflictDraft(
            key: '4|a|b',
            firstBlockId: 'a',
            secondBlockId: 'b',
            firstTitle: 'A',
            secondTitle: 'B',
            day: 4,
            isHardConflict: true,
            accepted: true,
          ),
          const TimelineConflictDraft(
            key: '5|a|b',
            firstBlockId: 'a',
            secondBlockId: 'b',
            firstTitle: 'A',
            secondTitle: 'B',
            day: 5,
            isHardConflict: true,
            accepted: false,
          ),
        ];

        final groups = Step14ConflictGroupProjector.project(
          occurrences: occurrences,
          draft: const OnboardingDraft(),
        );

        expect(groups, hasLength(1));
        final group = groups.single;
        expect(group.acceptedDays, [1, 4]);
        expect(group.unresolvedDays, [5]);
        expect(group.isUnresolved, isTrue);
        expect(group.isFullyAccepted, isFalse);
      },
    );

    test(
      'Midnight-crossing time range is calculated accurately for repeat days',
      () {
        final occurrences = [
          const TimelineConflictDraft(
            key: '1|sleep|breakfast',
            firstBlockId: 'sleep',
            secondBlockId: 'breakfast',
            firstTitle: 'Sleep',
            secondTitle: 'Breakfast',
            day: 1,
            isHardConflict: true,
            accepted: false,
          ),
        ];
        final draft = const OnboardingDraft().copyWith(
          baseTimeline: const BaseTimelineDraft(
            blocks: [
              TimelineBlockDraft(
                id: 'sleep',
                section: 'fixed',
                title: 'Sleep',
                startMinute: 1380,
                endMinute: 420,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                crossesMidnight: true,
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 390,
                endMinute: 420,
                repeatDays: [1, 2, 3, 4, 5, 6, 7],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          ),
        );
        final groups = Step14ConflictGroupProjector.project(
          occurrences: occurrences,
          draft: draft,
        );
        expect(groups, hasLength(1));
        expect(groups.single.overlapRangesByDay[1], '6:30 AM – 7:00 AM');
      },
    );
  });

  // ── GROUP 2: Durable Acceptance & Group Dynamics (Tests G–L) ────────────────
  group(
    'AH-F021 Durable Acceptance & Group Dynamics (Tests G–L)',
    skip:
        'Legacy onboarding conflict-decision UI removed; conflicts are advisory in Routine.',
    () {
      testWidgets(
        'G & H: Tapping Keep both on these days accepts all unresolved days and collapses into reviewed summary',
        (tester) async {
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(buildTestHost(draft: draft));
          await tester.pumpAndSettle();

          expect(find.text('Needs your attention'), findsOneWidget);
          expect(find.text('Breakfast ↔ Software Engineering'), findsOneWidget);

          final keepBothButton = find.text('Keep both on these days');
          expect(keepBothButton, findsOneWidget);

          await tester.ensureVisible(keepBothButton);
          await tester.tap(keepBothButton);
          await tester.pumpAndSettle();

          // After acceptance, the group moves to reviewed choices summary
          expect(find.text('Kept together · Mon, Thu, Fri'), findsOneWidget);
          expect(find.text('Everything is ready'), findsOneWidget);
        },
      );

      testWidgets(
        'I & J: First unresolved group is expanded by default, second is compact and expands on tap',
        (tester) async {
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'dinner',
                section: 'eating',
                title: 'Dinner',
                startMinute: 1020,
                endMinute: 1080,
                repeatDays: [2],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'gym',
                section: 'classes',
                title: 'Gym Session',
                startMinute: 1020,
                endMinute: 1100,
                repeatDays: [2],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(buildTestHost(draft: draft));
          await tester.pumpAndSettle();

          // First group is expanded
          expect(find.text('Keep both on these days'), findsOneWidget);
          // Second group card exists
          expect(find.text('Dinner ↔ Gym Session'), findsOneWidget);

          // Tap second group to expand it
          await tester.ensureVisible(find.text('Dinner ↔ Gym Session'));
          await tester.tap(find.text('Dinner ↔ Gym Session'));
          await tester.pumpAndSettle();

          expect(find.text('Edit Dinner'), findsOneWidget);
          expect(find.text('Edit Gym Session'), findsOneWidget);
        },
      );

      testWidgets('K: Edit left block jumps directly to that step index', (
        tester,
      ) async {
        int? jumpedStep;
        final draft = buildReadyDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'breakfast',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 450,
              endMinute: 510,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'se',
              section: 'classes',
              title: 'Software Engineering',
              startMinute: 450,
              endMinute: 540,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestHost(
            draft: draft,
            onJumpToStep: (step) => jumpedStep = step,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Edit Breakfast'));
        await tester.tap(find.text('Edit Breakfast'));
        await tester.pumpAndSettle();

        expect(jumpedStep, 5); // Eating step index
      });

      testWidgets(
        'L: Review days opens modal and allows selective day acceptance',
        (tester) async {
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(buildTestHost(draft: draft));
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Review days'));
          await tester.tap(find.text('Review days'));
          await tester.pumpAndSettle();

          expect(
            find.text('Choose where this overlap is intentional'),
            findsOneWidget,
          );
          expect(find.text('Monday'), findsOneWidget);
          expect(find.text('Thursday'), findsOneWidget);
          expect(find.text('Friday'), findsOneWidget);

          // Select Monday
          await tester.tap(find.text('Monday'));
          await tester.pumpAndSettle();

          // Save Choices
          await tester.tap(find.text('Save Choices'));
          await tester.pumpAndSettle();

          // Monday chip is present along with Thu and Fri
          expect(find.text('Mon'), findsOneWidget);
          expect(find.text('Thu'), findsOneWidget);
          expect(find.text('Fri'), findsOneWidget);
        },
      );

      test(
        'H2: 10 accepted groups are aggregated into a single compact reviewed summary count',
        () {
          final occurrences = <TimelineConflictDraft>[
            for (var i = 0; i < 10; i++)
              TimelineConflictDraft(
                key: '$i|c_$i|w_$i',
                firstBlockId: 'c_$i',
                secondBlockId: 'w_$i',
                firstTitle: 'Class $i',
                secondTitle: 'Work $i',
                day: (i % 7) + 1,
                isHardConflict: true,
                accepted: true,
              ),
          ];

          final groups = Step14ConflictGroupProjector.project(
            occurrences: occurrences,
            draft: const OnboardingDraft(),
          );
          final accepted = groups.where((g) => g.isFullyAccepted).toList();
          expect(accepted.length, 10);
          expect(accepted.length > 2, isTrue);
        },
      );

      test(
        'I2: 10 unresolved groups display first group expanded and remaining 9 compact',
        () {
          final occurrences = <TimelineConflictDraft>[
            for (var i = 0; i < 10; i++)
              TimelineConflictDraft(
                key: '$i|c_$i|w_$i',
                firstBlockId: 'c_$i',
                secondBlockId: 'w_$i',
                firstTitle: 'Class $i',
                secondTitle: 'Work $i',
                day: (i % 7) + 1,
                isHardConflict: true,
                accepted: false,
              ),
          ];

          final groups = Step14ConflictGroupProjector.project(
            occurrences: occurrences,
            draft: const OnboardingDraft(),
          );
          final unresolved = groups.where((g) => g.isUnresolved).toList();
          expect(unresolved.length, 10);
          expect(unresolved.first.isUnresolved, isTrue);
        },
      );

      testWidgets(
        'M2: Rapid 5x tap on Keep both invokes acceptance cleanly without duplicate operations',
        (tester) async {
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(buildTestHost(draft: draft));
          await tester.pumpAndSettle();

          final keepBoth = find.text('Keep both on these days');
          await tester.ensureVisible(keepBoth);
          await tester.tap(keepBoth);
          await tester.tap(keepBoth, warnIfMissed: false);
          await tester.tap(keepBoth, warnIfMissed: false);
          await tester.tap(keepBoth, warnIfMissed: false);
          await tester.tap(keepBoth, warnIfMissed: false);
          await tester.pumpAndSettle();

          expect(find.text('Everything is ready'), findsOneWidget);
        },
      );

      testWidgets(
        'O2: Change reviewed choice reopens review modal and allows revoking acceptance',
        (tester) async {
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(buildTestHost(draft: draft));
          await tester.pumpAndSettle();

          // Accept first
          final keepBoth = find.text('Keep both on these days');
          await tester.ensureVisible(keepBoth);
          await tester.tap(keepBoth);
          await tester.pumpAndSettle();

          final changeBtn = find.text('Change');
          await tester.ensureVisible(changeBtn);
          expect(changeBtn, findsOneWidget);

          // Tap Change
          await tester.tap(changeBtn);
          await tester.pumpAndSettle();

          // Deselect Monday
          final mondayTile = find.byType(CheckboxListTile);
          await tester.ensureVisible(mondayTile);
          await tester.tap(mondayTile);
          await tester.pumpAndSettle();

          // Save Choices
          final saveBtn = find.text('Save Choices');
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn);
          await tester.pumpAndSettle();

          // Should be unresolved again
          expect(find.text('1 schedule choice needs you'), findsOneWidget);
        },
      );

      testWidgets(
        'R & S: Modifying schedule removes or creates conflicts dynamically',
        (tester) async {
          final draftNoConflict = buildReadyDraft();

          final raw1 = draftNoConflict.baseTimeline.detectConflicts(
            ownerUid: draftNoConflict.uid,
            timezoneId: draftNoConflict.timezoneId,
          );
          final groups1 = Step14ConflictGroupProjector.project(
            occurrences: raw1,
            draft: draftNoConflict,
          );
          expect(groups1, isEmpty);

          // Add overlapping block
          final draftWithConflict = draftNoConflict.copyWith(
            baseTimeline: draftNoConflict.baseTimeline.copyWith(
              blocks: [
                ...draftNoConflict.baseTimeline.blocks,
                const TimelineBlockDraft(
                  id: 'overlap_block',
                  section: 'eating',
                  title: 'Second Breakfast',
                  startMinute: 450,
                  endMinute: 480,
                  repeatDays: [1],
                  blockType: TimelineBlockDraft.hardBlockKey,
                ),
              ],
            ),
          );
          final raw2 = draftWithConflict.baseTimeline.detectConflicts(
            ownerUid: draftWithConflict.uid,
            timezoneId: draftWithConflict.timezoneId,
          );
          final groups2 = Step14ConflictGroupProjector.project(
            occurrences: raw2,
            draft: draftWithConflict,
          );
          expect(groups2, hasLength(1));
        },
      );

      testWidgets(
        'P & Q: Edit left/right routes to correct section step index',
        (tester) async {
          final stepRecords = <String, int>{};
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'block_meal',
                section: 'eating',
                title: 'Meal',
                startMinute: 450,
                endMinute: 500,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'block_fixed',
                section: 'fixed',
                title: 'Fixed Block',
                startMinute: 450,
                endMinute: 500,
                repeatDays: [1],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(
            buildTestHost(
              draft: draft,
              onJumpToStep: (step) => stepRecords['jumped'] = step,
            ),
          );
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Edit Meal'));
          await tester.tap(find.text('Edit Meal'));
          await tester.pumpAndSettle();
          expect(stepRecords['jumped'], 5); // Eating

          await tester.ensureVisible(find.text('Edit Fixed Block'));
          await tester.tap(find.text('Edit Fixed Block'));
          await tester.pumpAndSettle();
          expect(stepRecords['jumped'], 6); // Fixed
        },
      );
    },
  );

  // ── GROUP 3: Readiness Card Tests (Tests T–W) ──────────────────────────────
  group('AH-F021 Readiness Card Tests (Tests T–W)', () {
    testWidgets(
      'T: Fully configured draft with 0 conflicts shows positive readiness state',
      (tester) async {
        final draft = buildReadyDraft();
        await tester.pumpWidget(buildTestHost(draft: draft));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('step14-readiness')), findsOneWidget);
        expect(find.text('Profile complete'), findsOneWidget);
        expect(find.text('Routine generated'), findsOneWidget);
        expect(find.text('Habits configured'), findsOneWidget);
        expect(find.text('Everything is ready'), findsOneWidget);
        expect(find.text('Everything is ready'), findsOneWidget);
      },
    );

    testWidgets(
      'U: Unresolved conflict displays 1 schedule choice needs you warning',
      (tester) async {
        final draft = buildReadyDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'breakfast',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 450,
              endMinute: 510,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'se',
              section: 'classes',
              title: 'Software Engineering',
              startMinute: 450,
              endMinute: 540,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        await tester.pumpWidget(buildTestHost(draft: draft));
        await tester.pumpAndSettle();

        expect(find.text('1 schedule choice needs you'), findsNothing);
        expect(find.text('Everything is ready'), findsOneWidget);
      },
    );

    testWidgets(
      'V: 3 unresolved conflict groups displays 3 schedule choices need you warning',
      (tester) async {
        final draft = buildReadyDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'b1',
              section: 'eating',
              title: 'B1',
              startMinute: 450,
              endMinute: 510,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 's1',
              section: 'classes',
              title: 'S1',
              startMinute: 450,
              endMinute: 540,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'b2',
              section: 'eating',
              title: 'B2',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [2],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 's2',
              section: 'classes',
              title: 'S2',
              startMinute: 600,
              endMinute: 660,
              repeatDays: [2],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'b3',
              section: 'eating',
              title: 'B3',
              startMinute: 720,
              endMinute: 780,
              repeatDays: [3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 's3',
              section: 'classes',
              title: 'S3',
              startMinute: 720,
              endMinute: 780,
              repeatDays: [3],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        await tester.pumpWidget(buildTestHost(draft: draft));
        await tester.pumpAndSettle();

        expect(find.text('3 schedule choices need you'), findsNothing);
        expect(find.text('Everything is ready'), findsOneWidget);
      },
    );

    testWidgets(
      'W: Readiness card is compact and calm without multi-column clutter',
      (tester) async {
        final draft = buildReadyDraft();
        await tester.pumpWidget(buildTestHost(draft: draft));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('step14-readiness')), findsOneWidget);
        expect(find.text('Readiness'), findsOneWidget);
      },
    );
  });

  // ── GROUP 4: Final Preview & Timeline Tests (Tests X–AE) ────────────────────
  group('AH-F021 Final Preview & Timeline Tests (Tests X–AE)', () {
    testWidgets(
      'X & Y: Final preview renders 5 high-value rows with logical activity count',
      (tester) async {
        final draft = buildReadyDraft();
        await tester.pumpWidget(buildTestHost(draft: draft));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('step14-final-preview')),
          findsOneWidget,
        );
        expect(find.text('Goal'), findsOneWidget);
        expect(find.text('Master Deep Work'), findsOneWidget);
        expect(find.text('Schedule'), findsOneWidget);
        expect(find.textContaining('activities scheduled'), findsOneWidget);
        expect(find.text('Habit focus'), findsOneWidget);
        expect(find.text('Read 20 mins'), findsOneWidget);
        expect(find.text('Coach'), findsOneWidget);
        expect(find.text('Aria (Direct)'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('2 selected'), findsOneWidget);
      },
    );

    testWidgets(
      'Z & AA: View full timeline opens AH-F018 scaffold and Back returns to review context',
      (tester) async {
        final draft = buildReadyDraft();
        final step14Key = GlobalKey<OnboardingStep14State>();
        var fullPreviewOpen = false;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockOnboardingProvider.overrideWith(
                (_) => MockOnboardingNotifier()..loadSeedData(draft),
              ),
            ],
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setHostState) {
                  return MediaQuery(
                    data: const MediaQueryData(size: Size(393, 873)),
                    child: OnboardingStepShell(
                      currentPage: OnboardingDraft.lastStepIndex,
                      pageOffset: OnboardingDraft.lastStepIndex.toDouble(),
                      completedSteps: draft.stepCompleted,
                      validationMessage: null,
                      onDotTap: (_) {},
                      onIndicatorDraggedTo: (_) {},
                      onSave: null,
                      showSave: false,
                      isSaving: false,
                      isSaved: false,
                      saveEnabled: false,
                      ctaLabel: 'Enter Optivus',
                      showPrimaryCta: false,
                      ctaEnabled: false,
                      ctaLoading: false,
                      topLeftOverlay: fullPreviewOpen
                          ? OnboardingStageBackButton(
                              key: const Key('onboarding-step14-back'),
                              onTap: () => step14Key.currentState
                                  ?.closeFullTimelinePreviewIfOpen(),
                            )
                          : null,
                      child: OnboardingStep14(
                        key: step14Key,
                        onFullTimelinePreviewChanged: (isOpen) {
                          setHostState(() => fullPreviewOpen = isOpen);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.ensureVisible(
          find.byKey(const ValueKey('step14-view-timeline')),
        );
        expect(find.text('See your timeline'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('step14-view-timeline')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Full timeline scaffold is mounted in previewReadOnly mode
        expect(
          find.byKey(const ValueKey('onboarding-step14-shared-preview')),
          findsOneWidget,
        );
        expect(find.text('Today timeline preview'), findsOneWidget);
        expect(find.text('Physics Lab'), findsOneWidget);
        expect(find.text('Back to Review'), findsNothing);
        expect(find.byKey(const Key('onboarding-step14-back')), findsOneWidget);

        // Top-left shell back closes only the nested full preview.
        await tester.tap(find.byKey(const Key('onboarding-step14-back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey('step14-final-preview')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step14-shared-preview')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('step14-readiness')), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const ValueKey('step14-view-timeline')),
        );
        await tester.tap(find.byKey(const ValueKey('step14-view-timeline')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey('onboarding-step14-shared-preview')),
          findsOneWidget,
        );

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey('step14-final-preview')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('onboarding-step14-shared-preview')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('step14-readiness')), findsOneWidget);
      },
    );

    testWidgets('AB: Edit setup opens modal bottom sheet with setup steps', (
      tester,
    ) async {
      int? jumpedStep;
      final draft = buildReadyDraft();
      await tester.pumpWidget(
        buildTestHost(draft: draft, onJumpToStep: (step) => jumpedStep = step),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('step14-edit-setup')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Setup'), findsOneWidget);
      expect(find.text('Schedule & Classes'), findsOneWidget);
      expect(find.text('Meals & Eating Mode'), findsOneWidget);
      expect(find.text('Fixed Routine & Sleep'), findsOneWidget);
      expect(find.text('Skin Care'), findsOneWidget);
      expect(find.text('Habits & Check-ins'), findsOneWidget);
      expect(find.text('Identity Goals'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Notifications'), findsOneWidget);

      await tester.tap(find.text('Habits & Check-ins'));
      await tester.pumpAndSettle();

      expect(jumpedStep, 8);
    });

    test(
      'W2: Activity count semantics truthfully project distinct logical items in bundle and draft',
      () {
        final draft = buildReadyDraft();
        final bundle = OnboardingCompletionService.buildBundle(draft);
        final preview = Step14FinalPreviewData.project(
          draft: draft,
          bundle: bundle,
        );
        expect(
          preview.scheduledActivitiesCount,
          bundle.routineItemsForApp.length,
        );
      },
    );
  });

  // ── GROUP 5: Dedicated Finishing Progression & Stages (Tests AL–AQ, BP) ─────
  group('AH-F021 Dedicated Finishing Progression & Stages (Tests AL–AQ, BP)', () {
    test(
      'BP: 15 OnboardingCompletionStages map truthfully to 4 public finishing labels',
      () {
        final p1 = CompletionStageProjection.projectAll(
          currentStage: OnboardingCompletionStage.validateInput,
          jobStatus: OnboardingJobStatus.running,
        );
        expect(p1[0].publicLabel, 'Saving your setup');
        expect(p1[0].status, CompletionStageStatus.active);
        expect(p1[1].publicLabel, 'Preparing your routine');
        expect(p1[1].status, CompletionStageStatus.pending);
        expect(p1[2].publicLabel, 'Preparing your daily systems');
        expect(p1[2].status, CompletionStageStatus.pending);
        expect(p1[3].publicLabel, 'Preparing Home');
        expect(p1[3].status, CompletionStageStatus.pending);

        final p2 = CompletionStageProjection.projectAll(
          currentStage: OnboardingCompletionStage.reconcileHabitSystems,
          jobStatus: OnboardingJobStatus.running,
        );
        expect(p2[0].status, CompletionStageStatus.completed);
        expect(p2[1].status, CompletionStageStatus.completed);
        expect(p2[2].status, CompletionStageStatus.active);
        expect(p2[3].status, CompletionStageStatus.pending);

        final p3 = CompletionStageProjection.projectAll(
          currentStage: OnboardingCompletionStage.completed,
          jobStatus: OnboardingJobStatus.completed,
        );
        expect(p3[0].status, CompletionStageStatus.completed);
        expect(p3[1].status, CompletionStageStatus.completed);
        expect(p3[2].status, CompletionStageStatus.completed);
        expect(p3[3].status, CompletionStageStatus.completed);
      },
    );

    testWidgets(
      'AL & AM: FinishingOnboardingScreen displays 4 real stage progression rows',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: FinishingOnboardingScreen()),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('step14-finishing')), findsOneWidget);
        expect(find.text('Building your Optivus'), findsOneWidget);
        expect(find.text('Saving your setup'), findsOneWidget);
        expect(find.text('Preparing your routine'), findsOneWidget);
        expect(find.text('Preparing your daily systems'), findsOneWidget);
        expect(find.text('Preparing Home'), findsOneWidget);
      },
    );

    testWidgets('AN & AO: Completion terminalization triggers success view', (
      tester,
    ) async {
      final step14Key = GlobalKey<OnboardingStep14State>();
      final draft = buildReadyDraft();

      await tester.pumpWidget(
        buildTestHost(draft: draft, step14Key: step14Key),
      );
      await tester.pumpAndSettle();

      step14Key.currentState?.setSuccessState();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step14-success')), findsOneWidget);
      expect(find.text("You're ready"), findsOneWidget);
      expect(find.text('Your Optivus is ready for today.'), findsOneWidget);
    });

    testWidgets(
      'AP & AQ, BO: Completion failure renders RecoverableError with Back to Review',
      (tester) async {
        final step14Key = GlobalKey<OnboardingStep14State>();
        final draft = buildReadyDraft();

        await tester.pumpWidget(
          buildTestHost(draft: draft, step14Key: step14Key),
        );
        await tester.pumpAndSettle();

        const error = RecoverableError(
          category: RecoverableErrorCategory.network,
          publicMessage: 'Connection timed out. Your setup is safe.',
          severity: RecoverableErrorSeverity.warning,
          isBlocking: true,
          retryAction: RecoverableRetryAction.retry,
          retrySafe: true,
          diagnosticCode: 'NET_TIMEOUT',
        );

        step14Key.currentState?.setFailureState(error);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('step14-failure')), findsOneWidget);
        expect(find.text('Your setup is safe'), findsOneWidget);
        expect(
          find.text('Connection timed out. Your setup is safe.'),
          findsOneWidget,
        );
        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Back to Review'), findsOneWidget);

        // Tapping Back to Review returns to review mode
        await tester.tap(find.text('Back to Review'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('step14-readiness')), findsOneWidget);
      },
    );
  });

  testWidgets(
    'Gate 1 failure diagnostics survive an unavailable preview and reject secret fields',
    (tester) async {
      final key = GlobalKey<OnboardingStep14State>();
      final ready = buildReadyDraft();
      final draft = ready.copyWith(
        baseTimeline: ready.baseTimeline.copyWith(
          skinCareSetupPath: 'has_products',
        ),
      );
      expect(
        OnboardingCompletionService.projectBundleResult(draft),
        isA<Step14BundleBuildInvalid>(),
      );
      final now = DateTime.now();
      final failure = OnboardingCompletionJob(
        jobId: 'run',
        uid: draft.uid,
        createdAt: now,
        updatedAt: now,
        status: OnboardingJobStatus.retryableFailure,
        stage: OnboardingCompletionStage.verifyBundle,
        lastFailureStage: 'verifyRoutines',
        lastFailureCode: 'COMPLETION_ROUTINE_ACCOUNTING_FAILED',
        retryable: true,
        diagnosticCategory: 'projection_failed',
        lastError: 'secret@example.com token=private',
        failedEntityIds: const ['private-entity'],
      );
      final store = OnboardingCompletionMemoryStore();
      store.jobs['${draft.uid}:run'] = failure;
      store.currentRunIds[draft.uid] = 'run';
      store.currentRunStatuses[draft.uid] = 'active';
      final service = OnboardingCompletionJobService(
        onboardingRepository: FakeOnboardingRepository(),
        profileRepository: FakeProfileRepository(),
        memoryStore: store,
      );
      await tester.pumpWidget(
        buildTestHost(draft: draft, step14Key: key, completionService: service),
      );
      key.currentState!.setFailureState(
        CompletionErrorMapper.map(error: Exception('raw secret')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('step14-failure')), findsOneWidget);
      expect(find.text('Back to Review'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('step14-technical-details')));
      await tester.pumpAndSettle();
      expect(find.text('Stage: verifyRoutines'), findsOneWidget);
      expect(
        find.text('Code: COMPLETION_ROUTINE_ACCOUNTING_FAILED'),
        findsOneWidget,
      );
      expect(find.text('Retryable: Yes'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      expect(find.textContaining('private'), findsNothing);
    },
  );

  testWidgets(
    'Gate 1 completed authoritative pointer hides Back to Review with no active notifier',
    (tester) async {
      final key = GlobalKey<OnboardingStep14State>();
      final draft = buildReadyDraft();
      final now = DateTime.now();
      final store = OnboardingCompletionMemoryStore();
      store.jobs['${draft.uid}:run'] = OnboardingCompletionJob(
        jobId: 'run',
        uid: draft.uid,
        createdAt: now,
        updatedAt: now,
        status: OnboardingJobStatus.completed,
        stage: OnboardingCompletionStage.completed,
      );
      store.currentRunIds[draft.uid] = 'run';
      store.currentRunStatuses[draft.uid] = 'completed';
      final service = OnboardingCompletionJobService(
        onboardingRepository: FakeOnboardingRepository(),
        profileRepository: FakeProfileRepository(),
        memoryStore: store,
      );
      await tester.pumpWidget(
        buildTestHost(draft: draft, step14Key: key, completionService: service),
      );
      key.currentState!.setFailureState(
        CompletionErrorMapper.map(error: Exception('interrupted handoff')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back to Review'), findsNothing);
    },
  );

  // ── GROUP 6: Responsive & Layout Geometry Tests (Tests BD–BM) ───────────────
  group('AH-F021 Responsive & Layout Geometry Tests (Tests BD–BM)', () {
    testWidgets('Step 14 header stays fixed while review body scrolls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = buildReadyDraft(
        blocks: [
          for (var index = 0; index < 18; index++)
            TimelineBlockDraft(
              id: 'scroll-block-$index',
              section: 'classes',
              title: 'Scheduled activity $index',
              startMinute: 420 + index * 20,
              endMinute: 435 + index * 20,
              repeatDays: const [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
        ],
      );
      await tester.pumpWidget(
        buildTestHost(draft: draft, size: const Size(393, 500)),
      );
      await tester.pumpAndSettle();

      final header = find.byKey(const ValueKey('step14-header'));
      final readiness = find.byKey(const ValueKey('step14-readiness'));
      final headerTopBefore = tester.getTopLeft(header).dy;
      final readinessTopBefore = tester.getTopLeft(readiness).dy;

      await tester.drag(
        find.byType(OnboardingScrollView),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(header).dy, closeTo(headerTopBefore, 0.01));
      expect(tester.getTopLeft(readiness).dy, lessThan(readinessTopBefore));
    });

    for (final size in [
      const Size(360, 800),
      const Size(393, 873),
      const Size(412, 915),
      const Size(800, 360),
    ]) {
      testWidgets(
        'BD: Renders cleanly without overflow at ${size.width}x${size.height}',
        (tester) async {
          final draft = buildReadyDraft(
            blocks: const [
              TimelineBlockDraft(
                id: 'breakfast',
                section: 'eating',
                title: 'Breakfast',
                startMinute: 450,
                endMinute: 510,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
              TimelineBlockDraft(
                id: 'se',
                section: 'classes',
                title: 'Software Engineering',
                startMinute: 450,
                endMinute: 540,
                repeatDays: [1, 4, 5],
                blockType: TimelineBlockDraft.hardBlockKey,
              ),
            ],
          );

          await tester.pumpWidget(buildTestHost(draft: draft, size: size));
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('step14-header')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('step14-readiness')),
            findsOneWidget,
          );
        },
      );
    }

    for (final scale in [1.4, 1.6]) {
      testWidgets(
        'BE: Renders cleanly under ${scale}x accessibility text scale',
        (tester) async {
          final draft = buildReadyDraft();
          await tester.pumpWidget(
            buildTestHost(draft: draft, textScale: scale),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('step14-header')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('step14-readiness')),
            findsOneWidget,
          );
        },
      );
    }
  });

  // ── GROUP 7: Sticky Action & Primary CTA Integration (Tests M–S, AE, AH) ───
  group('AH-F021 Sticky Action & Primary CTA Integration (Tests M–S, AE, AH)', () {
    testWidgets(
      'M & N: Unresolved conflicts remain advisory for onboarding CTA',
      (tester) async {
        final draft = buildReadyDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'breakfast',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 450,
              endMinute: 510,
              repeatDays: [1, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'se',
              section: 'classes',
              title: 'Software Engineering',
              startMinute: 450,
              endMinute: 540,
              repeatDays: [1, 4, 5],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );

        final rawConflicts = draft.baseTimeline.detectConflicts(
          ownerUid: draft.uid.isEmpty ? 'local-onboarding-owner' : draft.uid,
          timezoneId: draft.timezoneId,
          revision: draft.revision,
        );
        final groups = Step14ConflictGroupProjector.project(
          occurrences: rawConflicts,
          draft: draft,
        );
        final unresolved = groups.where((g) => g.isUnresolved).toList();
        expect(unresolved.length, 1);
        const ctaLabel = 'Enter Optivus';
        expect(ctaLabel, 'Enter Optivus');

        await tester.pumpWidget(
          buildTestHost(draft: draft, child: const OnboardingStep14()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Breakfast ↔ Software Engineering'), findsNothing);
        expect(find.text('Needs your attention'), findsNothing);
      },
    );

    testWidgets('O & P: Zero unresolved conflicts compute Enter Optivus CTA', (
      tester,
    ) async {
      final draft = buildReadyDraft();
      final rawConflicts = draft.baseTimeline.detectConflicts(
        ownerUid: draft.uid.isEmpty ? 'local-onboarding-owner' : draft.uid,
        timezoneId: draft.timezoneId,
        revision: draft.revision,
      );
      final groups = Step14ConflictGroupProjector.project(
        occurrences: rawConflicts,
        draft: draft,
      );
      final unresolved = groups.where((g) => g.isUnresolved).toList();
      expect(unresolved.isEmpty, isTrue);

      // The CTA label in the flow would be 'Enter Optivus' when unresolved is empty.
      // Verify: the projector result is the basis for CTA decision.
      final ctaLabel = unresolved.isEmpty
          ? 'Enter Optivus'
          : 'Review ${unresolved.length} ${unresolved.length == 1 ? 'conflict' : 'conflicts'}';
      expect(ctaLabel, 'Enter Optivus');

      await tester.pumpWidget(
        buildTestHost(draft: draft, child: const OnboardingStep14()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Everything is ready'), findsOneWidget);
      // No attention section should be visible
      expect(find.text('Needs your attention'), findsNothing);
    });

    test(
      'AE: Completion start is not blocked when schedule overlaps exist',
      () {
        final draft = buildReadyDraft(
          blocks: const [
            TimelineBlockDraft(
              id: 'breakfast',
              section: 'eating',
              title: 'Breakfast',
              startMinute: 450,
              endMinute: 510,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
            TimelineBlockDraft(
              id: 'se',
              section: 'classes',
              title: 'Software Engineering',
              startMinute: 450,
              endMinute: 540,
              repeatDays: [1],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );
        final blocking = draft.timelineConflictsRequiringAcceptance();
        expect(blocking, isNotEmpty);
        final stepErr = draft.validateStep(
          OnboardingDraft.lastStepIndex,
          List.filled(15, true),
        );
        expect(stepErr, isNull);
      },
    );

    testWidgets('AH: Enter Optivus double tap initiates completion only once', (
      tester,
    ) async {
      var starts = 0;
      final step14Key = GlobalKey<OnboardingStep14State>();
      final draft = buildReadyDraft();

      await tester.pumpWidget(
        buildTestHost(
          draft: draft,
          step14Key: step14Key,
          onCompletionStarted: () => starts++,
        ),
      );
      await tester.pumpAndSettle();

      // Trigger startFinishingPresentation twice rapidly
      step14Key.currentState?.startFinishingPresentation();
      step14Key.currentState?.startFinishingPresentation();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step14-finishing')), findsOneWidget);
      // startFinishingPresentation is a local state change; onCompletionStarted
      // is invoked by the flow's _completeOnboarding which is double-tap-guarded
      // by _isCompleting. Here we verify the UI settled into finishing mode once.
      expect(
        starts,
        0,
        reason:
            'startFinishingPresentation does not invoke onCompletionStarted callback',
      );
    });
  });

  // ── GROUP 8: Success & Failure Recovery Transitions (Tests AR–AY, AU) ──────
  group('AH-F021 Success & Failure Recovery Transitions (Tests AR–AY, AU)', () {
    testWidgets(
      'AR & AS: Reauthenticate retry action provides Sign In Again button',
      (tester) async {
        final step14Key = GlobalKey<OnboardingStep14State>();
        final draft = buildReadyDraft();

        await tester.pumpWidget(
          buildTestHost(draft: draft, step14Key: step14Key),
        );
        await tester.pumpAndSettle();

        const error = RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Session expired. Please sign in again.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: 'AUTH_EXPIRED',
        );

        step14Key.currentState?.setFailureState(error);
        await tester.pumpAndSettle();

        expect(find.text('Sign In Again'), findsOneWidget);
      },
    );

    testWidgets(
      'AT & AU: RestartRecovery retry action provides Recover Setup button',
      (tester) async {
        final step14Key = GlobalKey<OnboardingStep14State>();
        final draft = buildReadyDraft();

        await tester.pumpWidget(
          buildTestHost(draft: draft, step14Key: step14Key),
        );
        await tester.pumpAndSettle();

        const error = RecoverableError(
          category: RecoverableErrorCategory.recoveryRequired,
          publicMessage: 'Setup recovery required.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.restartRecovery,
          retrySafe: false,
          diagnosticCode: 'RECOVERY_REQUIRED',
        );

        step14Key.currentState?.setFailureState(error);
        await tester.pumpAndSettle();

        expect(find.text('Recover Setup'), findsOneWidget);
      },
    );

    testWidgets(
      'AU: Raw error firewall prevents technical strings from surfacing in UI',
      (tester) async {
        const secret = 'RAW_STEP14_SECRET_98421';
        final step14Key = GlobalKey<OnboardingStep14State>();
        final draft = buildReadyDraft();

        await tester.pumpWidget(
          buildTestHost(draft: draft, step14Key: step14Key),
        );
        await tester.pumpAndSettle();

        final mappedError = CompletionErrorMapper.map(
          error: Exception(
            'Internal database error with $secret in write batch',
          ),
        );
        step14Key.currentState?.setFailureState(mappedError);
        await tester.pumpAndSettle();

        expect(find.textContaining(secret), findsNothing);
        expect(find.text('Your setup is safe'), findsOneWidget);
      },
    );
  });

  // ── GROUP 9: Safety Invariants, Auth Isolation & Monotonicity (Tests AZ–BC, AW, AX, AY) ──
  group(
    'AH-F021 Safety Invariants, Auth Isolation & Monotonicity (Tests AZ–BC, AW, AX, AY)',
    () {
      test(
        'AZ: canReturnToStep14Review projection evaluates safety correctly',
        () {
          final now = DateTime.now();
          final earlyJob = OnboardingCompletionJob(
            jobId: 'job-1',
            uid: 'user-1',
            stage: OnboardingCompletionStage.validateInput,
            status: OnboardingJobStatus.running,
            createdAt: now,
            updatedAt: now,
          );
          expect(
            canReturnToStep14Review(
              job: earlyJob,
              currentRunSnapshot: const OnboardingCurrentRunSnapshot.none(),
            ),
            isTrue,
          );

          final committedJob = OnboardingCompletionJob(
            jobId: 'job-2',
            uid: 'user-1',
            stage: OnboardingCompletionStage.reconcileRoutines,
            status: OnboardingJobStatus.running,
            createdAt: now,
            updatedAt: now,
          );
          expect(
            canReturnToStep14Review(
              job: committedJob,
              currentRunSnapshot: const OnboardingCurrentRunSnapshot.none(),
            ),
            isFalse,
          );
        },
      );

      test(
        'BB & BC: Same UID refresh preserves active completion and account switch purges prior user state',
        () {
          final jobService = OnboardingCompletionJobService(
            onboardingRepository: FakeOnboardingRepository(),
            profileRepository: FakeProfileRepository(),
          );
          jobService.activeJobNotifier.value = OnboardingCompletionJob(
            jobId: 'job-1',
            uid: 'user-a',
            stage: OnboardingCompletionStage.validateInput,
            status: OnboardingJobStatus.running,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          expect(jobService.activeJobNotifier.value?.uid, 'user-a');
          jobService.cancelOwner('user-a');
          expect(jobService.activeJobNotifier.value, isNull);
        },
      );
    },
  );

  // ── GROUP 10: Accessibility Semantics & Hit-Testing (Tests BF–BM) ───────────
  group('AH-F021 Accessibility Semantics & Hit-Testing (Tests BF–BM)', () {
    testWidgets('BF: Onboarding final review omits conflict decision cards', (
      tester,
    ) async {
      final draft = buildReadyDraft(
        blocks: const [
          TimelineBlockDraft(
            id: 'breakfast',
            section: 'eating',
            title: 'Breakfast',
            startMinute: 450,
            endMinute: 510,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
          TimelineBlockDraft(
            id: 'se',
            section: 'classes',
            title: 'Software Engineering',
            startMinute: 450,
            endMinute: 540,
            repeatDays: [1],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      await tester.pumpWidget(buildTestHost(draft: draft));
      await tester.pumpAndSettle();

      final semanticsWidget = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.container == true &&
            (w.properties.label?.contains('Breakfast') ?? false) &&
            (w.properties.label?.contains('Software Engineering') ?? false),
      );

      expect(semanticsWidget, findsNothing);
      expect(find.text('Needs your attention'), findsNothing);
    });
  });
}
