part of '../onboarding_step_7_skin_care_setup.dart';

enum _SkinPhotoSource { camera, gallery }

Future<_SkinPhotoSource?> _showSkinPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<_SkinPhotoSource>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            key: const ValueKey('onboarding-step7-take-photo'),
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, _SkinPhotoSource.camera),
          ),
          ListTile(
            key: const ValueKey('onboarding-step7-choose-gallery'),
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, _SkinPhotoSource.gallery),
          ),
        ],
      ),
    ),
  );
}

AiGenerationErrorCategory onboarding7AiErrorCategory(String? code) {
  return switch (code) {
    'provider_timeout' || 'timeout' => AiGenerationErrorCategory.timeout,
    'provider_quota_exceeded' ||
    'provider_rate_limited' ||
    'rate_limit_exceeded' => AiGenerationErrorCategory.rateLimited,
    'network_unavailable' ||
    'provider_unavailable' ||
    'provider_high_demand' => AiGenerationErrorCategory.serviceUnavailable,
    'unauthorized' ||
    'session_expired' => AiGenerationErrorCategory.unauthorized,
    _ => AiGenerationErrorCategory.responseInvalid,
  };
}

class _SkinCareResponseException implements Exception {
  final String message;
  final String? errorCode;
  const _SkinCareResponseException(this.message, {this.errorCode});
  AiGenerationErrorCategory get category =>
      onboarding7AiErrorCategory(errorCode);
  @override
  String toString() => message;
}

enum _ProductInputSource { none, photo, typed }

@visibleForTesting
List<String> onboarding7SplitTypedProductNames(String? value) {
  return onboarding7ParseTypedProductDetails(value)
      .map((product) => product.displayName.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
}

@visibleForTesting
List<SkinCareDetectedProduct> onboarding7ParseTypedProductDetails(
  String? value,
) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return const [];
  final products = <SkinCareDetectedProduct>[];
  final seen = <String>{};

  for (final raw in _typedProductEntryStrings(text)) {
    final parsed = _typedProductFromLine(raw);
    if (parsed == null) continue;
    final key = [
      parsed.name.toLowerCase(),
      parsed.category.toLowerCase(),
    ].join('|');
    if (seen.add(key)) products.add(parsed);
  }

  return products;
}

@visibleForTesting
List<SkinCareDetectedProduct> onboarding7ReconcileReviewedProducts(
  String? value,
  Iterable<SkinCareDetectedProduct> existing,
) {
  final parsed = onboarding7ParseTypedProductDetails(value);
  final remaining = existing.toList(growable: true);
  return parsed
      .map((typed) {
        final typedName = _reviewedProductIdentity(typed);
        final typedCategory = typed.category.trim().toLowerCase();
        final index = remaining.indexWhere((candidate) {
          if (_reviewedProductIdentity(candidate) != typedName) return false;
          final candidateCategory = candidate.category.trim().toLowerCase();
          return typedCategory.isEmpty ||
              candidateCategory.isEmpty ||
              typedCategory == candidateCategory;
        });
        if (index < 0) return typed;
        final matched = remaining.removeAt(index);
        return SkinCareDetectedProduct(
          name: typed.name,
          brand: typed.brand.isNotEmpty ? typed.brand : matched.brand,
          category: typed.category.isNotEmpty
              ? typed.category
              : matched.category,
          source: matched.source.isNotEmpty ? matched.source : typed.source,
          keyIngredients: matched.keyIngredients,
          possibleActives: matched.possibleActives,
          usageHint: matched.usageHint,
          warningIfAny: matched.warningIfAny,
          confidence: matched.confidence,
        );
      })
      .toList(growable: false);
}

