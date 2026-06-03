import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/routine_import_review_screen.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/routine_import_ai_review_update_service.dart';
import 'package:optivus/services/routine_import_validation_service.dart';
import 'package:optivus/state/routine_import_ai_state.dart';

void main() {
  test('AI config defaults to fake', () {
    expect(OptivusRoutineImportAiConfig.mode, OptivusRoutineImportAiMode.fake);
    expect(OptivusRoutineImportAiConfig.useWorker, isFalse);
  });

  test('Worker URL missing causes safe error in worker mode', () async {
    final result = await WorkerRoutineImportAiClient(
      baseUrl: '',
    ).extract(uid: 'uid-1', idToken: 'token', review: _review());

    expect(result.candidates, isEmpty);
    expect(
      result.warnings.single,
      'Routine import AI worker is not configured.',
    );
  });

  test('Fake AI client returns strict RoutineImportExtractionResult', () async {
    final result = await const FakeRoutineImportAiClient().extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(),
    );

    expect(result.id, isNotEmpty);
    expect(result.uid, 'uid-1');
    expect(result.source, RoutineImportReviewSource.classes);
    expect(result.engine, 'fake');
    expect(result.candidates, isNotEmpty);
    expect(
      result.candidates.first.candidateType,
      RoutineImportCandidateType.block,
    );
  });

  test('Disabled fake client returns engine disabled', () async {
    final result = await const FakeRoutineImportAiClient(
      disabled: true,
    ).extract(uid: 'uid-1', idToken: 'token', review: _review());

    expect(result.engine, 'disabled');
    expect(result.engineVersion, 'phase2d-disabled');
    expect(result.warnings, contains('AI provider is disabled.'));
    expect(result.candidates.single.extractionEngine, 'disabled');
  });

  test('Worker AI client parses valid JSON', () async {
    final client = WorkerRoutineImportAiClient(
      baseUrl: 'https://worker.test',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/routine-import/extract');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response(jsonEncode(_resultMap()), 200);
      }),
    );

    final result = await client.extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(),
    );

    expect(result.engine, 'fake');
    expect(result.candidates.single.id, 'ai_class_math');
  });

  test(
    'Worker disabled-style response with engine disabled parses safely',
    () async {
      final result = await _extractWorkerResult(
        _resultMap(
          engine: 'disabled',
          engineVersion: 'phase2d-disabled',
          candidateId: 'ai_disabled_manual_review',
          candidateTitle: 'Classes photo needs manual review',
          candidateType: 'flexibleTask',
          candidateExtractionEngine: 'disabled',
          warnings: const ['AI provider is disabled.'],
        ),
      );

      expect(result.engine, 'disabled');
      expect(result.engineVersion, 'phase2d-disabled');
      expect(result.warnings, ['AI provider is disabled.']);
      expect(result.candidates.single.extractionEngine, 'disabled');
    },
  );

  test('Worker AI client handles invalid JSON safely', () async {
    final client = WorkerRoutineImportAiClient(
      baseUrl: 'https://worker.test',
      client: MockClient((request) async => http.Response('not json', 200)),
    );

    final result = await client.extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(),
    );

    expect(result.candidates, isEmpty);
    expect(
      result.warnings,
      contains('AI extraction service returned invalid structured data.'),
    );
  });

  test('Flutter rejects Worker response with wrong uid', () async {
    final result = await _extractWorkerResult(_resultMap(uid: 'other-uid'));

    expect(result.candidates, isEmpty);
    expect(
      result.warnings,
      contains('AI extraction service returned invalid structured data.'),
    );
  });

  test('Flutter rejects Worker response with wrong source', () async {
    final result = await _extractWorkerResult(
      _resultMap(
        source: 'work',
        sourceR2Key: _keyForSource('classes'),
        candidateSourceR2Key: _keyForSource('classes'),
      ),
    );

    expect(result.candidates, isEmpty);
    expect(
      result.warnings,
      contains('AI extraction service returned invalid structured data.'),
    );
  });

  test('Flutter rejects Worker response with wrong sourceR2Key', () async {
    final result = await _extractWorkerResult(
      _resultMap(
        sourceR2Key: 'users/uid-1/onboarding/work_schedule/asset-1.jpg',
      ),
    );

    expect(result.candidates, isEmpty);
    expect(
      result.warnings,
      contains('AI extraction service returned invalid structured data.'),
    );
  });

  test('Flutter rejects candidate with mismatched sourceR2Key', () async {
    final result = await _extractWorkerResult(
      _resultMap(
        candidateSourceR2Key:
            'users/uid-1/onboarding/work_schedule/asset-1.jpg',
      ),
    );

    expect(result.candidates, isEmpty);
    expect(
      result.warnings,
      contains('AI extraction service returned invalid structured data.'),
    );
  });

  test('AI result candidates preserve sourceAssetId/sourceR2Key', () async {
    final result = await const FakeRoutineImportAiClient().extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(),
    );

    expect(result.candidates.first.sourceAssetId, 'asset-1');
    expect(result.candidates.first.sourceR2Key, contains('class_timetable'));
  });

  test('AI result never directly creates RoutineItem', () async {
    final result = await const FakeRoutineImportAiClient().extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(),
    );

    expect(result.toMap().containsKey('routineItems'), isFalse);
    expect(result.toMap().containsKey('appliedRoutineItemIds'), isFalse);
    expect(result.candidates.first, isNot(isA<RoutineItem>()));
  });

  test('Review updated with extraction metadata', () {
    final now = DateTime.utc(2026, 6, 2, 12);
    final result = RoutineImportExtractionResult.fromMap(_resultMap());
    final updated = const RoutineImportAiReviewUpdateService()
        .applySuccessfulExtraction(review: _review(), result: result, now: now);

    expect(updated.extractionEngine, 'fake');
    expect(updated.extractionVersion, 'phase2d');
    expect(updated.lastExtractedAt, now);
    expect(updated.extractionWarnings, ['Review manually.']);
    expect(updated.extractionAttemptCount, 1);
    expect(updated.status, RoutineImportReviewStatus.needsReview);
    expect(updated.candidateBlocks.single.sourceAssetId, 'asset-1');
  });

  test('Already applied review cannot run extraction', () {
    final error = routineImportAiPreflightError(
      review: _review(
        status: RoutineImportReviewStatus.accepted,
        appliedRoutineItemIds: const ['imported-review-candidate'],
      ),
      signedIn: true,
      emailVerified: true,
    );

    expect(error, 'Already applied reviews cannot run AI extraction.');
  });

  test('Missing uploadedAssetR2Key blocks extraction', () {
    final error = routineImportAiPreflightError(
      review: _review(clearUpload: true),
      signedIn: true,
      emailVerified: true,
    );

    expect(error, 'Upload a photo before running AI extraction.');
  });

  test('Duplicate review warnings are de-duplicated', () {
    final review = _review(
      warnings: const ['Review manually.'],
      extractionWarnings: const ['Review manually.'],
    );

    final messages = routineImportWarningSummaryMessages(
      review: review,
      validation: const RoutineImportValidationResult(candidateResults: []),
    );

    expect(messages, ['Review manually.']);
  });

  test('Attempt limit blocks extraction when extractionAttemptCount >= 5', () {
    final error = routineImportAiPreflightError(
      review: _review(extractionAttemptCount: 5),
      signedIn: true,
      emailVerified: true,
    );

    expect(error, "You've reached the extraction retry limit for this review.");
  });

  test('Cooldown blocks extraction when lastExtractedAt < 60 seconds', () {
    final now = DateTime.utc(2026, 6, 2, 12);
    final error = routineImportAiPreflightError(
      review: _review(
        lastExtractedAt: now.subtract(const Duration(seconds: 59)),
      ),
      signedIn: true,
      emailVerified: true,
      now: now,
    );

    expect(error, 'Please wait a moment before running extraction again.');
  });

  test('Candidate with unclear time becomes hasFixedTime=false', () async {
    final result = await const FakeRoutineImportAiClient().extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(source: RoutineImportReviewSource.skinCare),
    );

    expect(result.candidates.single.hasFixedTime, isFalse);
    expect(
      result.candidates.single.candidateType,
      RoutineImportCandidateType.checklistStep,
    );
  });

  test('Low confidence candidate is needsManualReview', () async {
    final result = await const FakeRoutineImportAiClient().extract(
      uid: 'uid-1',
      idToken: 'token',
      review: _review(source: RoutineImportReviewSource.skinCare),
    );

    expect(result.candidates.single.confidenceLabel, 'low');
    expect(result.candidates.single.needsManualReview, isTrue);
  });
}

