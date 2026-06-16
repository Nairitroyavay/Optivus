import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus/config/ai_workers_config.dart';

final skinCareAiClientProvider = Provider<SkinCareAiClient>((ref) {
  if (OptivusAiWorkersConfig.useWorker &&
      OptivusAiWorkersConfig.skinCareWorkerUrl.trim().isNotEmpty) {
    return WorkerSkinCareAiClient();
  }
  if (OptivusAiWorkersConfig.mode == OptivusAiWorkerMode.fake &&
      OptivusAiWorkersConfig.allowFakeAiForTestsOnly) {
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

  bool get hasError => errorMessage != null;
  List<SkinCareDetectedProduct> get detectedProducts => products
      .map(SkinCareDetectedProduct.fromValue)
      .where((product) => product.hasMeaningfulData)
      .toList(growable: false);

  const SkinCareAiProductResult({
    required this.products,
    this.warnings = const [],
    this.errorMessage,
  });

  factory SkinCareAiProductResult.error(String msg) {
    return SkinCareAiProductResult(products: [], errorMessage: msg);
  }
}

class SkinCareDetectedProduct {
  final String name;
  final String brand;
  final String category;
  final List<String> keyIngredients;
  final List<String> possibleActives;
  final String usageHint;
  final String warningIfAny;
  final String confidence;

  const SkinCareDetectedProduct({
    this.name = '',
    this.brand = '',
    this.category = '',
    this.keyIngredients = const [],
    this.possibleActives = const [],
    this.usageHint = '',
    this.warningIfAny = '',
    this.confidence = '',
  });

  factory SkinCareDetectedProduct.fromValue(dynamic value) {
    if (value is String) {
      return SkinCareDetectedProduct(name: value.trim());
    }
    if (value is! Map) return const SkinCareDetectedProduct();
    return SkinCareDetectedProduct.fromMap(Map<String, dynamic>.from(value));
  }

  factory SkinCareDetectedProduct.fromMap(Map<String, dynamic> map) {
    return SkinCareDetectedProduct(
      name: _stringValue(map['name']).trim(),
      brand: _stringValue(map['brand']).trim(),
      category: _stringValue(map['category']).trim(),
      keyIngredients: _stringListFromValue(
        map['keyIngredients'] ?? map['ingredients'],
      ),
      possibleActives: _stringListFromValue(
        map['possibleActives'] ?? map['actives'],
      ),
      usageHint: _stringValue(map['usageHint'] ?? map['usage']).trim(),
      warningIfAny: _stringValue(
        map['warningIfAny'] ?? map['warning'] ?? map['warnings'],
      ).trim(),
      confidence: _stringValue(map['confidence']).trim(),
    );
  }

  bool get hasMeaningfulData =>
      name.isNotEmpty ||
      brand.isNotEmpty ||
      category.isNotEmpty ||
      keyIngredients.isNotEmpty ||
      possibleActives.isNotEmpty ||
      usageHint.isNotEmpty ||
      warningIfAny.isNotEmpty;

  String get displayName {
    final cleanName = name.trim();
    final cleanBrand = brand.trim();
    if (cleanName.isEmpty) return cleanBrand;
    if (cleanBrand.isEmpty ||
        cleanName.toLowerCase().contains(cleanBrand.toLowerCase())) {
      return cleanName;
    }
    return '$cleanBrand $cleanName';
  }

  String get fallbackLabel {
    final display = displayName.trim();
    if (display.isNotEmpty) return display;
    final categoryValue = category.trim().toLowerCase();
    if (categoryValue == 'sunscreen' || _metadataLooksLikeSunscreen(this)) {
      return 'Sunscreen';
    }
    if (categoryValue == 'cleanser' || _metadataLooksLikeCleanser(this)) {
      return 'Cleanser';
    }
    if (categoryValue == 'moisturizer' ||
        categoryValue == 'moisturiser' ||
        _metadataLooksLikeMoisturizer(this)) {
      return 'Moisturizer';
    }
    return hasMeaningfulData ? 'Skin-care product' : '';
  }

  List<String> get searchableFields => [
    displayName,
    fallbackLabel,
    name,
    brand,
    category,
    ...keyIngredients,
    ...possibleActives,
    usageHint,
    warningIfAny,
    confidence,
  ];

  Map<String, dynamic> toMap() => {
    'name': name,
    'brand': brand,
    'category': category,
    'keyIngredients': keyIngredients,
    'possibleActives': possibleActives,
    'usageHint': usageHint,
    'warningIfAny': warningIfAny,
    'confidence': confidence,
  };

  Map<String, dynamic> toCompactRoutinePayload() {
    final map = <String, dynamic>{};
    if (name.isNotEmpty) map['name'] = _truncate(name, 50);
    if (brand.isNotEmpty) map['brand'] = _truncate(brand, 50);
    if (category.isNotEmpty) map['category'] = _truncate(category, 30);
    
    if (keyIngredients.isNotEmpty) {
      map['keyIngredients'] = keyIngredients
          .take(5)
          .map((e) => _truncate(e, 30))
          .toList(growable: false);
    }
    if (possibleActives.isNotEmpty) {
      map['possibleActives'] = possibleActives
          .take(5)
          .map((e) => _truncate(e, 30))
          .toList(growable: false);
    }
    if (usageHint.isNotEmpty) {
      map['usageHint'] = _truncate(usageHint, 100);
    }
    if (warningIfAny.isNotEmpty) {
      map['warningIfAny'] = _truncate(warningIfAny, 100);
    }
    if (confidence.isNotEmpty) map['confidence'] = confidence;

    return map;
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}

class SkinCareRoutinePlan {
  final String slotLabel;
  final String title;
  final List<String> steps;
  final List<String> productNames;
  final List<String> warnings;
  final List<int> repeatDays;

  const SkinCareRoutinePlan({
    required this.slotLabel,
    required this.title,
    required this.steps,
    required this.productNames,
    this.warnings = const [],
    this.repeatDays = const [],
  });

  factory SkinCareRoutinePlan.fromMap(Map<String, dynamic> map) {
    return SkinCareRoutinePlan(
      slotLabel: _stringValue(
        map['slotLabel'] ?? map['slot'] ?? map['timeOfDay'],
      ).toLowerCase().trim(),
      title: _stringValue(map['title'] ?? map['name']).trim(),
      steps: _stringListFromValue(
        map['steps'] ?? map['orderedSteps'] ?? map['instructions'],
      ),
      productNames: _stringListFromValue(
        map['productNames'] ?? map['products'] ?? map['skincareProducts'],
      ),
      warnings: _stringListFromValue(map['warnings'] ?? map['warningIfAny']),
      repeatDays: _repeatDaysFromValue(map['repeatDays'] ?? map['days']),
    );
  }

  Map<String, dynamic> toMap() => {
    'slotLabel': slotLabel,
    'title': title,
    'steps': steps,
    'productNames': productNames,
    'warnings': warnings,
    'repeatDays': repeatDays,
  };
}

class SkinCareAiRoutineResult {
  final List<SkinCareRoutinePlan> routinePlans;
  final List<dynamic> morningRoutine;
  final List<dynamic> nightRoutine;
  final List<dynamic> weeklyRoutine;
  final List<dynamic> timelineBlocks;
  final List<String> suggestedProducts;
  final List<String> warnings;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  const SkinCareAiRoutineResult({
    this.routinePlans = const [],
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
      routinePlans: [],
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
    final desired =
        (params['desiredApplicationsPerDay'] is num
                ? (params['desiredApplicationsPerDay'] as num).toInt()
                : 2)
            .clamp(2, 4)
            .toInt();
    const allPlans = [
      SkinCareRoutinePlan(
        slotLabel: 'morning',
        title: 'Morning Skin Care',
        steps: ['Cleanse face', 'Apply sunscreen'],
        productNames: ['Fake Cleanser', 'Sunscreen'],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'midday',
        title: 'Midday Skin Care',
        steps: ['Refresh skin', 'Reapply sunscreen'],
        productNames: ['Sunscreen'],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'afternoon',
        title: 'Afternoon Skin Care',
        steps: ['Reapply sunscreen'],
        productNames: ['Sunscreen'],
      ),
      SkinCareRoutinePlan(
        slotLabel: 'night',
        title: 'Night Skin Care',
        steps: ['Cleanse face', 'Apply moisturizer'],
        productNames: ['Fake Cleanser', 'Moisturizer'],
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
          _friendlyErrorMessage(
            response.statusCode,
            body,
            endpoint: _SkinCareWorkerEndpoint.productAnalyze,
          ),
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
          _friendlyErrorMessage(
            response.statusCode,
            body,
            endpoint: _SkinCareWorkerEndpoint.routineGenerate,
          ),
        );
      }

      final mR = body['morningRoutine'];
      final nR = body['nightRoutine'];
      final wR = body['weeklyRoutine'];
      final tB = body['timelineBlocks'];
      final sP = body['suggestedProducts'];
      final warnings = body['warnings'];
      final plans = body['routinePlans'] ?? body['plans'];

      return SkinCareAiRoutineResult(
        routinePlans: _routinePlansFromValue(plans, fallbackBlocks: tB),
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

  String _friendlyErrorMessage(
    int statusCode,
    Map<String, dynamic> body, {
    required _SkinCareWorkerEndpoint endpoint,
  }) {
    final rawError = body['error'] as String?;
    final rawMessage = _stringValue(body['message']).toLowerCase();

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
    if (rawError == 'provider_invalid_response' ||
        rawError == 'provider_invalid_json') {
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

List<SkinCareRoutinePlan> _routinePlansFromValue(
  dynamic value, {
  dynamic fallbackBlocks,
}) {
  final rawPlans = value is List ? value : const [];
  final plans = rawPlans
      .whereType<Map>()
      .map(
        (item) => SkinCareRoutinePlan.fromMap(Map<String, dynamic>.from(item)),
      )
      .where(_routinePlanHasContent)
      .toList(growable: false);
  if (plans.isNotEmpty) return plans;

  final rawBlocks = fallbackBlocks is List ? fallbackBlocks : const [];
  return rawBlocks
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

bool _metadataLooksLikeSunscreen(SkinCareDetectedProduct product) {
  return _rawProductFields(product).any((value) {
    final lower = value.toLowerCase();
    return lower.contains('sunscreen') ||
        lower.contains('spf') ||
        lower.contains('sun cream') ||
        lower.contains('suncream') ||
        lower.contains('sunblock') ||
        lower.contains('uv') ||
        lower.contains('pa++++') ||
        lower.contains('uv filter') ||
        lower.contains('uv-filter');
  });
}

bool _metadataLooksLikeCleanser(SkinCareDetectedProduct product) {
  return _rawProductFields(product).any((value) {
    final lower = value.toLowerCase();
    return lower.contains('cleanser') ||
        lower.contains('face wash') ||
        lower.contains('cleansing gel') ||
        lower.contains('cleansing foam') ||
        lower.contains('micellar') ||
        lower.contains('cleanse');
  });
}

bool _metadataLooksLikeMoisturizer(SkinCareDetectedProduct product) {
  return _rawProductFields(product).any((value) {
    final lower = value.toLowerCase();
    return lower.contains('moistur') ||
        lower.contains('cream') ||
        lower.contains('lotion') ||
        lower.contains('barrier repair') ||
        lower.contains('gel cream');
  });
}

List<String> _rawProductFields(SkinCareDetectedProduct product) => [
  product.displayName,
  product.name,
  product.brand,
  product.category,
  ...product.keyIngredients,
  ...product.possibleActives,
  product.usageHint,
  product.warningIfAny,
  product.confidence,
];