String _reviewedProductIdentity(SkinCareDetectedProduct product) {
  return (product.displayName.trim().isNotEmpty
          ? product.displayName
          : product.fallbackLabel)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

Iterable<String> _typedProductEntryStrings(String text) sync* {
  for (final raw in text.split(RegExp(r'[\n;]+'))) {
    final entry = raw.trim();
    if (entry.isEmpty) continue;
    if (_canSplitTypedProductEntryOnComma(entry)) {
      for (final commaPart in entry.split(',')) {
        final part = commaPart.trim();
        if (part.isNotEmpty) yield part;
      }
    } else {
      yield entry;
    }
  }
}

bool _canSplitTypedProductEntryOnComma(String entry) {
  if (!entry.contains(',')) return false;
  if (RegExp(r'\s+-\s+').hasMatch(entry)) return false;
  if (RegExp(r'\s*:\s+').hasMatch(entry)) return false;
  if (RegExp(r'\([^()]+\)').hasMatch(entry)) return false;
  return true;
}

@visibleForTesting
List<String> onboarding7ExtractPhotoProductNames(List<dynamic> products) {
  return _dedupeSkinCareNames(
    products
        .map(SkinCareDetectedProduct.fromValue)
        .where((product) => product.hasMeaningfulData)
        .map((product) => product.fallbackLabel)
        .where((name) => name.isNotEmpty),
  );
}

@visibleForTesting
List<String> onboarding7MergeProductNames(
  List<String> photoProducts,
  List<String> typedProducts,
) {
  return _dedupeSkinCareNames([...photoProducts, ...typedProducts]);
}

@visibleForTesting
List<String> onboarding7SpecialCareNotesFromAiResult({
  required Iterable<String> suggestedProducts,
  required Iterable<dynamic> weeklyRoutine,
  required Iterable<SkinCareRoutinePlan> specialCarePlans,
  List<String>? ownedProductNames,
}) {
  final notes = _dedupeSkinCareNames([
    ...suggestedProducts.map(_capSkinCareNote),
    ...weeklyRoutine.map(_weeklyRoutineNoteFromValue),
    ...specialCarePlans.map(_specialCareNoteFromPlan),
  ]);

  if (ownedProductNames != null && ownedProductNames.isNotEmpty) {
    final ownedNames = ownedProductNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    return notes
        .where(
          (note) => _onboarding7OwnedProductModeNoteAllowed(note, ownedNames),
        )
        .toList(growable: false);
  }

  return notes;
}

bool _onboarding7OwnedProductModeNoteAllowed(
  String note,
  List<String> ownedProductNames,
) {
  final lower = note.toLowerCase();
  final mentionsOwned = _onboarding7NoteMentionsOwnedProduct(
    note,
    ownedProductNames,
  );
  if (_onboarding7MentionsOutsideBrand(lower) &&
      !_onboarding7OutsideBrandIsOwned(lower, ownedProductNames)) {
    return false;
  }
  if (mentionsOwned) return true;

  if (lower.contains('no moisturizer') ||
      lower.contains('missing moisturizer') ||
      lower.contains('no sunscreen') ||
      lower.contains('missing sunscreen') ||
      lower.contains('no cleanser') ||
      lower.contains('missing cleanser')) {
    return true;
  }
  if (lower.startsWith('warning') || lower.contains('warning:')) {
    return true;
  }
  if (lower.startsWith('missing:')) {
    return true;
  }

  return false;
}

bool _onboarding7MentionsOutsideBrand(String lower) {
  return lower.contains('cerave') ||
      lower.contains('cera ve') ||
      lower.contains('la roche') ||
      lower.contains('laroche') ||
      lower.contains('posay') ||
      lower.contains('paula');
}

bool _onboarding7OutsideBrandIsOwned(
  String noteLower,
  List<String> ownedProductNames,
) {
  return ownedProductNames.any((owned) {
    final lower = owned.toLowerCase();
    return (noteLower.contains('cerave') && lower.contains('cerave')) ||
        (noteLower.contains('cera ve') && lower.contains('cera ve')) ||
        (noteLower.contains('la roche') && lower.contains('la roche')) ||
        (noteLower.contains('laroche') && lower.contains('laroche')) ||
        (noteLower.contains('posay') && lower.contains('posay')) ||
        (noteLower.contains('paula') && lower.contains('paula'));
  });
}

bool _onboarding7NoteMentionsOwnedProduct(
  String note,
  List<String> ownedProductNames,
) {
  final noteKey = _onboarding7NormalizedNoteKey(note);
  final noteTokens = noteKey
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toSet();

  for (final owned in ownedProductNames) {
    final ownedKey = _onboarding7NormalizedNoteKey(owned);
    if (ownedKey.isEmpty) continue;
    if (noteKey.contains(ownedKey)) return true;

    final tokens = ownedKey
        .split(' ')
        .where((token) => token.length > 2)
        .where((token) => !_onboarding7GenericNoteTokens.contains(token))
        .toList(growable: false);
    if (tokens.isNotEmpty && tokens.every(noteTokens.contains)) {
      return true;
    }
  }
  return false;
}

const Set<String> _onboarding7GenericNoteTokens = {
  'the',
  'and',
  'with',
  'for',
  'skin',
  'care',
  'product',
  'daily',
  'apply',
  'use',
  'routine',
};

String _onboarding7NormalizedNoteKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

@visibleForTesting
List<TimelineBlockDraft> onboarding7TimelineBlocksFromWorkerBlocks(
  List<dynamic> rawBlocks, {
  DateTime? now,
}) {
  final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final blocks = <TimelineBlockDraft>[];

  for (var index = 0; index < rawBlocks.length; index += 1) {
    final raw = rawBlocks[index];
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final title = _stringValue(map['title'] ?? map['name']).trim();
    if (title.isEmpty) continue;

    final start = _minuteValue(
      map['startMinute'] ??
          map['start_minutes'] ??
          map['start'] ??
          map['startTimeMinute'],
    );
    final end = _minuteValue(
      map['endMinute'] ??
          map['end_minutes'] ??
          map['end'] ??
          map['endTimeMinute'],
    );
    if (start == null || end == null) continue;
    final safeStart = start.clamp(0, 24 * 60 - 1).toInt();
    final safeEnd = end.clamp(1, 24 * 60).toInt();
    if (safeEnd <= safeStart) continue;

    final repeatDays = _repeatDaysValue(map['repeatDays'] ?? map['days']);
    final products = _dedupeSkinCareNames([
      ..._skinCareNamesFromValue(map['skincareProducts']),
      ..._skinCareNamesFromValue(map['products']),
      ..._skinCareNamesFromValue(map['productNames']),
    ]);
    final steps = _dedupeSkinCareNames([
      ..._skinCareNamesFromValue(map['skincareSteps']),
      ..._skinCareNamesFromValue(map['steps']),
      ..._skinCareNamesFromValue(map['orderedSteps']),
      ..._skinCareNamesFromValue(map['instructions']),
    ]);
    final missingItems = _dedupeSkinCareNames([
      ..._skinCareMissingItemLabelsFromValue(map['skincareMissingItems']),
      ..._skinCareMissingItemLabelsFromValue(map['missingItems']),
      ..._skinCareMissingItemLabelsFromValue(map['missing_products']),
    ]);
    if (products.isEmpty && steps.isEmpty) continue;

    final id = _stringValue(map['id']).trim();
    blocks.add(
      TimelineBlockDraft(
        id: id.isEmpty ? 'skin-care-$timestamp-$index' : id,
        section: 'skin_care',
        title: title,
        startMinute: safeStart,
        endMinute: safeEnd,
        repeatDays: repeatDays.isEmpty ? onboardingEveryDay() : repeatDays,
        blockType: TimelineBlockDraft.softBlockKey,
        source: onboardingSkinCareGeneratedSource,
        skincareProducts: products,
        skincareSteps: steps,
        skincareMissingItems: missingItems,
        skincareSlotLabel: _stringValue(
          map['slotLabel'] ?? map['slot'] ?? map['timeOfDay'],
        ).trim(),
      ),
    );
  }

  return blocks;
}

@visibleForTesting
List<SkinCareRoutinePlan> onboarding7RoutinePlansFromWorkerBlocks(
  List<dynamic> rawBlocks,
) {
  return rawBlocks
      .whereType<Map>()
      .map((raw) => SkinCareRoutinePlan.fromMap(Map<String, dynamic>.from(raw)))
      .where((plan) => plan.steps.isNotEmpty || plan.productNames.isNotEmpty)
      .toList(growable: false);
}

@visibleForTesting
String onboarding7FriendlyAiMessage(String? error, List<String> warnings) {
  final messages = [
    if (error?.trim().isNotEmpty == true) error!.trim(),
    ...warnings
        .map((warning) => warning.trim())
        .where((warning) => warning.isNotEmpty),
  ];
  final text = messages.join(' ').toLowerCase();

  if (text.contains('worker_mode_disabled')) {
    if (kDebugMode) {
      return 'Real AI is not configured. Enable worker mode with --dart-define=OPTIVUS_AI_WORKERS_MODE=worker and set --dart-define=OPTIVUS_SKIN_CARE_WORKER_URL=<skin-care-worker-url>.';
    }
    return 'Skin care AI is unavailable right now. Please try again later.';
  }
  if (text.contains('missing_worker_url') ||
      text.contains('worker url') ||
      text.contains('worker is not configured') ||
      text.contains('not configured')) {
    if (kDebugMode) {
      return 'Real AI is not configured. Missing skin-care worker URL. Run Flutter with --dart-define=OPTIVUS_SKIN_CARE_WORKER_URL=<skin-care-worker-url>.';
    }
    return 'Skin care AI is unavailable right now. Please try again later.';
  }
  if (text.contains('no_products_detected')) {
    return _onboarding7PhotoUnreadableMessage;
  }
  if (text.contains('ai_recommendation_repair_failed')) {
    return "We found some products, but couldn't complete the required product set right now. Retry product recommendations.";
  }
  if (text.contains('provider_unauthorized')) {
    return 'Skin care AI provider authorization failed. Check the worker configuration.';
  }
  if (text.contains('provider_model_not_found')) {
    return 'Skin care AI model is unavailable. Check the worker model configuration.';
  }
  if (text.contains('provider_timeout') ||
      text.contains('provider_unavailable') ||
      text.contains('provider_request_failed') ||
      text.contains('network_unavailable')) {
    return 'AI skin care service is unavailable. Try again later.';
  }
  if (text.contains('provider_invalid_image_payload')) {
    return 'AI could not process this photo. Upload a clearer JPEG, PNG, or WEBP image.';
  }
  if (text.contains('provider_invalid_request')) {
    return 'AI could not process this request. Please try again.';
  }
  if (text.contains('unsupported_content_type') ||
      text.contains('content type') ||
      text.contains('format')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  if (text.contains('r2_image_missing') || text.contains('not found')) {
    return 'Uploaded product photo could not be found. Please upload again.';
  }
  if (text.contains('json_payload_too_large') ||
      text.contains('product details were too large')) {
    return 'Skin-care product details were too large to send. Try typing your main products or upload a clearer single photo.';
  }
  if (text.contains('image_payload_too_large') ||
      text.contains('payload_too_large') ||
      text.contains('too large')) {
    return 'Product photo is too large. Upload a smaller, clearer photo.';
  }
  if (text.contains('provider_quota_exceeded') || text.contains('rate_limit')) {
    return 'AI usage limit reached. Try again later.';
  }
  if (text.contains('provider_high_demand')) {
    return 'AI is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_invalid_response') ||
      text.contains('provider_invalid_json')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (text.contains('ai_missing_required_slot:midday')) {
    return 'AI returned no midday routine for 3/day. Try again or choose 2 times/day.';
  }
  if (text.contains('ai_missing_required_slot:afternoon')) {
    return 'AI returned no afternoon routine for 4/day. Try again or choose 3 times/day.';
  }
  if (text.contains('ai_extra_daily_slot_count')) {
    return 'AI returned too many routines for some days. Try again.';
  }
  if (text.contains('ai_wrong_daily_slot_count')) {
    return 'AI returned the wrong daily routine count. Try again or choose fewer times per day.';
  }
  if (text.contains('ai_returned_fewer_routines')) {
    return _onboarding7AiFewerRoutinesMessage;
  }
  if (text.contains('unavailable')) {
    return 'AI skin care service is unavailable. Try again later.';
  }
  if (messages.isNotEmpty &&
      !messages.first.startsWith('provider_') &&
      !messages.first.toLowerCase().contains('exception') &&
      !messages.first.toLowerCase().contains('raw_') &&
      !messages.first.toLowerCase().contains('secret') &&
      !messages.first.contains('{') &&
      !messages.first.contains('}')) {
    return messages.first;
  }
  return 'AI failed to generate a routine. Try adding more details.';
}

@visibleForTesting
String onboarding7UnexpectedAiMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('failed host lookup') ||
      text.contains('timed out') ||
      text.contains('timeout')) {
    return 'AI skin care service is unavailable. Check your connection and try again.';
  }
  if (text.contains('formatexception') ||
      text.contains('invalid json') ||
      text.contains('is not a subtype of')) {
    return 'AI response could not be read safely. Please try again.';
  }
  return 'AI could not generate the routine. Please try again.';
}

