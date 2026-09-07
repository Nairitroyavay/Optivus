import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_6_fixed_schedule.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/features/recovery/models/onboarding_recovery_models.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

void main() {
  ProviderContainer makeContainer({OnboardingDraft? draft}) {
    final d =
        draft ??
        const OnboardingDraft().copyWith(
          baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
        );
    final container = ProviderContainer(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(d),
        ),
      ],
    );
    return container;
  }

  Widget buildTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: OnboardingStep6())),
    );
  }

  testWidgets('Test 1: renders new Step 6', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    expect(find.text('Fixed Schedule'), findsOneWidget);
    expect(find.text('Manual-only non-negotiable blocks.'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Bath'), findsOneWidget);

    expect(find.text('Optional fixed blocks'), findsNothing);
    expect(find.text('Review fixed blocks'), findsNothing);
    expect(find.text('Fixed schedule summary'), findsNothing);
    expect(find.text('Glass preview'), findsNothing);
  });

  testWidgets('Test 2: only timeline scrolls', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final headerFinder = find.text('Fixed Schedule');
    expect(headerFinder, findsOneWidget);

    final scrollable = find.byKey(
      const ValueKey('onboarding-step6-timeline-scroll'),
    );
    expect(scrollable, findsOneWidget);

    // Ensure the header is not found inside the scrollable content
    expect(
      find.descendant(of: scrollable, matching: headerFinder),
      findsNothing,
    );
  });

  testWidgets('Test 3: defaults inserted', (tester) async {
    final container = makeContainer(draft: const OnboardingDraft());
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final fixedBlocks = draft.baseTimeline.blocks
        .where((b) => b.section == 'fixed')
        .toList();

    expect(
      fixedBlocks.any((b) => b.id == BaseTimelineDraft.fixedSleepId),
      isTrue,
    );
    expect(
      fixedBlocks.any((b) => b.id == BaseTimelineDraft.fixedBathId),
      isTrue,
    );

    final sleep = fixedBlocks.firstWhere(
      (b) => b.id == BaseTimelineDraft.fixedSleepId,
    );
    expect(sleep.blockType, TimelineBlockDraft.hardBlockKey);
    expect(sleep.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
    expect(sleep.crossesMidnight, isTrue);

    final bath = fixedBlocks.firstWhere(
      (b) => b.id == BaseTimelineDraft.fixedBathId,
    );
    expect(bath.blockType, TimelineBlockDraft.hardBlockKey);
    expect(bath.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
  });

  testWidgets('Test 4: edit Sleep time only', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find
        .byKey(const ValueKey('onboarding-step6-menu-fixed-sleep'))
        .first;
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Sleep'), findsOneWidget);
    expect(find.text('Sleep time'), findsOneWidget);
    expect(find.text('Wake time'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);

    final titleField = find.byKey(const ValueKey('block_name_input'));
    final textFieldWidget = tester.widget<TextFormField>(titleField);
    expect(textFieldWidget.enabled, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '10:00 PM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '6:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final sleep = draft.baseTimeline.blocks.firstWhere(
      (b) => b.id == BaseTimelineDraft.fixedSleepId,
    );
    expect(sleep.id, BaseTimelineDraft.fixedSleepId);
    expect(sleep.title, 'Sleep');
    expect(sleep.startMinute, 22 * 60);
    expect(sleep.endMinute, 6 * 60);
    expect(sleep.section, 'fixed');
    expect(sleep.blockType, TimelineBlockDraft.hardBlockKey);
    expect(sleep.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
    expect(sleep.crossesMidnight, isTrue);
  });

  testWidgets('Test 5: Sleep equal time blocked', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find
        .byKey(const ValueKey('onboarding-step6-menu-fixed-sleep'))
        .first;
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '10:00 PM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '10:00 PM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sleep and wake time cannot be the same.'),
      findsOneWidget,
    );
  });

  testWidgets('Test 6: edit Bath time only', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(
      const ValueKey('onboarding-step6-menu-fixed-bath'),
    );
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Bath'), findsOneWidget);
    expect(find.text('Bath start'), findsOneWidget);
    expect(find.text('Bath end'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '8:00 AM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '8:30 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final bath = draft.baseTimeline.blocks.firstWhere(
      (b) => b.id == BaseTimelineDraft.fixedBathId,
    );
    expect(bath.id, BaseTimelineDraft.fixedBathId);
    expect(bath.title, 'Bath');
    expect(bath.startMinute, 8 * 60);
    expect(bath.endMinute, 8 * 60 + 30);
    expect(bath.section, 'fixed');
    expect(bath.blockType, TimelineBlockDraft.hardBlockKey);
    expect(bath.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
    expect(bath.crossesMidnight, isFalse);
  });

  testWidgets('Test 7: invalid Bath blocked', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(
      const ValueKey('onboarding-step6-menu-fixed-bath'),
    );
    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '8:30 AM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '8:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bath end time must be after bath start time.'),
      findsOneWidget,
    );
  });

  testWidgets('Test 8: add custom fixed block with +', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add fixed block'), findsOneWidget);

    final titleField = find.byKey(const ValueKey('block_name_input'));
    expect(
      (tester.widget<TextFormField>(titleField).controller?.text),
      'Fixed Block',
    );

    await tester.enterText(titleField, 'Reading');
    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '10:00 AM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '11:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Reading'), findsOneWidget);

    final draft = container.read(mockOnboardingProvider).draft;
    final custom = draft.baseTimeline.blocks.last;
    expect(custom.section, 'fixed');
    expect(custom.blockType, TimelineBlockDraft.hardBlockKey);
    expect(custom.repeatDays, [1, 2, 3, 4, 5, 6, 7]);
    expect(custom.source, OnboardingDraft.sourceOnboarding);
    expect(custom.crossesMidnight, isFalse);
  });

  testWidgets('Test 9: custom validation', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('block_name_input')), '');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Fixed block name is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('block_name_input')),
      'Custom',
    );
    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '11:00 AM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '10:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('End time must be after start time.'), findsOneWidget);
  });

  testWidgets('Test 10: edit/delete custom block', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '10:00 AM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '11:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;
    final customBlockId = draft.baseTimeline.blocks.last.id;
    final menuFinder = find.byKey(
      ValueKey('onboarding-step6-menu-$customBlockId'),
    );

    await tester.ensureVisible(menuFinder);
    await tester.pumpAndSettle();

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('block_name_input')),
      'Renamed',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsNothing);
    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Bath'), findsOneWidget);
  });

  testWidgets('Test 11: cannot delete Sleep/Bath', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    final sleepMenuFinder = find
        .byKey(const ValueKey('onboarding-step6-menu-fixed-sleep'))
        .first;
    await tester.ensureVisible(sleepMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(sleepMenuFinder);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);

    // Tap anywhere to close menu
    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();

    final bathMenuFinder = find.byKey(
      const ValueKey('onboarding-step6-menu-fixed-bath'),
    );
    await tester.ensureVisible(bathMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(bathMenuFinder);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
  });

  test('Test 13: step-level validation catches invalid saved data', () {
    final container = makeContainer();
    final draft = container.read(mockOnboardingProvider).draft;

    var invalidSleep = draft.baseTimeline.blocks.map((b) {
      if (b.id == BaseTimelineDraft.fixedSleepId) {
        return b.copyWith(startMinute: 10 * 60, endMinute: 10 * 60);
      }
      return b;
    }).toList();
    expect(
      draft
          .copyWith(
            baseTimeline: draft.baseTimeline.copyWith(blocks: invalidSleep),
          )
          .validateStep(6, []),
      'Sleep and wake time cannot be the same.',
    );

    var invalidBath = draft.baseTimeline.blocks.map((b) {
      if (b.id == BaseTimelineDraft.fixedBathId) {
        return b.copyWith(startMinute: 10 * 60, endMinute: 9 * 60);
      }
      return b;
    }).toList();
    expect(
      draft
          .copyWith(
            baseTimeline: draft.baseTimeline.copyWith(blocks: invalidBath),
          )
          .validateStep(6, []),
      'Bath end time must be after bath start time.',
    );

    var invalidCustomTitle = [
      ...draft.baseTimeline.blocks,
      TimelineBlockDraft(
        id: 'c1',
        title: ' ',
        section: 'fixed',
        startMinute: 60,
        endMinute: 120,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];
    expect(
      draft
          .copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              blocks: invalidCustomTitle,
            ),
          )
          .validateStep(6, []),
      'Fixed block name is required.',
    );

    var invalidCustomTime = [
      ...draft.baseTimeline.blocks,
      TimelineBlockDraft(
        id: 'c2',
        title: 'X',
        section: 'fixed',
        startMinute: 120,
        endMinute: 60,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];
    expect(
      draft
          .copyWith(
            baseTimeline: draft.baseTimeline.copyWith(
              blocks: invalidCustomTime,
            ),
          )
          .validateStep(6, []),
      'End time must be after start time.',
    );

    var notHard = [
      ...draft.baseTimeline.blocks,
      TimelineBlockDraft(
        id: 'c3',
        title: 'X',
        section: 'fixed',
        startMinute: 60,
        endMinute: 120,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
      ),
    ];
    expect(
      draft
          .copyWith(baseTimeline: draft.baseTimeline.copyWith(blocks: notHard))
          .validateStep(6, []),
      'Fixed blocks must be non-negotiable.',
    );

    var missingDay = [
      ...draft.baseTimeline.blocks,
      TimelineBlockDraft(
        id: 'c4',
        title: 'X',
        section: 'fixed',
        startMinute: 60,
        endMinute: 120,
        repeatDays: const [1, 2, 3, 4, 5, 6],
        blockType: TimelineBlockDraft.hardBlockKey,
      ),
    ];
    expect(
      draft
          .copyWith(
            baseTimeline: draft.baseTimeline.copyWith(blocks: missingDay),
          )
          .validateStep(6, []),
      'Fixed blocks must repeat every day.',
    );
  });
  testWidgets('Step 6 Next Step saves and advances directly to Step 7', (
    tester,
  ) async {
    final draft = _step6ResumeDraft(
      const BaseTimelineDraft().withRequiredFixedBlocks(),
    );
    final container = ProviderContainer(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(draft),
        ),
        authProvider.overrideWith((ref) => FakeAuthNotifier()),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: OnboardingFlow())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // We should be on Step 6
    expect(find.text('Fixed Schedule'), findsOneWidget);

    // Tap Next Step
    await tester.tap(find.text('Next Step'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final newDraft = container.read(mockOnboardingProvider).draft;
    expect(newDraft.currentStep, 7);
    expect(newDraft.stepCompleted[6], isTrue);
    expect(newDraft.stepDirty[6], isFalse);
  });

  testWidgets('Step 6 invalid fixed schedule blocks Next Step', (tester) async {
    // Sleep start == end
    final invalidSleepBlocks = const BaseTimelineDraft()
        .withRequiredFixedBlocks()
        .blocks
        .map((b) {
          if (b.id == BaseTimelineDraft.fixedSleepId) {
            return b.copyWith(startMinute: 10 * 60, endMinute: 10 * 60);
          }
          return b;
        })
        .toList();

    final draft = _step6ResumeDraft(
      const BaseTimelineDraft().copyWith(blocks: invalidSleepBlocks),
    );
    final container = ProviderContainer(
      overrides: [
        mockOnboardingProvider.overrideWith(
          (_) => MockOnboardingNotifier()..loadSeedData(draft),
        ),
        authProvider.overrideWith((ref) => FakeAuthNotifier()),
        onboardingRepositoryProvider.overrideWithValue(
          FakeOnboardingRepository(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: OnboardingFlow())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // We should be on Step 6
    expect(find.text('Fixed Schedule'), findsOneWidget);

    // Progressive CTA: Next Step is hidden because the schedule is invalid
    final newDraft = container.read(mockOnboardingProvider).draft;
    expect(newDraft.currentStep, 6);
    expect(newDraft.stepCompleted[6], isFalse);
    expect(newDraft.baseTimeline.validateFixedSchedule(), isNotNull);
  });

  testWidgets('Test 14: restore/rebuild persistence', (tester) async {
    final container = makeContainer();
    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    // Edit sleep
    final sleepMenuFinder = find
        .byKey(const ValueKey('onboarding-step6-menu-fixed-sleep'))
        .first;
    await tester.ensureVisible(sleepMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(sleepMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '11:00 PM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '7:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Add custom
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('block_name_input')),
      'Reading',
    );
    await tester.enterText(
      find.byKey(const ValueKey('start_time_input')),
      '10:00 AM',
    );
    await tester.enterText(
      find.byKey(const ValueKey('end_time_input')),
      '11:00 AM',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final draft = container.read(mockOnboardingProvider).draft;

    // Rebuild
    final container2 = makeContainer(draft: draft);
    await tester.pumpWidget(buildTestWidget(container2));
    await tester.pumpAndSettle();

    final draft2 = container2.read(mockOnboardingProvider).draft;
    final fixedBlocks = draft2.baseTimeline.blocks
        .where((b) => b.section == 'fixed')
        .toList();

    final sleep = fixedBlocks
        .where((b) => b.id == BaseTimelineDraft.fixedSleepId)
        .toList();
    final bath = fixedBlocks
        .where((b) => b.id == BaseTimelineDraft.fixedBathId)
        .toList();
    final custom = fixedBlocks.where((b) => b.title == 'Reading').toList();

    expect(sleep.length, 1);
    expect(sleep.first.startMinute, 23 * 60);
    expect(bath.length, 1);
    expect(custom.length, 1);
  });
}

OnboardingDraft _step6ResumeDraft(BaseTimelineDraft baseTimeline) {
  return OnboardingDraft(
    currentStep: 6,
    welcomeSaved: true,
    patiencePledgeAccepted: true,
    stepCompleted: List<bool>.generate(
      OnboardingDraft.stepCount,
      (index) => index < 6,
    ),
    lifeRole: const LifeRoleDraft(
      lifeRole: LifeRoleDraft.notStudentNotWorkingKey,
      exerciseLevel: 'moderate',
      waterIntake: 'medium',
      stressLevel: 'medium',
      sleepQuality: 'good',
    ),
    bodyBasics: const BodyBasicsDraft(
      ageRange: '25-34',
      heightCm: 175,
      weightKg: 70,
      gender: 'other',
    ),
    baseTimeline: baseTimeline.copyWith(
      eatingSetupPath: 'skip',
      blocks: [
        ...baseTimeline.blocks,
        const TimelineBlockDraft(
          id: 'meal',
          section: 'eating',
          title: 'Lunch',
          startMinute: 720,
          endMinute: 750,
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          blockType: TimelineBlockDraft.hardBlockKey,
        ),
      ],
    ),
  );
}

class FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeAuthNotifier()
    : super(
        const AuthState(
          user: AuthUser(
            uid: 'test-uid',
            email: 'test@example.com',
            emailVerified: true,
          ),
          status: AuthFlowStatus.signedInOnboardingIncomplete,
        ),
      );

  @override
  Future<void> acceptCanonicalOnboardingCompletion(AuthUser user) async {}

  @override
  Future<void> checkEmailVerification() async {}
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<bool> signInWithGoogle() async => false;
  @override
  Future<void> linkAnonymousWithEmail(
    String email,
    String password, {
    String? name,
  }) async {}
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> markOnboardingComplete(AuthUser user) async {}
  @override
  Future<void> markOnboardingIncomplete(AuthUser user) async {}
  Future<void> refreshProfile() async {}
  Future<void> register(String email, String password) async {}
  @override
  Future<void> executeRecoveryAction(OnboardingRecoveryAction action) async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> resendEmailVerification() async {}
  @override
  Future<void> retryBackendRestore() async {}
  @override
  Future<void> signup(String name, String email, String password) async {}
}

class FakeOnboardingRepository implements OnboardingRepository {
  @override
  Future<void> saveFinalDraftImmediately(OnboardingDraft draft) async {
    await saveDraft(draft);
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {}
  @override
  Future<void> flushPendingDraftSave() async {}
  @override
  void dispose() {}
  Future<OnboardingDraft?> getDraft(String uid) async => null;
  Future<void> deleteDraft(String uid) async {}
  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingCompletionBundle bundle,
    required OnboardingDraft finalDraft,
  }) async {
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: RoutineOnboardingProjection.build(bundle).receipt,
    );
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async =>
      null;
  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async => null;
  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {}
}
