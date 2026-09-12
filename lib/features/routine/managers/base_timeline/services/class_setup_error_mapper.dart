import 'dart:async';
import 'package:optivus/repositories/routine_transaction_repository.dart';

/// Maps raw exceptions and debug diagnostics into safe, user-friendly messages.
///
/// Ensures backend terminology, stack traces, and internal debug dumps
/// never leak to the user interface.
class ClassSetupErrorMapper {
  const ClassSetupErrorMapper._();

  /// Maps save and transaction errors to actionable user-facing messages.
  static String mapSaveError(Object error) {
    if (error is BaseTimelineConcurrencyException) {
      return 'Your Classes setup changed while you were editing.\n'
          'Reload the latest setup before saving again.';
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('stale') ||
        errStr.contains('revision') ||
        errStr.contains('conflict') ||
        errStr.contains('concurrency')) {
      return 'Your Classes setup changed while you were editing.\n'
          'Reload the latest setup before saving again.';
    }

    if (errStr.contains('unauthenticated') ||
        errStr.contains('session') ||
        errStr.contains('permission-denied') ||
        errStr.contains('auth')) {
      return 'Your session changed. Sign in again before saving.';
    }

    if (error is TimeoutException || errStr.contains('timeout')) {
      return 'Failed to save timetable.\n'
          'Saving timed out. Your current setup is still active. Please retry.';
    }

    if (errStr.contains('network') ||
        errStr.contains('unavailable') ||
        errStr.contains('offline') ||
        errStr.contains('connection')) {
      return 'Failed to save timetable.\n'
          'Your current setup is still active. Please retry.';
    }

    return 'Failed to save timetable.\n'
        'Your current setup is still active. Please try again.';
  }

  /// Maps photo selection, permission, and cloud storage upload errors into user-facing messages.
  static String mapUploadError(Object error) {
    final errStr = error.toString().toLowerCase();

    if (errStr.contains('permission') ||
        errStr.contains('denied') ||
        errStr.contains('access') ||
        errStr.contains('camera_access') ||
        errStr.contains('photo_access')) {
      return 'Camera or photo access was denied.\n'
          'Please allow access in your device Settings and try again.';
    }

    if (errStr.contains('network') ||
        errStr.contains('connection') ||
        errStr.contains('offline') ||
        errStr.contains('r2') ||
        errStr.contains('upload') ||
        errStr.contains('timeout')) {
      return "We couldn't upload this timetable photo.\n\n"
          'Check your connection and try again.';
    }

    if (errStr.contains('format') ||
        errStr.contains('corrupt') ||
        errStr.contains('decode') ||
        errStr.contains('image')) {
      return "We couldn't read this photo.\n"
          'Please choose a different photo or format.';
    }

    return "We couldn't upload this timetable photo.\n\n"
        'Check your connection and try again.';
  }

  /// Maps AI timetable extraction errors or warnings into user-safe explanations.
  static String mapAiExtractionError(Object? error, {List<String>? warnings}) {
    if (warnings != null && warnings.isNotEmpty) {
      final firstWarn = warnings.first.trim().toLowerCase();
      // Strictly prevent internal worker terminology, fallback model notices,
      // candidate validation messages, JSON fragments, and developer codes from leaking.
      final isInternal =
          firstWarn.contains('{') ||
          firstWarn.contains('code:') ||
          firstWarn.contains('worker') ||
          firstWarn.contains('snippet') ||
          firstWarn.contains('fallback') ||
          firstWarn.contains('model') ||
          firstWarn.contains('repair') ||
          firstWarn.contains('candidate') ||
          firstWarn.contains('validation') ||
          firstWarn.contains('json') ||
          firstWarn.contains('schema') ||
          firstWarn.contains('internal') ||
          firstWarn.contains('parse');

      if (!isInternal && firstWarn.length > 5 && firstWarn.length < 100) {
        return warnings.first.trim();
      }

      return "We couldn't read enough classes from this timetable.\n\n"
          'Try a clearer photo with the full timetable visible.';
    }

    if (error == null) {
      return "We couldn't read enough classes from this timetable.\n\n"
          'Try a clearer photo with the full timetable visible.';
    }

    if (error is TimeoutException) {
      return 'Timetable analysis timed out.\n'
          'Try a clearer photo or add classes manually.';
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('timeout')) {
      return 'Timetable analysis timed out.\n'
          'Try a clearer photo or add classes manually.';
    }

    if (errStr.contains('unauthenticated') || errStr.contains('session')) {
      return 'Your session expired. Please sign in again before extracting.';
    }

    if (errStr.contains('network') ||
        errStr.contains('offline') ||
        errStr.contains('unavailable')) {
      return 'The timetable service is temporarily unavailable. Please retry or add classes manually.';
    }

    return "We couldn't read enough classes from this timetable.\n\n"
        'Try a clearer photo with the full timetable visible.';
  }

  /// Sanitizes raw debug dropped-candidate strings for user presentation.
  ///
  /// Strips row/column dumps, JSON fragments, and developer codes.
  static List<String> sanitizeDroppedExamples(List<String> rawExamples) {
    final sanitized = <String>[];
    for (final raw in rawExamples) {
      final titleMatch = RegExp(r'title=([^ ]+)').firstMatch(raw);
      var title = titleMatch?.group(1);
      if (title == 'untitled' || title == null || title.isEmpty) {
        title = null;
      }

      if (raw.contains('droppedNoTitle')) {
        sanitized.add('Missing subject name for one entry');
      } else if (raw.contains('droppedNoRepeatDays')) {
        sanitized.add(
          title != null
              ? 'Couldn\'t determine the day for "$title"'
              : 'Couldn\'t determine the day for one timetable entry',
        );
      } else if (raw.contains('droppedInvalidTime') ||
          raw.contains('droppedNoFixedTime')) {
        sanitized.add(
          title != null
              ? 'Couldn\'t read the time for "$title"'
              : 'Couldn\'t read the time for one timetable entry',
        );
      } else if (raw.contains('droppedNonWork')) {
        sanitized.add(
          title != null
              ? 'Filtered non-class activity "$title"'
              : 'Filtered non-class entry',
        );
      } else {
        sanitized.add(
          title != null ? 'Needs review: "$title"' : 'One entry needs review',
        );
      }
    }
    return List<String>.unmodifiable(sanitized);
  }

  /// Formats user-facing dropped-items banner text.
  static String formatDroppedSummary(
    int droppedCount,
    List<String> sanitizedExamples,
  ) {
    if (droppedCount <= 0) return '';
    final exampleText = sanitizedExamples.isNotEmpty
        ? ' (${sanitizedExamples.first})'
        : '';
    final countLabel = droppedCount == 1
        ? '1 timetable entry was skipped'
        : '$droppedCount timetable entries were skipped';
    return '$countLabel$exampleText. Please verify your classes.';
  }
}