String _skinCareNameFromProduct(dynamic item) {
  if (item is String) return item.trim();
  if (item is Map) {
    final map = Map<String, dynamic>.from(item);
    final name = _stringValue(map['name']).trim();
    if (name.isEmpty) return '';
    final brand = _stringValue(map['brand']).trim();
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }
    return '$brand $name';
  }
  return '';
}

SkinCareDetectedProduct? _typedProductFromLine(String rawLine) {
  final line = rawLine.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (line.isEmpty) return null;

  String name = line;
  String category = '';

  final parenthetical = RegExp(r'^(.+?)\s*\(([^()]+)\)\s*$').firstMatch(line);
  if (parenthetical != null) {
    final candidateCategory = _normalizeTypedProductCategory(
      parenthetical.group(2) ?? '',
    );
    if (candidateCategory.isNotEmpty) {
      name = parenthetical.group(1)?.trim() ?? line;
      category = candidateCategory;
    }
  }

  if (category.isEmpty) {
    final dash = RegExp(r'^(.+?)\s+-\s+(.+)$').firstMatch(line);
    if (dash != null) {
      final candidateCategory = _normalizeTypedProductCategory(
        dash.group(2) ?? '',
      );
      if (candidateCategory.isNotEmpty) {
        name = dash.group(1)?.trim() ?? line;
        category = candidateCategory;
      }
    }
  }

  if (category.isEmpty) {
    final colon = RegExp(r'^(.+?)\s*:\s+(.+)$').firstMatch(line);
    if (colon != null) {
      final candidateCategory = _normalizeTypedProductCategory(
        colon.group(2) ?? '',
      );
      if (candidateCategory.isNotEmpty) {
        name = colon.group(1)?.trim() ?? line;
        category = candidateCategory;
      }
    }
  }

  name = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty) return null;
  category = category.isEmpty ? _inferTypedProductCategory(name) : category;

  final meta = _enrichTypedProductMetadata(category, name);
  return SkinCareDetectedProduct(
    name: name,
    category: category,
    source: 'typed',
    keyIngredients: meta['keyIngredients'] as List<String>,
    possibleActives: meta['possibleActives'] as List<String>,
    usageHint: meta['usageHint'] as String,
    warningIfAny: meta['warningIfAny'] as String,
    confidence: 'high',
  );
}

