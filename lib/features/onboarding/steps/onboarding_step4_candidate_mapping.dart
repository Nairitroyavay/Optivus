import 'package:flutter/foundation.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_4_schedule_models.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';

class Onboarding4CandidateMappingResult {
  final List<ClassRoutineBlock> blocks;
  final int droppedNoTitle;
  final int droppedInvalidTime;
  final int droppedNoRepeatDays;
  final int droppedNonWork;
  final List<String> droppedExamples;

  const Onboarding4CandidateMappingResult({
    required this.blocks,
    required this.droppedNoTitle,
    required this.droppedInvalidTime,
    required this.droppedNoRepeatDays,
    required this.droppedNonWork,
    this.droppedExamples = const [],
  });

  int get droppedTotal =>
      droppedNoTitle +
      droppedInvalidTime +
      droppedNoRepeatDays +
      droppedNonWork;

  String get filterSummary {
    if (droppedTotal == 0) return 'none';
    return 'noTitle=$droppedNoTitle invalidTime=$droppedInvalidTime '
        'noRepeatDays=$droppedNoRepeatDays nonWork=$droppedNonWork';
  }

  String get droppedExampleText =>
      droppedExamples.isEmpty ? 'none' : droppedExamples.join(' || ');
}

@visibleForTesting
List<int> normalizeOnboarding4AiRepeatDays(List<int> days) {
  return days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
}

