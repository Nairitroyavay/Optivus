import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optivus/config/routine_import_ai_config.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/services/routine_import_ai_client.dart';
import 'package:optivus/services/routine_import_ai_review_update_service.dart';
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

RoutineImportReviewDraft _review({
  RoutineImportReviewSource source = RoutineImportReviewSource.classes,
  RoutineImportReviewStatus status = RoutineImportReviewStatus.needsReview,
  List<String> appliedRoutineItemIds = const [],
  bool clearUpload = false,
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
    appliedRoutineItemIds: appliedRoutineItemIds,
    createdAt: DateTime.utc(2026, 6, 2),
    updatedAt: DateTime.utc(2026, 6, 2),
  );
}

Map<String, dynamic> _resultMap() {
  return {
    'id': 'fake-onboarding_classes_import_review',
    'uid': 'uid-1',
    'source': 'classes',
    'engine': 'fake',
    'engineVersion': 'phase2d',
    'sourceAssetId': 'asset-1',
    'sourceR2Key': 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
    'rawText': 'MON/WED/FRI 9:00 Math',
    'candidates': [
      {
        'id': 'ai_class_math',
        'title': 'Math class',
        'candidateType': 'block',
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
        'validationIssues': [],
        'sourceAssetId': 'asset-1',
        'sourceR2Key': 'users/uid-1/onboarding/class_timetable/asset-1.jpg',
        'sourceTextSnippet': 'MON/WED/FRI 9:00 Math',
        'sourceRowLabel': 'Weekdays',
        'sourceColumnLabel': 'Time',
        'extractionEngine': 'fake',
        'extractionVersion': 'phase2d',
        'steps': [],
      },
    ],
    'warnings': ['Review manually.'],
    'createdAt': DateTime.utc(2026, 6, 2, 12).toIso8601String(),
  };
}
