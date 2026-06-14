import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/services/nutrition_ai_client.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
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
      expect(find.text('Job'), findsOneWidget);
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
      final dataWidth = tester
          .getSize(
            find.byKey(
              const ValueKey('onboarding-step4-block-data-structures'),
            ),
          )
          .width;
      final jobWidth = tester
          .getSize(
            find.byKey(const ValueKey('onboarding-step4-block-part-time-job')),
          )
          .width;
      expect(dataLeft - jobLeft, greaterThan(70));
      expect(dataWidth, lessThan(jobWidth));

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
      final dataBlock = find.byKey(
        const ValueKey('onboarding-step4-block-data-structures'),
      );
      await tester.ensureVisible(jobBlock);
      await tester.pumpAndSettle();

      await tester.tap(dataBlock);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Work Block'), findsNothing);

      await tester.tapAt(tester.getTopLeft(jobBlock) + const Offset(18, 14));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Edit Work Block'), findsNothing);

      final dataLeftAfter = tester.getTopLeft(dataBlock).dx;
      final jobLeftAfter = tester.getTopLeft(jobBlock).dx;
      final dataWidthAfter = tester.getSize(dataBlock).width;
      final jobWidthAfter = tester.getSize(jobBlock).width;
      expect(jobLeftAfter - dataLeftAfter, greaterThan(70));
      expect(jobWidthAfter, lessThan(dataWidthAfter));

      await tester.tap(
        find.byKey(const ValueKey('onboarding-step4-menu-part-time-job')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Work Block'), findsOneWidget);
    },
  );

  testWidgets(
    'overlap front and back layout exposes tappable labels without hidden text',
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
          id: 'ps',
          title: 'PS',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          room: 'C25-B-109',
          config: ScheduleSetupConfig.classSetup,
        ),
        _scheduleBlock(
          id: 'afl',
          title: 'AFL',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          room: 'C25-B-108',
          config: ScheduleSetupConfig.classSetup,
        ),
        _scheduleBlock(
          id: 'ds',
          title: 'DS',
          startMinute: 11 * 60,
          endMinute: 12 * 60,
          room: 'C25-B-108',
          config: ScheduleSetupConfig.classSetup,
        ),
      ];
      final workBlocks = [
        _scheduleBlock(
          id: 'job',
          title: 'Office Work',
          startMinute: 9 * 60,
          endMinute: 12 * 60,
          config: ScheduleSetupConfig.workSetup,
        ),
      ];

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      final jobBlock = find.byKey(const ValueKey('onboarding-step4-block-job'));
      final aflBlock = find.byKey(const ValueKey('onboarding-step4-block-afl'));
      final dsBlock = find.byKey(const ValueKey('onboarding-step4-block-ds'));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-job')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-front-content-ps')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-front-content-afl')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-front-content-ds')),
        findsOneWidget,
      );
      expect(find.text('9:00 AM - 12:00 PM'), findsNothing);
      expect(find.textContaining('AFLice'), findsNothing);
      expect(find.text('Office'), findsOneWidget); // Only one back label now
      expect(find.text('C25-B-108'), findsNWidgets(2)); // AFL and DS
      expect(find.text('C25-B-109'), findsOneWidget); // PS
      expect(find.text('C25-'), findsNothing); // Ensure no badly cut chip

      final jobLeft = tester.getTopLeft(jobBlock).dx;
      final aflLeft = tester.getTopLeft(aflBlock).dx;
      final dsLeft = tester.getTopLeft(dsBlock).dx;
      final exposedWidth = aflLeft - jobLeft;
      expect(exposedWidth, greaterThanOrEqualTo(58));
      expect(exposedWidth, lessThanOrEqualTo(96));
      expect(dsLeft, closeTo(aflLeft, 0.5));
      expect(
        tester.getSize(jobBlock).width,
        greaterThan(tester.getSize(aflBlock).width),
      );
      expect(
        tester.getSize(jobBlock).width,
        greaterThan(tester.getSize(dsBlock).width),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-step4-back-label-job')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step4-back-label-job')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Work Block'), findsNothing);
      expect(
        find.byKey(const ValueKey('onboarding-step4-front-content-job')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-ps')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-afl')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-ds')),
        findsOneWidget,
      );
      expect(find.text('9:00 AM - 12:00 PM'), findsOneWidget);
      expect(find.text('9:00 AM - 10:00 AM'), findsNothing);
      expect(find.text('10:00 AM - 11:00 AM'), findsNothing);
      expect(find.text('11:00 AM - 12:00 PM'), findsNothing);
      expect(
        find.byKey(const ValueKey('onboarding-step4-menu-job')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-menu-afl')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-step4-back-label-afl')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-step4-back-label-afl')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Class'), findsNothing);
      expect(
        find.byKey(const ValueKey('onboarding-step4-front-content-afl')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-job')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-ps')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-step4-back-label-ds')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Student + Working shows deterministic class/work upload targets',
    (tester) async {
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

      expect(tester.takeException(), isNull);
      expect(find.text('Upload your class and work timetable'), findsOneWidget);
      expect(find.text('Class timetable'), findsOneWidget);
      expect(find.text('Work schedule'), findsOneWidget);
      expect(find.text('Set Your Weekly Schedule'), findsOneWidget);
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      final classTarget = find.byKey(
        const ValueKey('onboarding-step4-upload-target-classes'),
      );
      final workTarget = find.byKey(
        const ValueKey('onboarding-step4-upload-target-work'),
      );
      expect(classTarget, findsOneWidget);
      expect(workTarget, findsOneWidget);
      expect(
        (tester.getTopLeft(classTarget).dy - tester.getTopLeft(workTarget).dy)
            .abs(),
        lessThan(2),
      );
      expect(
        tester.getTopLeft(workTarget).dx,
        greaterThan(tester.getTopLeft(classTarget).dx),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('onboarding-step4-upload-card')))
            .height,
        lessThan(180),
      );
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(
        find.text('Add both photos, then generate your timeline.'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('onboarding-step4-upload-targets-horizontal'),
        ),
        findsOneWidget,
      );
    },
  );

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
      find.text('Add your work, shift, or business schedule photo.'),
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

    expect(find.text('Class and work schedule generated'), findsOneWidget);
    expect(
      find.text(
        'Your class and work blocks are ready. Use each block menu to edit or remove them.',
      ),
      findsOneWidget,
    );
    expect(find.text('Upload your class and work timetable'), findsNothing);
    expect(find.text('Saved Class'), findsOneWidget);
    expect(find.text('Saved Work'), findsOneWidget);
  });

  testWidgets('student only generated card shows correct copy', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
      baseTimeline: BaseTimelineDraft(
        blocks: [
          _timelineBlock(
            id: 'saved-class',
            section: 'classes',
            title: 'Saved Class',
            startMinute: 9 * 60,
            endMinute: 10 * 60,
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

    expect(find.text('Class schedule generated'), findsOneWidget);
    expect(
      find.text(
        'Your weekly class timeline is ready. Use each block menu to edit or remove it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('work only generated card shows correct copy', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey, workType: 'full_time'),
      baseTimeline: BaseTimelineDraft(
        blocks: [
          _timelineBlock(
            id: 'saved-work',
            section: 'job_work_business',
            title: 'Saved Work',
            startMinute: 9 * 60,
            endMinute: 17 * 60,
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

    expect(find.text('Work schedule generated'), findsOneWidget);
    expect(
      find.text(
        'Your weekly work timeline is ready. Use each block menu to edit or remove it.',
      ),
      findsOneWidget,
    );
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

      expect(find.text('Class and work schedule generated'), findsOneWidget);
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

    expect(find.text('Edit Work Block'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('onboarding-step4-menu-client-calls')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Edit'));
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
        repeatDaysForOnboarding4Candidate(_candidate(sourceRowLabel: 'MON(1)')),
        const [1],
      );
      expect(
        repeatDaysForOnboarding4Candidate(_candidate(sourceRowLabel: 'TUE(1)')),
        const [2],
      );
      expect(
        repeatDaysForOnboarding4Candidate(
          _candidate(sourceColumnLabel: 'Friday'),
        ),
        const [5],
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
    'Student + Working upload targets route source and purpose by target',
    () {
      final targets = onboarding4UploadTargetsForRole(
        LifeRoleDraft.studentWorkingKey,
      );

      expect(targets, hasLength(2));
      expect(targets.first.thumbnailLabel, 'Class');
      expect(targets.first.source, RoutineImportReviewSource.classes);
      expect(targets.first.purpose, UploadedAssetPurpose.classTimetable);
      expect(targets.last.thumbnailLabel, 'Work');
      expect(targets.last.source, RoutineImportReviewSource.work);
      expect(targets.last.purpose, UploadedAssetPurpose.workSchedule);

      final reversedUploadOrder = [targets.last, targets.first];
      expect(reversedUploadOrder.first.thumbnailLabel, 'Work');
      expect(
        targets.firstWhere((target) => target.thumbnailLabel == 'Class').source,
        RoutineImportReviewSource.classes,
      );
      expect(
        targets.firstWhere((target) => target.thumbnailLabel == 'Work').purpose,
        UploadedAssetPurpose.workSchedule,
      );
    },
  );

  test('combined class target maps the same class candidate as class-only', () {
    final studentOnlyTargets = onboarding4UploadTargetsForRole(
      LifeRoleDraft.studentKey,
    );
    final combinedTargets = onboarding4UploadTargetsForRole(
      LifeRoleDraft.studentWorkingKey,
    );
    final candidate = _candidate(
      title: 'AFL',
      category: 'other',
      sourceRowLabel: 'MON(1)',
    );

    final studentOnlyResult = mapOnboarding4Candidates(
      candidates: [candidate],
      config: ScheduleSetupConfig.classSetup,
    );
    final combinedResult = mapOnboarding4Candidates(
      candidates: [candidate],
      config: ScheduleSetupConfig.classSetup,
    );

    expect(studentOnlyTargets.single.source, RoutineImportReviewSource.classes);
    expect(
      combinedTargets
          .firstWhere((target) => target.thumbnailLabel == 'Class')
          .source,
      RoutineImportReviewSource.classes,
    );
    expect(studentOnlyResult.blocks.map((block) => block.subject), ['AFL']);
    expect(combinedResult.blocks.map((block) => block.subject), ['AFL']);
    expect(combinedResult.blocks.single.repeatDays, const [1]);
  });

  test(
    'Onboarding 4 failure messages distinguish partial and both-source failure',
    () {
      final classSuccessWorkFail = onboarding4PartialFailureMessage(
        needsBothPhotos: true,
        successfulSources: {RoutineImportReviewSource.classes},
        failedSources: {RoutineImportReviewSource.work},
      );
      final detailedClassSuccessWorkFail = onboarding4PartialFailureMessage(
        needsBothPhotos: true,
        successfulSources: {RoutineImportReviewSource.classes},
        failedSources: {RoutineImportReviewSource.work},
        failureMessages: const {
          RoutineImportReviewSource.work:
              'Work photo is too large. Upload a smaller, clearer photo.',
        },
      );
      final workSuccessClassFail = onboarding4PartialFailureMessage(
        needsBothPhotos: true,
        successfulSources: {RoutineImportReviewSource.work},
        failedSources: {RoutineImportReviewSource.classes},
      );
      final bothFail = onboarding4TimelineErrorForFailures(
        needsBothPhotos: true,
        role: LifeRoleDraft.studentWorkingKey,
        failures: {
          RoutineImportReviewSource.classes,
          RoutineImportReviewSource.work,
        },
      );
      final detailedBothFail = onboarding4TimelineErrorForFailures(
        needsBothPhotos: true,
        role: LifeRoleDraft.studentWorkingKey,
        failures: {
          RoutineImportReviewSource.classes,
          RoutineImportReviewSource.work,
        },
        failureMessages: const {
          RoutineImportReviewSource.classes:
              'AI response could not be read safely. Please try again.',
          RoutineImportReviewSource.work:
              'Work photo format is not supported. Please upload JPEG, PNG, or WEBP.',
        },
      );

      expect(
        classSuccessWorkFail,
        'Work schedule could not be read clearly. Check the Work photo or upload a clearer image.',
      );
      expect(
        detailedClassSuccessWorkFail,
        'Work photo is too large. Upload a smaller, clearer photo.',
      );
      expect(
        workSuccessClassFail,
        'Class timetable could not be read clearly. Check the Class photo or upload a clearer image.',
      );
      expect(
        bothFail,
        'AI could not detect class or work schedule blocks clearly.',
      );
      expect(
        detailedBothFail,
        'AI response could not be read safely. Please try again.\n'
        'Work photo format is not supported. Please upload JPEG, PNG, or WEBP.',
      );
    },
  );

  test('Onboarding 4 source failure messages surface worker reasons', () {
    expect(
      onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: LifeRoleDraft.studentWorkingKey,
        warnings: const ['Please upload JPEG, PNG, or WEBP for now.'],
        rawCandidateCount: null,
        mappedBlockCount: 0,
      ),
      'Class photo format is not supported. Please upload JPEG, PNG, or WEBP.',
    );
    expect(
      onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: LifeRoleDraft.studentWorkingKey,
        warnings: const ['Uploaded source image was not found.'],
        rawCandidateCount: null,
        mappedBlockCount: 0,
      ),
      'Uploaded work photo could not be found. Please upload again.',
    );
    expect(
      onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: LifeRoleDraft.studentWorkingKey,
        warnings: const [
          'AI extraction service returned invalid structured data.',
        ],
        rawCandidateCount: null,
        mappedBlockCount: 0,
      ),
      'AI response could not be read safely. Please try again.',
    );
    expect(
      onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: LifeRoleDraft.studentWorkingKey,
        warnings: const [],
        rawCandidateCount: 0,
        mappedBlockCount: 0,
      ),
      'AI could not read this timetable. Please upload a clearer image and try again.',
    );
    expect(
      onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: LifeRoleDraft.studentWorkingKey,
        warnings: const [],
        rawCandidateCount: 3,
        mappedBlockCount: 0,
      ),
      'AI could not read this timetable. Please upload a clearer image and try again.',
    );
  });

  test('Onboarding 4 source failure messages surface provider codes', () {
    final cases = <List<Object>>[
      const [
        'provider_model_not_found',
        'AI model is not available. Check worker model config.',
      ],
      const ['provider_unauthorized', 'AI key is invalid or unauthorized.'],
      const ['provider_quota_exceeded', 'AI is busy right now. Please try again.'],
      const [
        'provider_timeout',
        'AI import failed. Please try again.',
      ],
      const [
        'provider_invalid_image_payload',
        'AI could not process this image format.',
      ],
      const ['provider_empty_candidates', 'AI could not read this timetable. Please upload a clearer image and try again.'],
      const [
        'provider_request_failed',
        'AI import failed. Please try again.',
      ],
    ];

    for (final entry in cases) {
      expect(
        onboarding4SourceFailureMessage(
          source: RoutineImportReviewSource.classes,
          role: LifeRoleDraft.studentWorkingKey,
          warnings: [entry[0] as String],
          rawCandidateCount: null,
          mappedBlockCount: 0,
        ),
        entry[1],
        reason: entry[0] as String,
      );
    }
  });

  test(
    'Onboarding 4 mapping accepts class abbreviations with time and day',
    () {
      final result = mapOnboarding4Candidates(
        candidates: [
          _candidate(title: 'AFL', sourceRowLabel: 'MON(1)', category: 'other'),
          _candidate(title: 'DS', sourceColumnLabel: 'TUE(1)'),
          _candidate(title: 'DSD', sourceTextSnippet: 'Friday 9-10 DSD'),
          _candidate(title: '', sourceRowLabel: 'MON'),
          _candidate(title: 'PS'),
        ],
        config: ScheduleSetupConfig.classSetup,
      );

      expect(result.blocks.map((block) => block.subject), ['AFL', 'DS', 'DSD']);
      expect(result.blocks[0].repeatDays, const [1]);
      expect(result.blocks[1].repeatDays, const [2]);
      expect(result.blocks[2].repeatDays, const [5]);
      expect(result.droppedNoTitle, 1);
      expect(result.droppedNoRepeatDays, 1);
    },
  );

  test(
    'Onboarding 4 mapping accepts work blocks and rejects personal blocks',
    () {
      final result = mapOnboarding4Candidates(
        candidates: [
          for (final title in const [
            'Office Work',
            'Lunch Break',
            'Client Calls',
            'Freelance Project',
          ])
            _candidate(
              title: title,
              sourceColumnLabel: 'Mon-Fri',
              sourceTextSnippet: '$title near Gym / Rest Day',
            ),
          for (final title in const [
            'Gym',
            'Study',
            'Online Course',
            'Rest Day',
          ])
            _candidate(title: title, sourceColumnLabel: 'Mon-Fri'),
        ],
        config: ScheduleSetupConfig.workSetup,
      );

      expect(result.blocks.map((block) => block.subject), [
        'Office Work',
        'Lunch Break',
        'Client Calls',
        'Freelance Project',
      ]);
      expect(result.droppedNonWork, 4);
      expect(result.droppedInvalidTime, 0);
      expect(result.droppedNoRepeatDays, 0);
    },
  );

  test(
    'Routine import worker invalid response reason identifies source mismatch',
    () {
      final raw = _workerResultMap(
        source: 'work',
        sourceR2Key: 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
        candidateSourceR2Key:
            'users/uid-1/onboarding/class_timetable/asset-1.jpg',
      );
      final result = RoutineImportExtractionResult.fromMap(raw);
      final reason = routineImportWorkerResponseInvalidReason(
        result,
        uid: 'uid-1',
        review: _reviewDraft(),
        raw: raw,
      );

      expect(reason, 'source mismatch');
    },
  );

  test(
    'Routine import worker invalid response reason identifies candidate mismatch',
    () {
      final raw = _workerResultMap(
        candidateSourceR2Key:
            'users/uid-1/onboarding/work_schedule/asset-1.jpg',
      );
      final result = RoutineImportExtractionResult.fromMap(raw);
      final reason = routineImportWorkerResponseInvalidReason(
        result,
        uid: 'uid-1',
        review: _reviewDraft(),
        raw: raw,
      );

      expect(reason, 'candidate invalid at index 0: sourceR2Key mismatch');
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

  testWidgets('Next Step saves overlaps without changing focused block times', (
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
                id: 'afl',
                title: 'AFL',
                startMinute: 9 * 60,
                endMinute: 10 * 60,
                config: ScheduleSetupConfig.classSetup,
              ),
              _scheduleBlock(
                id: 'ds',
                title: 'DS',
                startMinute: 10 * 60,
                endMinute: 11 * 60,
                config: ScheduleSetupConfig.classSetup,
              ),
            ],
          ),
          onboardingWorkTimelineProvider.overrideWith(
            (_) => [
              _scheduleBlock(
                id: 'job',
                title: 'Job',
                startMinute: 9 * 60,
                endMinute: 13 * 60,
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-step4-back-label-job')),
    );
    await tester.tap(
      find.byKey(const ValueKey('onboarding-step4-back-label-job')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('onboarding-step4-front-content-job')),
      findsOneWidget,
    );

    await tester.tap(find.text('Next Step'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final nextDraft = notifier.state.draft;
    final savedClasses = nextDraft.baseTimeline.confirmedBlocksForSection(
      'classes',
    );
    final savedWork = nextDraft.baseTimeline.confirmedBlocksForSection(
      'job_work_business',
    );
    final savedAfl = savedClasses.firstWhere((block) => block.id == 'afl');
    final savedDs = savedClasses.firstWhere((block) => block.id == 'ds');
    final savedJob = savedWork.firstWhere((block) => block.id == 'job');

    expect(nextDraft.currentStep, onboardingEatingStepIndex);
    expect(nextDraft.stepCompleted[onboardingClassJobStepIndex], isTrue);
    expect(nextDraft.stepDirty[onboardingClassJobStepIndex], isFalse);
    expect(savedAfl.title, 'AFL');
    expect(savedAfl.startMinute, 9 * 60);
    expect(savedAfl.endMinute, 10 * 60);
    expect(savedAfl.blockType, TimelineBlockDraft.hardBlockKey);
    expect(savedAfl.source, 'ai_import');
    expect(savedDs.title, 'DS');
    expect(savedDs.startMinute, 10 * 60);
    expect(savedDs.endMinute, 11 * 60);
    expect(savedJob.title, 'Job');
    expect(savedJob.startMinute, 9 * 60);
    expect(savedJob.endMinute, 13 * 60);
    expect(savedJob.blockType, TimelineBlockDraft.hardBlockKey);
    expect(savedJob.source, 'ai_import');
    expect(
      nextDraft.validateStep(
        OnboardingDraft.lastStepIndex,
        nextDraft.stepCompleted,
      ),
      isNull,
    );
  });

  testWidgets('Eating setup starts with two simple choices', (tester) async {
    final draft = OnboardingDraft(
      currentStep: onboardingEatingStepIndex,
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
          home: Scaffold(body: SizedBox.expand(child: OnboardingStep5())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eating Setup'), findsOneWidget);
    expect(
      find.text('Build your weekly meal routine in a simple way.'),
      findsOneWidget,
    );
    expect(find.text('Yes, I have a routine/menu'), findsOneWidget);
    expect(find.text('No, help me create one'), findsOneWidget);
    expect(
      find.text('Generate a simple meal routine with dishes.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
    expect(find.byType(OnboardingScrollView), findsNothing);
    expect(find.text('Goal'), findsNothing);
    expect(find.text('Open review'), findsNothing);
  });

  testWidgets('Eating yes path shows inline upload timeline without review', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      currentStep: onboardingEatingStepIndex,
      baseTimeline: const BaseTimelineDraft(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(child: OnboardingStep5()),
                Consumer(
                  builder: (context, ref, child) {
                    final draft = ref.watch(mockOnboardingProvider).draft;
                    if (draft.baseTimeline.eatingSetupStep > 0) {
                      return OnboardingStageBackButton(
                        key: const ValueKey('onboarding-step5-back'),
                        onTap: () {
                          ref.read(mockOnboardingProvider.notifier).clearValidation();
                          updateBaseTimelineDraft(ref, 5, (base) => base.copyWith(eatingSetupStep: 0));
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes, I have a routine/menu'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('onboarding-step5-back')), findsOneWidget);
    expect(find.text('Upload your routine/menu'), findsOneWidget);
    expect(find.text('Add your weekly meal timetable photo.'), findsOneWidget);
    expect(find.text('Set Your Weekly Meal'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-step5-timeline-scroll')),
      findsNothing,
    );
    expect(find.byType(OnboardingScrollView), findsNothing);
    expect(
      find.text('Generate your weekly meal routine first.'),
      findsOneWidget,
    );
    expect(find.text('Open review'), findsNothing);
    expect(find.text('Review AI draft'), findsNothing);
    expect(find.text('Eating summary'), findsNothing);
    expect(find.text('provider_request_failed'), findsNothing);
  });

  testWidgets('Eating no path shows compact AI meal generation controls', (
    tester,
  ) async {
    final draft = OnboardingDraft(
      currentStep: onboardingEatingStepIndex,
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
          home: Scaffold(body: SizedBox.expand(child: OnboardingStep5())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('No, help me create one'));
    await tester.pumpAndSettle();

    expect(find.text('Create your meal intelligence'), findsOneWidget);
    expect(
      find.text('Body basics missing. Using a simple balanced routine.'),
      findsOneWidget,
    );
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Gain'), findsOneWidget);
    expect(find.text('Lose'), findsOneWidget);
    expect(find.text('Maintain'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
    expect(find.text('US'), findsOneWidget);
    expect(find.text('Germany'), findsOneWidget);
    expect(find.text('Veg'), findsOneWidget);
    expect(find.text('Non-veg'), findsOneWidget);
    expect(find.text('Generate meal routine'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Breakfast'), findsWidgets);
    expect(find.text('Lunch'), findsWidgets);
    expect(find.text('Snack'), findsWidgets);
    expect(find.text('Dinner'), findsWidgets);
    expect(find.byType(OnboardingScrollView), findsNothing);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Cooking skill'), findsNothing);
  });

  testWidgets('Eating stage back returns to choice screen', (tester) async {
    final draft = OnboardingDraft(
      currentStep: onboardingEatingStepIndex,
      baseTimeline: const BaseTimelineDraft(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(child: OnboardingStep5()),
                Consumer(
                  builder: (context, ref, child) {
                    final draft = ref.watch(mockOnboardingProvider).draft;
                    if (draft.baseTimeline.eatingSetupStep > 0) {
                      return OnboardingStageBackButton(
                        key: const ValueKey('onboarding-step5-back'),
                        onTap: () {
                          ref.read(mockOnboardingProvider.notifier).clearValidation();
                          updateBaseTimelineDraft(ref, 5, (base) => base.copyWith(eatingSetupStep: 0));
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('No, help me create one'));
    await tester.pumpAndSettle();
    expect(find.text('Create your meal intelligence'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-step5-back')));
    await tester.pumpAndSettle();

    expect(find.text('Yes, I have a routine/menu'), findsOneWidget);
    expect(find.text('No, help me create one'), findsOneWidget);
    expect(find.text('Create your meal intelligence'), findsNothing);
  });

  testWidgets('Eating no path saves generated blocks and advances to Fixed', (
    tester,
  ) async {
    late MockOnboardingNotifier notifier;
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    completed[onboardingEatingStepIndex] = false;
    final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
    dirty[onboardingEatingStepIndex] = true;
    final draft = OnboardingDraft(
      uid: 'eating-save-user',
      currentStep: onboardingEatingStepIndex,
      stepCompleted: completed,
      stepDirty: dirty,
      baseTimeline: const BaseTimelineDraft(
        eatingSetupPath: onboardingEatingPathCreate,
        eatingSetupStep: 1,
        mealsPerDay: 4,
        foodType: 'veg',
        breakfastMinute: 8 * 60,
        lunchMinute: 13 * 60,
        snackMinute: 17 * 60,
        dinnerMinute: 20 * 60 + 30,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith((_) {
            notifier = MockOnboardingNotifier()..loadSeedData(draft);
            return notifier;
          }),
          nutritionAiClientProvider.overrideWithValue(const FakeNutritionAiClient()),
        ],
        child: const MaterialApp(home: OnboardingFlow()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Next Step'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      notifier.state.validationMessage,
      'Generate your meal routine first.',
    );

    await tester.tap(find.text('Generate meal routine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Create your meal intelligence'), findsNothing);
    expect(
      find.textContaining('Maintain · India · Veg · 4 meals'),
      findsOneWidget,
    );
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Set Your Weekly Meal'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-step5-timeline-scroll')),
      findsOneWidget,
    );

    await tester.tap(find.text('Next Step'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final nextDraft = notifier.state.draft;
    final eatingBlocks = nextDraft.baseTimeline.confirmedBlocksForSection(
      'eating',
    );
    expect(nextDraft.currentStep, onboardingFixedStepIndex);
    expect(nextDraft.stepCompleted[onboardingEatingStepIndex], isTrue);
    expect(nextDraft.stepDirty[onboardingEatingStepIndex], isFalse);
    expect(
      eatingBlocks.map((b) => b.title).toList(),
      ['Breakfast', 'Lunch', 'Snack', 'Dinner'],
    );
    expect(
      eatingBlocks.every(
        (block) =>
            block.section == 'eating' &&
            block.source == onboardingEatingGeneratedSource &&
            block.blockType == TimelineBlockDraft.hardBlockKey &&
            block.repeatDays.length == 7,
      ),
      isTrue,
    );
    expect(eatingBlocks.first.dishes, isNotEmpty);
  });

  testWidgets('Eating has-routine path saves AI blocks without review screen', (
    tester,
  ) async {
    late MockOnboardingNotifier notifier;
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    completed[onboardingEatingStepIndex] = false;
    final dirty = List<bool>.filled(OnboardingDraft.stepCount, false);
    dirty[onboardingEatingStepIndex] = true;
    final draft = OnboardingDraft(
      uid: 'eating-ai-save-user',
      currentStep: onboardingEatingStepIndex,
      stepCompleted: completed,
      stepDirty: dirty,
      baseTimeline: BaseTimelineDraft(
        eatingSetupPath: onboardingEatingPathHasRoutine,
        eatingSetupStep: 1,
        blocks: [
          _timelineBlock(
            id: 'ai-breakfast',
            section: 'eating',
            title: 'Breakfast',
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 30,
          ).copyWith(source: onboardingEatingAiImportSource),
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
        child: const MaterialApp(home: OnboardingFlow()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Open review'), findsNothing);

    await tester.tap(find.text('Next Step'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final nextDraft = notifier.state.draft;
    expect(nextDraft.currentStep, onboardingFixedStepIndex);
    expect(nextDraft.stepCompleted[onboardingEatingStepIndex], isTrue);
    expect(nextDraft.stepDirty[onboardingEatingStepIndex], isFalse);
    expect(
      nextDraft.baseTimeline.confirmedBlocksForSection('eating').single.source,
      onboardingEatingAiImportSource,
    );
  });

  test('Eating AI candidates map directly to eating timeline blocks', () {
    final blocks = onboarding5MealBlocksFromCandidates([
      RoutineImportCandidateBlock(
        id: 'breakfast',
        title: 'Breakfast',
        startMinute: 8 * 60,
        endMinute: 8 * 60 + 30,
        repeatDays: const [1, 3, 5],
        blockType: TimelineBlockDraft.hardBlockKey,
        category: 'eating',
        hardBlock: true,
        mealCategory: 'breakfast',
        steps: const ['Idli', 'Sambar'],
      ),
      RoutineImportCandidateBlock(
        id: 'lunch',
        title: 'Lunch',
        startMinute: 13 * 60,
        endMinute: 13 * 60 + 45,
        repeatDays: const [],
        blockType: TimelineBlockDraft.hardBlockKey,
        category: 'eating',
        hardBlock: true,
        steps: const ['Lunch item'],
      ),
      RoutineImportCandidateBlock(
        id: 'bad',
        title: '',
        startMinute: 13 * 60,
        endMinute: 13 * 60 + 45,
        repeatDays: const [1],
        blockType: TimelineBlockDraft.hardBlockKey,
        category: 'eating',
        hardBlock: true,
      ),
    ], now: DateTime.utc(2026, 6, 9));

    expect(blocks.map((block) => block.title), ['Breakfast', 'Lunch']);
    expect(blocks.first.section, 'eating');
    expect(blocks.first.source, onboardingEatingAiImportSource);
    expect(blocks.first.repeatDays, const [1, 3, 5]);
    expect(blocks.first.mealCategory, 'breakfast');
    expect(blocks.first.dishes, const ['Idli', 'Sambar']);
    expect(blocks.last.repeatDays, onboardingEveryDay());
    expect(blocks.last.blockType, TimelineBlockDraft.hardBlockKey);
  });

  test(
    'Eating mess menu candidates derive day labels and default meal times',
    () {
      final mapped = mapOnboarding5MealCandidates([
        RoutineImportCandidateBlock(
          id: 'mon-breakfast',
          title: 'Breakfast',
          startMinute: 0,
          endMinute: 0,
          hasFixedTime: false,
          repeatDays: const [],
          blockType: TimelineBlockDraft.softBlockKey,
          category: 'eating',
          hardBlock: false,
          mealCategory: 'breakfast',
          sourceRowLabel: 'Monday',
          sourceColumnLabel: 'Breakfast 7:30 AM - 10:00 AM',
          sourceTextSnippet: 'Idli, Sambar, Chutney',
        ),
        RoutineImportCandidateBlock(
          id: 'wed-snacks',
          title: 'Snacks',
          startMinute: 0,
          endMinute: 0,
          hasFixedTime: false,
          repeatDays: const [],
          blockType: TimelineBlockDraft.softBlockKey,
          category: 'eating',
          hardBlock: false,
          mealCategory: 'snacks',
          sourceRowLabel: 'Wed',
          sourceColumnLabel: 'Snacks',
          steps: const ['Poha', 'Tea'],
        ),
        RoutineImportCandidateBlock(
          id: 'no-meal-time',
          title: 'Mess item',
          startMinute: 0,
          endMinute: 0,
          hasFixedTime: false,
          repeatDays: const [1],
          blockType: TimelineBlockDraft.softBlockKey,
          category: 'eating',
          hardBlock: false,
        ),
      ], now: DateTime.utc(2026, 6, 9));

      expect(mapped.blocks.length, 2);
      expect(mapped.droppedNoMealTime, 1);
      expect(mapped.blocks.first.title, 'Breakfast');
      expect(mapped.blocks.first.repeatDays, const [1]);
      expect(mapped.blocks.first.startMinute, 7 * 60 + 30);
      expect(mapped.blocks.first.endMinute, 10 * 60);
      expect(mapped.blocks.first.dishes, ['Idli', 'Sambar', 'Chutney']);
      expect(mapped.blocks.last.title, 'Snack');
      expect(mapped.blocks.last.repeatDays, const [3]);
      expect(mapped.blocks.last.startMinute, 18 * 60);
      expect(mapped.blocks.last.endMinute, 19 * 60);
      expect(mapped.blocks.last.dishes, ['Poha', 'Tea']);
    },
  );



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

  testWidgets('Bottom CTA clearance allows scrolling past last block', (
    tester,
  ) async {
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    completed[onboardingClassJobStepIndex] = false;
    final draft = OnboardingDraft(
      currentStep: onboardingClassJobStepIndex,
      stepCompleted: completed,
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.workingKey, workType: 'full_time'),
      baseTimeline: const BaseTimelineDraft(),
    );
    final workBlocks = [
      _scheduleBlock(
        id: 'late-shift',
        title: 'Late Shift',
        startMinute: 22 * 60, // 10 PM
        endMinute: 24 * 60,   // Midnight
        config: ScheduleSetupConfig.workSetup,
      ),
    ];

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockOnboardingProvider.overrideWith(
            (_) => MockOnboardingNotifier()..loadSeedData(draft),
          ),
          onboardingWorkTimelineProvider.overrideWith((_) => workBlocks),
        ],
        child: const MaterialApp(
          home: OnboardingFlow(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final lateBlock = find.byKey(const ValueKey('onboarding-step4-block-late-shift'));
    await tester.ensureVisible(lateBlock);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Drag up to see if we can scroll past the block (verifying bottom padding exists)
    await tester.drag(lateBlock, const Offset(0, -350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(lateBlock, findsOneWidget);

    final ctaButton = find.text('Next Step');
    expect(ctaButton, findsOneWidget);

    // The block should be positioned visually higher than the CTA's top
    // Because we scrolled to the bottom and added 420px padding.
    final blockBottom = tester.getBottomRight(lateBlock).dy;
    final ctaTop = tester.getTopLeft(ctaButton).dy;
    expect(blockBottom, lessThan(ctaTop));
  });

  test('Candidate mapping preserves room', () {
    final candidate = RoutineImportCandidateBlock(
      id: '1',
      title: 'AFL',
      startMinute: 600,
      endMinute: 660,
      hasFixedTime: true,
      repeatDays: [1, 2],
      blockType: 'class',
      category: 'class',
      hardBlock: true,
      selected: true,
      needsManualReview: false,
      candidateType: RoutineImportCandidateType.block,
      validationIssues: [],
      extractionEngine: 'fake',
      location: 'C25-B-108',
    );

    final room = extractRoomLabelFromOnboarding4Candidate(candidate);
    expect(room, 'C25-B-108');

    final candidateSnippet = RoutineImportCandidateBlock(
      id: '2',
      title: 'DS',
      startMinute: 660,
      endMinute: 720,
      hasFixedTime: true,
      repeatDays: [1, 2],
      blockType: 'class',
      category: 'class',
      hardBlock: true,
      selected: true,
      needsManualReview: false,
      candidateType: RoutineImportCandidateType.block,
      validationIssues: [],
      extractionEngine: 'fake',
      sourceTextSnippet: 'DS Lab 2',
    );

    final roomSnippet = extractRoomLabelFromOnboarding4Candidate(candidateSnippet);
    expect(roomSnippet, 'Lab 2');
  });

  testWidgets('Compact front class block shows room beside subject without overflow', (WidgetTester tester) async {
    final completed = List<bool>.filled(OnboardingDraft.stepCount, true);
    completed[onboardingClassJobStepIndex] = false;
    final draft = OnboardingDraft(
      currentStep: onboardingClassJobStepIndex,
      stepCompleted: completed,
      lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentWorkingKey, workType: 'full_time'),
      baseTimeline: const BaseTimelineDraft(),
    );

    final classBlocks = [
      _scheduleBlock(
        id: 'ps',
        title: 'PS',
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        room: 'C25-A-109',
        config: ScheduleSetupConfig.classSetup,
      ),
      _scheduleBlock(
        id: 'afl',
        title: 'AFL',
        startMinute: 10 * 60,
        endMinute: 11 * 60,
        room: 'C25-B-108',
        config: ScheduleSetupConfig.classSetup,
      ),
      _scheduleBlock(
        id: 'ds',
        title: 'DS',
        startMinute: 11 * 60,
        endMinute: 12 * 60,
        room: 'C25-B-108',
        config: ScheduleSetupConfig.classSetup,
      ),
      _scheduleBlock(
        id: 'ind4',
        title: 'IND4',
        startMinute: 12 * 60,
        endMinute: 13 * 60,
        room: 'C25-B-109',
        config: ScheduleSetupConfig.classSetup,
      ),
    ];

    final workBlocks = [
      _scheduleBlock(
        id: 'office',
        title: 'Office Work',
        startMinute: 9 * 60,
        endMinute: 12 * 60,
        config: ScheduleSetupConfig.workSetup,
      ),
      _scheduleBlock(
        id: 'job',
        title: 'Job',
        startMinute: 12 * 60,
        endMinute: 15 * 60,
        config: ScheduleSetupConfig.workSetup,
      ),
    ];

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          home: OnboardingFlow(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The front class blocks are extremely compact (height ~ 60)
    // Their room numbers must still be visible beside the subject
    expect(find.text('PS'), findsOneWidget);
    expect(find.text('C25-A-109'), findsOneWidget);
    
    expect(find.text('AFL'), findsOneWidget);
    expect(find.text('C25-B-108'), findsNWidgets(2)); // AFL and DS
    expect(find.text('DS'), findsOneWidget);
    
    expect(find.text('IND4'), findsOneWidget);
    expect(find.text('C25-B-109'), findsOneWidget);

    // The back/down overlap label is just "Office", no room
    expect(find.text('Office'), findsWidgets);
    
    // There shouldn't be any truncated versions
    expect(find.text('C25-'), findsNothing);

    // Menu may be hidden for very narrow spaces, but RenderFlex shouldn't crash
    expect(tester.takeException(), isNull);
  });
}

ClassRoutineBlock _scheduleBlock({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
  required ScheduleSetupConfig config,
  IconData? icon,
  String room = '',
}) {
  return ClassRoutineBlock(
    id: id,
    subject: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1],
    icon: icon ?? config.icon,
    color: OptivusColors.aquaAccent,
    room: room,
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
  String category = 'job',
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
    category: category,
    hardBlock: true,
    sourceColumnLabel: sourceColumnLabel,
    sourceRowLabel: sourceRowLabel,
    sourceTextSnippet: sourceTextSnippet,
  );
}

RoutineImportReviewDraft _reviewDraft() {
  return RoutineImportReviewDraft(
    id: 'onboarding_classes_import_review',
    uid: 'uid-1',
    source: RoutineImportReviewSource.classes,
    status: RoutineImportReviewStatus.needsReview,
    sourceLabel: 'Classes',
    uploadedAssetId: 'asset-1',
    uploadedAssetR2Key: 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
    uploadedAssetStatus: 'uploaded',
    createdAt: DateTime.utc(2026, 6, 2),
    updatedAt: DateTime.utc(2026, 6, 2),
  );
}

Map<String, dynamic> _workerResultMap({
  String uid = 'uid-1',
  String source = 'classes',
  String sourceR2Key = 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
  String sourceAssetId = 'asset-1',
  String? candidateSourceR2Key,
  String? candidateSourceAssetId,
}) {
  return {
    'id': 'fake-onboarding_classes_import_review',
    'uid': uid,
    'source': source,
    'engine': 'fake',
    'engineVersion': 'phase2d',
    'sourceAssetId': sourceAssetId,
    'sourceR2Key': sourceR2Key,
    'rawText': 'MON 9:00 AFL',
    'candidates': [
      {
        'id': 'ai_class_afl',
        'title': 'AFL',
        'candidateType': 'block',
        'startMinute': 9 * 60,
        'endMinute': 10 * 60,
        'hasFixedTime': true,
        'repeatDays': [1],
        'blockType': TimelineBlockDraft.hardBlockKey,
        'category': 'classBlock',
        'hardBlock': true,
        'selected': true,
        'needsManualReview': false,
        'confidenceScore': 0.82,
        'confidenceLabel': 'high',
        'validationIssues': [],
        'sourceAssetId': candidateSourceAssetId ?? sourceAssetId,
        'sourceR2Key': candidateSourceR2Key ?? sourceR2Key,
        'sourceTextSnippet': 'MON 9:00 AFL',
        'sourceRowLabel': 'MON(1)',
        'sourceColumnLabel': '9-10',
        'extractionEngine': 'fake',
        'extractionVersion': 'phase2d',
        'steps': [],
      },
    ],
    'warnings': [],
    'createdAt': DateTime.utc(2026, 6, 2, 12).toIso8601String(),
  };
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
