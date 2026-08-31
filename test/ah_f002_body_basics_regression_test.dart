import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/features/onboarding/onboarding_step_readiness.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_3_body_basics.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_5_eating_setup.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';

void main() {
  group('AH-F002 Body Basics durable data contract', () {
    test('fresh draft and serialization preserve missing measurements', () {
      const body = BodyBasicsDraft();

      expect(body.heightCm, isNull);
      expect(body.weightKg, isNull);

      final restored = BodyBasicsDraft.fromMap(body.toMap());
      expect(restored.heightCm, isNull);
      expect(restored.weightKg, isNull);
      expect(restored.bmiEstimate, isNull);
      expect(restored.calorieEstimate, isNull);
      expect(restored.proteinEstimate, isNull);
    });

    testWidgets('mounting and pumping Step 3 does not select measurements', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpStep3(tester, container);

      final body = container.read(mockOnboardingProvider).draft.bodyBasics;
      expect(body.heightCm, isNull);
      expect(body.weightKg, isNull);
      expect(find.text('Set cm'), findsOneWidget);
      expect(find.text('Set kg'), findsOneWidget);
    });

    test('missing and partial measurements block Step 3 readiness', () {
      const completed = <bool>[];
      const base = BodyBasicsDraft(ageRange: '25-34', gender: 'female');

      OnboardingStepReadiness readiness(BodyBasicsDraft body) =>
          evaluateOnboardingStepReadiness(
            draft: OnboardingDraft(bodyBasics: body),
            step: 3,
            completedSteps: completed,
          );

      expect(readiness(base).canRevealPrimary, isFalse);
      expect(readiness(base.copyWith(heightCm: 181)).canRevealPrimary, isFalse);
      expect(readiness(base.copyWith(weightKg: 79)).canRevealPrimary, isFalse);
      expect(
        readiness(base.copyWith(heightCm: 181, weightKg: 79)).canRevealPrimary,
        isTrue,
      );
    });

    testWidgets(
      'height and weight become durable only through their controls',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await _pumpStep3(tester, container);

        _slider(tester, 'height-slider').onChanged(181);
        await tester.pump();
        var body = container.read(mockOnboardingProvider).draft.bodyBasics;
        expect(body.heightCm, 181);
        expect(body.weightKg, isNull);

        _slider(tester, 'weight-slider').onChanged(79);
        await tester.pump();
        body = container.read(mockOnboardingProvider).draft.bodyBasics;
        expect(body.heightCm, 181);
        expect(body.weightKg, 79);
        expect(body.bmiEstimate, isNotNull);
      },
    );

    test('legitimate persisted 170 cm and 70 kg restore unchanged', () {
      const original = BodyBasicsDraft(
        ageRange: '25-34',
        heightCm: 170,
        weightKg: 70,
        gender: 'male',
      );

      final restored = BodyBasicsDraft.fromMap(original.toMap());
      expect(restored.heightCm, 170);
      expect(restored.weightKg, 70);
      expect(restored.validate(), isNull);
    });

    testWidgets('unit switches keep missing measurements missing', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpStep3(tester, container);

      await tester.tap(find.byKey(const ValueKey('height-unit-toggle')));
      await tester.tap(find.byKey(const ValueKey('weight-unit-toggle')));
      await tester.pump();

      final body = container.read(mockOnboardingProvider).draft.bodyBasics;
      expect(body.heightCm, isNull);
      expect(body.weightKg, isNull);
      expect(find.text('Set ft'), findsOneWidget);
      expect(find.text('Set lbs'), findsOneWidget);
    });

    testWidgets('unit switches preserve selected canonical metric values', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpStep3(tester, container);

      _slider(tester, 'height-slider').onChanged(180.25);
      await tester.pump();
      _slider(tester, 'weight-slider').onChanged(80.5);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('height-unit-toggle')));
      await tester.tap(find.byKey(const ValueKey('weight-unit-toggle')));
      await tester.pump();

      final body = container.read(mockOnboardingProvider).draft.bodyBasics;
      expect(body.heightCm, 180.25);
      expect(body.weightKg, 80.5);
      expect(
        _slider(tester, 'height-slider').value,
        closeTo(180.25 / 2.54, 0.000001),
      );
      expect(
        _slider(tester, 'weight-slider').value,
        closeTo(80.5 * 2.20462, 0.000001),
      );
    });

    test('Step 5 exposes no body-derived targets when inputs are missing', () {
      final context = onboarding5MealBodyContextFromDraft(
        const OnboardingDraft(
          bodyBasics: BodyBasicsDraft(
            ageRange: '25-34',
            gender: 'male',
            bmiEstimate: 24,
            calorieEstimate: 2200,
            proteinEstimate: 140,
          ),
        ),
      );

      expect(context.hasBodyBasics, isFalse);
      expect(context.currentWeightKg, isNull);
      expect(context.heightCm, isNull);
      expect(context.estimatedBmr, isNull);
      expect(context.estimatedMaintenanceCalories, isNull);
      expect(context.targetCalories, isNull);
      expect(context.proteinTarget, isNull);
    });

    testWidgets('Step 5 refuses generation when Body Basics is incomplete', (
      tester,
    ) async {
      final draft = const OnboardingDraft(
        bodyBasics: BodyBasicsDraft(ageRange: '25-34', gender: 'male'),
        baseTimeline: BaseTimelineDraft(
          eatingSetupPath: onboardingEatingPathCreate,
          eatingSetupStep: 1,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            optivusBackendModeProvider.overrideWithValue(
              OptivusBackendMode.fake,
            ),
            optivusDebugBuildProvider.overrideWithValue(true),
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

      await tester.tap(find.text('Generate meal routine'));
      await tester.pump();

      expect(
        find.textContaining('Complete Body Basics with your height and weight'),
        findsOneWidget,
      );
    });

    test('Step 5 derives targets from real selected measurements', () {
      final context = onboarding5MealBodyContextFromDraft(
        OnboardingDraft(
          lifeRole: const LifeRoleDraft(lifeRole: LifeRoleDraft.studentKey),
          bodyBasics: const BodyBasicsDraft(
            ageRange: '25-34',
            heightCm: 180,
            weightKg: 80,
            gender: 'male',
          ).withEstimates(),
        ),
      );

      expect(context.hasBodyBasics, isTrue);
      expect(context.currentWeightKg, 80);
      expect(context.heightCm, 180);
      expect(context.estimatedBmr, isNotNull);
      expect(context.estimatedMaintenanceCalories, 2496);
      expect(context.targetCalories, 2496);
      expect(context.proteinTarget, 160);
    });

    test(
      'completion projection omits rather than manufactures missing body data',
      () {
        final bundle = OnboardingCompletionService.buildBundle(
          const OnboardingDraft(uid: 'missing-body'),
        );

        expect(bundle.userProfilePatch, isNot(contains('height')));
        expect(bundle.userProfilePatch, isNot(contains('weight')));
        expect(bundle.userProfilePatch, isNot(contains('bmiEstimate')));
        expect(bundle.userProfilePatch, isNot(contains('calorieEstimate')));
        expect(bundle.userProfilePatch, isNot(contains('proteinEstimate')));
      },
    );

    test('completion projection preserves valid selected body data', () {
      final body = const BodyBasicsDraft(
        ageRange: '25-34',
        heightCm: 170,
        weightKg: 70,
        gender: 'female',
      ).withEstimates();
      final bundle = OnboardingCompletionService.buildBundle(
        OnboardingDraft(uid: 'selected-body', bodyBasics: body),
      );

      expect(bundle.userProfilePatch['height'], 170);
      expect(bundle.userProfilePatch['weight'], 70);
      expect(bundle.userProfilePatch['bmiEstimate'], body.bmiEstimate);
      expect(bundle.userProfilePatch['calorieEstimate'], body.calorieEstimate);
      expect(bundle.userProfilePatch['proteinEstimate'], body.proteinEstimate);
    });
  });
}

Future<void> _pumpStep3(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SizedBox.expand(child: OnboardingStep3())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

OnboardingLiquidContinuousSlider _slider(WidgetTester tester, String key) =>
    tester.widget<OnboardingLiquidContinuousSlider>(find.byKey(ValueKey(key)));
