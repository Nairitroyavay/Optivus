import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/base_timeline_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/classes_setup_controller.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/base_timeline_transaction_coordinator.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets(
    'BaseTimelineScreen displays 5 calm rows and never mentions Manager',
    (tester) async {
      final now = DateTime.now();
      final testSetup = BaseTimelineSetup(
        uid: 'user-base-test',
        updatedAt: now,
        classLogicalAssetR2Key: 'test/classes.jpg',
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'Math 101',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
        workBlocks: const [
          TimelineBlockDraft(
            id: 'w1',
            section: 'job_work_business',
            title: 'Deep Work',
            startMinute: 600,
            endMinute: 720,
            repeatDays: [1, 2, 3, 4, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
        eatingBlocks: const [],
        fixedBlocks: const [
          TimelineBlockDraft(
            id: BaseTimelineDraft.fixedSleepId,
            section: 'fixed',
            title: 'Sleep',
            startMinute: 1380,
            endMinute: 420,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
        skinCareSkipped: true,
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-base-test', testSetup);

      RoutineDetailTarget? openedTarget;
      var backPressed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-base-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
          ],
          child: MaterialApp(
            home: BaseTimelineScreen(
              onBack: () => backPressed = true,
              onOpenDetail: (target) => openedTarget = target,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header checks
      expect(find.text('Base Timeline'), findsOneWidget);
      expect(find.textContaining('Manager'), findsNothing);

      // 2. Row titles
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Work / Business'), findsOneWidget);
      expect(find.text('Eating'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
      expect(find.text('Skin Care'), findsOneWidget);

      // 3. Snapshot summaries
      expect(find.text('Timetable photo · 1 blocks'), findsOneWidget);
      expect(find.text('1 weekly blocks'), findsOneWidget);
      expect(find.text('Sleep, Bath'), findsOneWidget);
      expect(find.text('Not set up'), findsWidgets);

      // 4. Back navigation interaction
      final backFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backFinder, findsOneWidget);
      await tester.tap(backFinder);
      await tester.pump();
      expect(backPressed, isTrue);

      // 5. Open detail navigation interaction
      await tester.tap(find.text('Classes'));
      await tester.pump();
      expect(openedTarget?.view, RoutineDetailView.classesSetup);

      await tester.tap(find.text('Work / Business'));
      await tester.pump();
      expect(openedTarget?.view, RoutineDetailView.workSetup);

      await tester.tap(find.text('Eating'));
      await tester.pump();
      expect(openedTarget?.view, RoutineDetailView.eatingSetup);

      await tester.tap(find.text('Fixed'));
      await tester.pump();
      expect(openedTarget?.view, RoutineDetailView.fixedSetup);

      await tester.tap(find.text('Skin Care'));
      await tester.pump();
      expect(openedTarget?.view, RoutineDetailView.skinCareSetup);
    },
  );

  testWidgets(
    'BaseTimelinePhotoPreviewCard renders fallback when preview Uri is null',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-photo-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BaseTimelinePhotoPreviewCard(
                title: 'Timetable Photo',
                r2Key: 'test/key.jpg',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Timetable Photo'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen displays Current Setup and handles navigation',
    (tester) async {
      final now = DateTime.now();
      final testSetup = BaseTimelineSetup(
        uid: 'user-classes-test',
        updatedAt: now,
        classLogicalAssetR2Key: 'test/classes.jpg',
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c1',
            section: 'classes',
            title: 'Physics 101',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 3],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-classes-test', testSetup);
      final fakeRoutineRepo = FakeRoutineRepository();

      var backCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-classes-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
          ],
          child: MaterialApp(
            home: ClassesBaseSetupScreen(onBack: () => backCalled = true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifies Current Setup title & blocks
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Physics 101'), findsOneWidget);
      expect(find.text('Change setup'), findsOneWidget);

      // Tapping back button calls onBack
      final backBtn = find.byIcon(Icons.arrow_back_rounded);
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pump();
      expect(backCalled, isTrue);
    },
  );

  group('computeInitialClassWeekday tests', () {
    test('returns today when blocks list is empty', () {
      final now = DateTime(2026, 9, 10); // Thursday = weekday 4
      expect(computeInitialClassWeekday([], now: now), 4);
    });

    test('returns today when today has scheduled classes', () {
      final now = DateTime(2026, 9, 10); // Thursday = weekday 4
      final blocks = [
        ClassRoutineBlock(
          id: 'b1',
          subject: 'Algorithms',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [2, 4],
        ),
      ];
      expect(computeInitialClassWeekday(blocks, now: now), 4);
    });

    test('returns earliest scheduled day when today has no classes', () {
      final now = DateTime(2026, 9, 7); // Monday = weekday 1
      final blocks = [
        ClassRoutineBlock(
          id: 'b1',
          subject: 'Database',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [3, 5],
        ),
      ];
      expect(computeInitialClassWeekday(blocks, now: now), 3);
    });

    test('ignores out-of-range days and defaults cleanly to today', () {
      final now = DateTime(2026, 9, 10); // Thursday = weekday 4
      final blocks = [
        ClassRoutineBlock(
          id: 'b1',
          subject: 'Database',
          startMinute: 600,
          endMinute: 660,
          repeatDays: [0, 8],
        ),
      ];
      expect(computeInitialClassWeekday(blocks, now: now), 4);
    });
  });

  testWidgets(
    'ClassesBaseSetupScreen renders rich class card metadata (courseCode, classType, room, professor)',
    (tester) async {
      final now = DateTime.now();
      final testSetup = BaseTimelineSetup(
        uid: 'user-rich-class-test',
        updatedAt: now,
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c-rich',
            section: 'classes',
            title: 'Computer Architecture',
            courseCode: 'CS201',
            classType: 'Lecture',
            location: 'Science Hall 301',
            professor: 'Prof. Hopper',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-rich-class-test', testSetup);
      final fakeRoutineRepo = FakeRoutineRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-rich-class-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Computer Architecture'), findsOneWidget);
      expect(find.text('CS201'), findsOneWidget);
      expect(find.text('Lecture'), findsOneWidget);
      expect(find.text('Science Hall 301'), findsOneWidget);
      expect(find.text('Prof. Hopper'), findsOneWidget);
      // In read-only currentSetup mode, edit pencil icon is NOT rendered
      expect(find.byIcon(Icons.edit_rounded), findsNothing);
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen transitions to chooseSource and cancels back to currentSetup',
    (tester) async {
      final testSetup = BaseTimelineSetup(
        uid: 'user-stage-test',
        updatedAt: DateTime.now(),
        classBlocks: const [],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-stage-test', testSetup);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-stage-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(
              FakeRoutineRepository(),
            ),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Set up Classes'
      await tester.tap(find.text('Set up Classes'));
      await tester.pumpAndSettle();

      // Now on chooseSource
      expect(find.text('Update Timetable'), findsOneWidget);
      expect(find.text('Take a Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Set up manually'), findsOneWidget);

      // Tap close button to cancel back
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Back on currentSetup
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Set up Classes'), findsOneWidget);
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen manual flow enters review, preserves metadata, and saves successfully',
    (tester) async {
      final testSetup = BaseTimelineSetup(
        uid: 'user-manual-test',
        updatedAt: DateTime.now(),
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c-init',
            section: 'classes',
            title: 'Initial Class',
            courseCode: 'INIT101',
            classType: 'Seminar',
            location: 'Room 10',
            professor: 'Dr. Init',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-manual-test', testSetup);
      final fakeRoutineRepo = FakeRoutineRepository();
      final fakeTxRepo = FakeRoutineTransactionRepository(
        routineRepository: fakeRoutineRepo,
        setupRepository: fakeSetupRepo,
      );

      final coordinator = BaseTimelineTransactionCoordinator(
        routineRepo: fakeRoutineRepo,
        setupRepo: fakeSetupRepo,
        transactionRepo: fakeTxRepo,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-manual-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Change setup
      await tester.tap(find.text('Change setup'));
      await tester.pumpAndSettle();

      // Tap 'Set up manually'
      await tester.tap(find.text('Set up manually'));
      await tester.pumpAndSettle();

      // In review stage
      expect(find.text('Review Timetable'), findsOneWidget);
      expect(find.text('Use this timetable'), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
      expect(find.text('Add Class'), findsOneWidget);

      // In review mode, editable card shows edit icon
      expect(find.byIcon(Icons.edit_rounded), findsWidgets);

      // Tap 'Use this timetable' to save
      await tester.tap(find.text('Use this timetable'));
      await tester.pumpAndSettle();

      // Returns to currentSetup with success snackbar
      expect(find.text('Classes'), findsOneWidget);
      expect(find.textContaining('Classes updated'), findsOneWidget);

      // Verify committed setup in repository preserved all fields
      final updatedSetup = await fakeSetupRepo.fetchSetup('user-manual-test');
      expect(updatedSetup.classBlocks.length, 1);
      final savedBlock = updatedSetup.classBlocks.first;
      expect(savedBlock.title, 'Initial Class');
      expect(savedBlock.courseCode, 'INIT101');
      expect(savedBlock.classType, 'Seminar');
      expect(savedBlock.location, 'Room 10');
      expect(savedBlock.professor, 'Dr. Init');
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen handles save failure truthfully and displays inline error banner',
    (tester) async {
      final testSetup = BaseTimelineSetup(
        uid: 'user-fail-test',
        updatedAt: DateTime.now(),
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c-fail',
            section: 'classes',
            title: 'Failing Class',
            startMinute: 600,
            endMinute: 660,
            repeatDays: [1, 2, 3, 4, 5, 6, 7],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-fail-test', testSetup);
      final fakeRoutineRepo = FakeRoutineRepository();

      // Create a coordinator that throws on replaceSection
      final failingTxRepo = _FailingRoutineTransactionRepository();
      final coordinator = BaseTimelineTransactionCoordinator(
        routineRepo: fakeRoutineRepo,
        setupRepo: fakeSetupRepo,
        transactionRepo: failingTxRepo,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-fail-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
            baseTimelineTransactionCoordinatorProvider.overrideWithValue(
              coordinator,
            ),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Go to chooseSource -> Set up manually -> Review
      await tester.tap(find.text('Change setup'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set up manually'));
      await tester.pumpAndSettle();

      expect(find.text('Review Timetable'), findsOneWidget);

      // Attempt to save
      await tester.tap(find.text('Use this timetable'));
      await tester.pumpAndSettle();

      // Should remain on Review, displaying inline error banner
      expect(find.text('Review Timetable'), findsOneWidget);
      expect(find.textContaining('Failed to save timetable'), findsOneWidget);
      expect(find.text('Use this timetable'), findsOneWidget);
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen shows discard confirmation on dirty changes',
    (tester) async {
      final testSetup = BaseTimelineSetup(
        uid: 'user-discard-test',
        updatedAt: DateTime.now(),
        classBlocks: const [],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-discard-test', testSetup);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-discard-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(
              FakeRoutineRepository(),
            ),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Set up Classes -> Set up manually
      await tester.tap(find.text('Set up Classes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set up manually'));
      await tester.pumpAndSettle();

      // Tap 'Add Class' to make it dirty
      await tester.tap(find.text('Add Class'));
      await tester.pumpAndSettle();

      // Enter a subject in the edit sheet
      await tester.enterText(
        find.byKey(const Key('timeline-edit-subject-field')),
        'New Class',
      );
      // Tap Save in sheet shell
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Now dirty with 1 block. Tap close button on Review
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Discard dialog appears
      expect(find.text('Discard this setup?'), findsOneWidget);
      expect(
        find.text("Your current Classes setup won't be affected."),
        findsOneWidget,
      );

      // Tap 'Keep editing'
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      // Still in review
      expect(find.text('Review Timetable'), findsOneWidget);

      // Tap close again and tap 'Discard'
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Returns to currentSetup
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Set up Classes'), findsOneWidget);
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen tapping class card in read-only currentSetup opens detail sheet with full metadata',
    (tester) async {
      final now = DateTime.now();
      final testSetup = BaseTimelineSetup(
        uid: 'user-detail-sheet-test',
        updatedAt: now,
        classBlocks: const [
          TimelineBlockDraft(
            id: 'c-sheet',
            section: 'classes',
            title: 'Computer Architecture',
            courseCode: 'CS201',
            classType: 'Lecture',
            location: 'Science Hall 301',
            professor: 'Prof. Hopper',
            notes: 'Bring lab notebook',
            startMinute: 540,
            endMinute: 600,
            repeatDays: [1, 3, 5],
            blockType: TimelineBlockDraft.hardBlockKey,
          ),
        ],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-detail-sheet-test', testSetup);
      final fakeRoutineRepo = FakeRoutineRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-detail-sheet-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
          ],
          child: MaterialApp(home: ClassesBaseSetupScreen(onBack: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the class card
      await tester.tap(find.text('Computer Architecture'));
      await tester.pumpAndSettle();

      // Class detail bottom sheet should be displayed
      final sheetFinder = find.byType(BottomSheet);
      expect(sheetFinder, findsOneWidget);
      expect(
        find.descendant(of: sheetFinder, matching: find.text('Instructor')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheetFinder, matching: find.text('Prof. Hopper')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheetFinder, matching: find.text('Location')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheetFinder,
          matching: find.text('Science Hall 301'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheetFinder, matching: find.text('Notes')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheetFinder,
          matching: find.text('Bring lab notebook'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheetFinder, matching: find.text('Days')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheetFinder, matching: find.text('Mon, Wed, Fri')),
        findsOneWidget,
      );

      // Dismiss detail sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Back to current setup
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Instructor'), findsNothing);
    },
  );

  testWidgets(
    'ClassesBaseSetupScreen PopScope delegates system pop to onBack on currentSetup',
    (tester) async {
      final testSetup = BaseTimelineSetup(
        uid: 'user-popscope-test',
        updatedAt: DateTime.now(),
        classBlocks: const [],
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup('user-popscope-test', testSetup);

      var backInvoked = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) => UserProfileNotifier()
                ..loadSeedData(
                  UserProfile(
                    uid: 'user-popscope-test',
                    email: 'test@optivus.app',
                    displayName: 'Test User',
                  ),
                ),
            ),
            baseTimelineSetupRepositoryProvider.overrideWithValue(
              fakeSetupRepo,
            ),
            routineRepositoryProvider.overrideWithValue(
              FakeRoutineRepository(),
            ),
          ],
          child: MaterialApp(
            home: ClassesBaseSetupScreen(onBack: () => backInvoked = true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger system pop (Android back gesture/button)
      final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
      await widgetsAppState.didPopRoute();
      await tester.pump();

      expect(backInvoked, isTrue);
    },
  );
}

class _FailingRoutineTransactionRepository
    extends FakeRoutineTransactionRepository {
  @override
  Future<BaseTimelineSectionCommitResult> replaceBaseTimelineSection({
    required String uid,
    required BaseTimelineSection section,
    required int expectedRevision,
    required List<RoutineItem> newRoutineItems,
    List<String> additionalDeleteIds = const [],
    required BaseTimelineSetup Function(BaseTimelineSetup liveSetup)
    buildUpdatedSetup,
  }) async {
    throw Exception('Simulated Firestore transaction network failure');
  }
}
