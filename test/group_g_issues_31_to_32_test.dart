import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/services/routine_validation_service.dart';
import 'package:optivus/features/routine/services/routine_conflict_engine.dart';
import 'package:optivus/features/routine/domain/routine_conflict.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/features/onboarding/steps/onboarding_class_setup_timeline.dart';
import 'package:optivus/models/onboarding_draft.dart';

void main() {
  group('Issue 31: Class timetable overlap detection with routine items', () {
    test(
      '1.1 Class block (strict hard) overlapping soft block triggers non-blocking timeOverlap conflict (isValid = true)',
      () {
        final existingClass = RoutineItem(
          id: 'class_1',
          title: 'Math 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final newLunch = RoutineItem(
          id: 'lunch_1',
          title: 'Lunch',
          startMinute: 9 * 60 + 30, // 9:30 - 10:30 (overlaps)
          endMinute: 10 * 60 + 30,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.eating,
        );

        final engineConflicts = RoutineConflictEngine.detect([
          existingClass,
          newLunch,
        ], DateTime(2026, 7, 27));

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: newLunch,
            existingTemplates: [existingClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27), // Monday (day 1)
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          engineConflicts.any(
            (c) =>
                c.type == RoutineConflictType.compatibleOverlap &&
                c.blocking &&
                c.canKeepBoth,
          ),
          isTrue,
        );
      },
    );

    test(
      '1.2 Two soft blocks overlapping trigger non-blocking timeOverlap conflict (validation valid)',
      () {
        final habit1 = RoutineItem(
          id: 'habit_1',
          title: 'Morning Reading',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.habit,
        );

        final habit2 = RoutineItem(
          id: 'habit_2',
          title: 'Podcast Listening',
          startMinute: 9 * 60 + 30,
          endMinute: 10 * 60 + 30,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.habit,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: habit2,
            existingTemplates: [habit1],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(
          result.isValid,
          isTrue,
          reason: 'timeOverlap between soft blocks is non-blocking',
        );
      },
    );

    test(
      '1.3 Overlap between two class blocks triggers unavailableTime blocking conflict',
      () {
        final class1 = RoutineItem(
          id: 'class_1',
          title: 'Physics 101',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final class2 = RoutineItem(
          id: 'class_2',
          title: 'Chemistry 101',
          startMinute: 10 * 60 + 30,
          endMinute: 11 * 60 + 30,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: class2,
            existingTemplates: [class1],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.conflicts.any(
            (c) => c.type == RoutineConflictType.unavailableTime && c.blocking,
          ),
          isTrue,
        );
      },
    );

    test(
      '1.4 Overlap between non-class hard blocks triggers hardBlockConflict',
      () {
        final hard1 = RoutineItem(
          id: 'hard_1',
          title: 'Fixed Appointment',
          startMinute: 14 * 60,
          endMinute: 15 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.fixed,
        );

        final hard2 = RoutineItem(
          id: 'hard_2',
          title: 'Fixed Meeting',
          startMinute: 14 * 60 + 30,
          endMinute: 15 * 60 + 30,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.fixed,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: hard2,
            existingTemplates: [hard1],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.conflicts.any(
            (c) =>
                c.type == RoutineConflictType.compatibleOverlap &&
                c.blocking &&
                c.canKeepBoth,
          ),
          isTrue,
        );
      },
    );

    test(
      '1.5 Contiguous start/end boundaries (e.g. 09:00-10:00 and 10:00-11:00) do NOT conflict',
      () {
        final class1 = RoutineItem(
          id: 'class_1',
          title: 'Math 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final nextClass = RoutineItem(
          id: 'class_2',
          title: 'Physics 101',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: nextClass,
            existingTemplates: [class1],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(
          result.isValid,
          isTrue,
          reason: 'Contiguous time boundaries touch but do not overlap',
        );
      },
    );

    test(
      '1.6 Partial start minute overlap (08:30-09:15 vs 09:00-10:00 class) triggers blocking conflict for two class blocks',
      () {
        final existingClass = RoutineItem(
          id: 'class_1',
          title: 'Math 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final earlyClass = RoutineItem(
          id: 'class_early',
          title: 'Early Physics',
          startMinute: 8 * 60 + 30,
          endMinute: 9 * 60 + 15,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: earlyClass,
            existingTemplates: [existingClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isFalse);
        expect(result.conflicts.any((c) => c.blocking), isTrue);
      },
    );

    test(
      '1.7 Partial end minute overlap (09:45-10:30 vs 09:00-10:00 class) triggers blocking conflict for two class blocks',
      () {
        final existingClass = RoutineItem(
          id: 'class_1',
          title: 'Math 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final lateClass = RoutineItem(
          id: 'class_late',
          title: 'Late Chemistry',
          startMinute: 9 * 60 + 45,
          endMinute: 10 * 60 + 30,
          repeatDays: const [1],
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: lateClass,
            existingTemplates: [existingClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isFalse);
        expect(result.conflicts.any((c) => c.blocking), isTrue);
      },
    );

    test(
      '1.8 Overlapping start/end minutes on DIFFERENT repeat days produce NO conflict',
      () {
        final monClass = RoutineItem(
          id: 'class_mon',
          title: 'Math 101',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [1], // Monday
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final tueRoutine = RoutineItem(
          id: 'routine_tue',
          title: 'Tuesday Habit',
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          repeatDays: const [2], // Tuesday
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.habit,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: tueRoutine,
            existingTemplates: [monClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 28), // Tuesday (day 2)
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(
          result.isValid,
          isTrue,
          reason: 'Different repeat days never overlap',
        );
      },
    );

    test(
      '1.9 Multi-day items conflict ONLY on shared repeat days for class blocks',
      () {
        final multiClass = RoutineItem(
          id: 'class_mwf',
          title: 'Lecture',
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          repeatDays: const [1, 3, 5], // Mon, Wed, Fri
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final multiClass2 = RoutineItem(
          id: 'class_wt',
          title: 'Lab Session',
          startMinute: 10 * 60 + 15,
          endMinute: 11 * 60,
          repeatDays: const [3, 4], // Wed, Thu
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        // Validation context evaluates across all repeatDays of candidate (Wed & Thu)
        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: multiClass2,
            existingTemplates: [multiClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 29), // Wednesday (day 3)
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(
          result.isValid,
          isFalse,
          reason: 'Conflicts on Wednesday (day 3)',
        );
      },
    );

    test(
      '1.10 Weekly class vs One-time class item triggers conflict on matching date',
      () {
        final weeklyClass = RoutineItem(
          id: 'class_mon',
          title: 'Weekly Lab',
          startMinute: 14 * 60,
          endMinute: 16 * 60,
          repeatDays: const [1], // Monday
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final oneTimeOnMon = RoutineItem(
          id: 'onetime_mon',
          title: 'Special Exam Session',
          startMinute: 15 * 60,
          endMinute: 15 * 60 + 30,
          repeatDays: const [],
          repeatRule: 'once',
          date: DateTime(2026, 7, 27), // Monday, July 27 2026
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.classBlock,
        );

        final resultMon = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: oneTimeOnMon,
            existingTemplates: [weeklyClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(
          resultMon.isValid,
          isFalse,
          reason: 'One-time class event on Monday overlaps with weekly class',
        );

        final oneTimeOnTue = oneTimeOnMon.copyWith(
          id: 'onetime_tue',
          date: DateTime(2026, 7, 28), // Tuesday
        );

        final resultTue = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: oneTimeOnTue,
            existingTemplates: [weeklyClass],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 28),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(
          resultTue.isValid,
          isTrue,
          reason:
              'One-time event on Tuesday does not overlap with Monday class',
        );
      },
    );

    test(
      '1.11 Overlap with Sleep category triggers sleepConflict blocking conflict for non-strict blocks',
      () {
        final sleepBlock = RoutineItem(
          id: 'sleep_item',
          title: 'Sleep',
          startMinute: 23 * 60,
          endMinute: 7 * 60,
          repeatDays: const [1, 2, 3, 4, 5, 6, 7],
          crossesMidnight: true,
          blockType: RoutineBlockType.hardBlock,
          category: RoutineCategory.sleep,
        );

        final lateNightHabit = RoutineItem(
          id: 'night_habit',
          title: 'Late Reading',
          startMinute: 23 * 60 + 30,
          endMinute: 24 * 60,
          repeatDays: const [1],
          blockType: RoutineBlockType.softBlock,
          category: RoutineCategory.habit,
        );

        final result = RoutineValidationService.validate(
          RoutineValidationContext(
            candidate: lateNightHabit,
            existingTemplates: [sleepBlock],
            occurrences: const [],
            evaluationDate: DateTime(2026, 7, 27),
            operation: RoutineValidationOperation.create,
            authenticatedOwnerUid: 'test_user',
          ),
        );

        expect(result.isValid, isFalse);
        expect(
          result.conflicts.any(
            (c) => c.type == RoutineConflictType.sleepConflict && c.blocking,
          ),
          isTrue,
        );
      },
    );
  });

  group('Issue 32: Exam schedule priority override during class onboarding import', () {
    test(
      '2.1 Exam block preserves regular class schedule templates intact',
      () {
        final candidates = <RoutineImportCandidateBlock>[
          RoutineImportCandidateBlock(
            id: 'c1',
            title: 'Physics 101',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 10 * 60,
            endMinute: 11 * 60,
            hasFixedTime: true,
            repeatDays: const [1, 3], // Mon, Wed
          ),
          RoutineImportCandidateBlock(
            id: 'c2',
            title: 'Physics Final Exam',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 10 * 60 + 30, // Overlaps on Wed
            endMinute: 12 * 60,
            hasFixedTime: true,
            repeatDays: const [3], // Wed
          ),
        ];

        final mapped = mapOnboarding4Candidates(
          candidates: candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        expect(mapped.blocks.length, equals(2));

        final physicsClass = mapped.blocks.firstWhere((b) => b.id == 'c1');
        expect(
          physicsClass.repeatDays,
          equals([1, 3]),
          reason: 'Regular class repeatDays are preserved intact',
        );

        final physicsExam = mapped.blocks.firstWhere((b) => b.id == 'c2');
        expect(
          physicsExam.repeatDays,
          equals([3]),
          reason: 'Exam retains Wed (day 3)',
        );
      },
    );

    test('2.2 Exam preserves regular class when all repeat days overlap', () {
      final candidates = <RoutineImportCandidateBlock>[
        RoutineImportCandidateBlock(
          id: 'c1',
          title: 'Math 101',
          category: 'classes',
          blockType: 'hard',
          hardBlock: true,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          hasFixedTime: true,
          repeatDays: const [1], // Mon
        ),
        RoutineImportCandidateBlock(
          id: 'c2',
          title: 'Math Midterm Exam',
          category: 'classes',
          blockType: 'hard',
          hardBlock: true,
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          hasFixedTime: true,
          repeatDays: const [1], // Mon
        ),
      ];

      final mapped = mapOnboarding4Candidates(
        candidates: candidates,
        config: ScheduleSetupConfig.classSetup,
      );

      expect(
        mapped.blocks.length,
        equals(2),
        reason: 'Both regular class and exam are kept intact',
      );
      expect(mapped.blocks.any((b) => b.id == 'c1'), isTrue);
      expect(mapped.blocks.any((b) => b.id == 'c2'), isTrue);
    });

    test(
      '2.3 Exam title detection is case-insensitive ("exam", "EXAM", "Physics Exam")',
      () {
        final candidates = <RoutineImportCandidateBlock>[
          RoutineImportCandidateBlock(
            id: 'c1',
            title: 'Chemistry 101',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 14 * 60,
            endMinute: 15 * 60,
            hasFixedTime: true,
            repeatDays: const [2], // Tue
          ),
          RoutineImportCandidateBlock(
            id: 'c2',
            title: 'CHEMISTRY FINAL EXAM',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 14 * 60,
            endMinute: 16 * 60,
            hasFixedTime: true,
            repeatDays: const [2], // Tue
          ),
        ];

        final mapped = mapOnboarding4Candidates(
          candidates: candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        expect(mapped.blocks.length, equals(2));
        expect(isExamCandidateTitle('CHEMISTRY FINAL EXAM'), isTrue);
      },
    );

    test(
      '2.4 Non-overlapping exam and regular class on same day preserve both blocks intact',
      () {
        final candidates = <RoutineImportCandidateBlock>[
          RoutineImportCandidateBlock(
            id: 'c1',
            title: 'Bio 101',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            hasFixedTime: true,
            repeatDays: const [1], // Mon
          ),
          RoutineImportCandidateBlock(
            id: 'c2',
            title: 'History Exam',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 14 * 60,
            endMinute: 16 * 60,
            hasFixedTime: true,
            repeatDays: const [1], // Mon
          ),
        ];

        final mapped = mapOnboarding4Candidates(
          candidates: candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        expect(mapped.blocks.length, equals(2));
        expect(
          mapped.blocks.firstWhere((b) => b.id == 'c1').repeatDays,
          equals([1]),
        );
        expect(
          mapped.blocks.firstWhere((b) => b.id == 'c2').repeatDays,
          equals([1]),
        );
      },
    );

    test(
      '2.5 Contiguous start/end times between class and exam preserve both blocks intact',
      () {
        final candidates = <RoutineImportCandidateBlock>[
          RoutineImportCandidateBlock(
            id: 'c1',
            title: 'CS 101 Class',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 9 * 60,
            endMinute: 10 * 60, // Ends at 10:00
            hasFixedTime: true,
            repeatDays: const [1],
          ),
          RoutineImportCandidateBlock(
            id: 'c2',
            title: 'CS 101 Exam',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 10 * 60, // Starts at 10:00
            endMinute: 12 * 60,
            hasFixedTime: true,
            repeatDays: const [1],
          ),
        ];

        final mapped = mapOnboarding4Candidates(
          candidates: candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        expect(mapped.blocks.length, equals(2));
        expect(
          mapped.blocks.firstWhere((b) => b.id == 'c1').repeatDays,
          equals([1]),
        );
        expect(
          mapped.blocks.firstWhere((b) => b.id == 'c2').repeatDays,
          equals([1]),
        );
      },
    );

    test('2.6 Multiple overlapping exams preserve all exam blocks intact', () {
      final candidates = <RoutineImportCandidateBlock>[
        RoutineImportCandidateBlock(
          id: 'e1',
          title: 'Physics Exam',
          category: 'classes',
          blockType: 'hard',
          hardBlock: true,
          startMinute: 10 * 60,
          endMinute: 12 * 60,
          hasFixedTime: true,
          repeatDays: const [1],
        ),
        RoutineImportCandidateBlock(
          id: 'e2',
          title: 'Math Exam',
          category: 'classes',
          blockType: 'hard',
          hardBlock: true,
          startMinute: 11 * 60,
          endMinute: 13 * 60,
          hasFixedTime: true,
          repeatDays: const [1],
        ),
      ];

      final mapped = mapOnboarding4Candidates(
        candidates: candidates,
        config: ScheduleSetupConfig.classSetup,
      );

      expect(mapped.blocks.length, equals(2));
      expect(mapped.blocks.any((b) => b.id == 'e1'), isTrue);
      expect(mapped.blocks.any((b) => b.id == 'e2'), isTrue);
    });

    test(
      '2.7 Candidate mapping filters invalid candidates and preserves valid class templates',
      () {
        final candidates = <RoutineImportCandidateBlock>[
          RoutineImportCandidateBlock(
            id: 'invalid_title',
            title: '   ',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: const [1],
          ),
          RoutineImportCandidateBlock(
            id: 'invalid_time',
            title: 'Broken Class',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 10 * 60,
            endMinute: 9 * 60, // end < start
            repeatDays: const [1],
          ),
          RoutineImportCandidateBlock(
            id: 'valid_class',
            title: 'Economics 101',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            repeatDays: const [1, 2],
          ),
          RoutineImportCandidateBlock(
            id: 'valid_exam',
            title: 'Economics Exam',
            category: 'classes',
            blockType: 'hard',
            hardBlock: true,
            startMinute: 9 * 60,
            endMinute: 11 * 60,
            repeatDays: const [1], // Overlaps on Mon (day 1)
          ),
        ];

        final mapped = mapOnboarding4Candidates(
          candidates: candidates,
          config: ScheduleSetupConfig.classSetup,
        );

        expect(mapped.droppedNoTitle, equals(1));
        expect(mapped.droppedInvalidTime, equals(1));
        expect(mapped.blocks.length, equals(2));

        final econClass = mapped.blocks.firstWhere(
          (b) => b.id == 'valid_class',
        );
        expect(
          econClass.repeatDays,
          equals([1, 2]),
          reason: 'Economics 101 repeatDays are preserved intact',
        );
      },
    );

    test(
      '2.8 Expanded exam keyword matching recognizes exam, midterm, final, quiz, test, and assessment',
      () {
        expect(isExamCandidateTitle('Math Midterm'), isTrue);
        expect(isExamCandidateTitle('Physics Final'), isTrue);
        expect(isExamCandidateTitle('Bio Quiz 1'), isTrue);
        expect(isExamCandidateTitle('CS Unit Test'), isTrue);
        expect(isExamCandidateTitle('Psychology Assessment'), isTrue);
        expect(isExamCandidateTitle('Organic Chem Exam'), isTrue);
        expect(isExamCandidateTitle('Regular Lecture'), isFalse);
      },
    );
  });

  group('Onboarding Draft Restoration & Step 6 Persistence Integration', () {
    test(
      '3.1 Step 6 fixed schedule validation enforces invariants on sleep, bath, and custom blocks',
      () {
        final baseDraft = const OnboardingDraft().copyWith(
          baseTimeline: const BaseTimelineDraft().withRequiredFixedBlocks(),
        );

        // Invalid sleep (startMinute == endMinute)
        final sleepSameTime = baseDraft.baseTimeline.blocks.map((b) {
          if (b.id == BaseTimelineDraft.fixedSleepId) {
            return b.copyWith(startMinute: 600, endMinute: 600);
          }
          return b;
        }).toList();
        final draft1 = baseDraft.copyWith(
          baseTimeline: baseDraft.baseTimeline.copyWith(blocks: sleepSameTime),
        );
        expect(
          draft1.validateStep(6, []),
          equals('Sleep and wake time cannot be the same.'),
        );

        // Invalid bath (endMinute < startMinute)
        final bathInvalidTime = baseDraft.baseTimeline.blocks.map((b) {
          if (b.id == BaseTimelineDraft.fixedBathId) {
            return b.copyWith(startMinute: 500, endMinute: 400);
          }
          return b;
        }).toList();
        final draft2 = baseDraft.copyWith(
          baseTimeline: baseDraft.baseTimeline.copyWith(
            blocks: bathInvalidTime,
          ),
        );
        expect(
          draft2.validateStep(6, []),
          equals('Bath end time must be after bath start time.'),
        );
      },
    );
  });
}
