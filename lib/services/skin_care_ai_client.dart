import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/skin_care_product_draft.dart';

export 'package:optivus/models/skin_care_product_draft.dart';

final skinCareAiClientProvider = Provider<SkinCareAiClient>((ref) {
  if (OptivusAiWorkersConfig.useWorker &&
      OptivusAiWorkersConfig.skinCareWorkerUrl.trim().isNotEmpty) {
    return WorkerSkinCareAiClient();
  }
  if (OptivusAiWorkersConfig.mode == OptivusAiWorkerMode.fake &&
      OptivusAiWorkersConfig.allowFakeAiForTestsOnly &&
      ref.watch(fakeDataAllowedProvider)) {
    return const FakeSkinCareAiClient();
  }
  if (!OptivusAiWorkersConfig.useWorker) {
    return const UnavailableSkinCareAiClient('worker_mode_disabled');
  }
  return const UnavailableSkinCareAiClient('missing_worker_url');
});

class SkinCareAiProductResult {
  final List<dynamic> products;
  final List<String> warnings;
  final String? errorMessage;
  final String? errorCode;

  bool get hasError => errorMessage != null;
  List<SkinCareDetectedProduct> get detectedProducts => products
      .map(SkinCareDetectedProduct.fromValue)
      .where((product) => product.hasMeaningfulData)
      .toList(growable: false);

  const SkinCareAiProductResult({
    required this.products,
    this.warnings = const [],
    this.errorMessage,
    this.errorCode,
  });

  factory SkinCareAiProductResult.error(String msg, {String? errorCode}) {
    return SkinCareAiProductResult(
      products: [],
      errorMessage: msg,
      errorCode: errorCode ?? msg,
    );
  }
}

class SkinCareRoutinePlan {
  final String slotLabel;
  final String title;
  final List<String> steps;
  final List<String> productNames;
  final List<SkinCareMissingItem> missingItems;
  final List<String> warnings;
  final List<int> repeatDays;

  const SkinCareRoutinePlan({
    required this.slotLabel,
    required this.title,
    required this.steps,
    required this.productNames,
    this.missingItems = const [],
    this.warnings = const [],
    this.repeatDays = const [],
  });

  factory SkinCareRoutinePlan.fromMap(Map<String, dynamic> map) {
    final slotLabel = _stringValue(
      map['slotLabel'] ?? map['slot'] ?? map['timeOfDay'],
    ).toLowerCase().trim();
    final isNight = slotLabel == 'night' || slotLabel == 'evening';
    final rawSteps = _stringListFromValue(
      map['steps'] ?? map['orderedSteps'] ?? map['instructions'],
    );
    final rawProductNames = _stringListFromValue(
      map['productNames'] ?? map['products'] ?? map['skincareProducts'],
    );

    final seqRes = SkinCareStepSequenceValidator.validateAndReorder(
      rawSteps,
      isNight: isNight,
    );
    final parsedWarnings = _stringListFromValue(
      map['warnings'] ?? map['warningIfAny'],
    );
    final warnings = List<String>.from(parsedWarnings);
    if (seqRes.sequenceAdjustedWarning != null &&
        !warnings.contains(seqRes.sequenceAdjustedWarning)) {
      warnings.add(seqRes.sequenceAdjustedWarning!);
    }

    final contraindications =
        SkinCareContraindicationDetector.detectContraindications(
          slotLabel: slotLabel,
          productNamesOrSteps: [...rawProductNames, ...seqRes.steps],
        );
    for (final c in contraindications) {
      if (!warnings.contains(c.message)) {
        warnings.add(c.message);
      }
    }

    return SkinCareRoutinePlan(
      slotLabel: slotLabel,
      title: _stringValue(map['title'] ?? map['name']).trim(),
      steps: seqRes.steps,
      productNames: rawProductNames,
      missingItems: _missingItemsFromValue(
        map['missingItems'] ??
            map['missing_items'] ??
            map['missingProducts'] ??
            map['missing_products'],
      ),
      warnings: warnings,
      repeatDays: _repeatDaysFromValue(map['repeatDays'] ?? map['days']),
    );
  }

  Map<String, dynamic> toMap() => {
    'slotLabel': slotLabel,
    'title': title,
    'steps': steps,
    'productNames': productNames,
    'missingItems': missingItems.map((item) => item.toMap()).toList(),
    'warnings': warnings,
    'repeatDays': repeatDays,
  };
}

class SkinCareMissingItem {
  final String name;
  final String importance;
  final String reason;

  const SkinCareMissingItem({
    required this.name,
    this.importance = 'important',
    this.reason = '',
  });

  factory SkinCareMissingItem.fromValue(dynamic value) {
    if (value is Map) {
      return SkinCareMissingItem.fromMap(Map<String, dynamic>.from(value));
    }
    return SkinCareMissingItem(
      name: _stringValue(value).trim(),
      importance: 'important',
    );
  }

  factory SkinCareMissingItem.fromMap(Map<String, dynamic> map) {
    return SkinCareMissingItem(
      name: _stringValue(
        map['name'] ?? map['product'] ?? map['productName'] ?? map['category'],
      ).trim(),
      importance: _normalizeMissingItemImportance(
        map['importance'] ?? map['priority'],
      ),
      reason: _stringValue(map['reason'] ?? map['note'] ?? map['why']).trim(),
    );
  }

  String get displayLabel {
    final cleanName = name.trim();
    final cleanImportance = importance.trim();
    if (cleanName.isEmpty) return '';
    if (cleanImportance.isEmpty) return '$cleanName (missing)';
    return '$cleanName ($cleanImportance, missing)';
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'importance': importance,
    'reason': reason,
  };
}

