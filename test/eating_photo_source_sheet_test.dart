import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/eating_base_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_setup_controller.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/repositories/routine_transaction_repository.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  const uid = 'test-user-eating-sheet';

  testWidgets(
    'Eating photo source sheet renders visible title, icons, and text without white-on-white defect',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final setup = BaseTimelineSetup(
        uid: uid,
        updatedAt: now,
        eatingSetupPath: 'has_routine',
        eatingBlocks: [
          const TimelineBlockDraft(
            id: 'meal-1',
            section: 'eating',
            title: 'Breakfast',
            startMinute: 480,
            endMinute: 510,
            repeatDays: [1, 2, 3, 4, 5],
            blockType: TimelineBlockDraft.softBlockKey,
            mealSlot: 'breakfast',
            dishes: ['Oatmeal'],
          ),
        ],
        eatingPhotoR2Key: 'test-r2-key',
        eatingPhotoAssetId: 'test-asset-id',
      );

      final fakeOnboardingRepo = FakeOnboardingRepository();
      final fakeSetupRepo = FakeBaseTimelineSetupRepository(
        onboardingRepo: fakeOnboardingRepo,
      );
      await fakeSetupRepo.saveSetup(uid, setup);
      final fakeRoutineRepo = FakeRoutineRepository();
      final fakeTxRepo = FakeRoutineTransactionRepository(
        routineRepository: fakeRoutineRepo,
        setupRepository: fakeSetupRepo,
      );

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(
            (ref) => UserProfileNotifier()
              ..loadSeedData(
                UserProfile(
                  uid: uid,
                  email: 'eating@optivus.local',
                  displayName: 'Eating Sheet User',
                ),
              ),
          ),
          baseTimelineSetupRepositoryProvider.overrideWithValue(fakeSetupRepo),
          routineRepositoryProvider.overrideWithValue(fakeRoutineRepo),
          routineTransactionRepositoryProvider.overrideWithValue(fakeTxRepo),
        ],
      );

      // Initialize controller in review stage with photo source
      final controller = container.read(eatingSetupControllerProvider.notifier);
      controller.editCurrentMealPlan(setup);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.light(),
            home: EatingBaseSetupScreen(onBack: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In Review / Edit stage
      expect(find.text('Edit Eating Schedule'), findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);

      // Tap 'Change photo'
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title is visible and rendered in textPrimary
      final titleFinder = find.text('Scan Meal Plan Photo');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.color, OptivusColors.textPrimary);

      // Verify gallery option
      final galleryTile = find.byKey(
        const ValueKey('eating-photo-source-gallery'),
      );
      expect(galleryTile, findsOneWidget);
      expect(
        find.descendant(
          of: galleryTile,
          matching: find.text('Choose from gallery'),
        ),
        findsOneWidget,
      );
      final galleryText = tester.widget<Text>(
        find.descendant(
          of: galleryTile,
          matching: find.text('Choose from gallery'),
        ),
      );
      expect(galleryText.style?.color, OptivusColors.textPrimary);
      expect(galleryText.style?.color, isNot(Colors.white));

      final galleryIcon = tester.widget<Icon>(
        find.descendant(of: galleryTile, matching: find.byType(Icon)),
      );
      expect(galleryIcon.color, OptivusColors.roseAccent);
      expect(galleryIcon.color, isNot(Colors.white));

      // Verify camera option
      final cameraTile = find.byKey(
        const ValueKey('eating-photo-source-camera'),
      );
      expect(cameraTile, findsOneWidget);
      expect(
        find.descendant(of: cameraTile, matching: find.text('Take a photo')),
        findsOneWidget,
      );
      final cameraText = tester.widget<Text>(
        find.descendant(of: cameraTile, matching: find.text('Take a photo')),
      );
      expect(cameraText.style?.color, OptivusColors.textPrimary);
      expect(cameraText.style?.color, isNot(Colors.white));

      final cameraIcon = tester.widget<Icon>(
        find.descendant(of: cameraTile, matching: find.byType(Icon)),
      );
      expect(cameraIcon.color, OptivusColors.roseAccent);
      expect(cameraIcon.color, isNot(Colors.white));

      // Tap gallery option dismisses the sheet
      await tester.tap(galleryTile);
      await tester.pumpAndSettle();

      expect(find.text('Scan Meal Plan Photo'), findsNothing);
    },
  );
}