Map<String, dynamic> _enrichTypedProductMetadata(String category, String name) {
  final lower = name.toLowerCase();
  final keyIngredients = <String>[];
  final possibleActives = <String>[];
  String usageHint = '';
  String warningIfAny = '';

  switch (category) {
    case 'cleanser':
      keyIngredients.addAll(['gentle surfactants', 'water']);
      usageHint = 'Apply AM/PM to cleanse skin';
      break;
    case 'moisturizer':
      keyIngredients.addAll(['ceramides', 'glycerin']);
      usageHint = 'Apply AM/PM after cleansing/serums';
      break;
    case 'sunscreen':
      keyIngredients.addAll(['UV filters']);
      possibleActives.add('zinc oxide');
      usageHint = 'Apply every morning as last step';
      break;
    case 'vitamin_c_serum':
      keyIngredients.add('L-ascorbic acid');
      possibleActives.add('Vitamin C');
      usageHint = 'Apply AM before moisturizer';
      break;
    case 'treatment_serum':
      if (lower.contains('retinol') || lower.contains('retinal')) {
        possibleActives.add('Retinol');
        usageHint = 'Apply PM 2-3x weekly';
        warningIfAny = 'Use sunscreen during daytime';
      } else if (lower.contains('niacinamide')) {
        possibleActives.add('Niacinamide');
        usageHint = 'Apply AM/PM';
      } else {
        possibleActives.add('active ingredient');
        usageHint = 'Apply as directed';
      }
      break;
    case 'exfoliant':
      possibleActives.addAll(['AHA', 'BHA']);
      usageHint = 'Use 1-3x weekly PM';
      warningIfAny = 'Avoid combining with other strong acids in same routine';
      break;
  }

  return {
    'keyIngredients': keyIngredients,
    'possibleActives': possibleActives,
    'usageHint': usageHint,
    'warningIfAny': warningIfAny,
  };
}

String _normalizeTypedProductCategory(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return '';

  if (normalized.contains('vitamin c')) {
    return 'vitamin_c_serum';
  }
  if (normalized.contains('treatment serum') ||
      normalized == 'treatment' ||
      normalized.contains('spot treatment')) {
    return 'treatment_serum';
  }
  if (normalized.contains('sunscreen') ||
      normalized.contains('sun protection') ||
      normalized.contains('sun cream') ||
      normalized.contains('sunblock') ||
      RegExp(r'(^| )spf( |$)').hasMatch(normalized)) {
    return 'sunscreen';
  }
  if (normalized.contains('cleanser') ||
      normalized.contains('face wash') ||
      normalized.contains('facial wash') ||
      normalized.contains('facewash') ||
      normalized.contains('cleansing gel') ||
      normalized.contains('cleansing foam')) {
    return 'cleanser';
  }
  if (normalized.contains('moistur') ||
      normalized.contains('hydrator') ||
      normalized.contains('hydrating gel') ||
      normalized.contains('hydration') ||
      normalized.contains('barrier cream') ||
      normalized.contains('barrier repair') ||
      normalized.contains('water gel') ||
      normalized.contains('face cream')) {
    return 'moisturizer';
  }

  const known = {
    'cleanser',
    'face wash',
    'moisturizer',
    'moisturiser',
    'sunscreen',
    'spf',
    'serum',
    'toner',
    'exfoliant',
    'exfoliator',
    'lip balm',
    'face mask',
    'mask',
    'spot treatment',
    'treatment',
    'treatment serum',
    'vitamin c serum',
    'retinol',
  };
  if (!known.contains(normalized)) return '';
  return switch (normalized) {
    'face wash' => 'cleanser',
    'moisturiser' => 'moisturizer',
    'spf' => 'sunscreen',
    'exfoliator' => 'exfoliant',
    'mask' => 'face mask',
    'spot treatment' ||
    'treatment' ||
    'treatment serum' ||
    'retinol' => 'treatment_serum',
    'vitamin c serum' => 'vitamin_c_serum',
    _ => normalized,
  };
}

