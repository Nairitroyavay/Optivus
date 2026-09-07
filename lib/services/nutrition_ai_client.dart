import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/models/routine_import_review.dart';

class MissingConfigException implements Exception {
  final String message;
  const MissingConfigException(this.message);

  @override
  String toString() => message;
}

class MissingConfigNutritionAiClient implements NutritionAiClient {
  final String warning;
  const MissingConfigNutritionAiClient([this.warning = 'missing_worker_url']);

  @override
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    return RoutineImportExtractionResult(
      id: 'missing-config',
      uid: uid,
      source: RoutineImportReviewSource.eating,
      engine: 'disabled',
      engineVersion: 'none',
      candidates: const [],
      warnings: [warning],
      createdAt: DateTime.now(),
    );
  }
}

enum NutritionAiClientMode { worker, disabled, missingConfig }

final nutritionAiClientModeProvider = Provider<NutritionAiClientMode>((ref) {
  if (OptivusAiWorkersConfig.mode == OptivusAiWorkerMode.disabled) {
    return NutritionAiClientMode.disabled;
  }
  if (OptivusAiWorkersConfig.nutritionWorkerUrl.trim().isEmpty) {
    return NutritionAiClientMode.missingConfig;
  }
  return NutritionAiClientMode.worker;
});

final nutritionAiClientProvider = Provider<NutritionAiClient>((ref) {
  final mode = ref.watch(nutritionAiClientModeProvider);
  switch (mode) {
    case NutritionAiClientMode.worker:
      return WorkerNutritionAiClient();
    case NutritionAiClientMode.disabled:
      return const MissingConfigNutritionAiClient('worker_disabled');
    case NutritionAiClientMode.missingConfig:
      return const MissingConfigNutritionAiClient('missing_worker_url');
  }
});

abstract class NutritionAiClient {
  Future<RoutineImportExtractionResult> generateEatingRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  });
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
        id: 'missing-config',
        uid: uid,
        source: RoutineImportReviewSource.eating,
        engine: 'worker',
        engineVersion: 'phase2d',
        candidates: const [],
        warnings: const ['missing_worker_url'],
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
        final errorCode = body['error'] as String? ?? 'provider_request_failed';
        final errorMessage = body['message'] as String?;
        return RoutineImportExtractionResult(
          id: 'worker-gen-error',
          uid: uid,
          source: RoutineImportReviewSource.eating,
          engine: 'worker',
          engineVersion: 'phase2d',
          candidates: const [],
          warnings: [
            errorCode,
            if (errorMessage != null &&
                errorMessage.trim().isNotEmpty &&
                errorMessage != errorCode)
              errorMessage.trim(),
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
        warnings: const [
          'AI generation service is unavailable. Try again later.',
        ],
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