List<int> _dayNumbersFromText(String text) {
  final lower = text
      .toLowerCase()
      .replaceAll(RegExp(r'[–—]'), '-')
      .replaceAll(RegExp(r'[\(\)\[\]\{\},.:;_/]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final found = <int>{};
  if (RegExp(r'(^|[^a-z])weekdays?($|[^a-z])').hasMatch(lower)) {
    found.addAll(const [1, 2, 3, 4, 5]);
  }
  final aliases = <String, int>{
    'mon': 1,
    'monday': 1,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'wed': 3,
    'wednesday': 3,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'thursday': 4,
    'fri': 5,
    'friday': 5,
    'sat': 6,
    'saturday': 6,
    'sun': 7,
    'sunday': 7,
  };
  const dayToken =
      r'monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thur|thu|friday|fri|saturday|sat|sunday|sun';
  final rangePattern = RegExp(
    r'(^|[^a-z])(' +
        dayToken +
        r')\s*(?:-|to|through|thru)\s*(' +
        dayToken +
        r')(?=$|[^a-z])',
  );
  for (final match in rangePattern.allMatches(lower)) {
    final start = aliases[match.group(2)];
    final end = aliases[match.group(3)];
    if (start == null || end == null || end < start) continue;
    for (var day = start; day <= end; day += 1) {
      found.add(day);
    }
  }

  final tokenPattern = RegExp(r'(^|[^a-z])(' + dayToken + r')(?=$|[^a-z])');
  final matches = tokenPattern.allMatches(lower).toList(growable: false);
  for (final match in matches) {
    final day = aliases[match.group(2)];
    if (day != null) found.add(day);
  }

  return found.toList()..sort();
}

@visibleForTesting
List<int> repeatDaysForOnboarding4Candidate(
  RoutineImportCandidateBlock candidate,
) {
  final explicitDays = normalizeOnboarding4AiRepeatDays(candidate.repeatDays);
  if (explicitDays.isNotEmpty) return explicitDays;

  final derived = <int>{};
  for (final text in [
    candidate.sourceColumnLabel,
    candidate.sourceRowLabel,
    candidate.sourceTextSnippet,
  ]) {
    if (text == null || text.trim().isEmpty) continue;
    derived.addAll(_dayNumbersFromText(text));
  }
  return derived.toList()..sort();
}

@visibleForTesting
String? extractRoomLabelFromOnboarding4Candidate(
  RoutineImportCandidateBlock candidate,
) {
  final loc = candidate.location?.trim();
  if (loc != null && loc.isNotEmpty) {
    final upperLoc = loc.toUpperCase();
    if (!['AFL', 'DS', 'PS', 'STW', 'IND4'].contains(upperLoc)) {
      return loc;
    }
  }

  final roomRegExp = RegExp(
    r'\b(?:[A-Z]{1,3}\d{1,3}-[A-Z0-9-]+|Room\s*\d+[A-Z]?|Lab\s*\d+[A-Z]?|[A-Z]{1,3}-\d+)\b',
    caseSensitive: false,
  );

  for (final text in [
    candidate.sourceTextSnippet,
    candidate.sourceColumnLabel,
    candidate.sourceRowLabel,
  ]) {
    if (text == null || text.trim().isEmpty) continue;
    final match = roomRegExp.firstMatch(text);
    if (match != null) {
      return match.group(0);
    }
  }

  return loc?.isNotEmpty == true ? loc : null;
}

String _normalizedWorkCandidateText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _hasDisallowedWorkPhrase(String normalized) {
  return normalized.contains('rest day') ||
      normalized.contains('no work') ||
      normalized.contains('online course') ||
      normalized.contains('personal habit') ||
      normalized.contains('habit');
}

bool _hasDisallowedWorkToken(String normalized) {
  final tokens = normalized.split(' ').toSet();
  return tokens.contains('gym') ||
      tokens.contains('exercise') ||
      tokens.contains('workout') ||
      tokens.contains('study') ||
      tokens.contains('reading');
}

bool _hasDisallowedWorkText(String normalized) {
  if (normalized.isEmpty) return false;
  return _hasDisallowedWorkPhrase(normalized) ||
      _hasDisallowedWorkToken(normalized);
}

bool _hasAllowedWorkText(String normalized) {
  if (normalized.isEmpty) return false;
  return normalized.contains('office work') ||
      normalized == 'work' ||
      normalized.contains(' work') ||
      normalized.contains('work ') ||
      normalized.contains('shift') ||
      normalized.contains('client call') ||
      normalized.contains('meeting') ||
      normalized.contains('team sync') ||
      normalized.contains('team review') ||
      normalized.contains('weekly review') ||
      normalized.contains('project work') ||
      normalized.contains('training') ||
      normalized.contains('freelance') ||
      normalized.contains('business hours') ||
      normalized.contains('commute') ||
      normalized.contains('lunch break') ||
      normalized == 'break';
}

@visibleForTesting
bool isDisallowedOnboarding4WorkCandidate(
  RoutineImportCandidateBlock candidate,
) {
  final normalized = _normalizedWorkCandidateText(candidate.title);
  if (_hasDisallowedWorkText(normalized)) {
    return true;
  }
  if (_hasAllowedWorkText(normalized)) return false;
  final snippet = candidate.sourceTextSnippet;
  if (snippet == null || snippet.isEmpty) return false;
  final normalizedSnippet = _normalizedWorkCandidateText(snippet);
  if (_hasDisallowedWorkPhrase(normalizedSnippet)) return true;
  return _hasDisallowedWorkToken(normalizedSnippet);
}

@visibleForTesting
bool isExamCandidateTitle(String title) {
  final lower = title.toLowerCase();
  const keywords = ['exam', 'midterm', 'final', 'quiz', 'test', 'assessment'];
  return keywords.any((k) => lower.contains(k));
}

@visibleForTesting
String candidateDayDebugLabel(RoutineImportCandidateBlock candidate) {
  final title = candidate.title.trim().isEmpty
      ? 'untitled'
      : candidate.title.trim();
  final row = candidate.sourceRowLabel?.trim();
  final column = candidate.sourceColumnLabel?.trim();
  final snippet = candidate.sourceTextSnippet?.trim();
  final shortSnippet = snippet == null || snippet.isEmpty
      ? 'none'
      : (snippet.length > 80 ? '${snippet.substring(0, 80)}...' : snippet);
  return 'title=$title startMinute=${candidate.startMinute} '
      'endMinute=${candidate.endMinute} repeatDays=${candidate.repeatDays} '
      'row=${row?.isEmpty ?? true ? 'none' : row} '
      'column=${column?.isEmpty ?? true ? 'none' : column} '
      'snippet=$shortSnippet category=${candidate.category} '
      'blockType=${candidate.blockType} hasFixedTime=${candidate.hasFixedTime}';
}

Onboarding4CandidateMappingResult mapOnboarding4Candidates({
  required List<RoutineImportCandidateBlock> candidates,
  required ScheduleSetupConfig config,
}) {
  final blocks = <ClassRoutineBlock>[];
  var droppedNoTitle = 0;
  var droppedInvalidTime = 0;
  var droppedNoRepeatDays = 0;
  var droppedNonWork = 0;
  final droppedExamples = <String>[];

  void addExample(String reason, RoutineImportCandidateBlock candidate) {
    if (droppedExamples.length >= 5) return;
    droppedExamples.add('$reason ${candidateDayDebugLabel(candidate)}');
  }

  for (final candidate in candidates) {
    final title = candidate.title.trim();
    if (title.isEmpty) {
      droppedNoTitle++;
      addExample('droppedNoTitle', candidate);
      continue;
    }
    if (config.source == RoutineImportReviewSource.work &&
        isDisallowedOnboarding4WorkCandidate(candidate)) {
      droppedNonWork++;
      addExample('droppedNonWork', candidate);
      continue;
    }
    if (!candidate.hasFixedTime) {
      droppedInvalidTime++;
      addExample('droppedNoFixedTime', candidate);
      continue;
    }
    if (candidate.startMinute >= candidate.endMinute) {
      droppedInvalidTime++;
      addExample('droppedInvalidTime', candidate);
      continue;
    }
    final repeatDays = repeatDaysForOnboarding4Candidate(candidate);
    if (repeatDays.isEmpty) {
      droppedNoRepeatDays++;
      addExample('droppedNoRepeatDays', candidate);
      continue;
    }

    final isExam = isExamCandidateTitle(title);
    final effectiveCandidate = isExam
        ? candidate.copyWith(
            hardBlock: true,
            blockType: TimelineBlockDraft.hardBlockKey,
          )
        : candidate;

    blocks.add(
      ClassRoutineBlock(
        id: effectiveCandidate.id,
        subject: title,
        room:
            extractRoomLabelFromOnboarding4Candidate(effectiveCandidate) ?? '',
        professor: effectiveCandidate.professor ?? '',
        courseCode: effectiveCandidate.courseCode ?? '',
        classType: effectiveCandidate.classType ?? '',
        section: effectiveCandidate.sectionLabel ?? '',
        notes: effectiveCandidate.notes ?? '',
        startMinute: effectiveCandidate.startMinute.clamp(0, 24 * 60 - 1),
        endMinute: effectiveCandidate.endMinute.clamp(1, 24 * 60),
        repeatDays: repeatDays,
        icon: config.icon,
        color: config.colorCycle[blocks.length % config.colorCycle.length],
        hasTopTape: true,
        hasBottomTape: true,
      ),
    );
  }

  final resolvedBlocks = List<ClassRoutineBlock>.unmodifiable(blocks);

  return Onboarding4CandidateMappingResult(
    blocks: resolvedBlocks,
    droppedNoTitle: droppedNoTitle,
    droppedInvalidTime: droppedInvalidTime,
    droppedNoRepeatDays: droppedNoRepeatDays,
    droppedNonWork: droppedNonWork,
    droppedExamples: droppedExamples,
  );
}
