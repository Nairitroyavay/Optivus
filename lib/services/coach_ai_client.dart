import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/backend_config.dart';

final coachAiClientProvider = Provider<CoachAiClient>((ref) {
  if (OptivusAiWorkersConfig.useWorker) {
    return WorkerCoachAiClient();
  }
  if (ref.watch(fakeDataAllowedProvider)) {
    return const FakeCoachAiClient();
  }
  return const UnavailableCoachAiClient();
});

class CoachAiResult {
  final String reply;
  final List<dynamic> cards;
  final List<String> warnings;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  const CoachAiResult({
    required this.reply,
    this.cards = const [],
    this.warnings = const [],
    this.errorMessage,
  });

  factory CoachAiResult.error(String msg) {
    return CoachAiResult(reply: '', errorMessage: msg);
  }
}

abstract class CoachAiClient {
  Future<CoachAiResult> getReply({
    required String uid,
    required String idToken,
    required Map<String, dynamic> context,
  });
}

class UnavailableCoachAiClient implements CoachAiClient {
  const UnavailableCoachAiClient();

  @override
  Future<CoachAiResult> getReply({
    required String uid,
    required String idToken,
    required Map<String, dynamic> context,
  }) async {
    return CoachAiResult.error('Coach AI is not configured.');
  }
}

class FakeCoachAiClient implements CoachAiClient {
  const FakeCoachAiClient();

  @override
  Future<CoachAiResult> getReply({
    required String uid,
    required String idToken,
    required Map<String, dynamic> context,
  }) async {
    return const CoachAiResult(
      reply: "This is a fake AI coach reply. I'm here to support you!",
      cards: [],
      warnings: [],
    );
  }
}

class WorkerCoachAiClient implements CoachAiClient {
  final String baseUrl;
  final http.Client _client;

  WorkerCoachAiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? OptivusAiWorkersConfig.coachWorkerUrl,
      _client = client ?? http.Client();

  @override
  Future<CoachAiResult> getReply({
    required String uid,
    required String idToken,
    required Map<String, dynamic> context,
  }) async {
    if (baseUrl.trim().isEmpty) {
      return CoachAiResult.error('Coach AI worker is not configured.');
    }

    try {
      final response = await _client.post(
        _workerUri('/v1/coach/reply'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(context),
      );
      final body = _jsonObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return CoachAiResult.error(
          _friendlyErrorMessage(response.statusCode, body),
        );
      }

      final cards = body['cards'];
      final warnings = body['warnings'];

      return CoachAiResult(
        reply: body['reply'] as String? ?? "I'm here to help.",
        cards: cards is List ? cards : [],
        warnings: warnings is List
            ? warnings.map((e) => e.toString()).toList()
            : [],
      );
    } catch (_) {
      return CoachAiResult.error(
        'AI coach service is unavailable. Try again later.',
      );
    }
  }

  Uri _workerUri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(
      '${baseUrl.trim().replaceFirst(RegExp(r'/+\$'), '')}/$normalizedPath',
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
    if (rawError == 'provider_invalid_response') {
      return 'AI response could not be safely read. Please try again.';
    }
    if (rawError?.startsWith('invalid_') == true &&
        rawError?.endsWith('_request') == true) {
      return 'The request was invalid. Please try again.';
    }

    return 'AI coach service could not process this request.';
  }
}
