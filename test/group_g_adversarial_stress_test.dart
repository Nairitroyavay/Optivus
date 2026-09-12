import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';

void main() {
  group(
    'Group G Adversarial Stress-Test: Class, Exam, Job, Habit, Meal Combinations',
    () {
      // =========================================================================
      // 1. COMBINATORIAL MATRIX OVERLAP STRESS TEST
      // =========================================================================
      group('1. Full Category-Pair Overlap Matrix Generator', () {
        final categories = [
          RoutineCategory.classBlock,
          RoutineCategory.job,
          RoutineCategory.fixed,
          RoutineCategory.sleep,
          RoutineCategory.eating,
          RoutineCategory.habit,
          RoutineCategory.skinCare,
          RoutineCategory.health,
        ];

        for (final catA in categories) {
          for (final catB in categories) {
            final typeA =
                (catA == RoutineCategory.classBlock ||
                    catA == RoutineCategory.job ||
                    catA == RoutineCategory.fixed ||
                    catA == RoutineCategory.sleep)
                ? RoutineBlockType.hardBlock
                : RoutineBlockType.softBlock;
            final typeB =
                (catB == RoutineCategory.classBlock ||
                    catB == RoutineCategory.job ||
                    catB == RoutineCategory.fixed ||
                    catB == RoutineCategory.sleep)
                ? RoutineBlockType.hardBlock
                : RoutineBlockType.softBlock;

            test(
              'Matrix Pair: ${catA.name} ($typeA) vs ${catB.name} ($typeB) overlap is valid',
              () {
                final itemA = RoutineItem(
                  id: 'item_a_${catA.name}',
                  title: 'Block A (${catA.name})',
                  startMinute: 10 * 60,
                  endMinute: 11 * 60,
                  repeatDays: const [1],
                  blockType: typeA,
                  category: catA,
                );

                final itemB = RoutineItem(
                  id: 'item_b_${catB.name}',
                  title: 'Block B (${catB.name})',
                  startMinute: 10 * 60 + 30, // 10:30 - 11:30 (overlaps)
                  endMinute: 11 * 60 + 30,
                  repeatDays: const [1],
                  blockType: typeB,
                  category: catB,
                );

                final valResult = RoutineValidationService.validate(
                  RoutineValidationContext(
                    candidate: itemB,
                    existingTemplates: [itemA],
                    occurrences: const [],
                    evaluationDate: DateTime(2026, 7, 27),
                    operation: RoutineValidationOperation.create,
                    authenticatedOwnerUid: 'test_user',
                  ),
                );

                expect(
                  valResult.isValid,
                  isTrue,
                  reason:
                      'Validation permits overlaps across all category pairs in live Routine',
                );
              },
            );
          }
        }
      });

      // =========================================================================
      // 2. EXAM KEYWORD & ONBOARDING CANDIDATE MAPPING STRESS
      // =========================================================================
      group('2. Onboarding Candidate Mapping & Exam Stress Generator', () {
        test(
          'Adversarial: 30+ mixed candidates stress mapOnboarding4Candidates for class and work configs',
          () {
            final candidateSpecs = [
              ('Math 101', 'classes', [1, 3, 5], 540, 600, true),
              ('Math Midterm Exam', 'classes', [3], 570, 690, true),
              ('Physics Final', 'classes', [5], 840, 960, true),
              ('Bio Quiz 3', 'classes', [1], 600, 630, true),
              ('Chemistry Assessment 1', 'classes', [2], 660, 720, true),
              ('CS Unit Test', 'classes', [4], 780, 840, true),
              ('English Literature Exam', 'classes', [2, 4], 900, 1020, true),
              ('History Class', 'classes', [1, 2, 3, 4, 5], 600, 660, true),
              (
                'Disallowed Gym',
                'work',
                [1],
                420,
                480,
                true,
              ), // Disallowed work
              (
                'No Title Block',
                'classes',
                [1],
                540,
                600,
                true,
              ), // Empty title test below
              (
                'Invalid End Time',
                'classes',
                [1],
                600,
                540,
                true,
              ), // Invalid time range
              (
                'Missing Repeat Days',
                'classes',
                <int>[],
                600,
                660,
                true,
              ), // Empty repeat days
            ];

            final candidates = <RoutineImportCandidateBlock>[];
            int idCounter = 1;

            for (final spec in candidateSpecs) {
              candidates.add(
                RoutineImportCandidateBlock(
                  id: 'cand_${idCounter++}',
                  title: spec.$1 == 'No Title Block' ? '   ' : spec.$1,
                  category: spec.$2,
                  blockType: 'hard',
                  hardBlock: true,
                  repeatDays: spec.$3,
                  startMinute: spec.$4,
                  endMinute: spec.$5,
                  hasFixedTime: spec.$6,
                ),
              );
            }

            // Test class setup mapping
            final classMapped = mapOnboarding4Candidates(
              candidates: candidates,
              config: ScheduleSetupConfig.classSetup,
            );

            // Verify invalid items dropped correctly
            expect(classMapped.droppedNoTitle, equals(1));
            expect(classMapped.droppedInvalidTime, equals(1));
            expect(classMapped.droppedNoRepeatDays, equals(1));
            expect(
              classMapped.blocks.length,
              equals(9),
            ); // 8 class + 1 gym (kept in class config)

            // Test work setup mapping (where Disallowed Gym gets dropped)
            final workMapped = mapOnboarding4Candidates(
              candidates: candidates,
              config: ScheduleSetupConfig.workSetup,
            );
            expect(workMapped.droppedNonWork, equals(1));

            // Verify all exam blocks are recognized
            final examTitles = [
              'Math Midterm Exam',
              'Physics Final',
              'Bio Quiz 3',
              'Chemistry Assessment 1',
              'CS Unit Test',
              'English Literature Exam',
            ];

            for (final title in examTitles) {
              expect(
                isExamCandidateTitle(title),
                isTrue,
                reason: '$title must be recognized as exam candidate',
              );
            }

            // Verify template class retains all 3 days [1, 3, 5]
            final mathClass = classMapped.blocks.firstWhere(
              (b) => b.subject == 'Math 101',
            );
            expect(
              mathClass.repeatDays,
              equals([1, 3, 5]),
              reason:
                  'Regular class repeatDays must remain intact despite overlapping exam',
            );
          },
        );
      });
    },
  );
}