enum SkinCareRoutineResultStatus {
  generated,
  accepted,
  modified,
  rejected,
  partial,
}

class SkinCareRejectionExplanation {
  final String ruleId;
  final List<String> products;
  final List<String> ingredients;
  final String severity; // 'info', 'warning', 'high', 'critical'
  final String reason;
  final String repairSuggestion;

  const SkinCareRejectionExplanation({
    required this.ruleId,
    this.products = const [],
    this.ingredients = const [],
    this.severity = 'warning',
    required this.reason,
    required this.repairSuggestion,
  });

  factory SkinCareRejectionExplanation.fromMap(Map<String, dynamic> map) {
    return SkinCareRejectionExplanation(
      ruleId:
          _stringValue(
            map['ruleId'] ?? map['rule_id'] ?? map['rule'],
          ).trim().isEmpty
          ? 'unknown_rule'
          : _stringValue(map['ruleId'] ?? map['rule_id'] ?? map['rule']).trim(),
      products: _stringListFromValue(map['products'] ?? map['productNames']),
      ingredients: _stringListFromValue(
        map['ingredients'] ?? map['activeIngredients'],
      ),
      severity: _stringValue(map['severity'] ?? map['level']).trim().isEmpty
          ? 'warning'
          : _stringValue(map['severity'] ?? map['level']).trim(),
      reason: _stringValue(
        map['reason'] ?? map['explanation'] ?? map['message'],
      ).trim(),
      repairSuggestion: _stringValue(
        map['repairSuggestion'] ??
            map['suggestion'] ??
            map['fix'] ??
            map['repair'],
      ).trim(),
    );
  }

  Map<String, dynamic> toMap() => {
    'ruleId': ruleId,
    'products': products,
    'ingredients': ingredients,
    'severity': severity,
    'reason': reason,
    'repairSuggestion': repairSuggestion,
  };
}

const String skinCareCosmeticGuidanceDisclaimer =
    'Cosmetic guidance only. This AI routine provides general skin-care suggestions and does not constitute medical diagnosis, treatment, or clinical advice.';

const String skinCareIrritationEscalationGuidance =
    'If you experience severe redness, burning, peeling, or irritation, discontinue use immediately and consult a board-certified dermatologist.';

class SkinCareAiRoutineResult {
  final List<SkinCareRoutinePlan> routinePlans;
  final List<dynamic> morningRoutine;
  final List<dynamic> nightRoutine;
  final List<dynamic> weeklyRoutine;
  final List<dynamic> timelineBlocks;
  final List<SkinCareProductRecommendation> recommendedProducts;
  final List<String> suggestedProducts;
  final List<String> warnings;
  final List<String> rejectedPlanReasons;
  final List<SkinCareRejectionExplanation> rejectionExplanations;
  final String? errorMessage;
  final String? errorCode;

  final SkinCareRoutineResultStatus? _explicitResultStatus;
  final int? _explicitGeneratedCount;
  final int? _explicitAcceptedCount;
  final int? _explicitModifiedCount;
  final int? _explicitRejectedCount;
  final bool? _explicitIsPartial;

  bool get hasError => errorMessage != null || errorCode != null;

  const SkinCareAiRoutineResult({
    this.routinePlans = const [],
    required this.morningRoutine,
    required this.nightRoutine,
    required this.weeklyRoutine,
    required this.timelineBlocks,
    this.recommendedProducts = const [],
    this.suggestedProducts = const [],
    this.warnings = const [],
    this.rejectedPlanReasons = const [],
    this.rejectionExplanations = const [],
    this.errorMessage,
    this.errorCode,
    SkinCareRoutineResultStatus? resultStatus,
    int? generatedCount,
    int? acceptedCount,
    int? modifiedCount,
    int? rejectedCount,
    bool? isPartial,
  }) : _explicitResultStatus = resultStatus,
       _explicitGeneratedCount = generatedCount,
       _explicitAcceptedCount = acceptedCount,
       _explicitModifiedCount = modifiedCount,
       _explicitRejectedCount = rejectedCount,
       _explicitIsPartial = isPartial;

  int get generatedCount => _explicitGeneratedCount ?? routinePlans.length;
  int get acceptedCount => _explicitAcceptedCount ?? routinePlans.length;
  int get modifiedCount => _explicitModifiedCount ?? 0;
  int get rejectedCount => _explicitRejectedCount ?? rejectedPlanReasons.length;
  bool get isPartial =>
      _explicitIsPartial ??
      (acceptedCount < generatedCount ||
          rejectedPlanReasons.isNotEmpty ||
          rejectionExplanations.isNotEmpty);

  SkinCareRoutineResultStatus get resultStatus {
    if (_explicitResultStatus != null) return _explicitResultStatus;
    if (errorMessage != null || errorCode != null) {
      return SkinCareRoutineResultStatus.rejected;
    }
    if (isPartial) return SkinCareRoutineResultStatus.partial;
    if (modifiedCount > 0) return SkinCareRoutineResultStatus.modified;
    return SkinCareRoutineResultStatus.accepted;
  }

  factory SkinCareAiRoutineResult.error(String msg, {String? errorCode}) {
    return SkinCareAiRoutineResult(
      routinePlans: [],
      morningRoutine: [],
      nightRoutine: [],
      weeklyRoutine: [],
      timelineBlocks: [],
      recommendedProducts: [],
      suggestedProducts: [],
      rejectedPlanReasons: [],
      rejectionExplanations: [],
      errorMessage: msg,
      errorCode: errorCode,
      resultStatus: SkinCareRoutineResultStatus.rejected,
      generatedCount: 0,
      acceptedCount: 0,
      modifiedCount: 0,
      rejectedCount: 0,
      isPartial: false,
    );
  }
}