Future<RoutineImportExtractionResult> _extractWorkerResult(
  Map<String, dynamic> body, {
  RoutineImportReviewDraft? review,
}) {
  final client = WorkerRoutineImportAiClient(
    baseUrl: 'https://worker.test',
    client: MockClient((request) async => http.Response(jsonEncode(body), 200)),
  );
  return client.extract(
    uid: 'uid-1',
    idToken: 'token',
    review: review ?? _review(),
  );
}

RoutineImportReviewDraft _review({
  RoutineImportReviewSource source = RoutineImportReviewSource.classes,
  RoutineImportReviewStatus status = RoutineImportReviewStatus.needsReview,
  List<String> appliedRoutineItemIds = const [],
  bool clearUpload = false,
  List<String> warnings = const [],
  List<String> extractionWarnings = const [],
  int extractionAttemptCount = 0,
  DateTime? lastExtractedAt,
}) {
  final sourceLabel = switch (source) {
    RoutineImportReviewSource.classes => 'Classes',
    RoutineImportReviewSource.work => 'Job / Work / Business',
    RoutineImportReviewSource.eating => 'Eating',
    RoutineImportReviewSource.skinCare => 'Skin Care',
  };
  final purpose = switch (source) {
    RoutineImportReviewSource.classes => 'class_timetable',
    RoutineImportReviewSource.work => 'work_schedule',
    RoutineImportReviewSource.eating => 'eating_menu',
    RoutineImportReviewSource.skinCare => 'skin_care',
  };
  return RoutineImportReviewDraft(
    id: 'onboarding_${source.name}_import_review',
    uid: 'uid-1',
    source: source,
    status: status,
    sourceLabel: sourceLabel,
    uploadedAssetId: clearUpload ? null : 'asset-1',
    uploadedAssetR2Key: clearUpload
        ? null
        : 'users/uid-1/onboarding/$purpose/asset-1.jpg',
    uploadedAssetStatus: clearUpload ? null : 'uploaded',
    candidateBlocks: const [],
    warnings: warnings,
    appliedRoutineItemIds: appliedRoutineItemIds,
    lastExtractedAt: lastExtractedAt,
    extractionWarnings: extractionWarnings,
    extractionAttemptCount: extractionAttemptCount,
    createdAt: DateTime.utc(2026, 6, 2),
    updatedAt: DateTime.utc(2026, 6, 2),
  );
}