String _inferTypedProductCategory(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('sunscreen') ||
      lower.contains('spf') ||
      lower.contains('sun cream') ||
      lower.contains('suncream') ||
      lower.contains('sunblock')) {
    return 'sunscreen';
  }
  if (lower.contains('cleanser') ||
      lower.contains('face wash') ||
      lower.contains('cleanse')) {
    return 'cleanser';
  }
  if (lower.contains('moisturiz') ||
      lower.contains('moisturis') ||
      lower.contains('cream') ||
      lower.contains('lotion')) {
    return 'moisturizer';
  }
  if (lower.contains('vitamin c')) {
    return 'vitamin_c_serum';
  }
  if (lower.contains('treatment serum') ||
      lower.contains('alpha arbutin') ||
      lower.contains('niacinamide') ||
      lower.contains('azelaic') ||
      lower.contains('retinol') ||
      lower.contains('retinal') ||
      lower.contains('benzoyl peroxide') ||
      lower.contains('salicylic serum')) {
    return 'treatment_serum';
  }
  if (lower.contains('serum')) return 'serum';
  if (lower.contains('toner')) return 'toner';
  if (lower.contains('exfoliant') ||
      lower.contains('exfoliator') ||
      _containsAcidInitialism(lower, 'aha') ||
      _containsAcidInitialism(lower, 'bha') ||
      _containsAcidInitialism(lower, 'pha')) {
    return 'exfoliant';
  }
  return '';
}

const List<String> _onboarding7EssentialProductCategories = [
  'cleanser',
  'moisturizer',
  'sunscreen',
];

const int _onboarding7MaximumRecommendations = 10;

@visibleForTesting
List<SkinCareProductRecommendation> onboarding7NormalizeRecommendations(
  Iterable<SkinCareProductRecommendation> products, {
  String? expectedCurrencyCode,
}) {
  final expectedCurrency = expectedCurrencyCode?.trim().toUpperCase();
  final valid = <SkinCareProductRecommendation>[];
  final seen = <String>{};
  for (final product in products) {
    if (product.name.trim().isEmpty ||
        product.brand.trim().isEmpty ||
        product.category.trim().isEmpty ||
        product.estimatedPrice.trim().isEmpty ||
        product.currencyCode.trim().isEmpty ||
        product.reason.trim().isEmpty ||
        (expectedCurrency != null &&
            (product.currencyCode.trim().toUpperCase() != expectedCurrency ||
                !onboarding7PriceMatchesCurrency(
                  product.estimatedPrice,
                  expectedCurrency,
                )))) {
      continue;
    }
    final key = normalizeSkinCareSelectionKey(product.displayName);
    if (key.isNotEmpty && seen.add(key)) valid.add(product);
  }

  final grouped = <String, List<SkinCareProductRecommendation>>{};
  for (final product in valid) {
    final draft = SkinCareProductRecommendationDraft(
      name: product.name,
      brand: product.brand,
      category: product.category,
      estimatedPrice: product.estimatedPrice,
      currencyCode: product.currencyCode,
      reason: product.reason,
    );
    grouped
        .putIfAbsent(onboarding7RecommendationCategory(draft), () => [])
        .add(product);
  }

  final result = <SkinCareProductRecommendation>[];
  for (final category in _onboarding7EssentialProductCategories) {
    result.addAll((grouped[category] ?? const []).take(2));
  }
  for (final product in valid) {
    if (result.length >= _onboarding7MaximumRecommendations) break;
    if (!result.contains(product)) result.add(product);
  }
  return result
      .take(_onboarding7MaximumRecommendations)
      .toList(growable: false);
}

@visibleForTesting
bool onboarding7PriceMatchesCurrency(
  String estimatedPrice,
  String expectedCurrencyCode,
) {
  final price = estimatedPrice.trim().toUpperCase();
  final expected = expectedCurrencyCode.trim().toUpperCase();
  if (price.isEmpty || expected.isEmpty) return false;
  const knownCodes = {
    'AED',
    'AUD',
    'BDT',
    'BRL',
    'CAD',
    'CHF',
    'CNY',
    'CZK',
    'DKK',
    'EGP',
    'EUR',
    'GBP',
    'HKD',
    'IDR',
    'INR',
    'JPY',
    'KRW',
    'LKR',
    'MYR',
    'MXN',
    'NGN',
    'NOK',
    'NPR',
    'NZD',
    'PHP',
    'PKR',
    'PLN',
    'SAR',
    'SEK',
    'SGD',
    'THB',
    'TRY',
    'TWD',
    'USD',
    'VND',
    'ZAR',
  };
  for (final code in knownCodes) {
    if (code != expected &&
        RegExp('(^|[^A-Z])$code([^A-Z]|\$)').hasMatch(price)) {
      return false;
    }
  }
  if (price.contains('₹') && expected != 'INR') return false;
  if (price.contains('€') && expected != 'EUR') return false;
  if (price.contains('£') && expected != 'GBP') return false;
  if (price.contains('¥') && expected != 'JPY' && expected != 'CNY') {
    return false;
  }
  if (price.contains(r'$') &&
      !const {
        'USD',
        'CAD',
        'AUD',
        'NZD',
        'SGD',
        'HKD',
        'MXN',
        'BRL',
      }.contains(expected)) {
    return false;
  }
  return true;
}

