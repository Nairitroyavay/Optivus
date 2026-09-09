import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/features/onboarding/onboarding_flow.dart';
import 'package:optivus/features/onboarding/steps/onboarding_steps.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('semantic onboarding step registry', () {
    test('dead split Step 4 file and import path cannot return', () {
      final legacyPath = [
        'lib/features/onboarding/steps',
        ['onboarding_class_setup', 'timeline.dart'].join('_'),
      ].join('/');
      expect(File(legacyPath).existsSync(), isFalse);

      final legacyImportName = [
        'onboarding_class_setup',
        'timeline.dart',
      ].join('_');
      final offenders = [Directory('lib'), Directory('test')]
          .expand((directory) => directory.listSync(recursive: true))
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains(legacyImportName))
          .map((file) => file.path)
          .toList();
      expect(offenders, isEmpty);
    });

    test('semantic ownership and repository architecture stay singular', () {
      final libDartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false);

      final registryDeclarations = libDartFiles.fold<int>(
        0,
        (count, file) =>
            count +
            RegExp(
              r'\benum\s+OnboardingStepId\b',
            ).allMatches(file.readAsStringSync()).length,
      );
      expect(registryDeclarations, 1);

      final duplicateRepositoryName = [
        'onboarding',
        'repositories.dart',
      ].join('_');
      final duplicateRepositoryPath = [
        'lib/repositories',
        duplicateRepositoryName,
      ].join('/');
      expect(File(duplicateRepositoryPath).existsSync(), isFalse);

      final importRoots = [
        'lib',
        'test',
        'integration_test',
        'tools',
        'scripts',
        'workers',
        'bin',
      ].map(Directory.new).where((directory) => directory.existsSync());
      final duplicateImportOffenders = importRoots
          .expand((directory) => directory.listSync(recursive: true))
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) => file.readAsStringSync().contains(duplicateRepositoryName),
          )
          .map((file) => file.path)
          .toList();
      expect(duplicateImportOffenders, isEmpty);

      final activeFoundationFiles = libDartFiles.where((file) {
        final path = file.path;
        return path.startsWith('lib/features/onboarding/') ||
            path.startsWith('lib/features/recovery/') ||
            path.startsWith('lib/services/onboarding_') ||
            path == 'lib/state/app_state.dart' ||
            path == 'lib/state/auth_state.dart' ||
            path.startsWith('lib/models/onboarding');
      });
      final semanticVectorWrite = RegExp(
        r'(?:stepCompleted|stepDirty|stepLoading|completed|dirty|loading)'
        r'\s*\[\s*(?:[0-9]|1[0-4])\s*\]\s*=',
      );
      final semanticValidateCall = RegExp(
        r'validateStep\s*\(\s*(?:[0-9]|1[0-4])\b',
      );
      final numericAffectedStep = RegExp(
        r'earliestAffectedStep\s*=\s*(?:[0-9]|1[0-4])\b',
      );
      final semanticOffenders = <String>[];
      for (final file in activeFoundationFiles) {
        final source = file.readAsStringSync();
        if (semanticVectorWrite.hasMatch(source) ||
            semanticValidateCall.hasMatch(source) ||
            numericAffectedStep.hasMatch(source)) {
          semanticOffenders.add(file.path);
        }
      }
      expect(semanticOffenders, isEmpty);

      final shellSource = File(
        'lib/features/onboarding/widgets/onboarding_step_shell.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'currentPage\s*==\s*(?:0|14)\b').hasMatch(shellSource),
        isFalse,
      );

      final activeDartFiles = [Directory('lib'), Directory('test')]
          .expand((directory) => directory.listSync(recursive: true))
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false);
      final legacyActionName = ['MigrateLegacy', 'SetupAction'].join('');
      final legacyActionId = ['migrate_legacy', 'setup'].join('_');
      final legacyMigrationActionOffenders = activeDartFiles
          .where((file) {
            final source = file.readAsStringSync();
            return source.contains(legacyActionName) ||
                source.contains(legacyActionId);
          })
          .map((file) => file.path)
          .toList();
      expect(legacyMigrationActionOffenders, isEmpty);
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

    test(
      'A full legacy vectors without domain evidence decouple steps 5, 6, 7',
      () {
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 11,
          'stepCompleted': vector(12, value: true),
          'stepDirty': vector(12),
          'stepLoading': vector(12),
        });
        expect(draft.currentStep, OnboardingStepId.todayReady.index);
        // Steps 0..4 and 8..14 map positional, but decoupled steps 5, 6, 7 require evidence
        expect(draft.stepCompleted[0], isTrue);
        expect(draft.stepCompleted[1], isTrue);
        expect(draft.stepCompleted[2], isTrue);
        expect(draft.stepCompleted[3], isTrue);
        expect(draft.stepCompleted[4], isTrue);
        expect(draft.stepCompleted[5], isFalse);
        expect(draft.stepCompleted[6], isFalse);
        expect(draft.stepCompleted[7], isFalse);
        expect(draft.stepCompleted[8], isTrue);
        expect(draft.stepCompleted[9], isTrue);
        expect(draft.stepCompleted[10], isTrue);
        expect(draft.stepCompleted[11], isTrue);
        expect(draft.stepCompleted[12], isTrue);
        expect(draft.stepCompleted[13], isTrue);
      },
    );

    test(
      'A2 full legacy vectors with domain evidence preserve steps 5, 6, 7 completion',
      () {
        final base = const BaseTimelineDraft(
          eatingSetupPath: 'skip',
          skinCareSkipped: true,
          blocks: [
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 1380,
              endMinute: 420,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              crossesMidnight: true,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 430,
              endMinute: 460,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 11,
          'stepCompleted': vector(12, value: true),
          'stepDirty': vector(12),
          'stepLoading': vector(12),
          'baseTimeline': base.toMap(),
        });
        expect(draft.currentStep, OnboardingStepId.todayReady.index);
        expect(draft.stepCompleted, vector(15, value: true));
      },
    );

    test(
      'A3 legacy old Step 4 + only valid Eating evidence: only Eating migrates complete',
      () {
        final base = const BaseTimelineDraft(eatingSetupPath: 'skip');
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 4,
          'stepCompleted': [true, true, true, true, true],
          'baseTimeline': base.toMap(),
        });
        expect(draft.stepCompleted[OnboardingStepId.eating.index], isTrue);
        expect(
          draft.stepCompleted[OnboardingStepId.fixedSchedule.index],
          isFalse,
        );
        expect(draft.stepCompleted[OnboardingStepId.skinCare.index], isFalse);
      },
    );

    test(
      'A4 legacy old Step 4 + valid Fixed evidence: Fixed completion is derived independently',
      () {
        final base = const BaseTimelineDraft(
          blocks: [
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedSleepId,
              section: 'fixed',
              title: 'Sleep',
              startMinute: 1380,
              endMinute: 420,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              crossesMidnight: true,
            ),
            TimelineBlockDraft(
              id: BaseTimelineDraft.fixedBathId,
              section: 'fixed',
              title: 'Bath',
              startMinute: 430,
              endMinute: 460,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
            ),
          ],
        );
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 4,
          'stepCompleted': [true, true, true, true, true],
          'baseTimeline': base.toMap(),
        });
        expect(draft.stepCompleted[OnboardingStepId.eating.index], isFalse);
        expect(
          draft.stepCompleted[OnboardingStepId.fixedSchedule.index],
          isTrue,
        );
        expect(draft.stepCompleted[OnboardingStepId.skinCare.index], isFalse);
      },
    );

    test(
      'A5 legacy Skin Care explicit skip satisfies Skin Care migration contract',
      () {
        final base = const BaseTimelineDraft(skinCareSkipped: true);
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 4,
          'stepCompleted': [true, true, true, true, true],
          'baseTimeline': base.toMap(),
        });
        expect(draft.stepCompleted[OnboardingStepId.skinCare.index], isTrue);
      },
    );

    test(
      'A6 legacy obsolete generated Eating plan does not migrate Step 5 as complete',
      () {
        final base = BaseTimelineDraft(
          eatingSetupPath: 'create',
          blocks: const [
            TimelineBlockDraft(
              id: 'legacy-meal-1',
              section: 'eating',
              title: 'Legacy Meal',
              startMinute: 480,
              endMinute: 510,
              repeatDays: [1, 2, 3, 4, 5, 6, 7],
              blockType: TimelineBlockDraft.hardBlockKey,
              source: 'ai_generated_meal_setup',
            ),
          ],
        );
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 4,
          'stepCompleted': [true, true, true, true, true],
          'baseTimeline': base.toMap(),
        });
        expect(draft.stepCompleted[OnboardingStepId.eating.index], isFalse);
      },
    );

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

    test('schema-v2 exact 12-vector is ambiguous and is not shifted', () {
      final completed = vector(12)..[4] = true;
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': 8,
        'stepCompleted': completed,
      });
      expect(draft.currentStep, OnboardingStepId.badHabits.index);
      expect(draft.stepCompleted.take(12), completed);
      expect(draft.stepCompleted.skip(12), [false, false, false]);
      expect(draft.stepCompleted[OnboardingStepId.eating.index], isFalse);
      expect(draft.stepCompleted[OnboardingStepId.skinCare.index], isFalse);
    });

    test('schema-v2 short completed vector preserves current meaning', () {
      final completed = [true, true, true, true, true, false];
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': 5,
        'stepCompleted': completed,
      });
      expect(draft.currentStep, OnboardingStepId.eating.index);
      expect(draft.stepCompleted.take(6), completed);
      expect(draft.stepCompleted.skip(6).every((value) => !value), isTrue);
    });

    test('schema-v2 exact 12 dirty and loading vectors stay positional', () {
      final dirty = vector(12)..[8] = true;
      final loading = vector(12)..[8] = true;
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': 8,
        'stepDirty': dirty,
        'stepLoading': loading,
      });
      expect(draft.currentStep, OnboardingStepId.badHabits.index);
      expect(draft.stepDirty[8], isTrue);
      expect(draft.stepLoading.every((v) => !v), isTrue);
      expect(draft.stepDirty[11], isFalse);
    });

    test('schema-v2 ambiguous round trip becomes unequivocally current', () {
      final first = OnboardingDraft.fromMap({
        'schemaVersion': 2,
        'currentStep': 8,
        'stepCompleted': vector(12)..[8] = true,
      });
      final serialized = first.toMap();
      final second = OnboardingDraft.fromMap(serialized);
      expect(serialized['schemaVersion'], OnboardingDraft.schemaVersion);
      expect((serialized['stepCompleted'] as List), hasLength(15));
      expect(second.currentStep, 8);
      expect(second.stepCompleted, first.stepCompleted);
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

    test(
      'E partial historical vector maps positions and decouples unverified steps',
      () {
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 5,
          'stepCompleted': [true, true, true, true, true, false],
        });
        expect(draft.stepCompleted.take(5), [true, true, true, true, true]);
        expect(draft.stepCompleted[5], isFalse);
        expect(draft.stepCompleted[6], isFalse);
        expect(draft.stepCompleted[7], isFalse);
      },
    );

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

    test(
      'G stepLoading always normalizes to false to prevent sticky spinners',
      () {
        final draft = OnboardingDraft.fromMap({
          'schemaVersion': 1,
          'currentStep': 8,
          'stepCompleted': vector(12),
          'stepLoading': [false, false, false, false, false, true],
        });
        expect(draft.stepLoading.every((v) => !v), isTrue);
      },
    );

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

    test('current schema exact 12-vector is padded without legacy fan-out', () {
      final completed = vector(12)..[4] = true;
      final draft = OnboardingDraft.fromMap({
        'schemaVersion': OnboardingDraft.schemaVersion,
        'currentStep': 8,
        'stepCompleted': completed,
      });
      expect(draft.currentStep, 8);
      expect(draft.stepCompleted.take(12), completed);
      expect(draft.stepCompleted[OnboardingStepId.eating.index], isFalse);
      expect(draft.stepCompleted.skip(12), [false, false, false]);
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
      expect(restored.stepLoading.every((v) => !v), isTrue);
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
