import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_plan_freshness.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';

import 'package:optivus/services/nutrition_ai_client.dart';

void main() {
  group('Eating Plan Freshness & Fingerprint Parity Tests', () {
    final engine = EatingDomainEngine(
      client: const MissingConfigNutritionAiClient(),
    );
    const uid = 'test-user-parity';

    final profile = UserProfile(
      uid: uid,
      email: 'parity@optivus.local',
      displayName: 'Parity User',
      weight: 70,
      height: 175,
      gender: 'male',
      ageRange: '25',
      exerciseLevel: 'moderate',
      lifeRole: 'employed',
    );

    final baseSetup = BaseTimelineSetup(
      uid: uid,
      updatedAt: DateTime.now(),
      eatingSetupPath: 'create',
      mealPlanningGoal: 'maintain',
      mealsPerDay: 3,
      eatingMode: 'balanced',
      foodType: 'mixed',
      breakfastMinute: 8 * 60,
      lunchMinute: 13 * 60,
      dinnerMinute: 19 * 60,
    );

    test('Fingerprint parity with non-empty country code (IN)', () {
      const country = 'IN';

      // 1. Generation builds canonical inputs with country
      final genInputs = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: country,
      );
      final fingerprintA = genInputs.computeFingerprint();

      // 2. Simulate successful generation & save
      final savedSetup = baseSetup.copyWith(
        eatingGeneratedInputFingerprint: fingerprintA,
        eatingGeneratedPlanVersion:
            BaseTimelineDraft.currentGate2EatingPlanVersion,
        eatingCustomized: false,
      );

      // 3. Evaluate freshness with the same country
      final freshness = EatingPlanFreshness.evaluate(
        setup: savedSetup,
        profile: profile,
        engine: engine,
        country: country,
      );

      // 4. Rebuild freshness inputs
      final freshnessInputs = engine.buildCanonicalInputs(
        profile: profile,
        setup: savedSetup,
        country: country,
      );
      final fingerprintB = freshnessInputs.computeFingerprint();

      expect(fingerprintB, equals(fingerprintA));
      expect(freshness, equals(EatingPlanFreshness.current));
      expect(freshness.isCurrent, isTrue);
      expect(freshness.isStale, isFalse);
    });

    test('Country normalization parity (IN vs in vs "  IN  ")', () {
      final inputsUppercase = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: 'IN',
      );
      final inputsLowercase = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: 'in',
      );
      final inputsPadded = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: '  IN  ',
      );

      expect(
        inputsUppercase.computeFingerprint(),
        equals(inputsLowercase.computeFingerprint()),
      );
      expect(
        inputsPadded.computeFingerprint(),
        equals(inputsLowercase.computeFingerprint()),
      );

      // Evaluates current across case differences
      final setup = baseSetup.copyWith(
        eatingGeneratedInputFingerprint: inputsUppercase.computeFingerprint(),
      );
      expect(
        EatingPlanFreshness.evaluate(
          setup: setup,
          profile: profile,
          engine: engine,
          country: 'in',
        ),
        equals(EatingPlanFreshness.current),
      );
    });

    test(
      'Customized meal dishes (eatingCustomized: true) remain current if inputs unchanged',
      () {
        const country = 'IN';
        final genInputs = engine.buildCanonicalInputs(
          profile: profile,
          setup: baseSetup,
          country: country,
        );
        final fingerprint = genInputs.computeFingerprint();

        // User edited meal dish from Suji Halwa to Oatmeal
        final customizedSetup = baseSetup.copyWith(
          eatingGeneratedInputFingerprint: fingerprint,
          eatingCustomized: true, // Meal edited
          eatingBlocks: const [
            TimelineBlockDraft(
              id: 'meal-1',
              title: 'Oatmeal with Almonds',
              section: 'eating',
              blockType: 'meal',
              repeatDays: [1],
              startMinute: 480,
              endMinute: 510,
            ),
          ],
        );

        final freshness = EatingPlanFreshness.evaluate(
          setup: customizedSetup,
          profile: profile,
          engine: engine,
          country: country,
        );

        expect(freshness, equals(EatingPlanFreshness.current));
        expect(freshness.isStale, isFalse);
      },
    );

    test('Body Basics change after generation marks plan stale', () {
      const country = 'IN';
      final genInputs = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: country,
      );
      final savedSetup = baseSetup.copyWith(
        eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
      );

      // Weight changed from 70 to 80 kg
      final updatedProfile = profile.copyWith(weight: 80);

      final freshness = EatingPlanFreshness.evaluate(
        setup: savedSetup,
        profile: updatedProfile,
        engine: engine,
        country: country,
      );

      expect(freshness, equals(EatingPlanFreshness.stale));
      expect(freshness.isStale, isTrue);
    });

    test('Plan settings change after generation marks plan stale', () {
      const country = 'IN';
      final genInputs = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: country,
      );
      final savedSetup = baseSetup.copyWith(
        eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
      );

      // User changed mealsPerDay from 3 to 4 without regenerating
      final updatedSetup = savedSetup.copyWith(mealsPerDay: 4);

      final freshness = EatingPlanFreshness.evaluate(
        setup: updatedSetup,
        profile: profile,
        engine: engine,
        country: country,
      );

      expect(freshness, equals(EatingPlanFreshness.stale));
      expect(freshness.isStale, isTrue);
    });

    test('Incomplete Body Basics returns EatingPlanFreshness.unknown', () {
      const country = 'IN';
      final genInputs = engine.buildCanonicalInputs(
        profile: profile,
        setup: baseSetup,
        country: country,
      );
      final savedSetup = baseSetup.copyWith(
        eatingGeneratedInputFingerprint: genInputs.computeFingerprint(),
      );

      final incompleteProfile = UserProfile(
        uid: uid,
        email: 'incomplete@optivus.local',
        displayName: 'Incomplete',
        weight: 0, // Incomplete
        height: 0,
      );

      final freshness = EatingPlanFreshness.evaluate(
        setup: savedSetup,
        profile: incompleteProfile,
        engine: engine,
        country: country,
      );

      expect(freshness, equals(EatingPlanFreshness.unknown));
      expect(freshness.isUnknown, isTrue);
    });
  });
}