/// Normalizes currency and estimated price display strings to prevent duplicated
/// prefixes (such as "INR INR 300-400" or "\$ \$15").
///
/// Pure display helper: does not mutate Worker response contracts or persisted drafts.
String formatSkinCarePriceDisplay(
  String? currencyCode,
  String? estimatedPrice,
) {
  final price = estimatedPrice?.trim() ?? '';
  final code = currencyCode?.trim() ?? '';
  if (price.isEmpty) return '';
  if (code.isEmpty) return price;

  final codeUpper = code.toUpperCase();
  final priceUpper = price.toUpperCase();

  if (priceUpper.startsWith(codeUpper)) {
    final remainder = price.substring(code.length).trim();
    return remainder.isNotEmpty ? '$codeUpper $remainder' : codeUpper;
  }

  const symbols = {'INR': '₹', 'USD': r'$', 'EUR': '€', 'GBP': '£', 'JPY': '¥'};
  final symbol = symbols[codeUpper];
  if (symbol != null && price.startsWith(symbol)) {
    return price;
  }

  return '$codeUpper $price';
}

@visibleForTesting
String onboarding7RecommendationCategory(
  SkinCareProductRecommendationDraft product,
) {
  final explicit = _normalizeTypedProductCategory(product.category);
  if (explicit == 'serum') {
    final inferred = _inferTypedProductCategory(product.displayName);
    if (inferred == 'vitamin_c_serum' || inferred == 'treatment_serum') {
      return inferred;
    }
  }
  if (explicit.isNotEmpty) return explicit;
  return _inferTypedProductCategory(product.displayName);
}

String _onboarding7ProductSelectionGroup(
  SkinCareProductRecommendationDraft product,
) {
  final category = onboarding7RecommendationCategory(product);
  if (category.isNotEmpty) return category;
  final rawCategory = product.category
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return rawCategory.isNotEmpty ? rawCategory : product.selectionKey;
}

@visibleForTesting
List<String> onboarding7MissingEssentialRecommendationCategories(
  Iterable<SkinCareProductRecommendationDraft> products, {
  Iterable<String>? selectedProductNames,
}) {
  final selectedKeys = selectedProductNames
      ?.map((name) => normalizeSkinCareSelectionKey(name))
      .where((name) => name.isNotEmpty)
      .toSet();
  final categories = <String>{};
  for (final product in products) {
    if (selectedKeys != null && !selectedKeys.contains(product.selectionKey)) {
      continue;
    }
    final category = onboarding7RecommendationCategory(product);
    if (category.isNotEmpty) categories.add(category);
  }
  return _onboarding7EssentialProductCategories
      .where((category) => !categories.contains(category))
      .toList(growable: false);
}

String _onboarding7EssentialSelectionMessage(List<String> missing) {
  if (missing.isEmpty) return '';
  final labels = missing
      .map(_onboarding7ProductCategoryLabel)
      .toList(growable: false);
  if (labels.length == 1) return 'Select a ${labels.single} to continue.';
  if (labels.length == 2) {
    return 'Select a ${labels.first} and ${labels.last} to continue.';
  }
  return 'Select ${labels.take(labels.length - 1).join(', ')}, and '
      '${labels.last} to continue.';
}

String _onboarding7ProductCategoryLabel(String category) {
  return switch (category) {
    'vitamin_c_serum' => 'Vitamin C serum',
    'treatment_serum' => 'treatment serum',
    _ => category.replaceAll('_', ' '),
  };
}

bool _containsAcidInitialism(String value, String token) {
  return RegExp('(^|[^a-z0-9])$token([^a-z0-9]|\$)').hasMatch(value);
}

String _weeklyRoutineNoteFromValue(dynamic item) {
  if (item is String) return _capSkinCareNote(item);
  if (item is! Map) return '';

  final map = Map<String, dynamic>.from(item);
  final title = _firstTextValue(map, const ['title', 'name']).trim();
  final products = _readNoteParts(map['products'] ?? map['productNames']);
  final steps = _readNoteParts(
    map['steps'] ?? map['orderedSteps'] ?? map['instructions'],
  );
  final warnings = _readNoteParts(map['warnings'] ?? map['warningIfAny']);
  final detailParts = _dedupeSkinCareNames([
    ...products,
    ...steps,
    ...warnings,
  ]);

  if (title.isNotEmpty && detailParts.isNotEmpty) {
    return _capSkinCareNote('Special care: $title - ${detailParts.join('; ')}');
  }
  if (title.isNotEmpty) return _capSkinCareNote('Special care: $title');
  if (detailParts.isNotEmpty) {
    return _capSkinCareNote('Special care: ${detailParts.join('; ')}');
  }
  return '';
}

String _specialCareNoteFromPlan(SkinCareRoutinePlan plan) {
  final title = plan.title.trim().isNotEmpty
      ? plan.title.trim()
      : plan.slotLabel.trim();
  final detailParts = _dedupeSkinCareNames([
    ...plan.productNames,
    ...plan.steps,
    ...plan.warnings,
    if (plan.repeatDays.isNotEmpty && plan.repeatDays.length < 7)
      'repeat ${_repeatDaysLabel(plan.repeatDays)}',
  ]);

  if (title.isNotEmpty && detailParts.isNotEmpty) {
    return _capSkinCareNote('Special care: $title - ${detailParts.join('; ')}');
  }
  if (title.isNotEmpty) return _capSkinCareNote('Special care: $title');
  if (detailParts.isNotEmpty) {
    return _capSkinCareNote('Special care: ${detailParts.join('; ')}');
  }
  return '';
}

