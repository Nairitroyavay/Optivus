import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/ai_workers_config.dart';

final skinCareAiClientProvider = Provider<SkinCareAiClient>((ref) {
  if (OptivusAiWorkersConfig.useWorker) {
    return WorkerSkinCareAiClient();
  }
  return const FakeSkinCareAiClient();
});

class SkinCareAiProductResult {
  final List<dynamic> products;
  final List<String> warnings;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  const SkinCareAiProductResult({
    required this.products,
    this.warnings = const [],
    this.errorMessage,
  });

  factory SkinCareAiProductResult.error(String msg) {
    return SkinCareAiProductResult(products: [], errorMessage: msg);
  }
}

class SkinCareAiRoutineResult {
  final List<dynamic> morningRoutine;
  final List<dynamic> nightRoutine;
  final List<dynamic> weeklyRoutine;
  final List<dynamic> timelineBlocks;
  final List<String> suggestedProducts;
  final List<String> warnings;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  const SkinCareAiRoutineResult({
    required this.morningRoutine,
    required this.nightRoutine,
    required this.weeklyRoutine,
    required this.timelineBlocks,
    this.suggestedProducts = const [],
    this.warnings = const [],
    this.errorMessage,
  });

  factory SkinCareAiRoutineResult.error(String msg) {
    return SkinCareAiRoutineResult(
      morningRoutine: [],
      nightRoutine: [],
      weeklyRoutine: [],
      timelineBlocks: [],
      suggestedProducts: [],
      errorMessage: msg,
    );
  }
}

abstract class SkinCareAiClient {
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  });

  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  });
}

class FakeSkinCareAiClient implements SkinCareAiClient {
  const FakeSkinCareAiClient();

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    if (productPhotos.length > 10) {
      return SkinCareAiProductResult.error(
        'Upload your main 10 products first. You can add more later.',
      );
    }
    return const SkinCareAiProductResult(
      products: [
        {
          "name": "Fake Cleanser",
          "brand": "Fake Brand",
          "category": "cleanser",
          "confidence": "high",
        },
      ],
      warnings: [],
    );
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    return const SkinCareAiRoutineResult(
      morningRoutine: ["Fake Cleanser", "Sunscreen"],
      nightRoutine: ["Fake Cleanser", "Moisturizer"],
      weeklyRoutine: [],
      timelineBlocks: [
        <String, dynamic>{
          "id": "skincare-1",
          "section": "skin_care",
          "title": "Morning skin care",
          "startMinute": 420,
          "endMinute": 435,
          "blockType": "soft_block",
          "repeatDays": <int>[1, 2, 3, 4, 5, 6, 7],
          "skincareProducts": <String>["Fake Cleanser", "Sunscreen"],
        },
        <String, dynamic>{
          "id": "skincare-2",
          "section": "skin_care",
          "title": "Night skin care",
          "startMinute": 1320,
          "endMinute": 1335,
          "blockType": "soft_block",
          "repeatDays": <int>[1, 2, 3, 4, 5, 6, 7],
          "skincareProducts": <String>["Fake Cleanser", "Moisturizer"],
        },
      ],
      suggestedProducts: ["Suggested Cleanser", "Suggested Moisturizer"],
      warnings: [],
    );
  }
}

class WorkerSkinCareAiClient implements SkinCareAiClient {
  final String baseUrl;
  final http.Client _client;

  WorkerSkinCareAiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? OptivusAiWorkersConfig.skinCareWorkerUrl,
      _client = client ?? http.Client();

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    if (productPhotos.length > 10) {
      return SkinCareAiProductResult.error(
        'Upload your main 10 products first. You can add more later.',
      );
    }
    if (baseUrl.trim().isEmpty) {
      return SkinCareAiProductResult.error('missing_worker_url');
    }

    try {
      final response = await _client.post(
        _workerUri('/v1/skin-care/products/analyze'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'productPhotos': productPhotos}),
      );
      final body = _jsonObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SkinCareAiProductResult.error(
          _friendlyErrorMessage(response.statusCode, body),
        );
      }

      final products = body['products'];
      final warnings = body['warnings'];

      return SkinCareAiProductResult(
        products: products is List ? products : [],
        warnings: warnings is List
            ? warnings.map((e) => e.toString()).toList()
            : [],
      );
    } catch (_) {
      return SkinCareAiProductResult.error(
        'AI skin care service is unavailable. Try again later.',
      );
    }
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    if (baseUrl.trim().isEmpty) {
      return SkinCareAiRoutineResult.error('missing_worker_url');
    }

    try {
      final response = await _client.post(
        _workerUri('/v1/skin-care/routine/generate'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(params),
      );
      final body = _jsonObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SkinCareAiRoutineResult.error(
          _friendlyErrorMessage(response.statusCode, body),
        );
      }

      final mR = body['morningRoutine'];
      final nR = body['nightRoutine'];
      final wR = body['weeklyRoutine'];
      final tB = body['timelineBlocks'];
      final sP = body['suggestedProducts'];
      final warnings = body['warnings'];

      return SkinCareAiRoutineResult(
        morningRoutine: mR is List ? mR : [],
        nightRoutine: nR is List ? nR : [],
        weeklyRoutine: wR is List ? wR : [],
        timelineBlocks: tB is List ? tB : [],
        suggestedProducts: sP is List
            ? sP.map((e) => e.toString()).toList()
            : [],
        warnings: warnings is List
            ? warnings.map((e) => e.toString()).toList()
            : [],
      );
    } catch (_) {
      return SkinCareAiRoutineResult.error(
        'AI skin care service is unavailable. Try again later.',
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

  String _friendlyErrorMessage(int statusCode, Map<String, dynamic> body) {
    final rawError = body['error'] as String?;

    if (statusCode == 503 ||
        statusCode == 429 ||
        rawError == 'provider_high_demand' ||
        rawError == 'provider_quota_exceeded' ||
        rawError == 'provider_request_failed') {
      return 'AI is busy right now. Try again in a moment.';
    }
    if (rawError == 'too_many_photos') {
      return 'Upload your main 10 products first. You can add more later.';
    }
    if (rawError == 'provider_invalid_response') {
      return 'AI response could not be safely read. Please try again.';
    }
    if (rawError == 'provider_empty_candidates' ||
        rawError == 'no_blocks_generated') {
      return 'AI could not read the product from the photo. Try a clearer image.';
    }
    if (rawError == 'unsupported_content_type') {
      return 'Photo format is not supported. Please upload JPEG, PNG, or WEBP.';
    }
    if (rawError == 'r2_image_missing') {
      return 'Uploaded photo could not be found. Please upload again.';
    }
    if (rawError?.startsWith('invalid_') == true &&
        rawError?.endsWith('_request') == true) {
      return 'The request was invalid. Please try again.';
    }
    if (rawError == 'payload_too_large') {
      return 'The uploaded image is too large (max 15MB).';
    }
    return 'AI service could not process this request.';
  }
}