class SkinCareProductRecommendation {
  final String name;
  final String brand;
  final String category;
  final String estimatedPrice;
  final String currencyCode;
  final String reason;

  const SkinCareProductRecommendation({
    required this.name,
    this.brand = '',
    this.category = '',
    this.estimatedPrice = '',
    this.currencyCode = '',
    this.reason = '',
  });

  factory SkinCareProductRecommendation.fromValue(dynamic value) {
    if (value is String) {
      return SkinCareProductRecommendation(name: value.trim());
    }
    if (value is! Map) {
      return const SkinCareProductRecommendation(name: '');
    }
    final map = Map<String, dynamic>.from(value);
    return SkinCareProductRecommendation(
      name: _stringValue(map['name'] ?? map['productName']).trim(),
      brand: _stringValue(map['brand']).trim(),
      category: _stringValue(map['category']).trim(),
      estimatedPrice: _stringValue(
        map['estimatedPrice'] ?? map['price'] ?? map['priceRange'],
      ).trim(),
      currencyCode: _stringValue(map['currencyCode'] ?? map['currency']).trim(),
      reason: _stringValue(map['reason'] ?? map['why']).trim(),
    );
  }

  bool get isUsable => name.isNotEmpty || brand.isNotEmpty;

  String get displayName {
    if (name.isEmpty) return brand;
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }
    return '$brand $name';
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'brand': brand,
    'category': category,
    'estimatedPrice': estimatedPrice,
    'currencyCode': currencyCode,
    'reason': reason,
  };
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

class UnavailableSkinCareAiClient implements SkinCareAiClient {
  final String errorCode;

  const UnavailableSkinCareAiClient(this.errorCode);

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    return SkinCareAiProductResult.error(errorCode);
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    return SkinCareAiRoutineResult.error(errorCode);
  }
}

class FakeSkinCareAiClient implements SkinCareAiClient {
  const FakeSkinCareAiClient();

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    if (productPhotos.length != 1) {
      return SkinCareAiProductResult.error(
        'Upload one photo containing the products you want reviewed.',
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
    const recommendations = [
      SkinCareProductRecommendation(
        name: 'Gentle Cleanser',
        brand: 'Minimalist',
        category: 'cleanser',
        estimatedPrice: '299',
        currencyCode: 'INR',
        reason: 'Gentle daily cleansing',
      ),
      SkinCareProductRecommendation(
        name: 'Barrier Moisturizer',
        brand: 'Minimalist',
        category: 'moisturizer',
        estimatedPrice: '349',
        currencyCode: 'INR',
        reason: 'Supports the skin barrier',
      ),
      SkinCareProductRecommendation(
        name: 'SPF 50 Sunscreen',
        brand: 'Minimalist',
        category: 'sunscreen',
        estimatedPrice: '399',
        currencyCode: 'INR',
        reason: 'Daily sun protection',
      ),
    ];
    if (params['recommendationOnly'] == true) {
      return const SkinCareAiRoutineResult(
        routinePlans: [],
        morningRoutine: [],
        nightRoutine: [],
        weeklyRoutine: [],
        timelineBlocks: [],
        recommendedProducts: recommendations,
      );
    }

    final desired =
        (params['desiredApplicationsPerDay'] is num
                ? (params['desiredApplicationsPerDay'] as num).toInt()
                : 2)
            .clamp(2, 4)
            .toInt();
    final rawDetails = params['typedProductDetails'];
    final selectedDetails = rawDetails is List
        ? rawDetails.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
    String selectedName(String category, String fallback) {
      final match = selectedDetails.where(
        (product) =>
            _stringValue(product['category']).trim().toLowerCase() == category,
      );
      if (match.isEmpty) return fallback;
      final product = match.first;
      final name = _stringValue(product['name']).trim();
      final brand = _stringValue(product['brand']).trim();
      if (name.isEmpty) return brand.isEmpty ? fallback : brand;
      if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
        return name;
      }
      return '$brand $name';
    }

    final cleanser = selectedName('cleanser', 'Fake Cleanser');
    final moisturizer = selectedName('moisturizer', 'Moisturizer');
    final sunscreen = selectedName('sunscreen', 'Sunscreen');
    final allPlans = [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        steps: ['Cleanse face', 'Apply sunscreen'],
        productNames: [cleanser, sunscreen],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'midday',
        title: 'Midday Skin Care',
        steps: ['Refresh skin', 'Reapply sunscreen'],
        productNames: [sunscreen],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'afternoon',
        title: 'Afternoon Skin Care',
        steps: ['Reapply sunscreen'],
        productNames: [sunscreen],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Skin Care',
        steps: ['Cleanse face', 'Apply moisturizer'],
        productNames: [cleanser, moisturizer],
      ),
    ];
    final plans = desired == 2
        ? [allPlans.first, allPlans.last]
        : desired == 3
        ? [allPlans[0], allPlans[1], allPlans[3]]
        : allPlans;
    return SkinCareAiRoutineResult(
      routinePlans: plans,
      morningRoutine: ["Fake Cleanser", "Sunscreen"],
      nightRoutine: ["Fake Cleanser", "Moisturizer"],
      weeklyRoutine: [],
      timelineBlocks: const [
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
      recommendedProducts: recommendations,
      suggestedProducts: ["Suggested Cleanser", "Suggested Moisturizer"],
      warnings: [],
    );
  }
}

class WorkerSkinCareAiClient implements SkinCareAiClient {
  final String baseUrl;
  final http.Client _client;
  final Duration requestTimeout;

