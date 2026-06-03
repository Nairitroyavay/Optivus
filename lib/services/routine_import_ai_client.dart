import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';

abstract class RoutineImportAiClient {
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  });
}

class FakeRoutineImportAiClient implements RoutineImportAiClient {
  final bool disabled;

  const FakeRoutineImportAiClient({this.disabled = false});

  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) async {
    if (_missingPhoto(review)) {
      return _fallbackResult(
        uid: uid,
        review: review,
        engine: disabled ? 'disabled' : 'fake',
        engineVersion: disabled ? 'phase2d-disabled' : 'phase2d',
        warning: 'Upload a photo before running AI extraction.',
      );
    }

    if (disabled) {
      return _fallbackResult(
        uid: uid,
        review: review,
        engine: 'disabled',
        engineVersion: 'phase2d-disabled',
        warning: 'AI provider is disabled.',
        candidates: [
          _manualReviewCandidate(
            uid: uid,
            review: review,
            engine: 'disabled',
            engineVersion: 'phase2d-disabled',
          ),
        ],
      );
    }

    return RoutineImportExtractionResult(
      id: 'fake-${review.id}',
      uid: uid,
      source: review.source,
      engine: 'fake',
      engineVersion: 'phase2d',
      sourceAssetId: review.uploadedAssetId,
      sourceR2Key: review.uploadedAssetR2Key,
      rawText: 'Fake AI extraction for ${review.sourceLabel}.',
      candidates: _fakeCandidates(review),
      warnings: const [
        'Fake AI extraction result. Review manually before saving.',
      ],
      createdAt: DateTime.now(),
    );
  }

  List<RoutineImportCandidateBlock> _fakeCandidates(
    RoutineImportReviewDraft review,
  ) {
    final sourceAssetId = review.uploadedAssetId;
    final sourceR2Key = review.uploadedAssetR2Key;
    RoutineImportCandidateBlock common(
      String id,
      String title,
      int start,
      int end,
      List<int> days,
      String blockType,
      String category,
      bool hardBlock,
      String snippet,
    ) {
      return RoutineImportCandidateBlock(
        id: id,
        title: title,
        startMinute: start,
        endMinute: end,
        hasFixedTime: true,
        repeatDays: days,
        blockType: blockType,
        category: category,
        hardBlock: hardBlock,
        selected: true,
        candidateType: RoutineImportCandidateType.block,
        confidenceScore: 0.78,
        confidenceLabel: 'medium',
        sourceAssetId: sourceAssetId,
        sourceR2Key: sourceR2Key,
        sourceTextSnippet: snippet,
        sourceImageIndex: 0,
        sourceRowLabel: days.length == 1 ? _dayLabel(days.first) : 'Weekdays',
        sourceColumnLabel: 'Time',
        extractionEngine: 'fake',
        extractionVersion: 'phase2d',
        needsManualReview: true,
        notes: 'Fake extraction candidate. Confirm details before saving.',
      );
    }

    return switch (review.source) {
      RoutineImportReviewSource.classes => [
        common(
          'ai_class_math',
          'Math class',
          9 * 60,
          10 * 60,
          const [1, 3, 5],
          TimelineBlockDraft.hardBlockKey,
          RoutineCategory.classBlock.name,
          true,
          'MON/WED/FRI 9:00 Math',
        ),
        _unclearCandidate(
          review: review,
          id: 'ai_class_unclear_period',
          title: 'Unclear class period',
          category: RoutineCategory.classBlock.name,
          snippet: 'Period 4 - Physics',
        ),
      ],
      RoutineImportReviewSource.work => [
        common(
          'ai_work_shift',
          'Work shift',
          9 * 60,
          17 * 60,
          const [1, 2, 3, 4, 5],
          TimelineBlockDraft.hardBlockKey,
          RoutineCategory.job.name,
          true,
          'Mon-Fri 9 AM - 5 PM shift',
        ),
      ],
      RoutineImportReviewSource.eating => [
        common(
          'ai_lunch_window',
          'Lunch',
          13 * 60,
          13 * 60 + 30,
          const [1, 2, 3, 4, 5, 6, 7],
          TimelineBlockDraft.softBlockKey,
          RoutineCategory.eating.name,
          false,
          'Lunch 1:00 PM',
        ).copyWith(mealCategory: 'Lunch', steps: const ['Rice', 'Dal']),
      ],
      RoutineImportReviewSource.skinCare => [
        _unclearCandidate(
          review: review,
          id: 'ai_skin_care_steps',
          title: 'Morning skin care routine',
          category: RoutineCategory.skinCare.name,
          snippet: 'Cleanser > Serum > Sunscreen',
          steps: const ['Cleanser', 'Serum', 'Sunscreen'],
        ).copyWith(
          candidateType: RoutineImportCandidateType.checklistStep,
          blockType: TimelineBlockDraft.flexibleTaskKey,
          hardBlock: false,
        ),
      ],
    };
  }
}

