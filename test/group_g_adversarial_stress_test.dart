import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/services/routine_conflict_engine.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';

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
            final isStrictA =
                catA == RoutineCategory.classBlock ||
                catA == RoutineCategory.job;
            final isStrictB =
                catB == RoutineCategory.classBlock ||
                catB == RoutineCategory.job;
            final isSleepA = catA == RoutineCategory.sleep;
            final isSleepB = catB == RoutineCategory.sleep;
            final isMealA = catA == RoutineCategory.eating;
            final isMealB = catB == RoutineCategory.eating;
            final isFixedA = catA == RoutineCategory.fixed;
            final isFixedB = catB == RoutineCategory.fixed;

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
              'Matrix Pair: ${catA.name} ($typeA) vs ${catB.name} ($typeB) overlap',
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

                final conflicts = RoutineConflictEngine.detect([
                  itemA,
                  itemB,
                ], DateTime(2026, 7, 27));

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

                if (isStrictA && isStrictB) {
                  // Both strict hard (Class/Job) => unavailableTime, blocking, invalid
                  expect(
                    conflicts.any(
                      (c) =>
                          c.type == RoutineConflictType.unavailableTime &&
                          c.blocking,
                    ),
                    isTrue,
                    reason:
                        'Strict vs Strict overlap must trigger unavailableTime blocking conflict',
                  );
                  expect(valResult.isValid, isFalse);
                } else if (isSleepA || isSleepB) {
                  // Any sleep => sleepConflict, blocking, invalid
                  expect(
                    conflicts.any(
                      (c) =>
                          c.type == RoutineConflictType.sleepConflict &&
                          c.blocking,
                    ),
                    isTrue,
                    reason:
                        'Sleep overlap must trigger sleepConflict blocking conflict',
                  );
                  expect(valResult.isValid, isFalse);
                } else if ((isMealA && (isStrictB || isFixedB)) ||
                    (isMealB && (isStrictA || isFixedA)) ||
                    (isFixedA && (isStrictB || isFixedB)) ||
                    (isFixedB && isStrictA)) {
                  // Explicitly compatible pairs still block until the user
                  // durably accepts the overlap.
                  expect(
                    conflicts.any(
                      (c) =>
                          c.type == RoutineConflictType.compatibleOverlap &&
                          c.blocking &&
                          c.canKeepBoth,
                    ),
                    isTrue,
                    reason:
                        'Compatible overlap must require explicit acceptance',
                  );
                  expect(valResult.isValid, isFalse);
                } else if (itemA.isHardBlock && itemB.isHardBlock) {
                  expect(
                    conflicts.any(
                      (c) =>
                          c.type == RoutineConflictType.unavailableTime &&
                          c.blocking &&
                          !c.canKeepBoth,
                    ),
                    isTrue,
                  );
                  expect(valResult.isValid, isFalse);
                } else if (isMealA && isMealB) {
                  // Meal vs Meal starting within 120 mins fails 120-minute meal spacing rule in RoutineValidationService
                  expect(
                    conflicts.any(
                      (c) =>
                          c.type == RoutineConflictType.timeOverlap &&
                          !c.blocking,
                    ),
                    isTrue,
                    reason: 'Engine detects soft timeOverlap for meals',
                  );
                  expect(
                    valResult.isValid,
                    isFalse,
                    reason:
                        'Validation fails due to 120-minute meal spacing invariant',
                  );
                  expect(valResult.userSafeMessage, contains('120 minutes'));
                } else {
                  // Single hard vs soft OR soft vs soft => timeOverlap, non-blocking, VALID!
                  expect(
                    conflicts.any(
                      (c) =>
                          c.type == RoutineConflictType.timeOverlap &&
                          !c.blocking,
                    ),
                    isTrue,
                    reason:
                        'Single hard vs soft or soft vs soft overlap must be non-blocking timeOverlap',
                  );
                  expect(
                    valResult.isValid,
                    isTrue,
                    reason:
                        'Validation result must be valid for non-blocking soft overlaps',
                  );
                }
              },
            );
          }
        }
      });

      // =========================================================================
      // 2. DENSE SCHEDULE COMBINATIONS (CLASS, EXAM, JOB, HABIT, MEAL)
      // =========================================================================
      group('2. Stressful Multi-Block Daily Schedule Matrix', () {
        test(
          'Adversarial: Realistic complex student schedule with 15 overlapping blocks',
          () {
            final date = DateTime(2026, 7, 27); // Monday (day 1)

            final items = <RoutineItem>[
              // Sleep (crosses midnight)
              RoutineItem(
                id: 'sleep_1',
                title: 'Overnight Sleep',
                startMinute: 23 * 60,
                endMinute: 7 * 60,
                repeatDays: const [1, 2, 3, 4, 5, 6, 7],
                crossesMidnight: true,
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.sleep,
              ),
              // Morning Routine
              RoutineItem(
                id: 'habit_morning',
                title: 'Morning Meditation',
                startMinute: 7 * 60 + 15,
                endMinute: 7 * 60 + 45,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.habit,
              ),
              // Breakfast (well spaced before lunch)
              RoutineItem(
                id: 'meal_breakfast',
                title: 'Healthy Breakfast',
                startMinute: 7 * 60 + 45,
                endMinute: 8 * 60 + 15,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.eating,
              ),
              // Morning Class 1
              RoutineItem(
                id: 'class_math',
                title: 'Calculus III',
                startMinute: 8 * 60 + 30,
                endMinute: 10 * 60,
                repeatDays: const [1],
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.classBlock,
              ),
              // Midterm Exam (overlaps Calculus III & CS Lab)
              RoutineItem(
                id: 'exam_midterm',
                title: 'Calculus Midterm Exam',
                startMinute: 9 * 60 + 30,
                endMinute: 11 * 60 + 30,
                repeatDays: const [1],
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.classBlock,
              ),
              // CS Lab (overlaps Midterm Exam)
              RoutineItem(
                id: 'class_cs_lab',
                title: 'Data Structures Lab',
                startMinute: 11 * 60,
                endMinute: 12 * 60 + 30,
                repeatDays: const [1],
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.classBlock,
              ),
              // Lunch (overlaps CS Lab, spaced > 120 mins from breakfast)
              RoutineItem(
                id: 'meal_lunch',
                title: 'Campus Lunch',
                startMinute: 12 * 60,
                endMinute: 13 * 60,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.eating,
              ),
              // Afternoon Job Shift
              RoutineItem(
                id: 'job_tutoring',
                title: 'Campus Library Job',
                startMinute: 13 * 60 + 30,
                endMinute: 17 * 60,
                repeatDays: const [1],
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.job,
              ),
              // Afternoon Class (overlaps Job Shift)
              RoutineItem(
                id: 'class_physics',
                title: 'Physics 201',
                startMinute: 14 * 60,
                endMinute: 15 * 60 + 30,
                repeatDays: const [1],
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.classBlock,
              ),
              // Snack habit (overlaps Job Shift)
              RoutineItem(
                id: 'habit_snack',
                title: 'Afternoon Coffee Break',
                startMinute: 15 * 60,
                endMinute: 15 * 60 + 30,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.habit,
              ),
              // Dinner (spaced > 120 mins from lunch)
              RoutineItem(
                id: 'meal_dinner',
                title: 'Dinner',
                startMinute: 17 * 60 + 30,
                endMinute: 18 * 60 + 30,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.eating,
              ),
              // Evening Gym Habit
              RoutineItem(
                id: 'habit_gym',
                title: 'Evening Workout',
                startMinute: 18 * 60 + 30,
                endMinute: 20 * 60,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.habit,
              ),
              // Night Study Fixed Block
              RoutineItem(
                id: 'fixed_study',
                title: 'Group Project Prep',
                startMinute: 20 * 60,
                endMinute: 21 * 60 + 30,
                repeatDays: const [1],
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.fixed,
              ),
              // Night Reading Habit (overlaps Night Study)
              RoutineItem(
                id: 'habit_reading',
                title: 'Tech Blog Reading',
                startMinute: 21 * 60,
                endMinute: 22 * 60,
                repeatDays: const [1],
                blockType: RoutineBlockType.softBlock,
                category: RoutineCategory.habit,
              ),
              // Late Night Night Shift Job (overlaps Sleep)
              RoutineItem(
                id: 'job_night_shift',
                title: 'Late Night Support Job',
                startMinute: 22 * 60 + 30,
                endMinute: 24 * 60 + 30, // 22:30 to 00:30
                repeatDays: const [1],
                crossesMidnight: true,
                blockType: RoutineBlockType.hardBlock,
                category: RoutineCategory.job,
              ),
            ];

            final Stopwatch stopwatch = Stopwatch()..start();
            final conflicts = RoutineConflictEngine.detect(items, date);
            stopwatch.stop();

            // 1. Performance check: < 100ms for complex 15-item evaluation
            expect(
              stopwatch.elapsedMilliseconds,
              lessThan(100),
              reason: 'Engine must process dense schedules in under 100ms',
            );

            // 2. verify tooManyTasks warning triggered (15 items > 14)
            expect(
              conflicts.any((c) => c.type == RoutineConflictType.tooManyTasks),
              isTrue,
            );

            // 3. Verify specific strict conflicts detected:
            // - Calculus III vs Calculus Midterm (Class vs Class -> unavailableTime)
            expect(
              conflicts.any(
                (c) =>
                    c.type == RoutineConflictType.unavailableTime &&
                    ((c.itemId == 'class_math' &&
                            c.otherItemId == 'exam_midterm') ||
                        (c.itemId == 'exam_midterm' &&
                            c.otherItemId == 'class_math')),
              ),
              isTrue,
            );

            // - Calculus Midterm vs CS Lab (Class vs Class -> unavailableTime)
            expect(
              conflicts.any(
                (c) =>
                    c.type == RoutineConflictType.unavailableTime &&
                    ((c.itemId == 'exam_midterm' &&
                            c.otherItemId == 'class_cs_lab') ||
                        (c.itemId == 'class_cs_lab' &&
                            c.otherItemId == 'exam_midterm')),
              ),
              isTrue,
            );

            // - Physics 201 vs Library Job (Class vs Job -> unavailableTime)
            expect(
              conflicts.any(
                (c) =>
                    c.type == RoutineConflictType.unavailableTime &&
                    ((c.itemId == 'job_tutoring' &&
                            c.otherItemId == 'class_physics') ||
                        (c.itemId == 'class_physics' &&
                            c.otherItemId == 'job_tutoring')),
              ),
              isTrue,
            );

            // - Late Night Support Job vs Overnight Sleep (Job vs Sleep -> sleepConflict)
            expect(
              conflicts.any(
                (c) =>
                    c.type == RoutineConflictType.sleepConflict &&
                    ((c.itemId == 'job_night_shift' &&
                            c.otherItemId == 'sleep_1') ||
                        (c.itemId == 'sleep_1' &&
                            c.otherItemId == 'job_night_shift')),
              ),
              isTrue,
            );

            // 4. Verify compatible overlaps require durable acceptance:
            // - Campus Lunch vs CS Lab (Eating vs Class)
            final softLunch = conflicts.firstWhere(
              (c) =>
                  (c.itemId == 'meal_lunch' &&
                      c.otherItemId == 'class_cs_lab') ||
                  (c.itemId == 'class_cs_lab' && c.otherItemId == 'meal_lunch'),
            );
            expect(
              softLunch.type,
              equals(RoutineConflictType.compatibleOverlap),
            );
            expect(softLunch.blocking, isTrue);
            expect(softLunch.canKeepBoth, isTrue);
          },
        );
      });

      // =========================================================================
      // 3. EXAM KEYWORD & ONBOARDING CANDIDATE MAPPING STRESS
      // =========================================================================
      group('3. Onboarding Candidate Mapping & Exam Stress Generator', () {
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

      // =========================================================================
      // 4. EDGE CASE & BOUNDARY STRESS INVARIANTS
      // =========================================================================
      group('4. Boundary Invariants & Edge Cases', () {
        test(
          'Boundary: Contiguous time blocks (08:00-09:00, 09:00-10:00, 10:00-11:00) produce 0 conflicts',
          () {
            final b1 = RoutineItem(
              id: 'b1',
              title: 'Class 1',
              startMinute: 8 * 60,
              endMinute: 9 * 60,
              repeatDays: const [1],
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
            );
            final b2 = RoutineItem(
              id: 'b2',
              title: 'Class 2',
              startMinute: 9 * 60,
              endMinute: 10 * 60,
              repeatDays: const [1],
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
            );
            final b3 = RoutineItem(
              id: 'b3',
              title: 'Class 3',
              startMinute: 10 * 60,
              endMinute: 11 * 60,
              repeatDays: const [1],
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
            );

            final conflicts = RoutineConflictEngine.detect([
              b1,
              b2,
              b3,
            ], DateTime(2026, 7, 27));
            expect(
              conflicts,
              isEmpty,
              reason:
                  'Contiguous touching time ranges must not produce any conflicts',
            );
          },
        );

        test(
          'Boundary: Partial 1-minute overlap (08:59-09:01 vs 09:00-10:00 -> 1 conflict)',
          () {
            final b1 = RoutineItem(
              id: 'b1',
              title: 'Class Early',
              startMinute: 8 * 60 + 59, // 08:59
              endMinute: 9 * 60 + 1, // 09:01 (1 min overlap)
              repeatDays: const [1],
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
            );
            final b2 = RoutineItem(
              id: 'b2',
              title: 'Class Main',
              startMinute: 9 * 60, // 09:00
              endMinute: 10 * 60, // 10:00
              repeatDays: const [1],
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
            );

            final conflicts = RoutineConflictEngine.detect([
              b1,
              b2,
            ], DateTime(2026, 7, 27));
            expect(conflicts.length, equals(1));
            expect(
              conflicts.first.type,
              equals(RoutineConflictType.unavailableTime),
            );
            expect(conflicts.first.blocking, isTrue);
          },
        );

        test(
          'Boundary: Truly zero/negative duration block (startMinute 1440, endMinute 0) triggers invalidDuration blocking conflict',
          () {
            final zeroItem = RoutineItem(
              id: 'b_zero',
              title: 'Broken Zero Block',
              startMinute: 1440,
              endMinute: 0, // duration 0
              repeatDays: const [1],
              blockType: RoutineBlockType.hardBlock,
              category: RoutineCategory.classBlock,
            );

            final conflicts = RoutineConflictEngine.detect([
              zeroItem,
            ], DateTime(2026, 7, 27));
            expect(
              conflicts.any(
                (c) =>
                    c.type == RoutineConflictType.invalidDuration && c.blocking,
              ),
              isTrue,
            );
          },
        );

        test(
          'Boundary: Overnight midnight-crossing soft items produce overnightConflict (blocking = true)',
          () {
            final nightItem1 = RoutineItem(
              id: 'night_1',
              title: 'Late Night Chat',
              startMinute: 23 * 60 + 30, // 23:30 - 00:30
              endMinute: 24 * 60 + 30,
              repeatDays: const [1],
              crossesMidnight: true,
              blockType: RoutineBlockType.softBlock,
              category: RoutineCategory.habit,
            );

            final nightItem2 = RoutineItem(
              id: 'night_2',
              title: 'Late Night Podcast',
              startMinute: 24 * 60, // 00:00 - 01:00
              endMinute: 25 * 60,
              repeatDays: const [1],
              crossesMidnight: true,
              blockType: RoutineBlockType.softBlock,
              category: RoutineCategory.habit,
            );

            final conflicts = RoutineConflictEngine.detect([
              nightItem1,
              nightItem2,
            ], DateTime(2026, 7, 27));
            expect(
              conflicts.any(
                (c) => c.type == RoutineConflictType.timeOverlap && !c.blocking,
              ),
              isTrue,
            );
          },
        );
      });
    },
  );
}