  WorkerSkinCareAiClient({
    String? baseUrl,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 55),
  }) : baseUrl = baseUrl ?? OptivusAiWorkersConfig.skinCareWorkerUrl,
       _client = client ?? http.Client();

  @override
  Future<SkinCareAiProductResult> analyzeProducts({
    required String uid,
    required String idToken,
    required List<String> productPhotos,
  }) async {
    final validation = SkinCareWorkerPayloadValidator.validateAnalyzeParams(
      productPhotos,
    );
    if (!validation.isValid) {
      return SkinCareAiProductResult.error(validation.errorMessage!);
    }
    if (baseUrl.trim().isEmpty) {
      return SkinCareAiProductResult.error('missing_worker_url');
    }

    try {
      final response = await _client
          .post(
            _workerUri('/v1/skin-care/products/analyze'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'productPhotos': productPhotos}),
          )
          .timeout(requestTimeout);
      final body = _jsonObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SkinCareAiProductResult.error(
          _friendlyErrorMessage(
            response.statusCode,
            body,
            endpoint: _SkinCareWorkerEndpoint.productAnalyze,
          ),
          errorCode: body['error'] as String?,
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
    } on FormatException {
      return SkinCareAiProductResult.error('provider_invalid_json');
    } on TimeoutException {
      return SkinCareAiProductResult.error('provider_timeout');
    } on SocketException {
      return SkinCareAiProductResult.error('network_unavailable');
    } on http.ClientException {
      return SkinCareAiProductResult.error('network_unavailable');
    } catch (_) {
      return SkinCareAiProductResult.error('provider_unavailable');
    }
  }

  @override
  Future<SkinCareAiRoutineResult> generateRoutine({
    required String uid,
    required String idToken,
    required Map<String, dynamic> params,
  }) async {
    final validation = SkinCareWorkerPayloadValidator.validateRoutineParams(
      params,
    );
    if (!validation.isValid) {
      return SkinCareAiRoutineResult.error(
        validation.errorMessage!,
        errorCode: 'client_payload_validation_error',
      );
    }

    if (baseUrl.trim().isEmpty) {
      return SkinCareAiRoutineResult.error('missing_worker_url');
    }

    try {
      final response = await _client
          .post(
            _workerUri('/v1/skin-care/routine/generate'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(params),
          )
          .timeout(requestTimeout);
      final body = _jsonObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final rawError = body['error'] as String?;
        return SkinCareAiRoutineResult.error(
          _friendlyErrorMessage(
            response.statusCode,
            body,
            endpoint: _SkinCareWorkerEndpoint.routineGenerate,
          ),
          errorCode: rawError,
        );
      }

      final mR = body['morningRoutine'];
      final nR = body['nightRoutine'];
      final wR = body['weeklyRoutine'];
      final tB = body['timelineBlocks'];
      final rP = body['recommendedProducts'];
      final sP = body['suggestedProducts'];
      final warnings = body['warnings'];
      final rejectedPlanReasons = body['rejectedPlanReasons'];
      final plans = body['routinePlans'] ?? body['plans'];

      if (kDebugMode) {
        debugPrint(
          '[SkinCareWorkerClient] routine raw '
          'routinePlanCount=${plans is List ? plans.length : 0} '
          'weeklyRoutineCount=${wR is List ? wR.length : 0} '
          'suggestedProductCount=${sP is List ? sP.length : 0} '
          'warningCount=${warnings is List ? warnings.length : 0} '
          'rejectedPlanCount='
          '${rejectedPlanReasons is List ? rejectedPlanReasons.length : 0}',
        );
      }

      return SkinCareAiRoutineResult(
        routinePlans: _routinePlansFromValue(plans),
        morningRoutine: mR is List ? mR : [],
        nightRoutine: nR is List ? nR : [],
        weeklyRoutine: wR is List ? wR : [],
        timelineBlocks: tB is List ? tB : [],
        recommendedProducts: rP is List
            ? rP
                  .map(SkinCareProductRecommendation.fromValue)
                  .where((product) => product.isUsable)
                  .toList(growable: false)
            : const [],
        suggestedProducts: sP is List
            ? sP.map((e) => e.toString()).toList()
            : [],
        warnings: warnings is List
            ? warnings.map((e) => e.toString()).toList()
            : [],
        rejectedPlanReasons: rejectedPlanReasons is List
            ? rejectedPlanReasons.map((e) => e.toString()).toList()
            : [],
      );
    } on FormatException {
      return SkinCareAiRoutineResult.error(
        'provider_invalid_json',
        errorCode: 'provider_invalid_json',
      );
    } on TimeoutException {
      return SkinCareAiRoutineResult.error(
        'provider_timeout',
        errorCode: 'provider_timeout',
      );
    } on SocketException {
      return SkinCareAiRoutineResult.error(
        'network_unavailable',
        errorCode: 'network_unavailable',
      );
    } on http.ClientException {
      return SkinCareAiRoutineResult.error(
        'network_unavailable',
        errorCode: 'network_unavailable',
      );
    } catch (_) {
      return SkinCareAiRoutineResult.error(
        'provider_unavailable',
        errorCode: 'provider_unavailable',
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
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected a JSON object');
  }

  String _friendlyErrorMessage(
    int statusCode,
    Map<String, dynamic> body, {
    required _SkinCareWorkerEndpoint endpoint,
  }) {
    final rawError = body['error'] as String?;
    final rawMessage = _stringValue(body['message']).toLowerCase();

    if (rawError == 'provider_unauthorized') {
      return 'Skin care AI provider authorization failed. Please check the worker configuration.';
    }
    if (rawError == 'provider_model_not_found') {
      return 'Skin care AI model is unavailable. Please check the worker model configuration.';
    }
    if (rawError == 'provider_timeout' ||
        rawError == 'provider_unavailable' ||
        rawError == 'provider_request_failed') {
      return 'AI skin care service is unavailable. Try again later.';
    }
    if (statusCode == 429 || rawError == 'provider_quota_exceeded') {
      return 'AI usage limit reached. Try again later.';
    }
    if (statusCode == 503 || rawError == 'provider_high_demand') {
      return 'AI is busy right now. Try again in a moment.';
    }
    if (rawError == 'too_many_photos') {
      return 'Upload one photo containing the products you want reviewed.';
    }
    if (rawError == 'provider_invalid_response' ||
        rawError == 'provider_invalid_json') {
      return 'AI response could not be safely read. Please try again.';
    }
    if (rawError == 'provider_invalid_image_payload') {
      return 'AI could not process this photo. Upload a clearer JPEG, PNG, or WEBP image.';
    }
    if (rawError == 'provider_invalid_request') {
      return 'AI could not process this request. Please try again.';
    }
    if (rawError == 'provider_empty_candidates' ||
        rawError == 'no_blocks_generated') {
      return 'AI could not read your products. Upload a clearer photo or use typed product names.';
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
    if (rawError == 'json_payload_too_large' ||
        (rawError == 'payload_too_large' &&
            endpoint == _SkinCareWorkerEndpoint.routineGenerate &&
            rawMessage.contains('json'))) {
      return 'Skin-care product details were too large to send. Try typing your main products or upload a clearer single photo.';
    }
    if (rawError == 'image_payload_too_large' ||
        rawError == 'payload_too_large') {
      return endpoint == _SkinCareWorkerEndpoint.productAnalyze
          ? 'Product photo is too large. Upload a smaller, clearer photo.'
          : 'Uploaded photo is too large. Upload a smaller photo.';
    }
    return 'AI service could not process this request.';
  }
}

enum _SkinCareWorkerEndpoint { productAnalyze, routineGenerate }

List<SkinCareRoutinePlan> _routinePlansFromValue(dynamic value) {
  final rawPlans = value is List ? value : const [];
  return rawPlans
      .whereType<Map>()
      .map(
        (item) => SkinCareRoutinePlan.fromMap(Map<String, dynamic>.from(item)),
      )
      .where(_routinePlanHasContent)
      .toList(growable: false);
}

bool _routinePlanHasContent(SkinCareRoutinePlan plan) {
  return plan.steps.isNotEmpty || plan.productNames.isNotEmpty;
}

String _stringValue(dynamic value) => value == null ? '' : value.toString();

List<SkinCareMissingItem> _missingItemsFromValue(dynamic value) {
  if (value == null) return const [];
  final raw = value is List ? value : [value];
  final seen = <String>{};
  final result = <SkinCareMissingItem>[];
  for (final item in raw) {
    final parsed = SkinCareMissingItem.fromValue(item);
    final cleanName = parsed.name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.isEmpty) continue;
    final key = cleanName.toLowerCase();
    if (!seen.add(key)) continue;
    result.add(
      SkinCareMissingItem(
        name: cleanName,
        importance: parsed.importance,
        reason: parsed.reason,
      ),
    );
  }
  return result;
}

String _normalizeMissingItemImportance(dynamic value) {
  final text = _stringValue(value)
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return 'important';
  if (text == 'required' ||
      text == 'must have' ||
      text == 'essential' ||
      text == 'critical') {
    return 'required';
  }
  if (text == 'recommended' || text == 'suggested' || text == 'helpful') {
    return 'recommended';
  }
  if (text == 'optional' || text == 'extra' || text == 'nice to have') {
    return 'optional';
  }
  return 'important';
}

List<String> _stringListFromValue(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    return _dedupeStrings(
      value
          .split(RegExp(r'[\n,]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }
  if (value is List) {
    return _dedupeStrings(value.map(_stringFromRoutineItem));
  }
  final single = _stringFromRoutineItem(value).trim();
  return single.isEmpty ? const [] : [single];
}

String _stringFromRoutineItem(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    for (final key in const [
      'instruction',
      'step',
      'text',
      'name',
      'productName',
      'product',
    ]) {
      final text = _stringValue(map[key]).trim();
      if (text.isNotEmpty) return text;
    }
  }
  return value.toString().trim();
}

List<int> _repeatDaysFromValue(dynamic value) {
  final raw = value is List ? value : const [];
  final days =
      raw
          .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
          .whereType<int>()
          .where((day) => day >= 1 && day <= 7)
          .toSet()
          .toList()
        ..sort();
  return days;
}

List<String> _dedupeStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) continue;
    if (seen.add(value.toLowerCase())) result.add(value);
  }
  return result;
}

