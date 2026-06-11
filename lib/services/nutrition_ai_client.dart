import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/models/routine_import_review.dart';

final nutritionAiClientProvider = Provider<NutritionAiClient>((ref) {
  if (OptivusAiWorkersConfig.useWorker) {
    if (OptivusAiWorkersConfig.nutritionWorkerUrl.trim().isEmpty) {
      throw StateError('OPTIVUS_NUTRITION_WORKER_URL is missing. Please configure it.');
    }
    return WorkerNutritionAiClient();
  }
  return const FakeNutritionAiClient();
});

abstract class NutritionAiClient {
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  });
}

class FakeNutritionAiClient implements NutritionAiClient {
  const FakeNutritionAiClient();

  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    final start = (params['breakfastMinute'] as int?) ?? 480;
    final int mealsPerDay = params['mealsPerDay'] as int? ?? 3;
    final List<RoutineImportCandidateBlock> candidates = [];

    if (mealsPerDay >= 1) {
      candidates.add(RoutineImportCandidateBlock(
        id: 'ai_breakfast_gen',
        title: 'Breakfast',
        startMinute: start,
        endMinute: start + 30,
        hasFixedTime: true,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: 'soft_block',
        category: 'eating',
        hardBlock: false,
        selected: true,
        candidateType: RoutineImportCandidateType.block,
        confidenceScore: 0.90,
        confidenceLabel: 'high',
        extractionEngine: 'fake',
        extractionVersion: 'phase2d',
        needsManualReview: false,
        steps: const ['Oatmeal', 'Banana'],
        mealCategory: 'breakfast',
      ));
    }
    
    if (mealsPerDay >= 2) {
      candidates.add(RoutineImportCandidateBlock(
        id: 'ai_lunch_gen',
        title: 'Lunch',
        startMinute: (params['lunchMinute'] as int?) ?? 13 * 60,
        endMinute: ((params['lunchMinute'] as int?) ?? 13 * 60) + 45,
        hasFixedTime: true,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: 'soft_block',
        category: 'eating',
        hardBlock: false,
        selected: true,
        candidateType: RoutineImportCandidateType.block,
        confidenceScore: 0.90,
        confidenceLabel: 'high',
        extractionEngine: 'fake',
        extractionVersion: 'phase2d',
        needsManualReview: false,
        steps: const ['Rice', 'Dal'],
        mealCategory: 'lunch',
      ));
    }

    if (mealsPerDay >= 4) {
      candidates.add(RoutineImportCandidateBlock(
        id: 'ai_snack_gen',
        title: 'Snack',
        startMinute: (params['snackMinute'] as int?) ?? 17 * 60,
        endMinute: ((params['snackMinute'] as int?) ?? 17 * 60) + 20,
        hasFixedTime: true,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: 'soft_block',
        category: 'eating',
        hardBlock: false,
        selected: true,
        candidateType: RoutineImportCandidateType.block,
        confidenceScore: 0.90,
        confidenceLabel: 'high',
        extractionEngine: 'fake',
        extractionVersion: 'phase2d',
        needsManualReview: false,
        steps: const ['Apple'],
        mealCategory: 'snack',
      ));
    }

    if (mealsPerDay >= 3) {
      candidates.add(RoutineImportCandidateBlock(
        id: 'ai_dinner_gen',
        title: 'Dinner',
        startMinute: (params['dinnerMinute'] as int?) ?? 20 * 60 + 30,
        endMinute: ((params['dinnerMinute'] as int?) ?? 20 * 60 + 30) + 45,
        hasFixedTime: true,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        blockType: 'soft_block',
        category: 'eating',
        hardBlock: false,
        selected: true,
        candidateType: RoutineImportCandidateType.block,
        confidenceScore: 0.90,
        confidenceLabel: 'high',
        extractionEngine: 'fake',
        extractionVersion: 'phase2d',
        needsManualReview: false,
        steps: const ['Roti', 'Curry'],
        mealCategory: 'dinner',
      ));
    }

    return RoutineImportExtractionResult(
      id: 'fake-gen',
      uid: uid,
      source: RoutineImportReviewSource.eating,
      engine: 'fake',
      engineVersion: 'phase2d',
      candidates: candidates,
      warnings: const ['Fake AI generation result. Review manually.'],
      createdAt: DateTime.now(),
    );
  }
}

class WorkerNutritionAiClient implements NutritionAiClient {
  final String baseUrl;
  final http.Client _client;

  WorkerNutritionAiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? OptivusAiWorkersConfig.nutritionWorkerUrl,
      _client = client ?? http.Client();

  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    if (baseUrl.trim().isEmpty) {
      return RoutineImportExtractionResult(
        id: 'worker-gen-missing-url',
        uid: uid,
        source: RoutineImportReviewSource.eating,
        engine: 'worker',
        engineVersion: 'phase2d',
        candidates: const [],
        warnings: const ['Nutrition AI worker is not configured.'],
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client.post(
        _workerUri('/v1/eating/generate-routine'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(params),
      );
      final body = _jsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RoutineImportExtractionResult(
          id: 'worker-gen-error',
          uid: uid,
          source: RoutineImportReviewSource.eating,
          engine: 'worker',
          engineVersion: 'phase2d',
          candidates: const [],
          warnings: [
            body['error'] as String? ?? 'provider_request_failed'
          ],
          createdAt: DateTime.now(),
        );
      }

      final candidatesList = body['candidates'] as List?;
      final List<RoutineImportCandidateBlock> candidates = [];
      if (candidatesList != null) {
        for (final raw in candidatesList) {
          if (raw is Map<String, dynamic>) {
            candidates.add(RoutineImportCandidateBlock.fromMap(raw));
          }
        }
      }

      return RoutineImportExtractionResult(
        id: body['id'] as String? ?? 'worker-gen',
        uid: uid,
        source: RoutineImportReviewSource.eating,
        engine: 'worker',
        engineVersion: 'phase2d',
        candidates: candidates,
        warnings: const [],
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return RoutineImportExtractionResult(
        id: 'worker-gen-exception',
        uid: uid,
        source: RoutineImportReviewSource.eating,
        engine: 'worker',
        engineVersion: 'phase2d',
        candidates: const [],
        warnings: const ['AI generation service is unavailable. Try again later.'],
        createdAt: DateTime.now(),
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


}