class WorkerRoutineImportAiClient implements RoutineImportAiClient {
  final String baseUrl;
  final http.Client _client;

  WorkerRoutineImportAiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? OptivusRoutineImportAiConfig.workerBaseUrl,
      _client = client ?? http.Client();

  @override
  Future<RoutineImportExtractionResult> extract({
    required String uid,
    required String idToken,
    required RoutineImportReviewDraft review,
  }) async {
    if (_missingPhoto(review)) {
      return _fallbackResult(
        uid: uid,
        review: review,
        engine: 'worker',
        engineVersion: 'phase2d',
        warning: 'Upload a photo before running AI extraction.',
      );
    }
    if (baseUrl.trim().isEmpty) {
      return _fallbackResult(
        uid: uid,
        review: review,
        engine: 'worker',
        engineVersion: 'phase2d',
        warning: 'Routine import AI worker is not configured.',
      );
    }

    try {
      final response = await _client.post(
        _workerUri('/v1/routine-import/extract'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'reviewId': review.id,
          'source': review.source.name,
          'uploadedAssetId': review.uploadedAssetId,
          'uploadedAssetR2Key': review.uploadedAssetR2Key,
          'uploadedAssetStatus': review.uploadedAssetStatus,
          'sourceLabel': review.sourceLabel,
        }),
      );
      final body = _jsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackResult(
          uid: uid,
          review: review,
          engine: 'worker',
          engineVersion: 'phase2d',
          warning:
              body['message'] as String? ??
              body['error'] as String? ??
              'AI extraction service could not process this photo.',
        );
      }

      final result = RoutineImportExtractionResult.fromMap(body);
      if (!_isValidResult(result, uid: uid, review: review, raw: body)) {
        return _fallbackResult(
          uid: uid,
          review: review,
          engine: 'worker',
          engineVersion: 'phase2d',
          warning: 'AI extraction service returned invalid structured data.',
        );
      }
      return result;
    } catch (_) {
      return _fallbackResult(
        uid: uid,
        review: review,
        engine: 'worker',
        engineVersion: 'phase2d',
        warning: 'AI extraction service is unavailable. Try again later.',
      );
    }
  }

  Uri _workerUri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      '${baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/$normalizedPath',
    );
  }

  Map<String, dynamic> _jsonObject(String source) {
    if (source.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return const {};
    } on FormatException {
      return const {};
    }
  }

  bool _isValidResult(
    RoutineImportExtractionResult result, {
    required String uid,
    required RoutineImportReviewDraft review,
    required Map<String, dynamic> raw,
  }) {
    if (_containsForbiddenField(raw)) return false;
    if (result.id.trim().isEmpty) return false;
    if (result.uid != uid) return false;
    if (result.source != review.source) return false;
    if (raw['source'] != review.source.name) return false;
    if (!_allowedResultEngines.contains(result.engine)) return false;
    if (!_matchesRequiredReference(
      result.sourceR2Key,
      review.uploadedAssetR2Key,
    )) {
      return false;
    }
    if (!_matchesRequiredReference(
      result.sourceAssetId,
      review.uploadedAssetId,
    )) {
      return false;
    }

    final rawCandidates = raw['candidates'];
    if (rawCandidates is! List) return false;
    if (rawCandidates.length != result.candidates.length) return false;

    for (var i = 0; i < result.candidates.length; i += 1) {
      final rawCandidate = rawCandidates[i];
      if (rawCandidate is! Map) return false;
      final candidate = result.candidates[i];
      if (!_isValidCandidate(candidate, rawCandidate, review)) return false;
    }
    return true;
  }

  bool _isValidCandidate(
    RoutineImportCandidateBlock candidate,
    Map<dynamic, dynamic> rawCandidate,
    RoutineImportReviewDraft review,
  ) {
    if (_containsForbiddenField(rawCandidate)) return false;
    if (candidate.id.trim().isEmpty) return false;
    if (candidate.title.trim().isEmpty && !_hasMissingTitleIssue(candidate)) {
      return false;
    }
    if (!_allowedCandidateTypeNames.contains(rawCandidate['candidateType'])) {
      return false;
    }
    if (candidate.extractionEngine.trim().isEmpty) return false;
    if (!_matchesOptionalReference(
      candidate.sourceR2Key,
      review.uploadedAssetR2Key,
    )) {
      return false;
    }
    if (!_matchesOptionalReference(
      candidate.sourceAssetId,
      review.uploadedAssetId,
    )) {
      return false;
    }
    return true;
  }

  bool _hasMissingTitleIssue(RoutineImportCandidateBlock candidate) {
    return candidate.validationIssues.any((issue) {
      final normalized = issue.toLowerCase();
      return normalized.contains('title') &&
          (normalized.contains('missing') || normalized.contains('required'));
    });
  }

  bool _matchesRequiredReference(String? value, String? expected) {
    if (expected == null || expected.trim().isEmpty) return value == null;
    return value == expected;
  }

  bool _matchesOptionalReference(String? value, String? expected) {
    if (value == null || value.trim().isEmpty) return true;
    return value == expected;
  }

  bool _containsForbiddenField(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_forbiddenWorkerFields.contains(key)) return true;
        if (_containsForbiddenField(entry.value)) return true;
      }
    }
    if (value is List) {
      return value.any(_containsForbiddenField);
    }
    return false;
  }
}

