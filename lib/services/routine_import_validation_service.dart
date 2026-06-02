import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineImportCandidateValidation {
  final String candidateId;
  final List<String> issues;
  final List<String> warnings;

  const RoutineImportCandidateValidation({
    required this.candidateId,
    this.issues = const [],
    this.warnings = const [],
  });

  bool get hasBlockingIssues => issues.isNotEmpty;
}

class RoutineImportValidationResult {
  final List<RoutineImportCandidateValidation> candidateResults;

  const RoutineImportValidationResult({required this.candidateResults});

  bool get hasBlockingIssues {
    return candidateResults.any((result) => result.hasBlockingIssues);
  }

  bool hasBlockingIssuesFor(String candidateId) {
    return issuesFor(candidateId).isNotEmpty;
  }

  List<String> issuesFor(String candidateId) {
    return _resultFor(candidateId)?.issues ?? const [];
  }

  List<String> warningsFor(String candidateId) {
    return _resultFor(candidateId)?.warnings ?? const [];
  }

  List<String> messagesFor(String candidateId) {
    return [...issuesFor(candidateId), ...warningsFor(candidateId)];
  }

  RoutineImportCandidateValidation? _resultFor(String candidateId) {
    for (final result in candidateResults) {
      if (result.candidateId == candidateId) return result;
    }
    return null;
  }
}

class RoutineImportValidationService {
  const RoutineImportValidationService();

  RoutineImportValidationResult validateCandidates({
    required List<RoutineImportCandidateBlock> candidates,
    List<RoutineItem> existingRoutineItems = const [],
  }) {
    final duplicateIds = _duplicates(candidates.map((item) => item.id));
    final duplicateSignatures = _duplicates(
      candidates.map(
        (item) =>
            '${item.title.trim().toLowerCase()}|${item.startMinute}|${item.endMinute}',
      ),
    );

    return RoutineImportValidationResult(
      candidateResults: [
        for (final candidate in candidates)
          _validateCandidate(
            candidate,
            existingRoutineItems: existingRoutineItems,
            duplicateIds: duplicateIds,
            duplicateSignatures: duplicateSignatures,
          ),
      ],
    );
  }

  RoutineImportCandidateValidation _validateCandidate(
    RoutineImportCandidateBlock candidate, {
    required List<RoutineItem> existingRoutineItems,
    required Set<String> duplicateIds,
    required Set<String> duplicateSignatures,
  }) {
    final issues = <String>[];
    final warnings = <String>[];
    final title = candidate.title.trim();

    if (title.isEmpty) issues.add('Title is required.');
    if (candidate.startMinute < 0 || candidate.startMinute >= 24 * 60) {
      issues.add('Start time is invalid.');
    }
    if (candidate.endMinute <= 0 || candidate.endMinute > 24 * 60) {
      issues.add('End time is invalid.');
    }
    if (candidate.startMinute >= candidate.endMinute) {
      issues.add('End time must be after start time.');
    }
    if (candidate.repeatDays.isEmpty) {
      issues.add('Choose at least one repeat day.');
    }
    if (duplicateIds.contains(candidate.id)) {
      issues.add('Duplicate candidate id.');
    }
    final signature =
        '${title.toLowerCase()}|${candidate.startMinute}|${candidate.endMinute}';
    if (title.isNotEmpty && duplicateSignatures.contains(signature)) {
      warnings.add('Possible duplicate title/time candidate.');
    }
    if (candidate.candidateType == RoutineImportCandidateType.unknown) {
      issues.add('Candidate type is unknown.');
    }
    if (candidate.confidenceLabel == 'low') {
      warnings.add('Low confidence. Review manually before saving.');
    }
    if (candidate.needsManualReview) {
      warnings.add('Needs manual review.');
    }
    if (_overlapsExisting(candidate, existingRoutineItems)) {
      warnings.add('Overlaps an existing routine item.');
    }

    return RoutineImportCandidateValidation(
      candidateId: candidate.id,
      issues: issues,
      warnings: warnings,
    );
  }

  bool _overlapsExisting(
    RoutineImportCandidateBlock candidate,
    List<RoutineItem> existingItems,
  ) {
    if (candidate.startMinute >= candidate.endMinute) return false;
    for (final item in existingItems) {
      if (!_sharesRepeatDay(candidate.repeatDays, item.repeatDays)) continue;
      if (candidate.startMinute < item.endMinute &&
          candidate.endMinute > item.startMinute) {
        return true;
      }
    }
    return false;
  }

  bool _sharesRepeatDay(List<int> first, List<int> second) {
    if (first.isEmpty || second.isEmpty) return false;
    final days = first.toSet();
    return second.any(days.contains);
  }

  Set<String> _duplicates(Iterable<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) duplicates.add(value);
    }
    return duplicates;
  }
}
