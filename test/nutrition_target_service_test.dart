import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/services/nutrition_target_service.dart';

void main() {
  const service = NutritionTargetService();

  group('NutritionTargetService - Deterministic Matrix', () {
    test('missing body measurements yields no targets', () {
      final noMeasurements = service.calculate();
      expect(noMeasurements.hasBodyBasics, isFalse);
      expect(noMeasurements.estimatedBmr, isNull);
      expect(noMeasurements.estimatedMaintenanceCalories, isNull);
      expect(noMeasurements.targetCalories, isNull);
      expect(noMeasurements.proteinTarget, isNull);
      expect(noMeasurements.bmi, isNull);

      final onlyWeight = service.calculate(weightKg: 70);
      expect(onlyWeight.hasBodyBasics, isFalse);
      expect(onlyWeight.estimatedBmr, isNull);
      expect(onlyWeight.proteinTarget, 140.0);

      final outOfRangeHeight = service.calculate(
        ageRange: '25-34',
        heightCm: 100, // < 120
        weightKg: 70,
        gender: 'male',
      );
      expect(outOfRangeHeight.hasBodyBasics, isFalse);
    });

    test('maintain goal sets targetCalories equal to maintenance', () {
      final targets = service.calculate(
        ageRange: '25-34',
        heightCm: 175,
        weightKg: 70,
        gender: 'male',
        exerciseLevel: '3_4_days',
        bodyGoal: 'maintain',
      );

      expect(targets.hasBodyBasics, isTrue);
      expect(targets.estimatedBmr, isNotNull);
      expect(targets.estimatedMaintenanceCalories, isNotNull);
      expect(targets.targetCalories, targets.estimatedMaintenanceCalories);
      expect(targets.bodyGoal, 'maintain');
    });

    test('gain goal increases targetCalories above maintenance', () {
      final targets = service.calculate(
        ageRange: '25-34',
        heightCm: 175,
        weightKg: 70,
        gender: 'male',
        exerciseLevel: '3_4_days',
        bodyGoal: 'gain',
      );

      expect(targets.hasBodyBasics, isTrue);
      expect(
        targets.targetCalories,
        greaterThan(targets.estimatedMaintenanceCalories!),
      );
      expect(
        targets.targetCalories,
        targets.estimatedMaintenanceCalories! + 300,
      );
    });

    test(
      'lose goal decreases targetCalories below maintenance with safe floor',
      () {
        final targets = service.calculate(
          ageRange: '25-34',
          heightCm: 175,
          weightKg: 70,
          gender: 'male',
          exerciseLevel: '3_4_days',
          bodyGoal: 'lose',
        );

        expect(targets.hasBodyBasics, isTrue);
        expect(
          targets.targetCalories,
          lessThan(targets.estimatedMaintenanceCalories!),
        );
        expect(
          targets.targetCalories,
          targets.estimatedMaintenanceCalories! - 350,
        );
        expect(targets.targetCalories, greaterThanOrEqualTo(1400));
      },
    );

    test('lose goal respects 1200 female floor', () {
      final targets = service.calculate(
        ageRange: '45+',
        heightCm: 150,
        weightKg: 42,
        gender: 'female',
        exerciseLevel: 'rarely',
        bodyGoal: 'lose',
      );

      expect(targets.hasBodyBasics, isTrue);
      // Even if maintenance - 350 drops below 1200, floor 1200 is protected
      expect(targets.targetCalories, greaterThanOrEqualTo(1200));
    });

    test(
      'exercise mapping produces distinct multipliers for all 4 UI options',
      () {
        final rarely = service.calculate(
          ageRange: '25-34',
          heightCm: 180,
          weightKg: 80,
          gender: 'male',
          exerciseLevel: 'rarely',
        );
        final days12 = service.calculate(
          ageRange: '25-34',
          heightCm: 180,
          weightKg: 80,
          gender: 'male',
          exerciseLevel: '1_2_days',
        );
        final days34 = service.calculate(
          ageRange: '25-34',
          heightCm: 180,
          weightKg: 80,
          gender: 'male',
          exerciseLevel: '3_4_days',
        );
        final days5plus = service.calculate(
          ageRange: '25-34',
          heightCm: 180,
          weightKg: 80,
          gender: 'male',
          exerciseLevel: '5_plus_days',
        );

        expect(rarely.activityFactor, 1.25);
        expect(days12.activityFactor, 1.30);
        expect(days34.activityFactor, 1.35);
        expect(days5plus.activityFactor, 1.45);

        expect(
          rarely.estimatedMaintenanceCalories,
          lessThan(days12.estimatedMaintenanceCalories!),
        );
        expect(
          days12.estimatedMaintenanceCalories,
          lessThan(days34.estimatedMaintenanceCalories!),
        );
        expect(
          days34.estimatedMaintenanceCalories,
          lessThan(days5plus.estimatedMaintenanceCalories!),
        );
      },
    );

    test(
      'legacy activity aliases are supported for backward compatibility',
      () {
        expect(NutritionTargetService.activityFactor('high'), 1.45);
        expect(NutritionTargetService.activityFactor('active'), 1.45);
        expect(NutritionTargetService.activityFactor('medium'), 1.35);
        expect(NutritionTargetService.activityFactor('moderate'), 1.35);
        expect(NutritionTargetService.activityFactor('low'), 1.25);
        expect(NutritionTargetService.activityFactor('sedentary'), 1.25);
      },
    );

    test(
      'gender calculations support male, female, non_binary, and prefer_not_to_say',
      () {
        final male = service.calculate(
          ageRange: '25-34',
          heightCm: 175,
          weightKg: 70,
          gender: 'male',
        );
        final female = service.calculate(
          ageRange: '25-34',
          heightCm: 175,
          weightKg: 70,
          gender: 'female',
        );
        final nonBinary = service.calculate(
          ageRange: '25-34',
          heightCm: 175,
          weightKg: 70,
          gender: 'non_binary',
        );
        final preferNotToSay = service.calculate(
          ageRange: '25-34',
          heightCm: 175,
          weightKg: 70,
          gender: 'prefer_not_to_say',
        );

        expect(male.estimatedBmr, greaterThan(female.estimatedBmr!));
        expect(nonBinary.estimatedBmr, isNotNull);
        expect(preferNotToSay.estimatedBmr, isNotNull);
        expect(nonBinary.estimatedBmr, preferNotToSay.estimatedBmr);
      },
    );

    test('age ranges map deterministically to estimated ages', () {
      expect(NutritionTargetService.estimateAgeFromRange('<18'), 17);
      expect(NutritionTargetService.estimateAgeFromRange('18-24'), 21);
      expect(NutritionTargetService.estimateAgeFromRange('25-34'), 30);
      expect(NutritionTargetService.estimateAgeFromRange('35-44'), 40);
      expect(NutritionTargetService.estimateAgeFromRange('45+'), 50);
      expect(NutritionTargetService.estimateAgeFromRange(null), isNull);
    });

    test('protein target uses canonical 2.0 g/kg formula', () {
      final targets = service.calculate(
        ageRange: '25-34',
        heightCm: 175,
        weightKg: 75.5,
        gender: 'male',
      );
      expect(targets.proteinTarget, 151.0);
    });
  });
}