const Set<String> _allowedResultEngines = {
  'disabled',
  'fake',
  'aiVision',
  'aiText',
  'worker',
};

final Set<String> _allowedCandidateTypeNames = RoutineImportCandidateType.values
    .map((type) => type.name)
    .toSet();

const Set<String> _forbiddenWorkerFields = {
  'routineItems',
  'appliedRoutineItemIds',
  'imageBytes',
  'localPath',
  'localFilePath',
  'localPreviewPath',
};

final routineImportAiClientProvider = Provider<RoutineImportAiClient>((ref) {
  return switch (OptivusRoutineImportAiConfig.mode) {
    OptivusRoutineImportAiMode.disabled => const FakeRoutineImportAiClient(
      disabled: true,
    ),
    OptivusRoutineImportAiMode.worker => WorkerRoutineImportAiClient(),
    OptivusRoutineImportAiMode.fake => const FakeRoutineImportAiClient(),
  };
});

bool _missingPhoto(RoutineImportReviewDraft review) {
  return review.uploadedAssetR2Key?.trim().isEmpty ?? true;
}

RoutineImportExtractionResult _fallbackResult({
  required String uid,
  required RoutineImportReviewDraft review,
  required String engine,
  required String engineVersion,
  required String warning,
  List<RoutineImportCandidateBlock> candidates = const [],
}) {
  return RoutineImportExtractionResult(
    id: '$engine-${review.id}',
    uid: uid,
    source: review.source,
    engine: engine,
    engineVersion: engineVersion,
    sourceAssetId: review.uploadedAssetId,
    sourceR2Key: review.uploadedAssetR2Key,
    candidates: candidates,
    warnings: [warning],
    createdAt: DateTime.now(),
  );
}

RoutineImportCandidateBlock _manualReviewCandidate({
  required String uid,
  required RoutineImportReviewDraft review,
  required String engine,
  required String engineVersion,
}) {
  return _unclearCandidate(
    review: review,
    id: 'ai_disabled_manual_review',
    title: '${review.sourceLabel} photo needs manual review',
    category: _categoryName(review.source),
    snippet: 'AI provider is disabled.',
    engine: engine,
    engineVersion: engineVersion,
  );
}

RoutineImportCandidateBlock _unclearCandidate({
  required RoutineImportReviewDraft review,
  required String id,
  required String title,
  required String category,
  required String snippet,
  List<String> steps = const [],
  String engine = 'fake',
  String engineVersion = 'phase2d',
}) {
  return RoutineImportCandidateBlock(
    id: id,
    title: title,
    startMinute: 9 * 60,
    endMinute: 10 * 60,
    hasFixedTime: false,
    suggestedStartMinute: 9 * 60,
    suggestedEndMinute: 10 * 60,
    repeatDays: const [],
    blockType: TimelineBlockDraft.flexibleTaskKey,
    category: category,
    hardBlock: false,
    selected: false,
    candidateType: RoutineImportCandidateType.flexibleTask,
    confidenceScore: 0.28,
    confidenceLabel: 'low',
    validationIssues: const ['Unclear time in source image.'],
    sourceAssetId: review.uploadedAssetId,
    sourceR2Key: review.uploadedAssetR2Key,
    sourceTextSnippet: snippet,
    sourceImageIndex: 0,
    extractionEngine: engine,
    extractionVersion: engineVersion,
    needsManualReview: true,
    notes: 'Time was unclear. Assign a time if this should become routine.',
    steps: steps,
  );
}

String _categoryName(RoutineImportReviewSource source) {
  return switch (source) {
    RoutineImportReviewSource.classes => RoutineCategory.classBlock.name,
    RoutineImportReviewSource.work => RoutineCategory.job.name,
    RoutineImportReviewSource.eating => RoutineCategory.eating.name,
    RoutineImportReviewSource.skinCare => RoutineCategory.skinCare.name,
  };
}

String _dayLabel(int day) {
  return switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'Unknown day',
  };
}
