import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets(
    'Onboarding 4 timeline aligns overlaps and non-hour blocks without flex errors',
    (tester) async {
      final draft = OnboardingDraft(
        lifeRole: const LifeRoleDraft(
          lifeRole: LifeRoleDraft.studentWorkingKey,
          workType: 'part_time',
        ),
        baseTimeline: const BaseTimelineDraft(),
      );
      final classBlocks = [
        _scheduleBlock(
          id: 'data-structures',
          title: 'Data Structures',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          config: ScheduleSetupConfig.classSetup,
        ),
        _scheduleBlock(
          id: 'ps',
          title: 'PS',
          startMinute: 15 * 60 + 15,
          endMinute: 16 * 60 + 15,
          config: ScheduleSetupConfig.classSetup,
        ),
        _scheduleBlock(
          id: 'study',
          title: 'Study',
          startMinute: 16 * 60 + 45,
          endMinute: 18 * 60 + 15,
          config: ScheduleSetupConfig.classSetup,
        ),
      ];
      final workBlocks = [
        _scheduleBlock(
          id: 'part-time-job',
          title: 'Part-Time Job',
          startMinute: 9 * 60 + 30,
          endMinute: 13 * 60,
          config: ScheduleSetupConfig.workSetup,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith(
              (_) => MockOnboardingNotifier()..loadSeedData(draft),
            ),
            onboardingClassTimelineProvider.overrideWith((_) => classBlocks),
            onboardingWorkTimelineProvider.overrideWith((_) => workBlocks),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: OnboardingStep4Unified()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('Part-Time Job'), findsOneWidget);
      expect(find.text('3:15'), findsOneWidget);
      expect(find.text('4:15'), findsOneWidget);
      expect(find.text('4:45'), findsOneWidget);
      expect(find.text('6:15'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.textContaining('conflict'), findsNothing);
      expect(find.textContaining('Resolve'), findsNothing);
      expect(find.textContaining('overlap'), findsNothing);

      final dataLeft = tester
          .getTopLeft(
            find.byKey(
              const ValueKey('onboarding-step4-block-data-structures'),
            ),
          )
          .dx;
      final jobLeft = tester
          .getTopLeft(
            find.byKey(const ValueKey('onboarding-step4-block-part-time-job')),
          )
          .dx;
      expect(jobLeft - dataLeft, closeTo(14, 0.5));

      _expectBlockAlignedToTicks(
        tester,
        blockId: 'ps',
        startMinute: 15 * 60 + 15,
        endMinute: 16 * 60 + 15,
      );
      _expectBlockAlignedToTicks(
        tester,
        blockId: 'study',
        startMinute: 16 * 60 + 45,
        endMinute: 18 * 60 + 15,
      );

      await tester.tap(find.text('TUE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No fixed blocks on this day.'), findsOneWidget);

      await tester.tap(find.text('MON'));
      await tester.pumpAndSettle();
      final jobBlock = find.byKey(
        const ValueKey('onboarding-step4-block-part-time-job'),
      );
      await tester.ensureVisible(jobBlock);
      await tester.pumpAndSettle();
      await tester.tap(jobBlock);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Work Block'), findsOneWidget);
    },
  );

  testWidgets('Student + Working shows deterministic class/work upload targets', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.studentWorkingKey,
        workType: 'part_time',
      ),
      baseTimeline: const BaseTimelineDraft(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep4Unified()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload your class and work timetable'), findsOneWidget);
    expect(find.text('Class timetable'), findsOneWidget);
    expect(find.text('Work schedule'), findsOneWidget);
    expect(
      find.text(
        'Upload both class and work schedule photos before generating your timeline.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Business role uses work/business upload target only', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.businessKey,
        businessMode: 'fixed_business',
      ),
      baseTimeline: const BaseTimelineDraft(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep4Unified()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload your work/business schedule'), findsOneWidget);
    expect(find.text('Work/Business schedule'), findsOneWidget);
    expect(find.text('Class timetable'), findsNothing);
    expect(
      find.text(
        'Use a clear photo of your work, shift, client, or business schedule.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Working role ignores stale class provider blocks', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.workingKey,
        workType: 'full_time',
      ),
      baseTimeline: const BaseTimelineDraft(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
          onboardingClassTimelineProvider.overrideWith(
            (_) => [
              _scheduleBlock(
                id: 'stale-class',
                title: 'Stale Class',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                config: ScheduleSetupConfig.classSetup,
              ),
            ],
          ),
          onboardingWorkTimelineProvider.overrideWith(
            (_) => [
              _scheduleBlock(
                id: 'office-work',
                title: 'Office Work',
                startMinute: 9 * 60,
                endMinute: 17 * 60,
                config: ScheduleSetupConfig.workSetup,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep4Unified()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload your work schedule'), findsOneWidget);
    expect(find.text('Office Work'), findsOneWidget);
    expect(find.text('Stale Class'), findsNothing);
    expect(find.text('Class timetable'), findsNothing);
  });

  testWidgets('reopened saved schedule shows generated card and timeline', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.studentWorkingKey,
        workType: 'part_time',
      ),
      baseTimeline: BaseTimelineDraft(
        blocks: [
          _timelineBlock(
            id: 'saved-class',
            section: 'classes',
            title: 'Saved Class',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          _timelineBlock(
            id: 'saved-work',
            section: 'job_work_business',
            title: 'Saved Work',
            startMinute: 10 * 60,
            endMinute: 12 * 60,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep4Unified()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule generated'), findsOneWidget);
    expect(
      find.text(
        'Your fixed responsibilities are ready. Edit blocks directly on the timeline.',
      ),
      findsOneWidget,
    );
    expect(find.text('Upload your class and work timetable'), findsNothing);
    expect(find.text('Saved Class'), findsOneWidget);
    expect(find.text('Saved Work'), findsOneWidget);
  });

  testWidgets(
    'Replace schedule clears current role blocks and upload returns',
    (tester) async {
      late MockOnboardingNotifier notifier;
      final completed = List<bool>.filled(OnboardingDraft.stepCount, false);
      completed[onboardingClassJobStepIndex] = true;
      final draft = OnboardingDraft(
        uid: 'replace-user',
        currentStep: onboardingClassJobStepIndex,
        stepCompleted: completed,
        lifeRole: const LifeRoleDraft(
          lifeRole: LifeRoleDraft.studentWorkingKey,
          workType: 'part_time',
        ),
        baseTimeline: BaseTimelineDraft(
          blocks: [
            _timelineBlock(
              id: 'saved-class',
              section: 'classes',
              title: 'Saved Class',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
            ),
            _timelineBlock(
              id: 'saved-work',
              section: 'job_work_business',
              title: 'Saved Work',
              startMinute: 10 * 60,
              endMinute: 12 * 60,
            ),
            _timelineBlock(
              id: 'fixed-sleep',
              section: 'fixed',
              title: 'Sleep',
              startMinute: 23 * 60,
              endMinute: 7 * 60,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockOnboardingProvider.overrideWith((_) {
              notifier = MockOnboardingNotifier()..loadSeedData(draft);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(child: OnboardingStep4Unified()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule generated'), findsOneWidget);
      await tester.tap(find.text('Replace schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Replace saved schedule?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(TextButton, 'Replace schedule').last,
      );
      await tester.pumpAndSettle();

      final nextDraft = notifier.state.draft;
      expect(find.text('Upload your class and work timetable'), findsOneWidget);
      expect(find.text('Saved Class'), findsNothing);
      expect(find.text('Saved Work'), findsNothing);
      expect(
        nextDraft.baseTimeline.confirmedBlocksForSection('classes'),
        isEmpty,
      );
      expect(
        nextDraft.baseTimeline.confirmedBlocksForSection('job_work_business'),
        isEmpty,
      );
      expect(
        nextDraft.baseTimeline.confirmedBlocksForSection('fixed'),
        isNotEmpty,
      );
      expect(nextDraft.stepCompleted[onboardingClassJobStepIndex], isFalse);
      expect(nextDraft.stepDirty[onboardingClassJobStepIndex], isTrue);
    },
  );

  testWidgets('work block editing is routed by provider, not icon', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.workingKey,
        workType: 'full_time',
      ),
      baseTimeline: const BaseTimelineDraft(),
    );
    final misleadingWorkBlock = _scheduleBlock(
      id: 'client-calls',
      title: 'Client Calls',
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      config: ScheduleSetupConfig.workSetup,
      icon: ScheduleSetupConfig.classSetup.icon,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
          onboardingWorkTimelineProvider.overrideWith(
            (_) => [misleadingWorkBlock],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep4Unified()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final workBlock = find.byKey(
      const ValueKey('onboarding-step4-block-client-calls'),
    );
    await tester.ensureVisible(workBlock);
    await tester.tap(workBlock);
    await tester.pumpAndSettle();

    expect(find.text('Edit Work Block'), findsOneWidget);
    expect(find.text('Edit Class'), findsNothing);
  });

  testWidgets('nearby minute labels are not stacked unreadably', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      baseTimeline: const BaseTimelineDraft(),
    );
    final classBlocks = [
      _scheduleBlock(
        id: 'block-310',
        title: 'Block 310',
        startMinute: 15 * 60 + 10,
        endMinute: 15 * 60 + 20,
        config: ScheduleSetupConfig.classSetup,
      ),
      _scheduleBlock(
        id: 'block-315',
        title: 'Block 315',
        startMinute: 15 * 60 + 15,
        endMinute: 15 * 60 + 25,
        config: ScheduleSetupConfig.classSetup,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
          onboardingClassTimelineProvider.overrideWith((_) => classBlocks),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(child: OnboardingStep4Unified()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3:10'), findsOneWidget);
    expect(find.text('3:15'), findsNothing);
    expect(find.text('3:20'), findsNothing);
    expect(
      find.byKey(const ValueKey('onboarding-step4-minute-tick-910')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-step4-minute-tick-915')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-step4-minute-tick-920')),
      findsOneWidget,
    );
  });

  test('class/job step validation allows overlapping hard blocks', () {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentWorkingKey),
      baseTimeline: BaseTimelineDraft(
        blocks: [
          _timelineBlock(
            id: 'data-structures',
            section: 'classes',
            title: 'Data Structures',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          _timelineBlock(
            id: 'part-time-job',
            section: 'job_work_business',
            title: 'Part-Time Job',
            startMinute: 9 * 60 + 30,
            endMinute: 13 * 60,
          ),
        ],
      ),
    );

    expect(
      draft.validateStep(
        4,
        List<bool>.filled(OnboardingDraft.stepCount, false),
      ),
      isNull,
    );
  });

  test('final preview does not block class and work overlaps', () {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentWorkingKey),
      baseTimeline: BaseTimelineDraft(
        blocks: [
          _timelineBlock(
            id: 'data-structures',
            section: 'classes',
            title: 'Data Structures',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
          _timelineBlock(
            id: 'part-time-job',
            section: 'job_work_business',
            title: 'Part-Time Job',
            startMinute: 9 * 60 + 30,
            endMinute: 13 * 60,
          ),
        ],
      ),
    );

    final preview = draft.buildFinalPreview();

    expect(preview.blockingWarnings, isEmpty);
    expect(preview.warnings.join('\n'), isNot(contains('Resolve or accept')));
    expect(
      draft.validateStep(
        OnboardingDraft.lastStepIndex,
        List<bool>.filled(OnboardingDraft.stepCount, true),
      ),
      isNull,
    );
  });

  test(
    'AI repeat-day normalization derives clear labels without Monday default',
    () {
      expect(normalizeOnboarding4AiRepeatDays(const []), isEmpty);
      expect(normalizeOnboarding4AiRepeatDays(const [0, 1, 1, 3, 8]), const [
        1,
        3,
      ]);
      expect(
        repeatDaysForOnboarding4Candidate(
          _candidate(sourceColumnLabel: 'MONDAY'),
        ),
        const [1],
      );
      expect(
        repeatDaysForOnboarding4Candidate(_candidate(sourceRowLabel: 'Tue')),
        const [2],
      );
      expect(
        repeatDaysForOnboarding4Candidate(
          _candidate(sourceTextSnippet: 'Mon-Fri 9:00 Office Work'),
        ),
        const [1, 2, 3, 4, 5],
      );
      expect(
        repeatDaysForOnboarding4Candidate(_candidate(repeatDays: const [0, 8])),
        isEmpty,
      );
      expect(repeatDaysForOnboarding4Candidate(_candidate()), isEmpty);
    },
  );

  test(
    'work candidate filter keeps job blocks and rejects personal blocks',
    () {
      for (final title in const [
        'Office Work',
        'Work',
        'Shift',
        'Client Calls',
        'Meeting',
        'Lunch Break',
        'Project Work',
        'Freelance Project',
        'Business Hours',
        'Team Sync',
        'Training Session',
        'Commute',
        'Break',
      ]) {
        expect(
          isDisallowedOnboarding4WorkCandidate(_candidate(title: title)),
          isFalse,
          reason: title,
        );
      }

      for (final title in const [
        'Gym',
        'Gym / Exercise',
        'Gym/Exercise',
        'Workout',
        'Study',
        'Study / Reading',
        'Reading',
        'Online Course',
        'Rest Day',
        'No Work',
        'Rest Day / No Work',
        'Personal habits',
      ]) {
        expect(
          isDisallowedOnboarding4WorkCandidate(_candidate(title: title)),
          isTrue,
          reason: title,
        );
      }

      expect(
        isDisallowedOnboarding4WorkCandidate(
          _candidate(
            title: 'Office Work',
            sourceTextSnippet: 'Office Work row near No Work / Gym',
          ),
        ),
        isFalse,
      );
      expect(
        isDisallowedOnboarding4WorkCandidate(
          _candidate(
            title: 'Client Calls',
            sourceTextSnippet: 'Client Calls near Study / Reading',
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets('Next Step saves class job blocks and marks step clean', (
    tester,
  ) async {
    late MockOnboardingNotifier notifier;
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    completed[onboardingClassJobStepIndex] = false;
    final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
    dirty[onboardingClassJobStepIndex] = true;
    final draft = OnboardingDraft(
      uid: 'step4-save-user',
      currentStep: onboardingClassJobStepIndex,
      stepCompleted: completed,
      stepDirty: dirty,
      lifeRole: const LifeRoleDraft(
        lifeRole: LifeRoleDraft.studentWorkingKey,
        workType: 'part_time',
      ),
      baseTimeline: const BaseTimelineDraft(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith((_) {
            notifier = MockOnboardingNotifier()..loadSeedData(draft);
            return notifier;
          }),
          onboardingClassTimelineProvider.overrideWith(
            (_) => [
              _scheduleBlock(
                id: 'generated-class',
                title: 'Generated Class',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                config: ScheduleSetupConfig.classSetup,
              ),
            ],
          ),
          onboardingWorkTimelineProvider.overrideWith(
            (_) => [
              _scheduleBlock(
                id: 'generated-work',
                title: 'Generated Work',
                startMinute: 10 * 60,
                endMinute: 12 * 60,
                config: ScheduleSetupConfig.workSetup,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: OnboardingFlow()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Next Step'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nextDraft = notifier.state.draft;
    expect(nextDraft.currentStep, onboardingEatingStepIndex);
    expect(nextDraft.stepCompleted[onboardingClassJobStepIndex], isTrue);
    expect(nextDraft.stepDirty[onboardingClassJobStepIndex], isFalse);
    expect(
      nextDraft.baseTimeline
          .confirmedBlocksForSection('classes')
          .map((block) => block.title),
      contains('Generated Class'),
    );
    expect(
      nextDraft.baseTimeline
          .confirmedBlocksForSection('job_work_business')
          .map((block) => block.title),
      contains('Generated Work'),
    );
    expect(
      nextDraft.validateStep(
        OnboardingDraft.lastStepIndex,
        nextDraft.stepCompleted,
      ),
      isNull,
    );
  });

  test(
    'business class/job step validation asks for work/business timeline',
    () {
      final draft = OnboardingDraft(
        lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.businessKey),
        baseTimeline: const BaseTimelineDraft(),
      );

      expect(
        draft.validateStep(
          4,
          List<bool>.filled(OnboardingDraft.stepCount, false),
        ),
        'Generate your work/business timeline first.',
      );
    },
  );
}

ClassRoutineBlock _scheduleBlock({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
  required ScheduleSetupConfig config,
  IconData? icon,
}) {
  return ClassRoutineBlock(
    id: id,
    subject: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1],
    icon: icon ?? config.icon,
    color: OptivusColors.aquaAccent,
  );
}

TimelineBlockDraft _timelineBlock({
  required String id,
  required String section,
  required String title,
  required int startMinute,
  required int endMinute,
}) {
  return TimelineBlockDraft(
    id: id,
    section: section,
    title: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1],
    blockType: TimelineBlockDraft.hardBlockKey,
    source: 'ai_import',
  );
}

RoutineImportCandidateBlock _candidate({
  String title = 'Office Work',
  List<int> repeatDays = const [],
  String? sourceColumnLabel,
  String? sourceRowLabel,
  String? sourceTextSnippet,
}) {
  return RoutineImportCandidateBlock(
    id: 'candidate',
    title: title,
    startMinute: 9 * 60,
    endMinute: 10 * 60,
    repeatDays: repeatDays,
    blockType: TimelineBlockDraft.hardBlockKey,
    category: 'job',
    hardBlock: true,
    sourceColumnLabel: sourceColumnLabel,
    sourceRowLabel: sourceRowLabel,
    sourceTextSnippet: sourceTextSnippet,
  );
}

void _expectBlockAlignedToTicks(
  WidgetTester tester, {
  required String blockId,
  required int startMinute,
  required int endMinute,
}) {
  final block = find.byKey(ValueKey('onboarding-step4-block-$blockId'));
  final startTick = find.byKey(
    ValueKey('onboarding-step4-minute-tick-$startMinute'),
  );
  final endTick = find.byKey(
    ValueKey('onboarding-step4-minute-tick-$endMinute'),
  );

  expect(
    tester.getTopLeft(block).dy,
    closeTo(tester.getTopLeft(startTick).dy, 0.5),
  );
  expect(
    tester.getBottomLeft(block).dy,
    closeTo(tester.getTopLeft(endTick).dy, 0.5),
  );
}
