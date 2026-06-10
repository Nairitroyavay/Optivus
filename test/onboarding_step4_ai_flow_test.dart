import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/models/routine_import_review.dart';

void main() {
  group('Onboarding Step 4 AI Flow Logic', () {
    test('onboarding4SourceFailureMessage returns strict upload error for 0 candidates', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: 'student',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const [],
      );

      expect(
        message,
        'AI could not read this timetable. Please upload a clearer image and try again.',
      );
    });

    test('onboarding4SourceFailureMessage returns strict upload error for 0 mapped candidates', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: 'student',
        rawCandidateCount: 5, // AI read something
        mappedBlockCount: 0, // but mapped nothing
        warnings: const [],
      );

      expect(
        message,
        'AI could not read this timetable. Please upload a clearer image and try again.',
      );
    });

    test('onboarding4SourceFailureMessage handles standard provider errors', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['provider_request_failed'],
      );

      expect(message, 'AI import failed. Please try again.');
    });

    test('onboarding4SourceFailureMessage surfaces missing worker url properly', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: 'student',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['worker is not configured'],
      );

      expect(message, 'Real AI is not configured. Missing routine import worker URL.');
    });

    test('onboarding4SourceFailureMessage handles quota exceeded', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['provider_quota_exceeded'],
      );

      expect(message, 'AI is busy right now. Please try again.');
    });

    test('onboarding4SourceFailureMessage handles missing student photo', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.classes,
        role: 'student',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['Upload a photo before running AI extraction.'],
      );

      expect(message, 'Please upload your class timetable.');
    });

    test('onboarding4SourceFailureMessage handles missing working photo', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['Upload a photo before running AI extraction.'],
      );

      expect(message, 'Please upload your work/job timetable.');
    });

    test('onboarding4SourceFailureMessage handles incomplete R2 upload', () {
      final message = onboarding4SourceFailureMessage(
        source: RoutineImportReviewSource.work,
        role: 'student_working',
        rawCandidateCount: 0,
        mappedBlockCount: 0,
        warnings: const ['Upload incomplete. Please upload again.'],
      );

      expect(message, 'Upload incomplete. Please upload again.');
    });
  });
}
