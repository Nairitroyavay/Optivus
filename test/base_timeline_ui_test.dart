import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/base_timeline_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  testWidgets('BaseTimelineScreen displays 5 calm rows and never mentions Manager', (tester) async {
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
    final fakeSetupRepo = FakeBaseTimelineSetupRepository(onboardingRepo: fakeOnboardingRepo);
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
          baseTimelineSetupRepositoryProvider.overrideWithValue(fakeSetupRepo),
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
  });

  testWidgets('BaseTimelinePhotoPreviewCard renders fallback when preview Uri is null', (tester) async {
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
  });

  testWidgets('ClassesBaseSetupScreen displays Current Setup and handles navigation', (tester) async {
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
    final fakeSetupRepo = FakeBaseTimelineSetupRepository(onboardingRepo: fakeOnboardingRepo);
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
          baseTimelineSetupRepositoryProvider.overrideWithValue(fakeSetupRepo),
          routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
        ],
        child: MaterialApp(
          home: ClassesBaseSetupScreen(
            onBack: () => backCalled = true,
          ),
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
  });
}