class SkinCarePayloadValidationResult {
  final bool isValid;
  final String? errorMessage;

  const SkinCarePayloadValidationResult.valid()
    : isValid = true,
      errorMessage = null;

  const SkinCarePayloadValidationResult.invalid(this.errorMessage)
    : isValid = false;
}

class SkinCareWorkerPayloadValidator {
  static const int maxProductPhotos = 1;
  static const int maxTypedProducts = 20;
  static const Set<String> validSkinTypes = {
    'normal',
    'dry',
    'oily',
    'combination',
    'sensitive',
    'not_sure',
  };
  static const Set<String> validBudgets = {'low', 'medium', 'high'};
  static const Set<String> validPreferences = {
    'simple',
    'balanced',
    'advanced',
  };

  static SkinCarePayloadValidationResult validateAnalyzeParams(
    List<String> productPhotos,
  ) {
    if (productPhotos.isEmpty) {
      return const SkinCarePayloadValidationResult.invalid(
        'Product photos list cannot be empty.',
      );
    }
    if (productPhotos.length > maxProductPhotos) {
      return const SkinCarePayloadValidationResult.invalid(
        'Upload one photo containing the products you want reviewed.',
      );
    }
    for (final photo in productPhotos) {
      if (photo.trim().isEmpty) {
        return const SkinCarePayloadValidationResult.invalid(
          'Product photo path/key cannot be empty.',
        );
      }
    }
    return const SkinCarePayloadValidationResult.valid();
  }

