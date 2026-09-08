import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';

void main() {
  group('Adversarial Stress Testing — Issue 31: Routine & Class Overlap Validation', () {
    test(
      '31.A Contiguous Block Boundaries: Exact boundary touch vs 1-minute overlaps',
      () {
        final classA = RoutineItem(
          id: 'class_a',
          title: 'Math 101',
          startMinute: 540, // 09:00
          endMinute: 600, // 10:00
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        // 1. Contiguous class (10:00 - 11:00) -> Should be VALID
        final classBContiguous = RoutineItem(
          id: 'class_b_cont',
          title: 'Physics 101',
          startMinute: 600, // 10:00
          endMinute: 660, // 11:00
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final resContiguous = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: classBContiguous,
            existingTemplates: [classA],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27), // Monday
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );
        expect(
          resContiguous.isValid,
          isTrue,
          reason: 'Exact 10:00 boundary should not conflict',
        );

        // 2. 1-minute overlap at end (09:59 - 11:00) -> Should be INVALID
        final classBOverlapStart = RoutineItem(
          id: 'class_b_ov_start',
          title: 'Physics 101 Overlap',
          startMinute: 599, // 09:59
          endMinute: 660, // 11:00
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final resOverlapStart = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: classBOverlapStart,
            existingTemplates: [classA],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );
        expect(
          resOverlapStart.isValid,
          isFalse,
          reason: '1-minute overlap (09:59-10:00) must trigger conflict',
        );

        // 3. 1-minute overlap at start (08:00 - 09:01) -> Should be INVALID
        final classBOverlapEnd = RoutineItem(
          id: 'class_b_ov_end',
          title: 'Early Physics Overlap',
          startMinute: 480, // 08:00
          endMinute: 541, // 09:01
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final resOverlapEnd = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: classBOverlapEnd,
            existingTemplates: [classA],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );
        expect(
          resOverlapEnd.isValid,
          isFalse,
          reason: '1-minute overlap (09:00-09:01) must trigger conflict',
        );

        // 4. Soft block contiguous at boundary (10:00 - 11:00) -> Should be VALID
        final softContiguous = RoutineItem(
          id: 'soft_cont',
          title: 'Coffee Break',
          startMinute: 600, // 10:00
          endMinute: 660, // 11:00
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
        );

        final resSoftCont = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: softContiguous,
            existingTemplates: [classA],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );
        expect(resSoftCont.isValid, isTrue);
      },
    );

    test('31.B Midnight Wrapping & Overnight Blocks (1430 to 30)', () {
      // 1. Valid overnight block (23:50 to 00:30 -> startMinute: 1430, endMinute: 30, crossesMidnight: true)
      final overnightShift = RoutineItem(
        id: 'night_shift',
        title: 'Night Shift',
        startMinute: 1430, // 23:50
        endMinute: 30, // 00:30
        crossesMidnight: true,
        repeatDays: const [
          7,
        ], // Sunday night -> crosses into Monday morning (00:00-00:30)
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.job,
      );

      // Class block on Monday morning (00:15 - 01:00) overlapping continuation of Sunday night shift
      final mondayClass = RoutineItem(
        id: 'mon_class',
        title: 'Early Monday Class',
        startMinute: 15, // 00:15
        endMinute: 60, // 01:00
        repeatDays: const [1], // Monday
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );

      final resOvernightOverlap = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: mondayClass,
          existingTemplates: [overnightShift],
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27), // Monday
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );
      expect(
        resOvernightOverlap.isValid,
        isFalse,
        reason:
            'Monday 00:15 class overlaps Sunday night shift continuation (00:00-00:30)',
      );

      // 2. Overnight validation error invariants:
      // Invalid: crossesMidnight = true, but endMinute >= startMinute
      final invalidOvernight1 = RoutineItem(
        id: 'bad_overnight_1',
        title: 'Bad Overnight',
        startMinute: 100,
        endMinute: 200,
        crossesMidnight: true,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );
      final resBadOvernight1 = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: invalidOvernight1,
          existingTemplates: const [],
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27),
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );
      expect(resBadOvernight1.isValid, isFalse);
      expect(
        resBadOvernight1.userSafeMessage,
        contains(
          'Overnight items require end time to be strictly before start time',
        ),
      );

      // Invalid: crossesMidnight = false, but endMinute <= startMinute
      final invalidNonOvernight = RoutineItem(
        id: 'bad_non_overnight',
        title: 'Bad Non Overnight',
        startMinute: 1430,
        endMinute: 30,
        crossesMidnight: false,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );
      final resBadNonOvernight = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: invalidNonOvernight,
          existingTemplates: const [],
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27),
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );
      expect(resBadNonOvernight.isValid, isFalse);
      expect(
        resBadNonOvernight.userSafeMessage,
        contains(
          'Non-overnight items require end time to be strictly after start time',
        ),
      );

      // Invalid: startMinute == endMinute
      final sameStartEnd = RoutineItem(
        id: 'same_start_end',
        title: 'Equal Start End',
        startMinute: 600,
        endMinute: 600,
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
      );
      final resSameStartEnd = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: sameStartEnd,
          existingTemplates: const [],
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27),
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );
      expect(resSameStartEnd.isValid, isFalse);
      expect(
        resSameStartEnd.userSafeMessage,
        contains('Start and end time cannot be equal'),
      );
    });

    test('31.C Multiple Soft Blocks Overlapping One Class Block', () {
      final mainClass = RoutineItem(
        id: 'main_class',
        title: 'Full Morning Lecture',
        startMinute: 540, // 09:00
        endMinute: 720, // 12:00
        repeatDays: const [1],
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
      );

      final soft1 = RoutineItem(
        id: 'soft_1',
        title: 'Breakfast / Snack 1',
        startMinute: 510, // 08:30
        endMinute: 570, // 09:30
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );

      final soft2 = RoutineItem(
        id: 'soft_2',
        title: 'Morning Habit',
        startMinute: 600, // 10:00
        endMinute: 660, // 11:00
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.habit,
      );

      final soft3 = RoutineItem(
        id: 'soft_3',
        title: 'Skincare Routine',
        startMinute: 690, // 11:30
        endMinute: 750, // 12:30
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.skinCare,
      );

      // Validate soft3 when mainClass, soft1, soft2 are already present
      final resMultipleSoft = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: soft3,
          existingTemplates: [mainClass, soft1, soft2],
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27),
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );

      expect(
        resMultipleSoft.isValid,
        isTrue,
        reason:
            'Multiple soft blocks overlapping a class block should be non-blocking timeOverlaps',
      );
    });

    test('31.D Eating Category Invariants: 6-meal cap & 120-min spacing', () {
      // 1. Spacing check: 2 meals 119 mins apart -> INVALID
      final meal1 = RoutineItem(
        id: 'meal_1',
        title: 'Breakfast',
        startMinute: 480, // 08:00
        endMinute: 510, // 08:30
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );

      final meal2Close = RoutineItem(
        id: 'meal_2_close',
        title: 'Snack',
        startMinute: 599, // 09:59 (119 minutes after 08:00)
        endMinute: 620,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );

      final resCloseMeal = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: meal2Close,
          existingTemplates: [meal1],
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27),
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );
      expect(resCloseMeal.isValid, isFalse);
      expect(
        resCloseMeal.userSafeMessage,
        contains('spaced at least 120 minutes apart'),
      );

      // 2. 6 meals max limit: adding 7th meal -> INVALID
      final existing6Meals = List.generate(
        6,
        (i) => RoutineItem(
          id: 'meal_existing_$i',
          title: 'Meal $i',
          startMinute:
              360 + i * 150, // 06:00, 08:30, 11:00, 13:30, 16:00, 18:30
          endMinute: 390 + i * 150,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
        ),
      );

      final meal7th = RoutineItem(
        id: 'meal_7th',
        title: 'Midnight Snack',
        startMinute: 1260, // 21:00
        endMinute: 1290,
        repeatDays: const [1],
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
      );

      final res7thMeal = RoutineValidationService.validate(
        RoutineValidationContext(
          candidate: meal7th,
          existingTemplates: existing6Meals,
          occurrences: const [],
          evaluationDate: DateTime(2026, 7, 27),
          operation: RoutineValidationOperation.create,
          authenticatedOwnerUid: 'test_user',
        ),
      );
      expect(res7thMeal.isValid, isFalse);
      expect(
        res7thMeal.userSafeMessage,
        contains('Maximum 6 meals allowed per day'),
      );
    });
  });

  group(
    'Adversarial Stress Testing — Issue 32: Exam Priority & Keyword Matching',
    () {
      test(
        '32.A Multi-Exam Overlaps & Class Schedule Template Preservation',
        () {
          final candidates = <RoutineImportCandidateBlock>[
            RoutineImportCandidateBlock(
              id: 'c1',
              title: 'Math 101',
              category: 'classes',
              blockType: 'hard',
              hardBlock: true,
              startMinute: 540, // 09:00
              endMinute: 600, // 10:00
              hasFixedTime: true,
              repeatDays: const [1, 3, 5], // Mon, Wed, Fri
            ),
            RoutineImportCandidateBlock(
              id: 'c2',
              title: 'Physics 101',
              category: 'classes',
              blockType: 'hard',
              hardBlock: true,
              startMinute: 600, // 10:00
              endMinute: 660, // 11:00
              hasFixedTime: true,
              repeatDays: const [1, 3, 5], // Mon, Wed, Fri
            ),
            RoutineImportCandidateBlock(
              id: 'e1',
              title: 'Math Midterm Exam',
              category: 'classes',
              blockType: 'hard',
              hardBlock: true,
              startMinute: 570, // 09:30 (Overlaps Math 101 & Physics 101)
              endMinute: 690, // 11:30
              hasFixedTime: true,
              repeatDays: const [3], // Wed
            ),
            RoutineImportCandidateBlock(
              id: 'e2',
              title: 'Physics Pop-Quiz & Assessment',
              category: 'classes',
              blockType: 'hard',
              hardBlock: true,
              startMinute: 630, // 10:30 (Overlaps e1, Math 101, Physics 101)
              endMinute: 750, // 12:30
              hasFixedTime: true,
              repeatDays: const [3], // Wed
            ),
          ];

          final result = mapOnboarding4Candidates(
            candidates: candidates,
            config: ScheduleSetupConfig.classSetup,
          );

          // Verify that all 4 blocks are kept intact
          expect(result.blocks.length, equals(4));

          final c1Block = result.blocks.firstWhere((b) => b.id == 'c1');
          expect(
            c1Block.repeatDays,
            equals([1, 3, 5]),
            reason: 'Regular Math 101 repeatDays preserved',
          );

          final c2Block = result.blocks.firstWhere((b) => b.id == 'c2');
          expect(
            c2Block.repeatDays,
            equals([1, 3, 5]),
            reason: 'Regular Physics 101 repeatDays preserved',
          );

          final e1Block = result.blocks.firstWhere((b) => b.id == 'e1');
          expect(e1Block.repeatDays, equals([3]));

          final e2Block = result.blocks.firstWhere((b) => b.id == 'e2');
          expect(e2Block.repeatDays, equals([3]));
        },
      );

      test('32.B Uppercase, Mixed-Case, Hyphenated & Variant Exam Keywords', () {
        final examTitles = [
          'CHEMISTRY EXAM',
          'Math MidTerm',
          'Bio Pop-Quiz',
          'CS Unit Test',
          'Psychology ASSESSMENT',
          'Organic Chem FINAL',
          'History Mid-Term Exam',
          'Physics Final Examination',
        ];

        for (final title in examTitles) {
          expect(
            isExamCandidateTitle(title),
            isTrue,
            reason: 'Title "$title" should be recognized as an exam candidate',
          );
        }

        final nonExamTitles = [
          'Regular Lecture',
          'Weekly Discussion',
          'Lab Session',
        ];

        for (final title in nonExamTitles) {
          expect(
            isExamCandidateTitle(title),
            isFalse,
            reason:
                'Title "$title" should NOT be recognized as an exam candidate',
          );
        }
      });

      test('32.C Candidate Mapping Invariant & Filtering Edge Cases', () {
        final candidates = <RoutineImportCandidateBlock>[
          // Blank title -> droppedNoTitle
          RoutineImportCandidateBlock(
            id: 'bad_title',
            title: '   ',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 540,
            endMinute: 600,
            repeatDays: const [1],
          ),
          // endMinute <= startMinute -> droppedInvalidTime
          RoutineImportCandidateBlock(
            id: 'bad_time',
            title: 'Reversed Time Class',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 600,
            endMinute: 540,
            repeatDays: const [1],
          ),
          // noFixedTime -> droppedInvalidTime
          RoutineImportCandidateBlock(
            id: 'no_fixed',
            title: 'TBD Class',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 540,
            endMinute: 600,
            hasFixedTime: false,
            repeatDays: const [1],
          ),
          // Empty repeat days -> droppedNoRepeatDays
          RoutineImportCandidateBlock(
            id: 'no_days',
            title: 'Unassigned Day Class',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 540,
            endMinute: 600,
            repeatDays: const [],
          ),
          // Valid full week class (1..7) -> mapped
          RoutineImportCandidateBlock(
            id: 'full_week_class',
            title: 'Daily Seminar',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 540,
            endMinute: 600,
            repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          ),
        ];

        final mapped = mapOnboarding4Candidates(
          candidates: candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        expect(mapped.droppedNoTitle, equals(1));
        expect(mapped.droppedInvalidTime, equals(2));
        expect(mapped.droppedNoRepeatDays, equals(1));
        expect(mapped.blocks.length, equals(1));
        expect(mapped.blocks.first.id, equals('full_week_class'));
        expect(mapped.blocks.first.repeatDays, equals([1, 2, 3, 4, 5, 6, 7]));
      });

      test(
        '32.D Probing Substring False Positives & Hyphenated Exclusions in Exam Keyword Matcher',
        () {
          // Substring false positives where words contain exam keywords as substrings
          expect(
            isExamCandidateTitle('Software Testing'),
            isTrue,
            reason: 'contains "test"',
          );
          expect(
            isExamCandidateTitle('Programming Contest'),
            isTrue,
            reason: 'contains "test" in "contest"',
          );
          expect(
            isExamCandidateTitle('Finalize Report'),
            isTrue,
            reason: 'contains "final" in "finalize"',
          );
          expect(
            isExamCandidateTitle('Reading Example'),
            isTrue,
            reason: 'contains "exam" in "example"',
          );

          // Hyphenated term without exact keyword match
          expect(
            isExamCandidateTitle('Physics Mid-Term'),
            isFalse,
            reason: '"mid-term" does not contain "midterm"',
          );
        },
      );

      test('31.E Probing Overnight Soft Block Conflict Behavior', () {
        final nightSoft1 = RoutineItem(
          id: 'night_soft_1',
          title: 'Late Reading',
          startMinute: 1410, // 23:30
          endMinute: 90, // 01:30
          crossesMidnight: true,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.habit,
        );

        final nightSoft2 = RoutineItem(
          id: 'night_soft_2',
          title: 'Late Music',
          startMinute: 1420, // 23:40
          endMinute: 60, // 01:00
          crossesMidnight: true,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.habit,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: nightSoft2,
            existingTemplates: [nightSoft1],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isTrue);
        // Validation only returns conflict details when a blocker prevents the
        // write. Informational soft/soft overlaps remain valid and are surfaced
        // by RoutineConflictEngine in the Routine UI.
        expect(result.conflicts, isEmpty);
      });
    },
  );
}