String _firstTextValue(Map<String, dynamic> map, Iterable<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

List<String> _readNoteParts(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    return value
        .split(RegExp(r'[\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is List) {
    return value
        .map((item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            return _firstTextValue(map, const [
              'title',
              'name',
              'productName',
              'product',
              'instruction',
              'step',
              'text',
              'warning',
            ]);
          }
          return _stringValue(item).trim();
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is Map) {
    final text = _firstTextValue(Map<String, dynamic>.from(value), const [
      'title',
      'name',
      'productName',
      'product',
      'instruction',
      'step',
      'text',
      'warning',
    ]);
    return text.isEmpty ? const [] : [text];
  }
  final text = _stringValue(value).trim();
  return text.isEmpty ? const [] : [text];
}

String _capSkinCareNote(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= _onboarding7SpecialCareNoteMaxLength) {
    return normalized;
  }
  return '${normalized.substring(0, _onboarding7SpecialCareNoteMaxLength - 3)}...';
}

String _repeatDaysLabel(List<int> days) {
  const labels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };
  final normalized =
      days.where((day) => labels.containsKey(day)).toSet().toList()..sort();
  return normalized.map((day) => labels[day]!).join('/');
}

List<String> _skinCareNamesFromValue(dynamic value) {
  if (value == null) return const [];
  if (value is String) return onboarding7SplitTypedProductNames(value);
  if (value is List) return onboarding7ExtractPhotoProductNames(value);
  final name = _skinCareNameFromProduct(value);
  return name.isEmpty ? const [] : [name];
}

List<String> _skinCareMissingItemLabelsFromValue(dynamic value) {
  if (value == null) return const [];
  if (value is String) return onboarding7SplitTypedProductNames(value);
  if (value is List) {
    return value
        .expand(_skinCareMissingItemLabelsFromValue)
        .toList(growable: false);
  }
  if (value is Map) {
    final item = SkinCareMissingItem.fromMap(Map<String, dynamic>.from(value));
    final label = item.displayLabel.trim();
    return label.isEmpty ? const [] : [label];
  }
  final label = _stringValue(value).trim();
  return label.isEmpty ? const [] : [label];
}

List<String> _dedupeSkinCareNames(Iterable<String> source) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in source) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.add(key)) result.add(value);
  }
  return result;
}

String _stringValue(dynamic value) => value == null ? '' : value.toString();