  static SkinCarePayloadValidationResult validateRoutineParams(
    Map<String, dynamic> params,
  ) {
    if (params.containsKey('productPhotos')) {
      final photos = params['productPhotos'];
      if (photos is List) {
        if (photos.length > maxProductPhotos) {
          return const SkinCarePayloadValidationResult.invalid(
            'Upload one photo containing the products you want reviewed.',
          );
        }
        for (final photo in photos) {
          if (photo == null || photo.toString().trim().isEmpty) {
            return const SkinCarePayloadValidationResult.invalid(
              'Product photo path cannot be empty.',
            );
          }
        }
      }
    }

    if (params.containsKey('desiredApplicationsPerDay')) {
      final desired = params['desiredApplicationsPerDay'];
      if (desired is num) {
        final val = desired.toInt();
        if (val < 2 || val > 4) {
          return const SkinCarePayloadValidationResult.invalid(
            'Desired applications per day must be between 2 and 4.',
          );
        }
      }
    }

    if (params.containsKey('skinType')) {
      final skinType = params['skinType']?.toString().toLowerCase().trim();
      if (skinType != null &&
          skinType.isNotEmpty &&
          !validSkinTypes.contains(skinType)) {
        return const SkinCarePayloadValidationResult.invalid(
          'Invalid skin type provided.',
        );
      }
    }

    if (params.containsKey('budget')) {
      final budget = params['budget']?.toString().toLowerCase().trim();
      if (budget != null &&
          budget.isNotEmpty &&
          !validBudgets.contains(budget)) {
        return const SkinCarePayloadValidationResult.invalid(
          'Invalid budget option provided.',
        );
      }
    }

    if (params.containsKey('routinePreference')) {
      final pref = params['routinePreference']?.toString().toLowerCase().trim();
      if (pref != null && pref.isNotEmpty && !validPreferences.contains(pref)) {
        return const SkinCarePayloadValidationResult.invalid(
          'Invalid routine preference option provided.',
        );
      }
    }

    if (params.containsKey('typedProductDetails')) {
      final details = params['typedProductDetails'];
      if (details is List) {
        if (details.length > maxTypedProducts) {
          return const SkinCarePayloadValidationResult.invalid(
            'Maximum of 20 products can be analyzed at once.',
          );
        }
        for (final item in details) {
          if (item is Map) {
            final name = (item['name'] ?? item['brand'] ?? '')
                .toString()
                .trim();
            if (name.isEmpty) {
              return const SkinCarePayloadValidationResult.invalid(
                'Product name in typed product details cannot be empty.',
              );
            }
          }
        }
      }
    }

    return const SkinCarePayloadValidationResult.valid();
  }
}

class SkinCareContraindicationWarning {
  final String ingredientA;
  final String ingredientB;
  final String slotLabel;
  final String message;
  final String severity;

  const SkinCareContraindicationWarning({
    required this.ingredientA,
    required this.ingredientB,
    required this.slotLabel,
    required this.message,
    this.severity = 'warning',
  });

  Map<String, dynamic> toMap() => {
    'ingredientA': ingredientA,
    'ingredientB': ingredientB,
    'slotLabel': slotLabel,
    'message': message,
    'severity': severity,
  };
}

