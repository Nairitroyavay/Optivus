import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/onboarding_draft.dart';
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
}

ClassRoutineBlock _scheduleBlock({
  required String id,
  required String title,
  required int startMinute,
  required int endMinute,
  required ScheduleSetupConfig config,
}) {
  return ClassRoutineBlock(
    id: id,
    subject: title,
    startMinute: startMinute,
    endMinute: endMinute,
    repeatDays: const [1],
    icon: config.icon,
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