int? _minuteValue(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<int> _repeatDaysValue(dynamic value) {
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

String _friendlySkinCareUploadMessage(String? message) {
  final value = message?.trim();
  if (value == null || value.isEmpty) return 'Photo upload failed. Try again.';
  final lower = value.toLowerCase();
  if (lower.contains('expired') ||
      lower.contains('r2uploadexpiredurlexception')) {
    return 'Upload URL expired. Tap retry to get a fresh upload link.';
  }
  if (lower.contains('network') ||
      lower.contains('socketexception') ||
      lower.contains('r2uploadnetworkexception')) {
    return 'Network connection failed during photo upload. Please check your connection and retry.';
  }
  if (lower.contains('markcomplete') ||
      lower.contains('r2uploadmarkcompleteexception')) {
    return 'Failed to confirm photo upload. Please tap retry.';
  }
  if (lower.contains('heic') ||
      lower.contains('heif') ||
      lower.contains('format') ||
      lower.contains('content type')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  // Safe default: never leak raw exception or unmapped technical strings
  return 'Photo upload failed. Please try again.';
}

String _skinCareInteractionStatusLabel(UploadInteractionPhase phase) {
  return switch (phase) {
    UploadInteractionPhase.preparing => 'Preparing photo...',
    UploadInteractionPhase.uploading => 'Uploading photo...',
    UploadInteractionPhase.processing => 'Saving photo...',
    _ => 'Uploading photo...',
  };
}

bool _isSupportedSkinCareImageContentType(String contentType) {
  final normalized = contentType.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return normalized == 'image/jpeg' ||
      normalized == 'image/png' ||
      normalized == 'image/webp';
}

String _skinCareImageContentTypeFromR2Key(String r2Key) {
  final key = r2Key.split('?').first.toLowerCase();
  if (key.endsWith('.png')) return 'image/png';
  if (key.endsWith('.webp')) return 'image/webp';
  if (key.endsWith('.heic')) return 'image/heic';
  if (key.endsWith('.heif')) return 'image/heif';
  if (key.endsWith('.gif')) return 'image/gif';
  if (key.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}

@visibleForTesting
UploadedAsset? durableSkinProductsAssetFromDraft(OnboardingDraft draft) {
  final base = draft.baseTimeline;
  if (base.skinCareSetupPath != "has_products") return null;
  final assetId = base.skinCareProductPhotoAssetId?.trim() ?? '';
  final r2Key = base.skinCareProductPhotoR2Key?.trim() ?? '';
  final createdAt =
      base.skinCareProductPhotoCreatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final assetStatus = uploadedAssetStatusFromString(
    base.skinCareProductPhotoStatus,
  );
  final asset = UploadedAsset(
    assetId: assetId,
    ownerUid: draft.uid,
    sourceFeature: OnboardingDraft.sourceOnboarding,
    purpose: UploadedAssetPurpose.skinProducts,
    fileName: r2Key.split('/').lastOrNull ?? 'skin-products-photo.jpg',
    contentType: _skinCareImageContentTypeFromR2Key(r2Key),
    sizeBytes: 0,
    r2Key: r2Key,
    status: assetStatus,
    createdAt: createdAt,
    updatedAt: base.skinCareProductPhotoUpdatedAt ?? createdAt,
  );
  if (isUsableSkinUpload(
        asset: asset,
        uid: draft.uid,
        expectedPurpose: UploadedAssetPurpose.skinProducts,
      ) ||
      legacySkinCareUploadHasOwnedExactIdentity(
        assetId: assetId,
        ownerUid: draft.uid,
        r2Key: r2Key,
        status: assetStatus,
        uid: draft.uid,
      )) {
    return asset;
  }
  return null;
}

@visibleForTesting
UploadedAsset? durableSkinFaceAssetFromDraft(OnboardingDraft draft) {
  final base = draft.baseTimeline;
  if (base.skinCareSetupPath != "no_products") return null;
  var assetId = base.skinCareFacePhotoAssetId?.trim() ?? "";
  var r2Key = base.skinCareFacePhotoR2Key?.trim() ?? "";
  var statusStr = base.skinCareFacePhotoStatus;
  var createdAt =
      base.skinCareFacePhotoCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  var updatedAt = base.skinCareFacePhotoUpdatedAt ?? createdAt;

  // Legacy migration for draft: if face photo is empty but product photo has data AND it is a legacy skin_care upload, use product photo
  if (assetId.isEmpty &&
      (base.skinCareProductPhotoAssetId?.trim() ?? "").isNotEmpty) {
    final legacyR2Key = base.skinCareProductPhotoR2Key?.trim() ?? "";
    if (legacyR2Key.contains('/skin_care/')) {
      assetId = base.skinCareProductPhotoAssetId!.trim();
      r2Key = legacyR2Key;
      statusStr = base.skinCareProductPhotoStatus;
      createdAt =
          base.skinCareProductPhotoCreatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      updatedAt = base.skinCareProductPhotoUpdatedAt ?? createdAt;
    }
  }

  final status = uploadedAssetStatusFromString(statusStr);
  if (status != UploadedAssetStatus.uploaded) return null;
  if (!r2Key.startsWith('users/${draft.uid}/')) return null;
  if (assetId.isEmpty || r2Key.isEmpty) return null;
  final asset = UploadedAsset(
    assetId: assetId,
    ownerUid: draft.uid,
    sourceFeature: OnboardingDraft.sourceOnboarding,
    purpose: UploadedAssetPurpose.skinFace,
    fileName: r2Key.split('/').lastOrNull ?? 'skin-face-photo.jpg',
    contentType: _skinCareImageContentTypeFromR2Key(r2Key),
    sizeBytes: 0,
    r2Key: r2Key,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  if (isUsableSkinUpload(
        asset: asset,
        uid: draft.uid,
        expectedPurpose: UploadedAssetPurpose.skinFace,
      ) ||
      legacySkinCareUploadHasOwnedExactIdentity(
        assetId: assetId,
        ownerUid: draft.uid,
        r2Key: r2Key,
        status: status,
        uid: draft.uid,
      )) {
    return asset;
  }
  return null;
}

UploadedAsset? _restoredSkinAssetForSlot({
  required RestoredUploadsState restored,
  required OnboardingDraft draft,
  required UploadedAssetPurpose purpose,
}) {
  final direct = restored.forPurpose(purpose)?.asset;
  if (direct != null) return direct;

  final legacy = restored.forPurpose(UploadedAssetPurpose.skinCare)?.asset;
  if (legacy == null) return null;
  final base = draft.baseTimeline;
  final path = base.skinCareSetupPath;

  if (path == 'has_products' && purpose == UploadedAssetPurpose.skinProducts) {
    if (base.skinCareProductPhotoAssetId?.trim() == legacy.assetId.trim()) {
      return legacy;
    }
  } else if (path == 'no_products' &&
      purpose == UploadedAssetPurpose.skinFace) {
    if (base.skinCareFacePhotoAssetId?.trim() == legacy.assetId.trim() ||
        base.skinCareProductPhotoAssetId?.trim() == legacy.assetId.trim()) {
      return legacy;
    }
  }

  return null;
}

_ProductInputSource _initialProductInputSource(BaseTimelineDraft base) {
  final hasPhoto = base.skinCareProductPhotoR2Key?.trim().isNotEmpty == true;
  if (hasPhoto) return _ProductInputSource.photo;
  final hasTypedText = base.skinCareProductNames?.trim().isNotEmpty == true;
  if (hasTypedText) return _ProductInputSource.typed;
  return _ProductInputSource.none;
}

String? _productInputSourceLabel(_ProductInputSource source) {
  return switch (source) {
    _ProductInputSource.photo => 'Using product photo',
    _ProductInputSource.typed => 'Using typed product names',
    _ProductInputSource.none => null,
  };
}

/// Resolves the canonical active uploaded asset for a Skin Care transaction.
///
/// In an active transaction (such as deferred replacement during Edit/Rebuild),
/// [slot.effectiveAsset] yields [pendingReplacementAsset]. If that candidate
/// matches the current Step-7 draft asset identity and strictly belongs to
/// [draft.uid], it is returned as the active transactional photo.
///
/// An empty or mismatched owner is strictly rejected for active transactions.
/// Otherwise, it falls back to the canonical durable asset constructed from
/// [draft.baseTimeline] (which preserves existing legacy migration logic).
UploadedAsset? currentSkinPhotoForTransaction({
  required UploadSlotRuntimeState? slot,
  required OnboardingDraft draft,
  required UploadedAssetPurpose purpose,
}) {
  final candidate = slot?.effectiveAsset;
  final base = draft.baseTimeline;
  final currentUid = draft.uid.trim();

  if (currentUid.isEmpty) return null;

  if (purpose == UploadedAssetPurpose.skinProducts) {
    final expectedAssetId = base.skinCareProductPhotoAssetId?.trim();
    final expectedR2Key = base.skinCareProductPhotoR2Key?.trim();
    if (candidate != null &&
        expectedAssetId != null &&
        expectedAssetId.isNotEmpty &&
        expectedR2Key != null &&
        expectedR2Key.isNotEmpty &&
        candidate.assetId == expectedAssetId &&
        candidate.r2Key == expectedR2Key &&
        candidate.ownerUid == currentUid) {
      return candidate;
    }
    return durableSkinProductsAssetFromDraft(draft);
  } else if (purpose == UploadedAssetPurpose.skinFace) {
    final expectedAssetId = base.skinCareFacePhotoAssetId?.trim();
    final expectedR2Key = base.skinCareFacePhotoR2Key?.trim();
    if (candidate != null &&
        expectedAssetId != null &&
        expectedAssetId.isNotEmpty &&
        expectedR2Key != null &&
        expectedR2Key.isNotEmpty &&
        candidate.assetId == expectedAssetId &&
        candidate.r2Key == expectedR2Key &&
        candidate.ownerUid == currentUid) {
      return candidate;
    }
    return durableSkinFaceAssetFromDraft(draft);
  }
  return null;
}