class SkinCareContraindicationDetector {
  static List<SkinCareContraindicationWarning> detectContraindications({
    required String slotLabel,
    required List<String> productNamesOrSteps,
    List<SkinCareDetectedProduct>? productDetails,
  }) {
    final warnings = <SkinCareContraindicationWarning>[];
    final allText = productNamesOrSteps.map((s) => s.toLowerCase()).toList();

    bool hasRetinol = false;
    bool hasAhaBha = false;
    bool hasVitC = false;
    bool hasBpo = false;
    int retinoidCount = 0;
    int bhaCount = 0;

    for (final text in allText) {
      if (_matchesRetinol(text)) {
        hasRetinol = true;
        retinoidCount++;
      }
      if (_matchesAhaBha(text)) {
        hasAhaBha = true;
        if (text.contains('bha') || text.contains('salicylic')) bhaCount++;
      }
      if (_matchesVitC(text)) {
        hasVitC = true;
      }
      if (_matchesBpo(text)) {
        hasBpo = true;
      }
    }

    if (productDetails != null) {
      for (final p in productDetails) {
        final combined =
            '${p.displayName} ${p.category} ${p.keyIngredients.join(' ')} ${p.possibleActives.join(' ')}'
                .toLowerCase();
        if (_matchesRetinol(combined)) {
          hasRetinol = true;
          retinoidCount++;
        }
        if (_matchesAhaBha(combined)) {
          hasAhaBha = true;
          if (combined.contains('bha') || combined.contains('salicylic')) {
            bhaCount++;
          }
        }
        if (_matchesVitC(combined)) {
          hasVitC = true;
        }
        if (_matchesBpo(combined)) {
          hasBpo = true;
        }
      }
    }

    // 1. Retinol + AHA/BHA
    if (hasRetinol && hasAhaBha) {
      warnings.add(
        SkinCareContraindicationWarning(
          ingredientA: 'Retinol',
          ingredientB: 'AHA/BHA Exfoliants',
          slotLabel: slotLabel,
          message:
              'Combining Retinol and AHA/BHA exfoliants in the same routine slot can cause skin irritation.',
        ),
      );
    }

    // 2. Vitamin C + AHA/BHA
    if (hasVitC && hasAhaBha) {
      warnings.add(
        SkinCareContraindicationWarning(
          ingredientA: 'Vitamin C',
          ingredientB: 'AHA/BHA',
          slotLabel: slotLabel,
          message:
              'Vitamin C and AHA/BHA acids can destabilize each other and irritate skin when used together.',
        ),
      );
    }

    // 3. Retinol + Vitamin C
    if (hasRetinol && hasVitC) {
      warnings.add(
        SkinCareContraindicationWarning(
          ingredientA: 'Retinol',
          ingredientB: 'Vitamin C',
          slotLabel: slotLabel,
          message:
              'Using Retinol and Vitamin C together in the same slot increases skin sensitivity.',
        ),
      );
    }

    // 4. Benzoyl Peroxide + Retinol
    if (hasBpo && hasRetinol) {
      warnings.add(
        SkinCareContraindicationWarning(
          ingredientA: 'Benzoyl Peroxide',
          ingredientB: 'Retinol',
          slotLabel: slotLabel,
          message:
              'Benzoyl Peroxide can oxidize and deactivate Retinol while causing excessive dryness.',
        ),
      );
    }

    // 5. Duplicate Actives
    if (retinoidCount > 1) {
      warnings.add(
        SkinCareContraindicationWarning(
          ingredientA: 'Retinoid',
          ingredientB: 'Duplicate Retinoid',
          slotLabel: slotLabel,
          message:
              'Multiple retinoid products detected in the same routine slot.',
        ),
      );
    } else if (bhaCount > 1) {
      warnings.add(
        SkinCareContraindicationWarning(
          ingredientA: 'BHA Exfoliant',
          ingredientB: 'Duplicate BHA Exfoliant',
          slotLabel: slotLabel,
          message:
              'Multiple BHA/Salicylic Acid products detected in the same routine slot.',
        ),
      );
    }

    return warnings;
  }

  static bool _matchesRetinol(String t) =>
      t.contains('retinol') ||
      t.contains('retinoid') ||
      t.contains('tretinoin') ||
      t.contains('adapalene') ||
      t.contains('granactive') ||
      t.contains('retinal');

  static bool _matchesAhaBha(String t) =>
      t.contains('aha') ||
      t.contains('bha') ||
      t.contains('salicylic') ||
      t.contains('glycolic') ||
      t.contains('lactic acid') ||
      t.contains('mandelic') ||
      t.contains('exfolia');

  static bool _matchesVitC(String t) =>
      t.contains('vitamin c') ||
      t.contains('ascorbic') ||
      t.contains('l-ascorbic') ||
      t.contains('ascorbyl');

  static bool _matchesBpo(String t) =>
      t.contains('benzoyl peroxide') || t.contains('bpo');
}

class SkinCareScheduleValidationResult {
  final bool isValid;
  final String? errorMessage;

  const SkinCareScheduleValidationResult.valid()
    : isValid = true,
      errorMessage = null;

  const SkinCareScheduleValidationResult.invalid(this.errorMessage)
    : isValid = false;
}

class SkinCareScheduleEnforcer {
  static const int minRestMinutes = 240; // 4 hours
  static const int maxApplicationsPerDay = 4;

  static SkinCareScheduleValidationResult validateSchedule({
    required List<int> startMinutes,
  }) {
    if (startMinutes.length > maxApplicationsPerDay) {
      return const SkinCareScheduleValidationResult.invalid(
        'Maximum 4 skin care applications allowed per day.',
      );
    }
    final sorted = List<int>.from(startMinutes)..sort();
    for (int i = 0; i < sorted.length - 1; i++) {
      final diff = sorted[i + 1] - sorted[i];
      if (diff < minRestMinutes) {
        return SkinCareScheduleValidationResult.invalid(
          'Minimum 4 hours (240 minutes) rest required between skin care routines.',
        );
      }
    }
    return const SkinCareScheduleValidationResult.valid();
  }

  static List<int> enforceMinimumRestIntervals(List<int> startMinutes) {
    if (startMinutes.isEmpty) return [];
    final sorted = List<int>.from(startMinutes)..sort();
    final result = <int>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      int nextMin = sorted[i];
      final prevMin = result.last;
      if (nextMin - prevMin < minRestMinutes) {
        nextMin = (prevMin + minRestMinutes).clamp(0, 1439);
      }
      result.add(nextMin);
    }
    return result;
  }
}

class StepSequenceResult {
  final List<String> steps;
  final bool sequenceAdjusted;
  final String? sequenceAdjustedWarning;

  const StepSequenceResult({
    required this.steps,
    required this.sequenceAdjusted,
    this.sequenceAdjustedWarning,
  });
}

