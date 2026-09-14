import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/timeline/adapters/fixed_timeline_adapter.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/fixed_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('Base Timeline Fixed Completion Tests', () {
    test(
      'Overnight flag lockstep: crossesMidnight and endsNextDay in lockstep',
      () {
        // Overnight sleep block (23:00 to 07:00 next day)
        const overnightBlock = TimelineBlockDraft(
          id: BaseTimelineDraft.fixedSleepId,
          section: 'fixed',
          title: 'Sleep',
          startMinute: 23 * 60,
          endMinute: 7 * 60,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: true,
          endsNextDay: true,
        );

        // Both flags MUST be in lockstep for overnight blocks
        expect(overnightBlock.crossesMidnight, isTrue);
        expect(overnightBlock.endsNextDay, isTrue);

        // Daytime block: both are false in lockstep
        const dayBlock = TimelineBlockDraft(
          id: BaseTimelineDraft.fixedBathId,
          section: 'fixed',
          title: 'Bath',
          startMinute: 8 * 60,
          endMinute: 8 * 60 + 30,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
          crossesMidnight: false,
          endsNextDay: false,
        );

        expect(dayBlock.crossesMidnight, isFalse);
        expect(dayBlock.endsNextDay, isFalse);
      },
    );

    test(
      'Sleep and Bath semantic identities are strictly defined constants',
      () {
        expect(BaseTimelineDraft.fixedSleepId, 'fixed-sleep');
        expect(BaseTimelineDraft.fixedBathId, 'fixed-bath');
      },
    );

    testWidgets('Fixed edit sheet locks title for Sleep block', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    FixedTimelineAdapter.showFixedEditSheet(
                      context: context,
                      block: const TimelineBlockDraft(
                        id: BaseTimelineDraft.fixedSleepId,
                        section: 'fixed',
                        title: 'Sleep',
                        startMinute: 23 * 60,
                        endMinute: 7 * 60,
                        repeatDays: [1, 2, 3, 4, 5, 6, 7],
                        blockType: TimelineBlockDraft.hardBlockKey,
                        crossesMidnight: true,
                        endsNextDay: true,
                      ),
                      onSave: (updated) async => true,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.text('Core routine block name cannot be changed'),
        findsOneWidget,
      );
      expect(find.text('Sleep'), findsOneWidget);
    });

    testWidgets('Fixed edit sheet locks title for Bath block', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    FixedTimelineAdapter.showFixedEditSheet(
                      context: context,
                      block: const TimelineBlockDraft(
                        id: BaseTimelineDraft.fixedBathId,
                        section: 'fixed',
                        title: 'Bath',
                        startMinute: 8 * 60,
                        endMinute: 8 * 60 + 30,
                        repeatDays: [1, 2, 3, 4, 5, 6, 7],
                        blockType: TimelineBlockDraft.hardBlockKey,
                        crossesMidnight: false,
                        endsNextDay: false,
                      ),
                      onSave: (updated) async => true,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.text('Core routine block name cannot be changed'),
        findsOneWidget,
      );
      expect(find.text('Bath'), findsOneWidget);
    });

    testWidgets(
      'Fixed edit sheet allows editing title for custom non-core block',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      FixedTimelineAdapter.showFixedEditSheet(
                        context: context,
                        block: const TimelineBlockDraft(
                          id: 'custom_fixed_1',
                          section: 'fixed',
                          title: 'Evening Routine',
                          startMinute: 19 * 60,
                          endMinute: 19 * 60 + 30,
                          repeatDays: [1, 2, 3, 4, 5, 6, 7],
                          blockType: TimelineBlockDraft.hardBlockKey,
                        ),
                        onSave: (updated) async => true,
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // Custom block should NOT lock title or show the helper text
        expect(
          find.text('Core routine block name cannot be changed'),
          findsNothing,
        );
        expect(find.text('Evening Routine'), findsOneWidget);
      },
    );

    testWidgets(
      'Fixed setup screen displays BaseTimelineCurrentSetupHeader and allows reset',
      (tester) async {
        final now = DateTime.now();
        final setup = BaseTimelineSetup(
          uid: 'user-fixed-test',
          updatedAt: now,
          fixedBlocks: const [
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 23 * 60,
              endMinute: 7 * 60,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              crossesMidnight: true,
              endsNextDay: true,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 8 * 60,
              endMinute: 8 * 60 + 30,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              crossesMidnight: false,
              endsNextDay: false,
            ),
          ],
        );

        final fakeOnboardingRepo = FakeOnboardingRepository();
        final fakeSetupRepo = FakeBaseTimelineSetupRepository(
          onboardingRepo: fakeOnboardingRepo,
        );
        await fakeSetupRepo.saveSetup('user-fixed-test', setup);
        final fakeRoutineRepo = FakeRoutineRepository();
        final fakeTxRepo = FakeRoutineTransactionRepository(
          routineRepository: fakeRoutineRepo,
          setupRepository: fakeSetupRepo,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userProfileProvider.overrideWith(
                (ref) => UserProfileNotifier()
                  ..loadSeedData(
                    UserProfile(
                      uid: 'user-fixed-test',
                      email: 'test@optivus.local',
                      displayName: 'Fixed Test User',
                    ),
                  ),
              ),
              baseTimelineSetupRepositoryProvider.overrideWithValue(
                fakeSetupRepo,
              ),
              routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
              routineTransactionRepositoryProvider.overrideWithValue(
                fakeTxRepo,
              ),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: FixedBaseSetupScreen(onBack: () {}),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BaseTimelineCurrentSetupHeader), findsOneWidget);
        expect(find.text('Fixed'), findsWidgets);
        expect(find.text('Change setup'), findsOneWidget);

        final moreButton = find.byKey(
          const Key('base-timeline-header-menu-button'),
        );
        expect(moreButton, findsOneWidget);
        await tester.tap(moreButton);
        await tester.pumpAndSettle();

        expect(find.text('Reset Fixed Setup'), findsOneWidget);
        await tester.tap(find.text('Reset Fixed Setup'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Fixed Setup?'), findsOneWidget);
        expect(
          find.text(
            'This will restore default Sleep and Bath times and remove any custom fixed blocks.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(find.text('Fixed setup reset to defaults'), findsOneWidget);
      },
    );
  });
}
