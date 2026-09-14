import 'dart:async';
import 'package:optivus/repositories/routine_transaction_repository.dart';

/// Maps raw exceptions and debug diagnostics into safe, user-friendly messages for Work setup.
class WorkSetupErrorMapper {
  const WorkSetupErrorMapper._();

  /// Product-safe copy for canonical Work setup load failures.
  static String mapLoadError(Object? error) {
    return "We couldn't load your Work setup.\n"
        'Check your connection and try again.';
  }

  /// Product-safe copy for post-commit Routine reconciliation failures.
  static String mapRefreshError(Object? error) {
    return "Routine couldn't refresh yet. Please try again.";
  }

  /// Maps save and transaction errors to actionable user-facing messages.
  static String mapSaveError(Object error) {
    if (error is BaseTimelineConcurrencyException) {
      return 'Your Work setup changed while you were editing.\n'
          'Reload the latest setup before saving again.';
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('stale') ||
        errStr.contains('revision') ||
        errStr.contains('conflict') ||
        errStr.contains('concurrency')) {
      return 'Your Work setup changed while you were editing.\n'
          'Reload the latest setup before saving again.';
    }

    if (errStr.contains('unauthenticated') ||
        errStr.contains('session') ||
        errStr.contains('permission-denied') ||
        errStr.contains('auth')) {
      return 'Your session changed. Sign in again before saving.';
    }

    if (error is TimeoutException || errStr.contains('timeout')) {
      return 'Failed to save work schedule.\n'
          'Saving timed out. Your current setup is still active. Please retry.';
    }

    if (errStr.contains('network') ||
        errStr.contains('unavailable') ||
        errStr.contains('offline') ||
        errStr.contains('connection')) {
      return 'Failed to save work schedule.\n'
          'Your current setup is still active. Please retry.';
    }

    return 'Failed to save work schedule.\n'
        'Your current setup is still active. Please try again.';
  }

  /// Maps removal errors to actionable user-facing messages.
  static String mapRemoveError(Object error) {
    if (error is BaseTimelineConcurrencyException) {
      return 'Your Work setup changed while you were editing.\n'
          'Reload the latest setup before trying again.';
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('stale') ||
        errStr.contains('revision') ||
        errStr.contains('conflict') ||
        errStr.contains('concurrency')) {
      return 'Your Work setup changed while you were editing.\n'
          'Reload the latest setup before trying again.';
    }

    if (errStr.contains('unauthenticated') ||
        errStr.contains('session') ||
        errStr.contains('permission-denied') ||
        errStr.contains('auth')) {
      return 'Your session changed. Sign in again before trying again.';
    }

    if (error is TimeoutException || errStr.contains('timeout')) {
      return 'Failed to remove work setup.\n'
          'Removal timed out. Your current setup is still active. Please retry.';
    }

    if (errStr.contains('network') ||
        errStr.contains('unavailable') ||
        errStr.contains('offline') ||
        errStr.contains('connection')) {
      return 'Failed to remove work setup.\n'
          'Your current setup is still active. Please retry.';
    }

    return 'Failed to remove work setup.\n'
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
      return "We couldn't upload this work schedule photo.\n\n"
          'Check your connection and try again.';
    }

    if (errStr.contains('format') ||
        errStr.contains('corrupt') ||
        errStr.contains('decode') ||
        errStr.contains('image')) {
      return "We couldn't read this photo.\n"
          'Please choose a different photo or format.';
    }

    return "We couldn't upload this work schedule photo.\n\n"
        'Check your connection and try again.';
  }

  /// Maps AI work schedule extraction errors or warnings into user-safe explanations.
  static String mapAiExtractionError(Object? error, {List<String>? warnings}) {
    if (warnings != null && warnings.isNotEmpty) {
      final firstWarn = warnings.first.trim().toLowerCase();
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

      return "We couldn't read enough work blocks from this schedule.\n\n"
          'Try a clearer photo or add blocks manually.';
    }

    if (error == null) {
      return "We couldn't read enough work blocks from this schedule.\n\n"
          'Try a clearer photo or add blocks manually.';
    }

    if (error is TimeoutException) {
      return 'Schedule analysis timed out.\n'
          'Try a clearer photo or add blocks manually.';
    }

    final errStr = error.toString().toLowerCase();

    if (errStr.contains('timeout')) {
      return 'Schedule analysis timed out.\n'
          'Try a clearer photo or add blocks manually.';
    }

    if (errStr.contains('unauthenticated') || errStr.contains('session')) {
      return 'Your session expired. Please sign in again before extracting.';
    }

    if (errStr.contains('network') ||
        errStr.contains('offline') ||
        errStr.contains('unavailable')) {
      return 'The schedule service is temporarily unavailable. Please retry or add blocks manually.';
    }

    return "We couldn't read enough work blocks from this schedule.\n\n"
        'Try a clearer photo or add blocks manually.';
  }

  /// Sanitizes raw debug dropped-candidate strings for user presentation.
  static List<String> sanitizeDroppedExamples(List<String> rawExamples) {
    final sanitized = <String>[];
    for (final raw in rawExamples) {
      final titleMatch = RegExp(r'title=([^ ]+)').firstMatch(raw);
      var title = titleMatch?.group(1);
      if (title == 'untitled' || title == null || title.isEmpty) {
        title = null;
      }

      if (raw.contains('droppedNoTitle')) {
        sanitized.add('Missing role or title for one entry');
      } else if (raw.contains('droppedNoRepeatDays')) {
        sanitized.add(
          title != null
              ? 'Couldn\'t determine the day for "$title"'
              : 'Couldn\'t determine the day for one schedule entry',
        );
      } else if (raw.contains('droppedInvalidTime') ||
          raw.contains('droppedNoFixedTime')) {
        sanitized.add(
          title != null
              ? 'Couldn\'t read the time for "$title"'
              : 'Couldn\'t read the time for one schedule entry',
        );
      } else if (raw.contains('droppedNonWork')) {
        sanitized.add(
          title != null
              ? 'Filtered non-work activity "$title"'
              : 'Filtered non-work entry',
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
        ? '1 schedule entry was skipped'
        : '$droppedCount schedule entries were skipped';
    return '$countLabel$exampleText. Please verify your work blocks.';
  }
}