class SkinCareStepSequenceValidator {
  static StepSequenceResult validateAndReorder(
    List<String> steps, {
    required bool isNight,
  }) {
    if (steps.length <= 1) {
      return StepSequenceResult(steps: steps, sequenceAdjusted: false);
    }

    final ranked = <_RankedStep>[];
    for (int i = 0; i < steps.length; i++) {
      final rank = getStepRank(steps[i], isNight: isNight);
      ranked.add(_RankedStep(originalIndex: i, text: steps[i], rank: rank));
    }

    final sorted = List<_RankedStep>.from(ranked);
    sorted.sort((a, b) {
      final cmp = a.rank.compareTo(b.rank);
      if (cmp != 0) return cmp;
      return a.originalIndex.compareTo(b.originalIndex);
    });

    final reorderedSteps = sorted.map((e) => e.text).toList();
    bool adjusted = false;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i] != reorderedSteps[i]) {
        adjusted = true;
        break;
      }
    }

    return StepSequenceResult(
      steps: reorderedSteps,
      sequenceAdjusted: adjusted,
      sequenceAdjustedWarning: adjusted
          ? 'Steps were reordered for optimal skin absorption and sun protection.'
          : null,
    );
  }

  static int getStepRank(String stepName, {required bool isNight}) {
    final lower = stepName.toLowerCase();
    if (lower.contains('cleanse') ||
        lower.contains('wash') ||
        lower.contains('cleanser') ||
        lower.contains('micellar')) {
      return 1;
    }
    if (lower.contains('toner') ||
        lower.contains('essence') ||
        lower.contains('exfolia') ||
        lower.contains('prep') ||
        lower.contains('aha') ||
        lower.contains('bha') ||
        lower.contains('peel')) {
      return 2;
    }
    if (lower.contains('serum') ||
        lower.contains('treatment') ||
        lower.contains('retinol') ||
        lower.contains('vitamin c') ||
        lower.contains('active') ||
        lower.contains('niacinamide') ||
        lower.contains('spot')) {
      return 3;
    }
    if (lower.contains('moistur') ||
        lower.contains('cream') ||
        lower.contains('lotion') ||
        lower.contains('barrier') ||
        lower.contains('hydrat')) {
      return 4;
    }
    if (lower.contains('sunscreen') ||
        lower.contains('spf') ||
        lower.contains('sunblock') ||
        lower.contains('oil') ||
        lower.contains('balm') ||
        lower.contains('occlusive')) {
      return 5;
    }
    return 3;
  }
}

class _RankedStep {
  final int originalIndex;
  final String text;
  final int rank;

  const _RankedStep({
    required this.originalIndex,
    required this.text,
    required this.rank,
  });
}

class OfflineSkinCareRoutineGenerator {
  static SkinCareAiRoutineResult generateFallbackRoutine(
    Map<String, dynamic> params,
  ) {
    final rawDesired = params['desiredApplicationsPerDay'];
    final desired = (rawDesired is num ? rawDesired.toInt() : 2).clamp(2, 4);

    final rawDetails = params['typedProductDetails'];
    final details = rawDetails is List
        ? rawDetails.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];

    String findProduct(String category, String defaultName) {
      for (final p in details) {
        final cat = (p['category'] ?? '').toString().toLowerCase().trim();
        if (cat == category) {
          final name = (p['name'] ?? p['brand'] ?? '').toString().trim();
          if (name.isNotEmpty) return name;
        }
      }
      return defaultName;
    }

    final cleanser = findProduct('cleanser', 'Gentle Cleanser');
    final moisturizer = findProduct('moisturizer', 'Hydrating Moisturizer');
    final sunscreen = findProduct('sunscreen', 'Broad Spectrum SPF 50');

    final rawMorningSteps = ['Cleanse face', 'Apply sunscreen'];
    if (cleanser != 'Gentle Cleanser' ||
        moisturizer != 'Hydrating Moisturizer') {
      rawMorningSteps.insert(1, 'Apply moisturizer');
    }
    final morningRes = SkinCareStepSequenceValidator.validateAndReorder(
      rawMorningSteps,
      isNight: false,
    );

    final rawNightSteps = ['Cleanse face', 'Apply moisturizer'];
    final nightRes = SkinCareStepSequenceValidator.validateAndReorder(
      rawNightSteps,
      isNight: true,
    );

    final plans = <SkinCareRoutinePlan>[
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        steps: morningRes.steps,
        productNames: [cleanser, sunscreen],
      ),
    ];

    if (desired >= 3) {
      plans.add(
        SkinCareRoutinePlan(
          slotLabel: 'midday',
          title: 'Midday Skin Care',
          steps: ['Reapply sunscreen'],
          productNames: [sunscreen],
        ),
      );
    }
    if (desired == 4) {
      plans.add(
        SkinCareRoutinePlan(
          slotLabel: 'afternoon',
          title: 'Afternoon Skin Care',
          steps: ['Reapply sunscreen'],
          productNames: [sunscreen],
        ),
      );
    }

    plans.add(
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Skin Care',
        steps: nightRes.steps,
        productNames: [cleanser, moisturizer],
      ),
    );

    const warnings = [
      'Offline routine generated while AI service was unavailable.',
    ];

    final timelineBlocks = <Map<String, dynamic>>[
      {
        "id": "skincare-offline-1",
        "section": "skin_care",
        "title": "Morning skin care",
        "startMinute": 420,
        "endMinute": 435,
        "blockType": "soft_block",
        "repeatDays": [1, 2, 3, 4, 5, 6, 7],
        "skincareProducts": [cleanser, sunscreen],
        "skincareSteps": morningRes.steps,
      },
      {
        "id": "skincare-offline-2",
        "section": "skin_care",
        "title": "Night skin care",
        "startMinute": 1260,
        "endMinute": 1275,
        "blockType": "soft_block",
        "repeatDays": [1, 2, 3, 4, 5, 6, 7],
        "skincareProducts": [cleanser, moisturizer],
        "skincareSteps": nightRes.steps,
      },
    ];

    return SkinCareAiRoutineResult(
      routinePlans: plans,
      morningRoutine: [cleanser, sunscreen],
      nightRoutine: [cleanser, moisturizer],
      weeklyRoutine: const [],
      timelineBlocks: timelineBlocks,
      warnings: warnings,
    );
  }
}