Map<String, dynamic> _resultMap({
  String uid = 'uid-1',
  String source = 'classes',
  String engine = 'fake',
  String engineVersion = 'phase2d',
  String? sourceR2Key,
  String? sourceAssetId = 'asset-1',
  String? candidateSourceR2Key,
  String? candidateSourceAssetId,
  String candidateId = 'ai_class_math',
  String candidateTitle = 'Math class',
  String candidateType = 'block',
  String? candidateExtractionEngine,
  List<String> candidateValidationIssues = const [],
  List<String> warnings = const ['Review manually.'],
}) {
  final resolvedSourceR2Key = sourceR2Key ?? _keyForSource(source);
  return {
    'id': 'fake-onboarding_classes_import_review',
    'uid': uid,
    'source': source,
    'engine': engine,
    'engineVersion': engineVersion,
    'sourceAssetId': sourceAssetId,
    'sourceR2Key': resolvedSourceR2Key,
    'rawText': 'MON/WED/FRI 9:00 Math',
    'candidates': [
      {
        'id': candidateId,
        'title': candidateTitle,
        'candidateType': candidateType,
        'startMinute': 9 * 60,
        'endMinute': 10 * 60,
        'hasFixedTime': true,
        'repeatDays': [1, 3, 5],
        'blockType': TimelineBlockDraft.hardBlockKey,
        'category': RoutineCategory.classBlock.name,
        'hardBlock': true,
        'selected': true,
        'needsManualReview': true,
        'confidenceScore': 0.78,
        'confidenceLabel': 'medium',
        'validationIssues': candidateValidationIssues,
        'sourceAssetId': candidateSourceAssetId ?? sourceAssetId,
        'sourceR2Key': candidateSourceR2Key ?? resolvedSourceR2Key,
        'sourceTextSnippet': 'MON/WED/FRI 9:00 Math',
        'sourceRowLabel': 'Weekdays',
        'sourceColumnLabel': 'Time',
        'extractionEngine': candidateExtractionEngine ?? engine,
        'extractionVersion': engineVersion,
        'steps': [],
      },
    ],
    'warnings': warnings,
    'createdAt': DateTime.utc(2026, 6, 2, 12).toIso8601String(),
  };
}

String _keyForSource(String source) {
  final purpose = switch (source) {
    'work' => 'work_schedule',
    'eating' => 'eating_menu',
    'skinCare' => 'skin_care',
    _ => 'class_timetable',
  };
  return 'users/uid-1/onboarding/$purpose/asset-1.jpg';
}
