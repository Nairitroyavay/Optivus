import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_steps.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('semantic onboarding step registry', () {
    test('active production Step 4 has no legacy widget-file dependency', () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) =>
                !file.path.endsWith('onboarding_class_setup_timeline.dart'),
          )
          .where(
            (file) => file.readAsStringSync().contains(
              'onboarding_class_setup_timeline.dart',
            ),
          )
          .map((file) => file.path)
          .toList();
      expect(offenders, isEmpty);
    });

    test('owns one unique current 0-14 order', () {
      expect(OnboardingStepId.values, hasLength(15));
      expect(OnboardingStepId.values.map((id) => id.index).toSet(), {
        for (var index = 0; index < 15; index++) index,
      });
      expect(OnboardingDraft.stepCount, OnboardingStepId.values.length);
      expect(OnboardingStepId.todayReady.index, OnboardingDraft.lastStepIndex);
      expect(
        OnboardingStepId.values
            .map((id) => OnboardingStepId.fromIndex(id.index))
            .toList(),
        OnboardingStepId.values,
      );
      expect(currentOnboardingStepOrder, [
        OnboardingStepId.welcome,
        OnboardingStepId.patience,
        OnboardingStepId.roleLifestyle,
        OnboardingStepId.bodyBasics,
        OnboardingStepId.classesJob,
        OnboardingStepId.eating,
        OnboardingStepId.fixedSchedule,
        OnboardingStepId.skinCare,
        OnboardingStepId.badHabits,
        OnboardingStepId.goodHabits,
        OnboardingStepId.identityGoals,
        OnboardingStepId.coachSetup,
        OnboardingStepId.slipUp,
        OnboardingStepId.notifications,
        OnboardingStepId.todayReady,
      ]);
    });

    test('explicit legacy identity mapping owns the old combined boundary', () {
      expect(legacyOnboardingIndexToCurrentStepId(0), OnboardingStepId.welcome);
      expect(
        legacyOnboardingIndexToCurrentStepId(4),
        OnboardingStepId.classesJob,
      );
      expect(
        legacyOnboardingIndexToCurrentStepId(5),
        OnboardingStepId.badHabits,
      );
      expect(
        legacyOnboardingIndexToCurrentStepId(11),
        OnboardingStepId.todayReady,
      );
    });

    test('active onboarding page factory matches the product order', () {
      expect(
        currentOnboardingStepOrder
            .map((id) => onboardingPageForStep(id).runtimeType)
            .toList(),
        [
          OnboardingStep0,
          OnboardingStep1,
          OnboardingStep2,
          OnboardingStep3,
          OnboardingStep4,
          OnboardingStep5,
          OnboardingStep6,
          OnboardingStep7,
          OnboardingBadHabitsStep,
          OnboardingGoodHabitsStep,
          OnboardingIdentityGoalsStep,
          OnboardingCoachSetupStep,
          OnboardingSlipUpStep,
          OnboardingNotificationsStep,
          OnboardingTodayReadyStep,
        ],
      );
    });
  });

  group('12 to 15 persisted layout migration', () {
    List<bool> vector(int length, {bool value = false}) =>
        List<bool>.filled(length, value);

    test('A full legacy vectors and current step 11 map to current 14', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 1,
        'currentStep': 11,
        'stepCompleted': vector(12, value: true),
        'stepDirty': vector(12),
        'stepLoading': vector(12),
      });
      expect(draft.currentStep, OnboardingStepId.todayReady.index);
      expect(draft.stepCompleted, vector(15, value: true));
    });

    test('B schema-v2 current 15-step data is never shifted', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': 8,
        'stepCompleted': vector(15),
        'stepDirty': vector(15),
        'stepLoading': vector(15),
      });
      expect(draft.currentStep, OnboardingStepId.badHabits.index);
    });

    test('C current schema and full vectors remain unchanged', () {
      final completed = [for (var index = 0; index < 15; index++) index.isEven];
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': OnboardingDraft.schemaVersion,
        'currentStep': 9,
        'stepCompleted': completed,
      });
      expect(draft.currentStep, 9);
      expect(draft.stepCompleted, completed);
    });

    test('D missing schema and a full legacy vector use legacy mapping', () {
      final draft = OnboardingDraft.fromMap({
        'currentStep': 5,
        'stepCompleted': vector(12),
      });
      expect(draft.currentStep, OnboardingStepId.badHabits.index);
      expect(draft.stepCompleted, hasLength(15));
    });

    test('E partial historical vector maps positions and pads false', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 1,
        'currentStep': 5,
        'stepCompleted': [true, true, true, true, true, false],
      });
      expect(draft.stepCompleted, [
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
      ]);
    });

    test('F one document decision migrates a partial dirty vector', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 1,
        'currentStep': 8,
        'stepCompleted': vector(12),
        'stepDirty': [false, false, false, false, false, true],
      });
      expect(draft.stepDirty[OnboardingStepId.badHabits.index], isTrue);
      expect(draft.stepDirty[OnboardingStepId.eating.index], isFalse);
    });

    test('G one document decision migrates a partial loading vector', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 1,
        'currentStep': 8,
        'stepCompleted': vector(12),
        'stepLoading': [false, false, false, false, false, true],
      });
      expect(draft.stepLoading[OnboardingStepId.badHabits.index], isTrue);
      expect(draft.stepLoading[OnboardingStepId.eating.index], isFalse);
    });

    test('H current schema short vector is padded as current', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': OnboardingDraft.schemaVersion,
        'currentStep': 5,
        'stepCompleted': [true, false, true, false, true, false],
      });
      expect(draft.currentStep, OnboardingStepId.eating.index);
      expect(draft.stepCompleted.take(6), [
        true,
        false,
        true,
        false,
        true,
        false,
      ]);
      expect(draft.stepCompleted.skip(6).every((value) => !value), isTrue);
    });

    test('I mixed vector lengths fail safe without shifting progression', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': 8,
        'stepCompleted': vector(15),
        'stepDirty': vector(12)..[5] = true,
      });
      expect(draft.currentStep, OnboardingStepId.badHabits.index);
      expect(draft.stepDirty[5], isTrue);
      expect(draft.stepDirty[8], isFalse);
    });

    test('J string current step parses consistently', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': '5',
        'stepCompleted': vector(15),
      });
      expect(draft.currentStep, OnboardingStepId.eating.index);
    });

    test('K invalid current steps fail safely', () {
      expect(
        OnboardingDraft.fromMap({
          'schemaVersion': 3,
          'currentStep': -7,
        }).currentStep,
        0,
      );
      expect(
        OnboardingDraft.fromMap({
          'schemaVersion': 3,
          'currentStep': 99,
        }).currentStep,
        OnboardingDraft.lastStepIndex,
      );
      expect(
        OnboardingDraft.fromMap({
          'schemaVersion': 3,
          'currentStep': 'nonsense',
        }).currentStep,
        0,
      );
    });

    test('L missing vectors do not crash and normalize to 15', () {
      final draft = OnboardingDraft.fromMap({'currentStep': 4});
      expect(draft.currentStep, 4);
      expect(draft.stepCompleted, vector(15));
      expect(draft.stepDirty, vector(15));
      expect(draft.stepLoading, vector(15));
    });

    test('M legacy round trip is idempotent', () {
      final first = OnboardingDraft.fromMap({
        'schemaVersion': 1,
        'currentStep': 5,
        'stepCompleted': vector(12)..[5] = true,
      });
      final second = OnboardingDraft.fromMap(first.toMap());
      expect(second.currentStep, first.currentStep);
      expect(second.stepCompleted, first.stepCompleted);
      expect(second.stepDirty, first.stepDirty);
      expect(second.stepLoading, first.stepLoading);
    });

    test('N modern progression round trip is unchanged', () {
      final original = OnboardingDraft(
        currentStep: 8,
        stepCompleted: vector(15)..[0] = true,
        stepDirty: vector(15)..[8] = true,
        stepLoading: vector(15)..[7] = true,
      );
      final restored = OnboardingDraft.fromMap(original.toMap());
      expect(restored.currentStep, original.currentStep);
      expect(restored.stepCompleted, original.stepCompleted);
      expect(restored.stepDirty, original.stepDirty);
      expect(restored.stepLoading, original.stepLoading);
    });

    test('O completed legacy user stays complete after renumbering', () {
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 1,
        'currentStep': 11,
        'onboardingCompleted': true,
        'stepCompleted': vector(12, value: true),
      });
      expect(draft.onboardingCompleted, isTrue);
      expect(draft.currentStep, OnboardingDraft.lastStepIndex);
      expect(draft.stepCompleted.every((value) => value), isTrue);
    });
  });

  group('evidence-backed legacy enum normalization', () {
    test('body-goal aliases read and write as canonical current keys', () {
      const aliases = {
        'gain_weight': 'gain',
        'build_muscle': 'gain',
        'muscle_gain': 'gain',
        'lose_fat': 'lose',
        'fat_loss': 'lose',
        'weight_loss': 'lose',
        'maintenance': 'maintain',
        'eat_healthier': 'maintain',
        'balanced': 'maintain',
      };
      for (final entry in aliases.entries) {
        final draft = OnboardingDraft.fromMap({
          'baseTimeline': {'mealPlanningGoal': entry.key},
        });
        expect(draft.baseTimeline.mealPlanningGoal, entry.value);
        expect(
          (draft.toMap()['baseTimeline'] as Map)['mealPlanningGoal'],
          entry.value,
        );
      }
    });

    test('activity aliases read and write as canonical current keys', () {
      const aliases = {
        'low': 'rarely',
        'sedentary': 'rarely',
        'medium': '3_4_days',
        'moderate': '3_4_days',
        'high': '5_plus_days',
        'active': '5_plus_days',
      };
      for (final entry in aliases.entries) {
        final draft = OnboardingDraft.fromMap({
          'lifeRole': {'exerciseLevel': entry.key},
        });
        expect(draft.lifeRole.exerciseLevel, entry.value);
        expect(
          (draft.toMap()['lifeRole'] as Map)['exerciseLevel'],
          entry.value,
        );
      }
    });

    test('current values are unchanged and unknown values fail safe', () {
      final current = OnboardingDraft.fromMap({
        'lifeRole': {'exerciseLevel': '1_2_days'},
        'baseTimeline': {'mealPlanningGoal': 'gain'},
      });
      expect(current.lifeRole.exerciseLevel, '1_2_days');
      expect(current.baseTimeline.mealPlanningGoal, 'gain');

      final unknown = OnboardingDraft.fromMap({
        'lifeRole': {'exerciseLevel': 'extreme'},
        'baseTimeline': {'mealPlanningGoal': 'mystery'},
      });
      expect(unknown.lifeRole.exerciseLevel, isNull);
      expect(unknown.baseTimeline.mealPlanningGoal, isNull);
    });
  });
}
