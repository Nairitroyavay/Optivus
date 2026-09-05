import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/timeline/onboarding_timeline.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/providers/onboarding_upload_interaction_provider.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/services/device_country_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/auth_generation.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

const String onboardingSkinCareGeneratedSource = 'ai_skin_care_setup';
const String onboarding7CompactPayloadFinalMessage =
    'AI read too much product detail. Try typing only your main products or upload a clearer single photo.';
const int _onboarding7SpecialCareNoteMaxLength = 180;
const String _onboarding7NoTypedProductsMessage =
    'Type one product per line, for example "Daily SPF 50 - sunscreen".';
const String _onboarding7AiEmptyMessage =
    'AI returned no usable routine. Try clearer product names or 2 times/day.';
const String _onboarding7NoProductsAiEmptyMessage =
    'AI returned no usable starter routine. Try again or choose 2 times/day.';
const String _onboarding7AiFewerRoutinesMessage =
    'AI returned fewer routines than requested. Try again or choose fewer times per day.';
const String _onboarding7PhotoUnreadableMessage =
    'AI could not read your products. Upload a clearer photo or use typed product names.';

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

class _SkinCareResponseException implements Exception {
  final String message;
  const _SkinCareResponseException(this.message);
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
  Iterable<SkinCareProductRecommendation> products,
) {
  final valid = <SkinCareProductRecommendation>[];
  final seen = <String>{};
  for (final product in products) {
    if (product.name.trim().isEmpty ||
        product.brand.trim().isEmpty ||
        product.category.trim().isEmpty ||
        product.estimatedPrice.trim().isEmpty ||
        product.currencyCode.trim().isEmpty ||
        product.reason.trim().isEmpty) {
      continue;
    }
    final key = product.displayName.trim().toLowerCase();
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
      ?.map((name) => name.trim().toLowerCase())
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

class OnboardingStep7 extends ConsumerWidget {
  const OnboardingStep7({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(mockOnboardingProvider).draft.baseTimeline;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hasActivePath =
        base.skinCareSetupPath == 'has_products' ||
        base.skinCareSetupPath == 'no_products' ||
        base.skinCareSetupPath == 'skip' ||
        base.skinCareSkipped;
    final isChoice = base.skinCareSetupStep <= 0 || !hasActivePath;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!keyboardOpen) ...[
            const _SkinCareHeader(),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: isChoice
                ? _SkinCareChoiceScreen(base: base)
                : _SkinCareSelectedModeScreen(base: base),
          ),
        ],
      ),
    );
  }
}

class _SkinCareHeader extends StatelessWidget {
  const _SkinCareHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skin Care',
          style: TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Face and skin routine setup.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SkinCareChoiceScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareChoiceScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> select(String value) async {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      if (value == 'skip') {
        final draft = ref.read(mockOnboardingProvider).draft;
        final uid = ref.read(authProvider).user?.uid ?? draft.uid;
        final restored = ref.read(restoredUploadsProvider);
        if (uid.trim().isEmpty ||
            restored.isHydrating ||
            restored.errorMessage != null) {
          ref
              .read(mockOnboardingProvider.notifier)
              .setValidationMessage(
                'Reconnect before skipping so your private photos can be removed safely.',
              );
          return;
        }
        ref
            .read(mockOnboardingProvider.notifier)
            .setStepLoading(onboardingSkinCareStepIndex, true);
        final controller = ref.read(
          onboardingUploadInteractionProvider.notifier,
        );
        var cleanupSucceeded = true;
        for (final slot in const [
          onboardingSkinProductsUploadSlot,
          onboardingSkinFaceUploadSlot,
        ]) {
          final slotState = ref.read(onboardingUploadInteractionProvider)[slot];
          if (slotState?.hasDurableAsset == true) {
            cleanupSucceeded =
                await controller.remove(slot, uid: uid) && cleanupSucceeded;
          }
        }
        final repository = ref.read(uploadedAssetRepositoryProvider);
        final cleanupAssets = <String, UploadedAsset>{};
        final legacy = restored.forPurpose(UploadedAssetPurpose.skinCare)?.asset;
        if (legacy != null) cleanupAssets[legacy.assetId] = legacy;
        try {
          for (final asset in await repository.fetchRecentAssets(uid: uid, sourceFeature: 'onboarding', limit: 100)) {
            if (asset.errorMessage == 'private_cleanup_pending' &&
                const [UploadedAssetPurpose.skinCare, UploadedAssetPurpose.skinFace, UploadedAssetPurpose.skinProducts].contains(asset.purpose)) {
              cleanupAssets[asset.assetId] = asset;
            }
          }
          for (final asset in cleanupAssets.values) {
            await repository.saveAsset(asset.copyWith(
              status: UploadedAssetStatus.deleted,
              updatedAt: DateTime.now(),
              errorMessage: 'private_cleanup_pending',
            ));
            final token = await ref.read(authRepositoryProvider).currentIdToken();
            if (token == null || token.trim().isEmpty ||
                (ref.read(authProvider).user?.uid ?? ref.read(mockOnboardingProvider).draft.uid) != uid) {
              throw StateError('Private cleanup requires the same account');
            }
            await ref.read(r2UploadClientProvider).deleteUpload(objectKey: asset.r2Key, idToken: token);
            await repository.markDeleted(uid: uid, assetId: asset.assetId);
            ref.read(restoredUploadsProvider.notifier).removePurpose(uid: uid, purpose: asset.purpose);
          }
        } catch (_) {
          cleanupSucceeded = false;
        }
        ref
            .read(mockOnboardingProvider.notifier)
            .setStepLoading(onboardingSkinCareStepIndex, false);
        if (!cleanupSucceeded) {
          ref
              .read(mockOnboardingProvider.notifier)
              .setValidationMessage(
                'Your photo could not be removed yet. Try again before skipping.',
              );
          return;
        }
      }
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final isSkip = value == 'skip';
        final switchedPath = base.skinCareSetupPath != value;
        final legacyR2Key = base.skinCareProductPhotoR2Key?.trim() ?? '';
        final migrateLegacyFace =
            value == 'no_products' &&
            (base.skinCareSetupPath == 'has_products' ||
                base.skinCareSetupPath == 'no_products') &&
            (base.skinCareFacePhotoAssetId?.trim().isEmpty ?? true) &&
            (base.skinCareProductPhotoAssetId?.trim().isNotEmpty ?? false) &&
            legacyR2Key.contains('/skin_care/');
        final clearGeneratedData = isSkip || switchedPath;
        final blocks = switchedPath || isSkip
            ? base.blocks.where((b) => b.section != 'skin_care').toList()
            : base.blocks;
        return base.copyWith(
          blocks: blocks,
          skinCareSetupPath: value,
          skinCareSetupStep: 1,
          skinCareSkipped: isSkip,
          skinCareSpecialCareNotes: clearGeneratedData
              ? const []
              : base.skinCareSpecialCareNotes,
          skinCareFacePhotoAssetId: migrateLegacyFace
              ? base.skinCareProductPhotoAssetId
              : null,
          skinCareFacePhotoR2Key: migrateLegacyFace
              ? base.skinCareProductPhotoR2Key
              : null,
          skinCareFacePhotoStatus: migrateLegacyFace
              ? base.skinCareProductPhotoStatus
              : null,
          skinCareFacePhotoCreatedAt: migrateLegacyFace
              ? base.skinCareProductPhotoCreatedAt
              : null,
          skinCareFacePhotoUpdatedAt: migrateLegacyFace
              ? base.skinCareProductPhotoUpdatedAt
              : null,
          clearSkinCareProductNames: isSkip,
          clearSkinCareProductPhoto: isSkip || migrateLegacyFace,
          clearSkinCareFacePhoto: isSkip,
          clearSkinCareSkinType: isSkip,
          clearSkinCareProblems: isSkip,
          clearSkinCareBudget: isSkip,
          clearSkinCarePreference: isSkip,
          clearSkinCareProductRecommendations: isSkip,
          clearSkinCareSelectedProductNames: isSkip,
          clearSkinCareSuggestedProducts: isSkip,
          clearSkinCareReviewedProducts: isSkip,
          clearSkinCareRecommendationFingerprint: isSkip || switchedPath,
          clearSkinCareRoutineFingerprint: isSkip || switchedPath,
        );
      });
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SkinCarePathCard(
            title: 'I have products',
            subtitle: 'Type product names to build a routine.',
            icon: Icons.spa_rounded,
            accent: OptivusColors.roseAccent,
            selected:
                base.skinCareSetupPath == 'has_products' &&
                !base.skinCareSkipped,
            onTap: () => select('has_products'),
          ),
          const SizedBox(height: 12),
          _SkinCarePathCard(
            title: 'No products',
            subtitle: 'Get products for your skin, budget, and location.',
            icon: Icons.face_retouching_natural_rounded,
            accent: OptivusColors.purpleAccent,
            selected:
                base.skinCareSetupPath == 'no_products' &&
                !base.skinCareSkipped,
            onTap: () => select('no_products'),
          ),
          const SizedBox(height: 12),
          _SkinCarePathCard(
            title: 'Skip',
            subtitle: 'Skin care will be skipped for now.',
            icon: Icons.skip_next_rounded,
            accent: OptivusColors.textSecondary,
            selected: base.skinCareSetupPath == 'skip' || base.skinCareSkipped,
            onTap: () => select('skip'),
          ),
        ],
      ),
    );
  }
}

class _SkinCarePathCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _SkinCarePathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        tint: selected
            ? accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.48),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.62)
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCareSelectedModeScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareSelectedModeScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (base.skinCareSkipped || base.skinCareSetupPath == 'skip') {
      return const _SkipModeScreen();
    }

    final blocks = base.confirmedBlocksForSection('skin_care');

    if (base.skinCareSetupPath == 'has_products') {
      return _HasProductsModeScreen(base: base, blocks: blocks);
    }

    return _NoProductsModeScreen(base: base, blocks: blocks);
  }
}

class _SkipModeScreen extends StatelessWidget {
  const _SkipModeScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.textSecondary.withValues(alpha: 0.08),
          child: const Row(
            children: [
              Icon(Icons.skip_next_rounded, color: OptivusColors.textSecondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Skin care will be skipped for now.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HasProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _HasProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_HasProductsModeScreen> createState() =>
      _HasProductsModeScreenState();
}

class _HasProductsModeScreenState
    extends ConsumerState<_HasProductsModeScreen> {
  static const double _setupTileHeight = 184;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  late final AiGenerationController _lifecycle;
  bool _removingPhoto = false;
  bool _editingExisting = false;
  late bool _photoProductsReviewed;
  List<SkinCareDetectedProduct> _reviewedPhotoDetails = const [];
  String? _generationError;
  late _ProductInputSource _inputSource;
  int _selectedDay = DateTime.now().weekday;
  final _productNamesTargetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _lifecycle = AiGenerationController()..addListener(_onLifecycleChanged);
    _controller = TextEditingController(text: widget.base.skinCareProductNames);
    _focusNode = FocusNode();
    final draft = ref.read(mockOnboardingProvider).draft;
    _uploadedAsset =
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinProducts,
        ) ??
        durableSkinProductsAssetFromDraft(draft);
    _inputSource = _uploadedAsset != null
        ? _ProductInputSource.photo
        : _initialProductInputSource(widget.base);
    _reviewedPhotoDetails = widget.base.skinCareReviewedProducts;
    _photoProductsReviewed =
        _inputSource == _ProductInputSource.photo &&
        _reviewedPhotoDetails.isNotEmpty;
  }

  void _onLifecycleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_onLifecycleChanged);
    _lifecycle.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    final initialUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    if (initialUploadState?.isBusy == true) return;
    final retrying =
        initialUploadState?.phase == UploadInteractionPhase.failed &&
        initialUploadState?.transientFile != null;
    var source = retrying ? null : await _showSkinPhotoSourceSheet(context);
    if (!mounted) return;
    if (!retrying && source == null) {
      source = _SkinPhotoSource.gallery;
    }
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final controller = ref.read(onboardingUploadInteractionProvider.notifier);
    final asset = retrying
        ? await controller.retry(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : source == _SkinPhotoSource.camera
        ? await controller.takePhoto(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : await controller.chooseFromGallery(
            onboardingSkinProductsUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          );
    if (!mounted) return;

    final latestUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final latestAsset = asset;
    if (latestAsset != null) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareProductPhotoAssetId: latestAsset.assetId,
          skinCareProductPhotoR2Key: latestAsset.r2Key,
          skinCareProductPhotoStatus: latestAsset.status.wireName,
          skinCareProductPhotoCreatedAt: latestAsset.createdAt,
          skinCareProductPhotoUpdatedAt: latestAsset.updatedAt,
          skinCareSkipped: false,
        ),
      );
    }
    setState(() {
      if (latestAsset != null) {
        _uploadedAsset = latestAsset;
        _inputSource = _ProductInputSource.photo;
        _photoProductsReviewed = false;
        _reviewedPhotoDetails = const [];
      } else if (_uploadedAsset == null &&
          _inputSource == _ProductInputSource.photo) {
        _inputSource = _ProductInputSource.none;
      }
      _uploadError = latestUploadState?.phase == UploadInteractionPhase.failed
          ? _friendlySkinCareUploadMessage(latestUploadState?.attemptError)
          : null;
      _generationError = null;
    });
    if (latestAsset != null) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          clearSkinCareReviewedProducts: true,
          skinCareSkipped: false,
        ),
      );
      ref.read(restoredUploadsProvider.notifier).registerUploaded(latestAsset);
    }
  }

  Future<void> _removeUploadedAsset() async {
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;
    final draft = ref.read(mockOnboardingProvider).draft;
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinProducts,
        ) ??
        durableSkinProductsAssetFromDraft(draft);
    if (asset != null && asset.assetId.trim().isNotEmpty) {
      setState(() {
        _removingPhoto = true;
        _uploadError = null;
        _generationError = null;
      });
      final removed = await ref
          .read(onboardingUploadInteractionProvider.notifier)
          .remove(
            onboardingSkinProductsUploadSlot,
            uid: asset.ownerUid.trim().isNotEmpty ? asset.ownerUid : draft.uid,
          );
      if (!mounted) return;
      final latest = ref.read(
        onboardingUploadInteractionProvider,
      )[onboardingSkinProductsUploadSlot];
      if (!removed) {
        setState(() {
          _removingPhoto = false;
          _uploadError = _friendlySkinCareUploadMessage(latest?.attemptError);
        });
        return;
      }
    }
    final hasTypedProducts = _controller.text.trim().isNotEmpty;
    final manuallyReviewed =
        onboarding7ReconcileReviewedProducts(
              _controller.text,
              _reviewedPhotoDetails,
            )
            .map(
              (product) => SkinCareDetectedProduct(
                name: product.name,
                brand: product.brand,
                category: product.category,
                source: 'user_reviewed',
                keyIngredients: product.keyIngredients,
                possibleActives: product.possibleActives,
                usageHint: product.usageHint,
                warningIfAny: product.warningIfAny,
                confidence: product.confidence,
              ),
            )
            .toList(growable: false);
    setState(() {
      _uploadedAsset = null;
      _removingPhoto = false;
      _photoProductsReviewed = false;
      _reviewedPhotoDetails = const [];
      _uploadError = null;
      _generationError = null;
      _inputSource = hasTypedProducts
          ? _ProductInputSource.typed
          : _ProductInputSource.none;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareProductPhoto: true,
        skinCareReviewedProducts: manuallyReviewed,
        skinCareSkipped: false,
      ),
    );
  }

  Future<void> _generate() async {
    if (_lifecycle.state.isActive) return;
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy) return;

    final activeSource = _inputSource;
    final draft = ref.read(mockOnboardingProvider).draft;
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinProducts,
        ) ??
        durableSkinProductsAssetFromDraft(draft);
    var typedProductDetails = onboarding7ParseTypedProductDetails(
      _controller.text,
    );
    if (activeSource == _ProductInputSource.none) {
      setState(() {
        _generationError = _onboarding7NoTypedProductsMessage;
        _uploadError = null;
      });
      return;
    }
    if ((activeSource == _ProductInputSource.typed ||
            (activeSource == _ProductInputSource.photo &&
                _photoProductsReviewed)) &&
        typedProductDetails.isEmpty) {
      setState(() {
        _generationError = _onboarding7NoTypedProductsMessage;
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.photo && asset == null) {
      setState(() {
        _generationError = _onboarding7PhotoUnreadableMessage;
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.photo &&
        asset!.r2Key.trim().isEmpty) {
      setState(() {
        _generationError = 'Upload incomplete. Please upload again.';
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.photo &&
        !_isSupportedSkinCareImageContentType(asset!.contentType)) {
      setState(() {
        _generationError =
            'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
        _uploadError = null;
      });
      return;
    }

    final currentAuthGeneration = ref.read(authGenerationProvider);
    final currentSource = activeSource;
    final currentAssetId = asset?.assetId;
    final currentAssetKey = asset?.r2Key;
    final user = ref.read(authProvider).user;
    final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;

    setState(() {
      _generationError = null;
      _uploadError = null;
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    final isPhotoAnalyze =
        _inputSource == _ProductInputSource.photo && !_photoProductsReviewed;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    final run = await _lifecycle.run<bool>(
      operationType: isPhotoAnalyze ? 'skin-care-analyze' : 'skin-care-routine',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: isPhotoAnalyze
          ? 'Getting your photo ready…'
          : 'Getting your skin care preferences ready…',
      isSessionCurrent: () =>
          mounted &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(mockOnboardingProvider).draft.uid) ==
              uid &&
          (currentSource != _ProductInputSource.photo ||
              (() {
                final live =
                    ref
                        .read(
                          onboardingUploadInteractionProvider,
                        )[onboardingSkinProductsUploadSlot]
                        ?.durableAsset ??
                    durableSkinProductsAssetFromDraft(
                      ref.read(mockOnboardingProvider).draft,
                    );
                return live?.assetId == currentAssetId &&
                    live?.r2Key == currentAssetKey;
              })()) &&
          _inputSource == currentSource,
      mapError: (error) => AiGenerationError(
        category: error is _SkinCareResponseException
            ? AiGenerationErrorCategory.responseInvalid
            : AiGenerationErrorCategory.serviceUnavailable,
        message: error is _SkinCareResponseException
            ? error.message
            : onboarding7UnexpectedAiMessage(error),
        canRetry: true,
      ),
      operation: (scope) async {
        final idToken =
            await ref.read(authRepositoryProvider).currentIdToken() ?? '';
        if (!scope.isCurrent) return false;
        final client = ref.read(skinCareAiClientProvider);
        final desiredApplicationsPerDay = ref
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline
            .skinCareDesiredApplicationsPerDay;
        final latestBase = ref.read(mockOnboardingProvider).draft.baseTimeline;
        final skinType = latestBase.skinCareSkinType ?? 'not_sure';
        final mainProblem = latestBase.skinCareProblems
            .where((problem) => problem != 'none')
            .firstOrNull;
        final budget = latestBase.skinCareBudget ?? 'medium';
        final routinePreference = latestBase.skinCarePreference ?? 'balanced';

        if (isPhotoAnalyze) {
          scope.transition(
            AiGenerationPhase.analyzing,
            message: 'Analyzing your skin care products…',
          );
          final analysis = await client.analyzeProducts(
            uid: uid,
            idToken: idToken,
            productPhotos: [asset!.r2Key.trim()],
          );
          if (!scope.isCurrent) return false;
          if (analysis.hasError) {
            throw _SkinCareResponseException(
              onboarding7FriendlyAiMessage(
                analysis.errorMessage,
                analysis.warnings,
              ),
            );
          }
          final photoProductDetails = analysis.detectedProducts;
          final photoProductNames = onboarding7ExtractPhotoProductNames(
            analysis.products,
          );
          final hasMeaningfulPhotoProducts = photoProductDetails.any(
            (product) => product.hasMeaningfulData,
          );
          if (photoProductNames.isEmpty && !hasMeaningfulPhotoProducts) {
            throw const _SkinCareResponseException(
              _onboarding7PhotoUnreadableMessage,
            );
          }
          final reviewText = photoProductDetails
              .where((product) => product.hasMeaningfulData)
              .map((product) {
                final displayName = product.displayName.trim();
                final name = displayName.isNotEmpty
                    ? displayName
                    : product.fallbackLabel.trim();
                final category = product.category.trim();
                return category.isEmpty ? name : '$name - $category';
              })
              .where((line) => line.isNotEmpty)
              .join('\n');
          final fallbackText = photoProductNames.join('\n');
          _controller.text = reviewText.isNotEmpty ? reviewText : fallbackText;
          updateBaseTimelineDraft(
            ref,
            onboardingSkinCareStepIndex,
            (base) => base.copyWith(
              skinCareProductNames: _controller.text,
              skinCareReviewedProducts: photoProductDetails,
              skinCareSkipped: false,
            ),
          );
          _reviewedPhotoDetails = photoProductDetails;
          _photoProductsReviewed = true;
          return true;
        } else {
          scope.transition(
            AiGenerationPhase.generating,
            message: 'Building your skin care routine…',
          );
          final typedProductDetails = onboarding7ReconcileReviewedProducts(
            _controller.text,
            ref
                .read(mockOnboardingProvider)
                .draft
                .baseTimeline
                .skinCareReviewedProducts,
          );
          final ownedProductDetails = typedProductDetails;
          final ownedProductNames = typedProductDetails
              .map((product) => product.displayName.trim())
              .where((name) => name.isNotEmpty)
              .toList(growable: false);
          final routineParams = {
            'productInputSource': 'typed',
            'typedProductDetails': typedProductDetails
                .map((product) => product.toMap())
                .toList(),
            'desiredApplicationsPerDay': desiredApplicationsPerDay,
            'skinType': skinType,
            'mainProblem': mainProblem ?? 'none',
            'budget': budget,
            'routinePreference': routinePreference,
          };

          var result = await client.generateRoutine(
            uid: uid,
            idToken: idToken,
            params: routineParams,
          );

          var didCompactPayloadRetry = false;
          if (result.hasError && result.errorCode == 'json_payload_too_large') {
            didCompactPayloadRetry = true;
            result = await client.generateRoutine(
              uid: uid,
              idToken: idToken,
              params: {
                ...routineParams,
                'typedProductDetails': typedProductDetails
                    .map((product) => product.toCompactRoutinePayload())
                    .toList(),
                'compact': true,
              },
            );
          }
          if (!scope.isCurrent) return false;

          final routinePlans = result.routinePlans;

          if (result.hasError || routinePlans.isEmpty) {
            final errMsg = routinePlans.isEmpty && !result.hasError
                ? _onboarding7AiEmptyMessage
                : (didCompactPayloadRetry &&
                          result.errorCode == 'json_payload_too_large'
                      ? onboarding7CompactPayloadFinalMessage
                      : onboarding7FriendlyAiMessage(
                          result.errorMessage,
                          result.warnings,
                        ));
            throw _SkinCareResponseException(errMsg);
          }

          final partitioned = onboarding7PartitionRoutinePlans(routinePlans);
          var dailyPlans = partitioned.dailyPlans.where((plan) {
            if (plan.productNames.isEmpty && plan.missingItems.isNotEmpty) {
              return false;
            }
            if (plan.productNames.isEmpty) {
              return false;
            }
            return true;
          }).toList();
          final specialPlans = partitioned.specialCarePlans;

          final specialCareNotesForResult =
              onboarding7SpecialCareNotesFromAiResult(
                suggestedProducts: result.suggestedProducts,
                weeklyRoutine: result.weeklyRoutine,
                specialCarePlans: specialPlans,
                ownedProductNames: ownedProductNames,
              );

          if (result.warnings.any(
            (warning) =>
                warning.contains('ai_wrong_daily_slot_count') ||
                warning.contains('ai_missing_required_slot:') ||
                warning.contains('ai_extra_daily_slot_count'),
          )) {
            updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
              return base.copyWith(
                skinCareProductNames: _controller.text,
                skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
                skinCareSkipped: false,
                skinCareSpecialCareNotes:
                    base.blocks.any((block) => block.section == 'skin_care')
                    ? base.skinCareSpecialCareNotes
                    : specialCareNotesForResult,
              );
            });
            throw _SkinCareResponseException(
              onboarding7FriendlyAiMessage(null, result.warnings),
            );
          }

          final schedule = onboarding7ScheduleSkinCareRoutine(
            baseTimeline: ref.read(mockOnboardingProvider).draft.baseTimeline,
            routinePlans: dailyPlans,
            desiredApplicationsPerDay: desiredApplicationsPerDay,
            ownedProductNames: ownedProductNames,
            ownedProductDetails: ownedProductDetails,
            forceEveryDay: true,
          );
          if (schedule.hasError || schedule.blocks.isEmpty) {
            updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
              return base.copyWith(
                skinCareProductNames: _controller.text,
                skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
                skinCareSkipped: false,
                skinCareSpecialCareNotes:
                    base.blocks.any((block) => block.section == 'skin_care')
                    ? base.skinCareSpecialCareNotes
                    : specialCareNotesForResult,
              );
            });
            throw _SkinCareResponseException(
              schedule.errorMessage ?? _onboarding7AiEmptyMessage,
            );
          }

          updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
            final draftForFingerprint = base.copyWith(
              skinCareProductNames: _controller.text,
              skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
              skinCareReviewedProducts: ownedProductDetails,
              skinCareSkipped: false,
              skinCareSpecialCareNotes: specialCareNotesForResult,
            );
            final routineFingerprint = draftForFingerprint
                .computeSkinCareRoutineFingerprint();
            final taggedBlocks = schedule.blocks.map((block) {
              final prov = List<String>.from(block.provenanceSourceIds);
              final token = 'skin-care-generation:$routineFingerprint';
              if (!prov.contains(token)) prov.add(token);
              if (_uploadedAsset != null) {
                if (_uploadedAsset!.assetId.isNotEmpty &&
                    !prov.contains(_uploadedAsset!.assetId)) {
                  prov.add(_uploadedAsset!.assetId);
                }
                if (_uploadedAsset!.r2Key.isNotEmpty &&
                    !prov.contains(_uploadedAsset!.r2Key)) {
                  prov.add(_uploadedAsset!.r2Key);
                }
              }
              return block.copyWith(provenanceSourceIds: prov);
            }).toList();

            final List<TimelineBlockDraft> nextBlocks =
                base.blocks.where((b) => b.section != 'skin_care').toList()
                  ..addAll(taggedBlocks);
            return draftForFingerprint.copyWith(
              blocks: nextBlocks,
              skinCareRoutineFingerprint: routineFingerprint,
            );
          });

          return true;
        }
      },
    );

    if (mounted) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _editingExisting = false;
          _generationError = null;
        });
      } else if (run.error != null) {
        setState(() {
          _generationError = run.error!.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;
    final restored = ref.watch(restoredUploadsProvider);
    final draft = ref.watch(mockOnboardingProvider).draft;
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinProducts,
    );
    final uploadState = ref.watch(
      onboardingUploadInteractionProvider,
    )[onboardingSkinProductsUploadSlot];
    final slotAsset = uploadState?.durableAsset;
    final effectiveAsset =
        _uploadedAsset ??
        slotAsset ??
        restoredAsset ??
        durableSkinProductsAssetFromDraft(draft);
    final uploadBusy = uploadState?.isBusy == true;
    final uploadError =
        _uploadError ??
        (uploadState?.phase == UploadInteractionPhase.failed
            ? _friendlySkinCareUploadMessage(uploadState?.attemptError)
            : null);
    final busy = uploadBusy || _lifecycle.state.isActive || _removingPhoto;
    final sourceLabel =
        _inputSource == _ProductInputSource.photo && _photoProductsReviewed
        ? 'Review detected products before building'
        : _productInputSourceLabel(_inputSource);
    final textInputEnabled = !_lifecycle.state.isActive;
    final photoUploadEnabled = !busy;
    final typedPreviewProducts = onboarding7ParseTypedProductDetails(
      _controller.text,
    );
    final canGenerate =
        !busy &&
        (switch (_inputSource) {
          _ProductInputSource.none =>
            typedPreviewProducts.isNotEmpty || effectiveAsset != null,
          _ProductInputSource.typed => typedPreviewProducts.isNotEmpty,
          _ProductInputSource.photo =>
            effectiveAsset != null &&
                (!_photoProductsReviewed || typedPreviewProducts.isNotEmpty),
        });
    final textHelper =
        _inputSource == _ProductInputSource.photo && !_photoProductsReviewed
        ? 'Read labels to review and correct detected products.'
        : null;

    void handleProductNamesChanged(String value) {
      final hasText = value.trim().isNotEmpty;
      final canonical = onboarding7ReconcileReviewedProducts(
        value,
        ref
            .read(mockOnboardingProvider)
            .draft
            .baseTimeline
            .skinCareReviewedProducts,
      );
      setState(() {
        _generationError = null;
        if (_inputSource == _ProductInputSource.none && hasText) {
          _inputSource = _ProductInputSource.typed;
        } else if (_inputSource == _ProductInputSource.typed && !hasText) {
          _inputSource = _ProductInputSource.none;
        }
        if (_inputSource == _ProductInputSource.photo &&
            _photoProductsReviewed) {
          _reviewedPhotoDetails = canonical;
        }
      });
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareProductNames: value,
          skinCareReviewedProducts: canonical,
          skinCareSkipped: false,
        ),
      );
    }

    final setupCard = _HasProductsSetupCard(
      base: widget.base,
      controller: _controller,
      focusNode: _focusNode,
      productNamesTargetKey: _productNamesTargetKey,
      asset: effectiveAsset,
      tileHeight: _setupTileHeight,
      sourceLabel: sourceLabel,
      productCount: typedPreviewProducts.length,
      desiredApplicationsPerDay: widget.base.skinCareDesiredApplicationsPerDay,
      uploadBusy: uploadBusy || _removingPhoto,
      uploadStatusLabel: _removingPhoto
          ? 'Removing photo...'
          : uploadBusy
          ? _skinCareInteractionStatusLabel(uploadState!.phase)
          : null,
      localPreviewPath: uploadState?.usablePreviewPath,
      busy: busy,
      generating: _lifecycle.state.isActive,
      photoEnabled: photoUploadEnabled,
      textInputEnabled: textInputEnabled,
      photoHelper: _inputSource == _ProductInputSource.typed
          ? 'Or add one photo, then review the detected products.'
          : null,
      textHelper: textHelper,
      onUpload: photoUploadEnabled ? _startUpload : null,
      onRemove: busy ? null : _removeUploadedAsset,
      generateLabel:
          _inputSource == _ProductInputSource.photo && !_photoProductsReviewed
          ? 'Read product labels'
          : 'Build skin routine',
      onGenerate: canGenerate ? _generate : null,
      onSkinTypeChanged: busy
          ? null
          : (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCareSkinType: value,
                skinCareSkipped: false,
              ),
            ),
      onConcernChanged: busy
          ? null
          : (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCareProblems: [value],
                skinCareSkipped: false,
              ),
            ),
      onPreferenceChanged: busy
          ? null
          : (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCarePreference: value,
                skinCareSkipped: false,
              ),
            ),
      onFrequencyChanged: busy
          ? null
          : (value) {
              setState(() => _generationError = null);
              updateBaseTimelineDraft(
                ref,
                onboardingSkinCareStepIndex,
                (base) => base.copyWith(
                  skinCareDesiredApplicationsPerDay: value,
                  skinCareSkipped: false,
                ),
              );
            },
      onChanged: handleProductNamesChanged,
    );
    final message = uploadError ?? _generationError;

    if (_lifecycle.state.isActive) {
      final isPhotoAnalyze =
          _inputSource == _ProductInputSource.photo && !_photoProductsReviewed;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiThinkingCard(
            title: 'Skin Care AI',
            detail: isPhotoAnalyze
                ? 'Looking for product names and active ingredients'
                : 'Building your routine from product names and labels',
            accent: OptivusColors.roseAccent,
            state: _lifecycle.state,
            onRetry: _generate,
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
        ],
      );
    }

    if (!generated || _editingExisting) {
      if (!_editingExisting && MediaQuery.viewInsetsOf(context).bottom > 0) {
        return _SkinCareProductNamesTarget(
          key: _productNamesTargetKey,
          controller: _controller,
          focusNode: _focusNode,
          enabled: textInputEnabled,
          helperText: textHelper,
          productCount: typedPreviewProducts.length,
          onChanged: handleProductNamesChanged,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editingExisting) ...[
            const _SkinCareInlineMessage(
              message: 'Changes not applied yet. Your last routine is kept.',
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('onboarding-step7-cancel-rebuild'),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        _editingExisting = false;
                        _generationError = null;
                      }),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel edit'),
              ),
            ),
            const SizedBox(height: 4),
          ],
          setupCard,
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OnboardingGlassCard(
                tint: OptivusColors.roseAccent.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                radius: 20,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: OptivusColors.roseAccent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Routine built',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.base.skinCareDesiredApplicationsPerDay} routines per day',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: OptivusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    OnboardingActionPill(
                      label: 'Rebuild / Edit',
                      icon: Icons.edit_rounded,
                      accent: OptivusColors.roseAccent,
                      compact: true,
                      onTap: () => setState(() {
                        _editingExisting = true;
                        _generationError = null;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          _SkinCareInlineMessage(message: message),
        ],
        const SizedBox(height: 12),
        _SkinCareTimelineSection(
          selectedDay: _selectedDay,
          blocks: widget.blocks,
          onDayChanged: (d) => setState(() => _selectedDay = d),
          emptyLabel: 'Build your skin-care routine first.',
          accent: OptivusColors.roseAccent,
          specialCareNotes: widget.base.skinCareSpecialCareNotes,
        ),
      ],
    );
  }
}

class _HasProductsSetupCard extends StatelessWidget {
  final BaseTimelineDraft base;
  final TextEditingController controller;
  final UploadedAsset? asset;
  final double tileHeight;
  final String? sourceLabel;
  final int productCount;
  final int desiredApplicationsPerDay;
  final bool uploadBusy;
  final String? uploadStatusLabel;
  final String? localPreviewPath;
  final FocusNode? focusNode;
  final Key? productNamesTargetKey;
  final bool busy;
  final bool generating;
  final bool photoEnabled;
  final bool textInputEnabled;
  final String? photoHelper;
  final String? textHelper;
  final VoidCallback? onUpload;
  final VoidCallback? onRemove;
  final VoidCallback? onGenerate;
  final String generateLabel;
  final ValueChanged<String>? onSkinTypeChanged;
  final ValueChanged<String>? onConcernChanged;
  final ValueChanged<String>? onPreferenceChanged;
  final ValueChanged<int>? onFrequencyChanged;
  final ValueChanged<String> onChanged;

  const _HasProductsSetupCard({
    required this.base,
    required this.controller,
    this.focusNode,
    this.productNamesTargetKey,
    required this.asset,
    required this.tileHeight,
    required this.sourceLabel,
    required this.productCount,
    required this.desiredApplicationsPerDay,
    required this.uploadBusy,
    required this.uploadStatusLabel,
    required this.localPreviewPath,
    required this.busy,
    required this.generating,
    required this.photoEnabled,
    required this.textInputEnabled,
    required this.photoHelper,
    required this.textHelper,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
    required this.generateLabel,
    required this.onSkinTypeChanged,
    required this.onConcernChanged,
    required this.onPreferenceChanged,
    required this.onFrequencyChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final effectiveTileHeight = keyboardOpen ? 120.0 : tileHeight;
    return OnboardingGlassCard(
      key: const ValueKey('onboarding-step7-products-setup-card'),
      tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'I have products',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                if (sourceLabel != null) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: OptivusColors.roseAccent,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      sourceLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.roseAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Upload one clear photo with all your skin-care products together. Keep front labels visible.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 280;
              final photo = SizedBox(
                height: effectiveTileHeight,
                child: _SkinCarePhotoTarget(
                  asset: asset,
                  localPreviewPath: localPreviewPath,
                  purpose: UploadedAssetPurpose.skinProducts,
                  title: 'Add photo',
                  uploadedTitle: 'Photo uploaded',
                  busy: uploadBusy,
                  busyLabel: uploadStatusLabel,
                  enabled: photoEnabled,
                  helperText: photoHelper,
                  onRemove: onRemove,
                  onTap: onUpload,
                ),
              );
              final input = SizedBox(
                height: effectiveTileHeight,
                child: _SkinCareProductNamesTarget(
                  key: productNamesTargetKey,
                  controller: controller,
                  focusNode: focusNode,
                  enabled: textInputEnabled,
                  helperText: textHelper,
                  productCount: productCount,
                  onChanged: onChanged,
                ),
              );

              if (!sideBySide) {
                if (keyboardOpen) {
                  return input;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [photo, const SizedBox(height: 10), input],
                );
              }

              return SizedBox(
                height: effectiveTileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: photo),
                    const SizedBox(width: 10),
                    Expanded(child: input),
                  ],
                ),
              );
            },
          ),
          if (!keyboardOpen) ...[
            const SizedBox(height: 4),
            _SkinCarePersonalizeSection(
              skinType: base.skinCareSkinType ?? 'not_sure',
              concern: base.skinCareProblems.firstOrNull ?? 'none',
              preference: base.skinCarePreference ?? 'balanced',
              onSkinTypeChanged: onSkinTypeChanged,
              onConcernChanged: onConcernChanged,
              onPreferenceChanged: onPreferenceChanged,
            ),
            const SizedBox(height: 4),
            _SkinCareFrequencySelector(
              value: desiredApplicationsPerDay,
              onChanged: onFrequencyChanged,
            ),
            const SizedBox(height: 12),
            _SkinCareGenerateRoutineButton(
              label: uploadBusy ? 'Please wait...' : generateLabel,
              busy: generating,
              onTap: onGenerate,
              accent: OptivusColors.roseAccent,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkinCarePersonalizeSection extends StatelessWidget {
  final String skinType;
  final String concern;
  final String preference;
  final ValueChanged<String>? onSkinTypeChanged;
  final ValueChanged<String>? onConcernChanged;
  final ValueChanged<String>? onPreferenceChanged;

  const _SkinCarePersonalizeSection({
    required this.skinType,
    required this.concern,
    required this.preference,
    required this.onSkinTypeChanged,
    required this.onConcernChanged,
    required this.onPreferenceChanged,
  });

  String get _summary => [
    _skinCareOptionLabel(skinType),
    _skinCareOptionLabel(concern),
    _skinCareOptionLabel(preference),
  ].join(' · ');

  Future<void> _open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      enableDrag: false,
      elevation: 0,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (context) => _SkinCarePersonalizationSheet(
        skinType: skinType,
        concern: concern,
        preference: preference,
        onSkinTypeChanged: onSkinTypeChanged,
        onConcernChanged: onConcernChanged,
        onPreferenceChanged: onPreferenceChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        key: const ValueKey('onboarding-step7-personalize-tile'),
        behavior: HitTestBehavior.opaque,
        onTap: onSkinTypeChanged == null ? null : () => _open(context),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personalize routine',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.tune_rounded,
                color: OptivusColors.roseAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinCarePersonalizationSheet extends StatefulWidget {
  final String skinType;
  final String concern;
  final String preference;
  final ValueChanged<String>? onSkinTypeChanged;
  final ValueChanged<String>? onConcernChanged;
  final ValueChanged<String>? onPreferenceChanged;

  const _SkinCarePersonalizationSheet({
    required this.skinType,
    required this.concern,
    required this.preference,
    required this.onSkinTypeChanged,
    required this.onConcernChanged,
    required this.onPreferenceChanged,
  });

  @override
  State<_SkinCarePersonalizationSheet> createState() =>
      _SkinCarePersonalizationSheetState();
}

class _SkinCarePersonalizationSheetState
    extends State<_SkinCarePersonalizationSheet> {
  late String _skinType = widget.skinType;
  late String _concern = widget.concern;
  late String _preference = widget.preference;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('onboarding-step7-personalize-sheet'),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: OptivusColors.roseAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Personalize routine',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('onboarding-step7-personalize-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SkinCareChipGroup(
            label: 'Skin Type',
            children: [
              for (final option in _skinTypeOptions)
                _SkinCarePreferenceChip(
                  label: option.label,
                  selected: _skinType == option.key,
                  accent: OptivusColors.roseAccent,
                  onTap: widget.onSkinTypeChanged == null
                      ? null
                      : () {
                          setState(() => _skinType = option.key);
                          widget.onSkinTypeChanged!(option.key);
                        },
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SkinCareChipGroup(
            label: 'Main Concern',
            children: [
              for (final option in _skinConcernOptions)
                _SkinCarePreferenceChip(
                  label: option.label,
                  selected: _concern == option.key,
                  accent: OptivusColors.roseAccent,
                  onTap: widget.onConcernChanged == null
                      ? null
                      : () {
                          setState(() => _concern = option.key);
                          widget.onConcernChanged!(option.key);
                        },
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SkinCareChipGroup(
            label: 'Routine Style',
            children: [
              for (final option in _skinPreferenceOptions)
                _SkinCarePreferenceChip(
                  label: option.label,
                  selected: _preference == option.key,
                  accent: OptivusColors.roseAccent,
                  onTap: widget.onPreferenceChanged == null
                      ? null
                      : () {
                          setState(() => _preference = option.key);
                          widget.onPreferenceChanged!(option.key);
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _skinTypeOptions = [
  _SkinOption('oily', 'Oily'),
  _SkinOption('dry', 'Dry'),
  _SkinOption('combination', 'Combination'),
  _SkinOption('not_sure', 'Not sure'),
];

const _skinConcernOptions = [
  _SkinOption('pimples', 'Acne'),
  _SkinOption('dark_spots', 'Spots'),
  _SkinOption('tan', 'Tan'),
  _SkinOption('dryness', 'Dryness'),
  _SkinOption('oiliness', 'Oiliness'),
  _SkinOption('none', 'None'),
];

const _skinPreferenceOptions = [
  _SkinOption('simple', 'Simple'),
  _SkinOption('balanced', 'Balanced'),
];

String _skinCareOptionLabel(String value) {
  return [
        ..._skinTypeOptions,
        ..._skinConcernOptions,
        ..._skinPreferenceOptions,
      ].where((option) => option.key == value).firstOrNull?.label ??
      value;
}

class _SkinCareProductNamesTarget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String? helperText;
  final int productCount;
  final ValueChanged<String> onChanged;

  const _SkinCareProductNamesTarget({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.helperText,
    required this.productCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final card = OnboardingGlassCard(
      key: const ValueKey('onboarding-step7-product-names-tile'),
      tint: OptivusColors.roseAccent.withValues(alpha: enabled ? 0.06 : 0.025),
      padding: const EdgeInsets.all(11),
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product names',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: enabled
                        ? OptivusColors.textPrimary
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
              if (productCount > 0)
                Semantics(
                  label: '$productCount products ready',
                  child: Row(
                    key: const ValueKey('onboarding-step7-product-count'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: OptivusColors.roseAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$productCount',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.roseAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: TextField(
              key: const ValueKey('onboarding-step7-product-names-field'),
              controller: controller,
              focusNode: focusNode,
              minLines: null,
              maxLines: null,
              expands: true,
              enabled: enabled,
              readOnly: false,
              autofocus: false,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.22,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? OptivusColors.textPrimary
                    : OptivusColors.textSecondary,
              ),
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Minimalist SPF 50 - sunscreen\nVitamin C serum'
                    : helperText,
                hintStyle: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white.withValues(
                  alpha: enabled ? 0.34 : 0.18,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: OptivusColors.roseAccent),
                ),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 5),
            Text(
              helperText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (enabled && focusNode != null && !focusNode!.hasFocus) {
          focusNode!.requestFocus();
        }
      },
      child: card,
    );
    return Opacity(opacity: enabled ? 1 : 0.55, child: child);
  }
}

class _SkinCareFrequencySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final Color accent;
  final bool compact;

  const _SkinCareFrequencySelector({
    required this.value,
    required this.onChanged,
    this.accent = OptivusColors.roseAccent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'How many times per day?',
      style: TextStyle(
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w900,
        color: OptivusColors.textPrimary,
      ),
    );
    final selector = Container(
      padding: EdgeInsets.all(compact ? 2 : 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in const [2, 3, 4])
            GestureDetector(
              key: ValueKey('onboarding-step7-frequency-$option'),
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: compact ? 32 : 34,
                height: compact ? 28 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == option ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$option',
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12,
                    fontWeight: FontWeight.w900,
                    color: value == option
                        ? Colors.white
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 8), selector],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 10),
            selector,
          ],
        );
      },
    );
  }
}

class _SkinCareGenerateRoutineButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  final Color accent;

  const _SkinCareGenerateRoutineButton({
    required this.label,
    required this.busy,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.45,
        child: Container(
          key: const ValueKey('onboarding-step7-generate-button'),
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? accent : Colors.white.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: enabled
                            ? Colors.white
                            : OptivusColors.textSecondary,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : OptivusColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _NoProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_NoProductsModeScreen> createState() =>
      _NoProductsModeScreenState();
}

class _NoProductsModeScreenState extends ConsumerState<_NoProductsModeScreen> {
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  late final AiGenerationController _lifecycle;
  bool _removingPhoto = false;
  int? _pendingDesiredApplicationsPerDay;
  bool _editingExisting = false;
  bool _showProductSelection = false;
  String? _generationError;
  int _selectedDay = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    _lifecycle = AiGenerationController()..addListener(_onLifecycleChanged);
    final draft = ref.read(mockOnboardingProvider).draft;
    final restored = ref.read(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinFace,
    );
    _uploadedAsset = restoredAsset ?? durableSkinFaceAssetFromDraft(draft);
    _showProductSelection =
        widget.base.skinCareProductRecommendations.isNotEmpty;
  }

  void _onLifecycleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lifecycle.removeListener(_onLifecycleChanged);
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    final initialUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    if (initialUploadState?.isBusy == true) return;
    final retrying =
        initialUploadState?.phase == UploadInteractionPhase.failed &&
        initialUploadState?.transientFile != null;
    var source = retrying ? null : await _showSkinPhotoSourceSheet(context);
    if (!mounted) return;
    if (!retrying && source == null) {
      source = _SkinPhotoSource.gallery;
    }
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final controller = ref.read(onboardingUploadInteractionProvider.notifier);
    final asset = retrying
        ? await controller.retry(
            onboardingSkinFaceUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : source == _SkinPhotoSource.camera
        ? await controller.takePhoto(
            onboardingSkinFaceUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          )
        : await controller.chooseFromGallery(
            onboardingSkinFaceUploadSlot,
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
          );

    if (!mounted) return;

    final latestUploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final latestAsset = asset;
    if (latestAsset != null) {
      updateBaseTimelineDraft(
        ref,
        onboardingSkinCareStepIndex,
        (base) => base.copyWith(
          skinCareFacePhotoAssetId: latestAsset.assetId,
          skinCareFacePhotoR2Key: latestAsset.r2Key,
          skinCareFacePhotoStatus: latestAsset.status.wireName,
          skinCareFacePhotoCreatedAt: latestAsset.createdAt,
          skinCareFacePhotoUpdatedAt: latestAsset.updatedAt,
          clearSkinCareProductRecommendations: true,
          clearSkinCareSelectedProductNames: true,
          clearSkinCareSuggestedProducts: !base.blocks.any(
            (block) => block.section == 'skin_care',
          ),
          skinCareSkipped: false,
        ),
      );
    }
    setState(() {
      if (latestAsset != null) {
        _uploadedAsset = latestAsset;
      }
      _uploadError = latestUploadState?.phase == UploadInteractionPhase.failed
          ? _friendlySkinCareUploadMessage(latestUploadState?.attemptError)
          : null;
    });
    if (latestAsset != null) {
      ref.read(restoredUploadsProvider.notifier).registerUploaded(latestAsset);
    }
  }

  Future<void> _removeUploadedAsset() async {
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;
    final draft = ref.read(mockOnboardingProvider).draft;
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinFace,
        ) ??
        durableSkinFaceAssetFromDraft(draft);
    if (asset != null && asset.assetId.trim().isNotEmpty) {
      setState(() {
        _removingPhoto = true;
        _uploadError = null;
        _generationError = null;
      });
      final removed = await ref
          .read(onboardingUploadInteractionProvider.notifier)
          .remove(
            onboardingSkinFaceUploadSlot,
            uid: asset.ownerUid.trim().isNotEmpty ? asset.ownerUid : draft.uid,
          );
      if (!mounted) return;
      final latest = ref.read(
        onboardingUploadInteractionProvider,
      )[onboardingSkinFaceUploadSlot];
      if (!removed) {
        setState(() {
          _removingPhoto = false;
          _uploadError = _friendlySkinCareUploadMessage(latest?.attemptError);
        });
        return;
      }
    }
    setState(() {
      _uploadedAsset = null;
      _removingPhoto = false;
      _uploadError = null;
      _generationError = null;
      _showProductSelection = false;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareFacePhoto: true,
        clearSkinCareProductRecommendations: true,
        clearSkinCareSelectedProductNames: true,
        clearSkinCareSuggestedProducts: true,
        skinCareSkipped: false,
      ),
    );
  }

  Future<void> _findProducts() async {
    if (_lifecycle.state.isActive) return;
    final uploadState = ref.read(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final uploadBusy = uploadState?.isBusy == true;
    if (uploadBusy || _removingPhoto) return;

    final draft = ref.read(mockOnboardingProvider).draft;
    final currentBase = draft.baseTimeline;
    final desiredApplicationsPerDay = _effectiveDesiredApplications(
      currentBase,
    );
    final restored = ref.read(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinFace,
    );
    final asset =
        _uploadedAsset ?? restoredAsset ?? durableSkinFaceAssetFromDraft(draft);
    if (asset == null ||
        asset.r2Key.trim().isEmpty ||
        currentBase.skinCareSkinType == null ||
        currentBase.skinCareProblems.isEmpty ||
        currentBase.skinCareBudget == null) {
      setState(() {
        _generationError =
            'Add a face photo, then choose your skin type, concerns, and budget.';
        _uploadError = null;
      });
      return;
    }
    if (!_isSupportedSkinCareImageContentType(asset.contentType)) {
      setState(() {
        _generationError =
            'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
        _uploadError = null;
      });
      return;
    }

    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final currentAuthGeneration = ref.read(authGenerationProvider);
    final currentAssetId = asset.assetId;
    final currentAssetKey = asset.r2Key;
    final user = ref.read(authProvider).user;
    final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    setState(() {
      _generationError = null;
      _uploadError = null;
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    final run = await _lifecycle.run<bool>(
      operationType: 'skin-care-find-products',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: 'Getting your face photo ready…',
      isSessionCurrent: () =>
          mounted &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(mockOnboardingProvider).draft.uid) ==
              uid &&
          (() {
            final live =
                ref
                    .read(
                      onboardingUploadInteractionProvider,
                    )[onboardingSkinFaceUploadSlot]
                    ?.durableAsset ??
                durableSkinFaceAssetFromDraft(
                  ref.read(mockOnboardingProvider).draft,
                );
            return live?.assetId == currentAssetId &&
                live?.r2Key == currentAssetKey;
          })(),
      mapError: (error) => AiGenerationError(
        category: error is _SkinCareResponseException
            ? AiGenerationErrorCategory.responseInvalid
            : AiGenerationErrorCategory.serviceUnavailable,
        message: error is _SkinCareResponseException
            ? error.message
            : onboarding7UnexpectedAiMessage(error),
        canRetry: true,
      ),
      operation: (scope) async {
        final idToken =
            await ref.read(authRepositoryProvider).currentIdToken() ?? '';
        if (!scope.isCurrent) return false;
        final client = ref.read(skinCareAiClientProvider);
        var region = ref.read(regionSettingsProvider);
        final hasExplicitRegion =
            region.countryCode.trim().isNotEmpty && region.countryCode != 'ZZ';
        if (!hasExplicitRegion) {
          final detectedCountry = await ref
              .read(deviceCountryServiceProvider)
              .detectCountry();
          if (!scope.isCurrent) return false;
          if (detectedCountry != null) {
            // Device detection is a request-scoped default. Finding products
            // must not mutate the user's explicit global region setting.
            region = RegionSettings.forCountry(
              userId: uid,
              countryCode: detectedCountry.countryCode,
              countryName: detectedCountry.countryName,
            );
          }
        }
        scope.transition(
          AiGenerationPhase.analyzing,
          message:
              'Finding useful products available in ${region.countryName}…',
        );

        final result = await client.generateRoutine(
          uid: uid,
          idToken: idToken,
          params: {
            'recommendationOnly': true,
            'skinType': currentBase.skinCareSkinType,
            'mainProblem': currentBase.skinCareProblems.isNotEmpty
                ? currentBase.skinCareProblems.first
                : 'none',
            'skinConcerns': currentBase.skinCareProblems,
            'budget': currentBase.skinCareBudget,
            'routinePreference': currentBase.skinCarePreference,
            'desiredApplicationsPerDay': desiredApplicationsPerDay,
            'facePhotoR2Key': asset.r2Key,
            'countryCode': region.countryCode,
            'countryName': region.countryName,
            'currencyCode': region.currencyCode,
          },
        );
        if (!scope.isCurrent) return false;

        final deduped = onboarding7NormalizeRecommendations(
          result.recommendedProducts,
        );

        final recommendationDrafts = deduped
            .map(
              (product) => SkinCareProductRecommendationDraft(
                name: product.name,
                brand: product.brand,
                category: product.category,
                estimatedPrice: product.estimatedPrice,
                currencyCode: product.currencyCode,
                reason: product.reason,
              ),
            )
            .toList(growable: false);
        final missingEssentialCategories =
            onboarding7MissingEssentialRecommendationCategories(
              recommendationDrafts,
            );

        if (result.hasError ||
            deduped.isEmpty ||
            missingEssentialCategories.isNotEmpty) {
          throw _SkinCareResponseException(
            !result.hasError
                ? 'AI could not provide a complete branded cleanser, moisturizer, and sunscreen set with local prices. Please try again.'
                : onboarding7FriendlyAiMessage(
                    result.errorCode == 'json_payload_too_large'
                        ? 'json_payload_too_large'
                        : result.errorMessage,
                    result.warnings,
                  ),
          );
        }

        updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
          final hasExistingRoutine = base.blocks.any(
            (block) => block.section == 'skin_care',
          );
          final draftForFingerprint = base.copyWith(
            skinCareProductRecommendations: recommendationDrafts,
            skinCareSelectedProductNames: const [],
            skinCareRecommendationCountryCode: region.countryCode,
            skinCareRecommendationCurrencyCode: region.currencyCode,
            clearSkinCareSuggestedProducts: !hasExistingRoutine,
            skinCareFacePhotoSkipped: false,
            skinCareSkipped: false,
          );
          final recFingerprint = draftForFingerprint
              .computeSkinCareRecommendationFingerprint();
          return draftForFingerprint.copyWith(
            skinCareRecommendationFingerprint: recFingerprint,
          );
        });

        return true;
      },
    );

    if (mounted) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _showProductSelection = true;
          _generationError = null;
        });
      } else if (run.error != null) {
        setState(() {
          _generationError = run.error!.message;
        });
      }
    }
  }

  Future<void> _generate() async {
    if (_lifecycle.state.isActive) return;
    final draft = ref.read(mockOnboardingProvider).draft;
    final currentBase = draft.baseTimeline;
    final desiredApplicationsPerDay = _effectiveDesiredApplications(
      currentBase,
    );
    final selectedKeys = currentBase.skinCareSelectedProductNames
        .map((name) => name.trim().toLowerCase())
        .toSet();
    final selected = currentBase.skinCareProductRecommendations
        .where((product) => selectedKeys.contains(product.selectionKey))
        .toList(growable: false);
    final asset =
        _uploadedAsset ??
        _restoredSkinAssetForSlot(
          restored: ref.read(restoredUploadsProvider),
          draft: draft,
          purpose: UploadedAssetPurpose.skinFace,
        ) ??
        durableSkinFaceAssetFromDraft(draft);
    if (selected.isEmpty) {
      setState(() => _generationError = 'Select at least one product.');
      return;
    }
    final missingEssentialSelections =
        onboarding7MissingEssentialRecommendationCategories(selected);
    if (missingEssentialSelections.isNotEmpty) {
      setState(() {
        _generationError = _onboarding7EssentialSelectionMessage(
          missingEssentialSelections,
        );
      });
      return;
    }
    if (asset == null || asset.r2Key.trim().isEmpty) {
      setState(() {
        _showProductSelection = false;
        _generationError = 'Add a face photo before building your routine.';
      });
      return;
    }

    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final currentAuthGeneration = ref.read(authGenerationProvider);
    final currentAssetId = asset.assetId;
    final currentAssetKey = asset.r2Key;
    final user = ref.read(authProvider).user;
    final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
    final isRetry = _lifecycle.state.phase == AiGenerationPhase.error;

    setState(() {
      _generationError = null;
      _uploadError = null;
    });
    ref
        .read(mockOnboardingProvider.notifier)
        .setStepLoading(onboardingSkinCareStepIndex, true);

    final run = await _lifecycle.run<bool>(
      operationType: 'skin-care-routine',
      timeoutPolicy: AiOperationTimeouts.skinCare,
      retry: isRetry,
      preparingMessage: 'Getting your skin care routine ready…',
      isSessionCurrent: () =>
          mounted &&
          ref.read(authGenerationProvider) == currentAuthGeneration &&
          (ref.read(authProvider).user?.uid ??
                  ref.read(mockOnboardingProvider).draft.uid) ==
              uid &&
          (() {
            final live =
                ref
                    .read(
                      onboardingUploadInteractionProvider,
                    )[onboardingSkinFaceUploadSlot]
                    ?.durableAsset ??
                durableSkinFaceAssetFromDraft(
                  ref.read(mockOnboardingProvider).draft,
                );
            return live?.assetId == currentAssetId &&
                live?.r2Key == currentAssetKey;
          })(),
      mapError: (error) => AiGenerationError(
        category: error is _SkinCareResponseException
            ? AiGenerationErrorCategory.responseInvalid
            : AiGenerationErrorCategory.serviceUnavailable,
        message: error is _SkinCareResponseException
            ? error.message
            : onboarding7UnexpectedAiMessage(error),
        canRetry: true,
      ),
      operation: (scope) async {
        final idToken =
            await ref.read(authRepositoryProvider).currentIdToken() ?? '';
        if (!scope.isCurrent) return false;
        final region = ref.read(regionSettingsProvider);
        final selectedNames = selected
            .map((product) => product.displayName)
            .where((name) => name.isNotEmpty)
            .toList(growable: false);

        scope.transition(
          AiGenerationPhase.generating,
          message: 'Building your skin care routine…',
        );

        final result = await ref
            .read(skinCareAiClientProvider)
            .generateRoutine(
              uid: uid,
              idToken: idToken,
              params: {
                'sourceFeature': OnboardingDraft.sourceOnboarding,
                'productInputSource': 'typed',
                'typedProductDetails': selected
                    .map(
                      (product) => {
                        'name': product.name,
                        'brand': product.brand,
                        'category': product.category,
                        'source': 'ai_recommended',
                      },
                    )
                    .toList(growable: false),
                'skinType': currentBase.skinCareSkinType,
                'mainProblem':
                    currentBase.skinCareProblems.firstOrNull ?? 'none',
                'skinConcerns': currentBase.skinCareProblems,
                'budget': currentBase.skinCareBudget,
                'routinePreference': currentBase.skinCarePreference,
                'desiredApplicationsPerDay': desiredApplicationsPerDay,
                'countryCode': region.countryCode,
                'countryName': region.countryName,
                'currencyCode': region.currencyCode,
              },
            );
        if (!scope.isCurrent) return false;

        if (result.hasError || result.routinePlans.isEmpty) {
          throw _SkinCareResponseException(
            result.routinePlans.isEmpty && !result.hasError
                ? _onboarding7NoProductsAiEmptyMessage
                : onboarding7FriendlyAiMessage(
                    result.errorCode == 'json_payload_too_large'
                        ? 'json_payload_too_large'
                        : result.errorMessage,
                    result.warnings,
                  ),
          );
        }
        if (result.warnings.any(
          (warning) =>
              warning.contains('ai_wrong_daily_slot_count') ||
              warning.contains('ai_missing_required_slot:') ||
              warning.contains('ai_extra_daily_slot_count'),
        )) {
          throw _SkinCareResponseException(
            onboarding7FriendlyAiMessage(null, result.warnings),
          );
        }

        final partitioned = onboarding7PartitionRoutinePlans(
          result.routinePlans,
        );
        final schedule = onboarding7ScheduleSkinCareRoutine(
          baseTimeline: ref.read(mockOnboardingProvider).draft.baseTimeline,
          routinePlans: partitioned.dailyPlans,
          desiredApplicationsPerDay: desiredApplicationsPerDay,
          ownedProductNames: selectedNames,
          forceEveryDay: true,
        );
        if (schedule.hasError || schedule.blocks.isEmpty) {
          throw _SkinCareResponseException(
            schedule.errorMessage ?? _onboarding7NoProductsAiEmptyMessage,
          );
        }

        final specialCareNotes = onboarding7SpecialCareNotesFromAiResult(
          suggestedProducts: result.suggestedProducts,
          weeklyRoutine: result.weeklyRoutine,
          specialCarePlans: partitioned.specialCarePlans,
          ownedProductNames: selectedNames,
        );
        updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
          final draftForFingerprint = base.copyWith(
            skinCareProductNames: selectedNames.join('\n'),
            skinCareSpecialCareNotes: specialCareNotes,
            skinCareSuggestedProducts: selectedNames,
            skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
            skinCareFacePhotoSkipped: false,
            skinCareSkipped: false,
          );
          final routineFingerprint = draftForFingerprint
              .computeSkinCareRoutineFingerprint();
          final taggedBlocks = schedule.blocks.map((block) {
            final prov = List<String>.from(block.provenanceSourceIds);
            final token = 'skin-care-generation:$routineFingerprint';
            if (!prov.contains(token)) prov.add(token);
            if (asset.assetId.isNotEmpty && !prov.contains(asset.assetId)) {
              prov.add(asset.assetId);
            }
            if (asset.r2Key.isNotEmpty && !prov.contains(asset.r2Key)) {
              prov.add(asset.r2Key);
            }
            return block.copyWith(provenanceSourceIds: prov);
          }).toList();

          final nextBlocks =
              base.blocks
                  .where((block) => block.section != 'skin_care')
                  .toList()
                ..addAll(taggedBlocks);
          return draftForFingerprint.copyWith(
            blocks: nextBlocks,
            skinCareRoutineFingerprint: routineFingerprint,
          );
        });

        return true;
      },
    );

    if (mounted) {
      ref
          .read(mockOnboardingProvider.notifier)
          .setStepLoading(onboardingSkinCareStepIndex, false);
      if (run.isSuccess) {
        setState(() {
          _editingExisting = false;
          _showProductSelection = false;
          _pendingDesiredApplicationsPerDay = null;
          _generationError = null;
        });
      } else if (run.error != null) {
        setState(() {
          _generationError = run.error!.message;
        });
      }
    }
  }

  void _toggleProduct(SkinCareProductRecommendationDraft product) {
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final next = [...base.skinCareSelectedProductNames];
    final index = next.indexWhere(
      (name) => name.trim().toLowerCase() == product.selectionKey,
    );
    if (index >= 0) {
      next.removeAt(index);
    } else {
      final group = _onboarding7ProductSelectionGroup(product);
      final productsByKey = {
        for (final recommendation in base.skinCareProductRecommendations)
          recommendation.selectionKey: recommendation,
      };
      next.removeWhere((name) {
        final selectedProduct = productsByKey[name.trim().toLowerCase()];
        return selectedProduct != null &&
            _onboarding7ProductSelectionGroup(selectedProduct) == group;
      });
      next.add(product.displayName);
    }
    setState(() => _generationError = null);
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        skinCareSelectedProductNames: next,
        skinCareSkipped: false,
      ),
    );
  }

  void _changeDetails() {
    final hasRoutine = ref
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .blocks
        .any((block) => block.section == 'skin_care');
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareProductRecommendations: true,
        clearSkinCareSelectedProductNames: !hasRoutine,
        clearSkinCareSuggestedProducts: !hasRoutine,
        skinCareSkipped: false,
      ),
    );
    setState(() {
      _showProductSelection = false;
      _generationError = null;
    });
  }

  int _effectiveDesiredApplications(BaseTimelineDraft base) {
    return onboarding7NormalizeDesiredApplications(
      _pendingDesiredApplicationsPerDay ??
          base.skinCareDesiredApplicationsPerDay,
    );
  }

  void _changeDesiredApplications(int value) {
    final normalized = onboarding7NormalizeDesiredApplications(value);
    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final hasExistingRoutine = base.blocks.any(
      (block) => block.section == 'skin_care',
    );
    setState(() {
      _pendingDesiredApplicationsPerDay = hasExistingRoutine
          ? normalized
          : null;
      _generationError = null;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        skinCareDesiredApplicationsPerDay: hasExistingRoutine
            ? null
            : normalized,
        clearSkinCareRoutineFingerprint: hasExistingRoutine,
        clearSkinCareProductRecommendations: true,
        clearSkinCareSelectedProductNames: !hasExistingRoutine,
        clearSkinCareSuggestedProducts: !hasExistingRoutine,
        skinCareSkipped: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final restored = ref.watch(restoredUploadsProvider);
    final restoredAsset = _restoredSkinAssetForSlot(
      restored: restored,
      draft: draft,
      purpose: UploadedAssetPurpose.skinFace,
    );
    final uploadState = ref.watch(
      onboardingUploadInteractionProvider,
    )[onboardingSkinFaceUploadSlot];
    final slotAsset = uploadState?.durableAsset;
    final effectiveAsset =
        _uploadedAsset ??
        slotAsset ??
        restoredAsset ??
        durableSkinFaceAssetFromDraft(draft);
    final uploadBusy = uploadState?.isBusy == true;
    final busy = uploadBusy || _lifecycle.state.isActive || _removingPhoto;
    final uploadError =
        _uploadError ??
        (uploadState?.phase == UploadInteractionPhase.failed
            ? _friendlySkinCareUploadMessage(uploadState?.attemptError)
            : null);
    final inputsComplete =
        effectiveAsset != null &&
        effectiveAsset.r2Key.trim().isNotEmpty &&
        base.skinCareSkinType != null &&
        base.skinCareProblems.isNotEmpty &&
        base.skinCareBudget != null;
    final message = uploadError ?? _generationError;
    final region = ref.watch(regionSettingsProvider);
    final recommendationCountryName =
        base.skinCareRecommendationCountryCode?.trim().isNotEmpty == true
        ? RegionSettings.forCountry(
            userId: draft.uid,
            countryCode: base.skinCareRecommendationCountryCode!,
          ).countryName
        : region.countryName;
    final desiredApplicationsPerDay = _effectiveDesiredApplications(base);

    if (_lifecycle.state.isActive) {
      final isFindProducts =
          _lifecycle.state.operationId?.contains('find-products') ?? false;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiThinkingCard(
            title: 'Skin Care AI',
            detail: isFindProducts
                ? 'Finding useful products available in ${region.countryName}'
                : 'Building your routine from product names and labels',
            accent: isFindProducts
                ? OptivusColors.purpleAccent
                : OptivusColors.roseAccent,
            state: _lifecycle.state,
            onRetry: isFindProducts ? _findProducts : _generate,
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
        ],
      );
    }

    if (generated && !_editingExisting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingGlassCard(
            tint: OptivusColors.purpleAccent.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            radius: 20,
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: OptivusColors.purpleAccent,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Routine built',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                      ),
                      if (base.skinCareSuggestedProducts.isNotEmpty) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          key: const ValueKey(
                            'onboarding-step7-selected-products-button',
                          ),
                          tooltip: 'Selected products',
                          onPressed: () => _showSkinCareSelectedProductsSheet(
                            context,
                            products: base.skinCareSuggestedProducts,
                            recommendations:
                                base.skinCareProductRecommendations,
                            accent: OptivusColors.purpleAccent,
                          ),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                          ),
                          color: OptivusColors.purpleAccent,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          splashRadius: 15,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OnboardingActionPill(
                  label: 'Rebuild / Edit',
                  icon: Icons.edit_rounded,
                  accent: OptivusColors.purpleAccent,
                  compact: true,
                  onTap: () => setState(() {
                    _editingExisting = true;
                    _pendingDesiredApplicationsPerDay = null;
                    _showProductSelection =
                        base.skinCareProductRecommendations.isNotEmpty;
                    _generationError = null;
                  }),
                ),
              ],
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
          const SizedBox(height: 12),
          _SkinCareTimelineSection(
            selectedDay: _selectedDay,
            blocks: widget.blocks,
            onDayChanged: (day) => setState(() => _selectedDay = day),
            emptyLabel: 'No skin care scheduled for this day.',
            accent: OptivusColors.purpleAccent,
            specialCareNotes: base.skinCareSpecialCareNotes,
          ),
        ],
      );
    }

    if (_showProductSelection &&
        base.skinCareProductRecommendations.isNotEmpty) {
      final selectedKeys = base.skinCareSelectedProductNames
          .map((name) => name.trim().toLowerCase())
          .toSet();
      final missingEssentialSelections =
          onboarding7MissingEssentialRecommendationCategories(
            base.skinCareProductRecommendations,
            selectedProductNames: base.skinCareSelectedProductNames,
          );
      final selectionMessage = _onboarding7EssentialSelectionMessage(
        missingEssentialSelections,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editingExisting)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey(
                  'onboarding-step7-no-products-cancel-rebuild',
                ),
                onPressed: () => setState(() {
                  _editingExisting = false;
                  _pendingDesiredApplicationsPerDay = null;
                  _showProductSelection = false;
                  _generationError = null;
                }),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel edit'),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OnboardingGlassCard(
                tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
                padding: const EdgeInsets.all(12),
                radius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose products available in $recommendationCountryName',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI matched these to your skin and ${base.skinCareBudget} budget. Select products for $desiredApplicationsPerDay times per day.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: base.skinCareProductRecommendations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final product =
                              base.skinCareProductRecommendations[index];
                          final selected = selectedKeys.contains(
                            product.selectionKey,
                          );
                          final normalizedCategory =
                              onboarding7RecommendationCategory(product);
                          final details = [
                            if (normalizedCategory.isNotEmpty)
                              _onboarding7ProductCategoryLabel(
                                normalizedCategory,
                              )
                            else if (product.category.isNotEmpty)
                              product.category,
                            if (product.estimatedPrice.isNotEmpty)
                              [
                                product.currencyCode,
                                product.estimatedPrice,
                              ].where((part) => part.isNotEmpty).join(' '),
                          ].join(' • ');
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                'onboarding-step7-product-${product.selectionKey}',
                              ),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _toggleProduct(product),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: selected
                                      ? OptivusColors.purpleAccent.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.white.withValues(alpha: 0.38),
                                  border: Border.all(
                                    color: selected
                                        ? OptivusColors.purpleAccent
                                        : Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: selected
                                          ? OptivusColors.purpleAccent
                                          : OptivusColors.textSecondary,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.displayName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: OptivusColors.textPrimary,
                                            ),
                                          ),
                                          if (details.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              details,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    OptivusColors.purpleAccent,
                                              ),
                                            ),
                                          ],
                                          if (product.reason.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              product.reason,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                height: 1.3,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    OptivusColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      _SkinCareInlineMessage(message: message),
                    ],
                    if (message == null && selectionMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        selectionMessage,
                        key: const ValueKey(
                          'onboarding-step7-essential-selection-message',
                        ),
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: busy ? null : _changeDetails,
                          child: const Text('Change details'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SkinCareGenerateRoutineButton(
                            label: 'Build skin routine',
                            busy: busy,
                            accent: OptivusColors.purpleAccent,
                            onTap: !busy && missingEssentialSelections.isEmpty
                                ? _generate
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editingExisting)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SkinCareInlineMessage(
                message: 'Changes not applied yet. Your last routine is kept.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey(
                    'onboarding-step7-no-products-cancel-rebuild',
                  ),
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          _editingExisting = false;
                          _pendingDesiredApplicationsPerDay = null;
                          _generationError = null;
                        }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel edit'),
                ),
              ),
            ],
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OnboardingGlassCard(
              tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(12),
              radius: 18,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dense = constraints.maxHeight < 620;
                  final sectionGap = dense ? 6.0 : 8.0;
                  final content = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No products',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add a clear face photo and tell us your skin needs. The photo is required for personalized product suggestions.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: dense ? 6 : 8),
                      SizedBox(
                        height: dense ? 88 : 104,
                        child: _SkinCarePhotoTarget(
                          asset: effectiveAsset,
                          purpose: UploadedAssetPurpose.skinFace,
                          title: 'Add photo',
                          uploadedTitle: 'Photo uploaded',
                          busy: uploadBusy || _removingPhoto,
                          busyLabel: _removingPhoto
                              ? 'Removing...'
                              : uploadBusy
                              ? _skinCareInteractionStatusLabel(
                                  uploadState!.phase,
                                )
                              : null,
                          localPreviewPath: uploadState?.usablePreviewPath,
                          helperText: effectiveAsset == null
                              ? 'Face photo required'
                              : null,
                          onRemove: busy ? null : _removeUploadedAsset,
                          onTap: busy ? null : _startUpload,
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareChipGroup(
                        label: 'Skin Type',
                        compact: true,
                        children: [
                          for (final option in const [
                            _SkinOption('oily', 'Oily'),
                            _SkinOption('dry', 'Dry'),
                            _SkinOption('combination', 'Combination'),
                            _SkinOption('not_sure', 'Not sure'),
                          ])
                            _SkinCarePreferenceChip(
                              label: option.label,
                              selected: base.skinCareSkinType == option.key,
                              accent: OptivusColors.purpleAccent,
                              compact: true,
                              onTap: busy
                                  ? null
                                  : () => updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) {
                                        final hasRoutine = base.blocks.any(
                                          (block) =>
                                              block.section == 'skin_care',
                                        );
                                        return base.copyWith(
                                          skinCareSkinType: option.key,
                                          clearSkinCareProductRecommendations:
                                              true,
                                          clearSkinCareSelectedProductNames:
                                              !hasRoutine,
                                          clearSkinCareSuggestedProducts:
                                              !hasRoutine,
                                          skinCareSkipped: false,
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareChipGroup(
                        label: 'Concerns',
                        compact: true,
                        children: [
                          for (final option in const [
                            _SkinOption('pimples', 'Acne'),
                            _SkinOption('dark_spots', 'Spots'),
                            _SkinOption('tan', 'Tan'),
                            _SkinOption('dryness', 'Dryness'),
                            _SkinOption('oiliness', 'Oiliness'),
                            _SkinOption('none', 'None'),
                          ])
                            _SkinCarePreferenceChip(
                              label: option.label,
                              selected: base.skinCareProblems.contains(
                                option.key,
                              ),
                              accent: OptivusColors.purpleAccent,
                              compact: true,
                              onTap: busy
                                  ? null
                                  : () {
                                      final next = {...base.skinCareProblems};
                                      if (option.key == 'none') {
                                        next
                                          ..clear()
                                          ..add('none');
                                      } else {
                                        next.remove('none');
                                        next.contains(option.key)
                                            ? next.remove(option.key)
                                            : next.add(option.key);
                                      }
                                      updateBaseTimelineDraft(
                                        ref,
                                        onboardingSkinCareStepIndex,
                                        (base) {
                                          final hasRoutine = base.blocks.any(
                                            (block) =>
                                                block.section == 'skin_care',
                                          );
                                          return base.copyWith(
                                            skinCareProblems: next.toList(),
                                            clearSkinCareProductRecommendations:
                                                true,
                                            clearSkinCareSelectedProductNames:
                                                !hasRoutine,
                                            clearSkinCareSuggestedProducts:
                                                !hasRoutine,
                                            skinCareSkipped: false,
                                          );
                                        },
                                      );
                                    },
                            ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareChipGroup(
                        label: 'Budget',
                        compact: true,
                        children: [
                          for (final option in const [
                            _SkinOption('low', 'Low'),
                            _SkinOption('medium', 'Medium'),
                            _SkinOption('high', 'High'),
                          ])
                            _SkinCarePreferenceChip(
                              label: option.label,
                              selected: base.skinCareBudget == option.key,
                              accent: OptivusColors.purpleAccent,
                              compact: true,
                              onTap: busy
                                  ? null
                                  : () => updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) {
                                        final hasRoutine = base.blocks.any(
                                          (block) =>
                                              block.section == 'skin_care',
                                        );
                                        return base.copyWith(
                                          skinCareBudget: option.key,
                                          clearSkinCareProductRecommendations:
                                              true,
                                          clearSkinCareSelectedProductNames:
                                              !hasRoutine,
                                          clearSkinCareSuggestedProducts:
                                              !hasRoutine,
                                          skinCareSkipped: false,
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                      SizedBox(height: sectionGap),
                      _SkinCareFrequencySelector(
                        value: desiredApplicationsPerDay,
                        accent: OptivusColors.purpleAccent,
                        compact: true,
                        onChanged: busy ? null : _changeDesiredApplications,
                      ),
                      SizedBox(height: dense ? 8 : 10),
                      _SkinCareGenerateRoutineButton(
                        label: 'Find products',
                        busy: busy,
                        accent: OptivusColors.purpleAccent,
                        onTap: !busy && inputsComplete ? _findProducts : null,
                      ),
                      if (!inputsComplete) ...[
                        const SizedBox(height: 5),
                        const Text(
                          'Add a face photo and choose skin type, at least one concern, and budget to continue.',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                      if (message != null) ...[
                        const SizedBox(height: 6),
                        _SkinCareInlineMessage(message: message, compact: true),
                      ],
                    ],
                  );
                  return SingleChildScrollView(
                    key: const ValueKey(
                      'onboarding-step7-no-products-scroll-view',
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: content,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkinCarePhotoTarget extends ConsumerWidget {
  final UploadedAsset? asset;
  final String? localPreviewPath;
  final UploadedAssetPurpose purpose;
  final String title;
  final String uploadedTitle;
  final bool busy;
  final String? busyLabel;
  final bool enabled;
  final String? helperText;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _SkinCarePhotoTarget({
    required this.asset,
    this.localPreviewPath,
    this.purpose = UploadedAssetPurpose.skinProducts,
    this.title = 'Add photo',
    this.uploadedTitle = 'Photo uploaded',
    this.busy = false,
    this.busyLabel,
    this.enabled = true,
    this.helperText,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview =
        localPreviewPath ??
        (asset == null ? null : usableUploadedAssetLocalPreviewPath(asset!));
    final restoredUploads = ref.watch(restoredUploadsProvider);
    final restored =
        restoredUploads.forPurpose(purpose) ??
        (purpose == UploadedAssetPurpose.skinProducts ||
                purpose == UploadedAssetPurpose.skinFace
            ? restoredUploads.forPurpose(UploadedAssetPurpose.skinCare)
            : null);
    final remotePreview = restored?.asset.assetId == asset?.assetId
        ? restored?.previewUri
        : null;
    final previewStatus = restored?.asset.assetId == asset?.assetId
        ? restored?.previewStatus
        : UploadedAssetPreviewStatus.unavailable;
    final fileName = asset?.fileName.trim();

    return GestureDetector(
      key: const ValueKey('onboarding-step7-photo-tile'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.55,
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: preview != null
                      ? Image.file(
                          File(preview),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _fallback(previewStatus, fileName),
                        )
                      : remotePreview != null
                      ? Image.network(
                          remotePreview.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _fallback(
                            UploadedAssetPreviewStatus.unavailable,
                            fileName,
                          ),
                        )
                      : _fallback(previewStatus, fileName),
                ),
              ),
              if (busy)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.38),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: OptivusColors.roseAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            busyLabel ?? 'Uploading...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.roseAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (asset != null && !busy && onRemove != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    key: const ValueKey('onboarding-step7-remove-photo-button'),
                    onTap: onRemove,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(
    UploadedAssetPreviewStatus? previewStatus,
    String? fileName,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          asset == null
              ? Icons.add_photo_alternate_rounded
              : Icons.check_circle_rounded,
          color: enabled
              ? OptivusColors.roseAccent
              : OptivusColors.textSecondary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          asset == null ? title : uploadedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: enabled
                ? OptivusColors.textPrimary
                : OptivusColors.textSecondary,
          ),
        ),
        if (asset != null) ...[
          if (fileName != null && fileName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              fileName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            previewStatus == UploadedAssetPreviewStatus.loading
                ? 'Loading preview…'
                : 'Preview unavailable',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(helperText!, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _SkinCareInlineMessage extends StatelessWidget {
  final String message;
  final bool compact;

  const _SkinCareInlineMessage({required this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: OptivusColors.roseAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: OptivusColors.roseAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: OptivusColors.roseAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: compact ? 10 : 11.5,
                height: compact ? 1.2 : null,
                fontWeight: FontWeight.w800,
                color: OptivusColors.roseAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _skinCareSelectedProductIcon(String category) {
  return switch (category) {
    'cleanser' => Icons.face_retouching_natural_rounded,
    'moisturizer' => Icons.water_drop_rounded,
    'sunscreen' => Icons.wb_sunny_rounded,
    'vitamin_c_serum' => Icons.brightness_7_rounded,
    'treatment_serum' => Icons.science_rounded,
    _ => Icons.spa_rounded,
  };
}

void _showSkinCareSelectedProductsSheet(
  BuildContext context, {
  required List<String> products,
  required List<SkinCareProductRecommendationDraft> recommendations,
  required Color accent,
}) {
  final recommendationsByKey = {
    for (final product in recommendations) product.selectionKey: product,
  };
  final initialSize = math.min(0.78, 0.34 + (products.length * 0.075));

  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.24),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: 0.38,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: OptivusColors.textSecondary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected products',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Products used to build your routine',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${products.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey(
                      'onboarding-step7-selected-products-close',
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: OptivusColors.textSecondary,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: OptivusColors.textSecondary.withValues(alpha: 0.1),
            ),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('onboarding-step7-selected-products-list'),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final productName = products[index];
                  final recommendation =
                      recommendationsByKey[productName.trim().toLowerCase()];
                  final category = recommendation == null
                      ? ''
                      : onboarding7RecommendationCategory(recommendation);
                  final details = [
                    if (category.isNotEmpty)
                      _onboarding7ProductCategoryLabel(category),
                    if (recommendation?.estimatedPrice.isNotEmpty ?? false)
                      [
                        recommendation!.currencyCode,
                        recommendation.estimatedPrice,
                      ].where((part) => part.isNotEmpty).join(' '),
                  ].join(' • ');

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _skinCareSelectedProductIcon(category),
                            color: accent,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  details,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_rounded,
                          color: accent,
                          size: 19,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showSkinCareSpecialCareNotesSheet(
  BuildContext context,
  List<String> notes,
  Color accent,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Special-care notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final note in notes) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              note,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SkinCareTimelineSection extends ConsumerWidget {
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final ValueChanged<int> onDayChanged;
  final String emptyLabel;
  final Color accent;
  final List<String> specialCareNotes;

  const _SkinCareTimelineSection({
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
    required this.emptyLabel,
    required this.accent,
    this.specialCareNotes = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = SkinTimelineAdapter(accent: accent);
    final entries = [for (final block in blocks) ...adapter.toEntries(block)];
    return Expanded(
      child: FullScreenTimelineScaffold(
        key: const ValueKey('onboarding-step7-full-timeline'),
        entries: entries,
        selectedDay: selectedDay,
        onDayChanged: onDayChanged,
        title: 'Your Routine',
        emptyDayMessage: emptyLabel,
        accent: accent,
        styleBuilder: adapter.styleForEntry,
        blockBuilder: (context, positioned) {
          final block = blocks
              .where((candidate) => candidate.id == positioned.entry.sourceId)
              .first;
          return _SkinCareBlockCard(
            item: block,
            baseColor: accent,
            onEditRequested: () =>
                _showSkinCareBlockEditSheet(context, ref, block, accent),
          );
        },
        headerBanner: specialCareNotes.isEmpty
            ? null
            : Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your Routine',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey(
                      'onboarding-step7-special-care-notes-button',
                    ),
                    onPressed: () => _showSkinCareSpecialCareNotesSheet(
                      context,
                      specialCareNotes,
                      accent,
                    ),
                    icon: Icon(Icons.info_outline_rounded, color: accent),
                  ),
                ],
              ),
        onEntryTapped: (entry) {
          final block = blocks
              .where((candidate) => candidate.id == entry.sourceId)
              .firstOrNull;
          if (block == null) return;
          _showSkinCareBlockEditSheet(context, ref, block, accent);
        },
      ),
    );
  }
}

// ignore: unused_element
Future<void> _showSkinCareBlockEditSheet(
  BuildContext context,
  WidgetRef ref,
  TimelineBlockDraft block,
  Color accent,
) async {
  final titleCtrl = TextEditingController(text: block.title);
  final startTimeCtrl = TextEditingController(
    text: onboardingTimeLabel(block.startMinute),
  );
  final productsCtrl = TextEditingController(
    text: block.skincareProducts.join('\n'),
  );
  final stepsCtrl = TextEditingController(text: block.skincareSteps.join('\n'));
  final selectedDays = <int>{
    ...block.repeatDays.where((day) => day >= 1 && day <= 7),
  };
  if (selectedDays.isEmpty) selectedDays.addAll(onboardingEveryDay());
  final formKey = GlobalKey<FormState>();
  String? sheetError;

  try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setError(String? value) {
              setSheetState(() => sheetError = value);
            }

            TimelineBlockDraft? candidateFromInputs() {
              final parsedStart = _parseClockMinute(startTimeCtrl.text);
              final title = titleCtrl.text.trim();
              final repeatDays = selectedDays.toList()..sort();
              final parsedProducts = productsCtrl.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final parsedSteps = stepsCtrl.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (title.isEmpty) {
                setError('Routine title is required.');
                return null;
              }
              if (parsedStart == null) {
                setError('Use a valid start time like 7:45 AM.');
                return null;
              }
              if (parsedStart + onboarding7SkinCareDurationMinutes > 24 * 60) {
                setError('Choose a time before midnight.');
                return null;
              }
              if (repeatDays.isEmpty) {
                setError('Select at least one repeat day.');
                return null;
              }
              if (parsedProducts.isEmpty && parsedSteps.isEmpty) {
                setError('Add at least one product or routine step.');
                return null;
              }
              return block.copyWith(
                title: title,
                startMinute: parsedStart,
                endMinute: parsedStart + onboarding7SkinCareDurationMinutes,
                repeatDays: repeatDays,
                skincareProducts: parsedProducts,
                skincareSteps: parsedSteps,
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit skin-care block',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F111A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Duration stays fixed at 15 minutes.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: OptivusColors.textSecondary.withValues(
                                  alpha: 0.86,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (sheetError != null) ...[
                              Container(
                                key: const ValueKey(
                                  'onboarding-step7-edit-error',
                                ),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: OptivusColors.danger.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: OptivusColors.danger.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  sheetError!,
                                  style: const TextStyle(
                                    color: OptivusColors.danger,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(7, (index) {
                                  final dayName = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ][index];
                                  final day = index + 1;
                                  final isSelected = selectedDays.contains(day);
                                  return GestureDetector(
                                    key: ValueKey(
                                      'onboarding-step7-edit-day-$day',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setSheetState(() {
                                      if (selectedDays.contains(day)) {
                                        selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
                                      }
                                    }),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accent
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? accent
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        dayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-title-field',
                              ),
                              controller: titleCtrl,
                              decoration: InputDecoration(
                                labelText: 'Title',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-start-time-field',
                              ),
                              controller: startTimeCtrl,
                              decoration: InputDecoration(
                                labelText: 'Start time',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-products-field',
                              ),
                              controller: productsCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Products (one per line)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey(
                                'onboarding-step7-edit-steps-field',
                              ),
                              controller: stepsCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Steps (one per line)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey(
                                    'onboarding-step7-find-free-time-button',
                                  ),
                                  onPressed: () {
                                    final candidate = candidateFromInputs();
                                    if (candidate == null) return;
                                    final base = ref
                                        .read(mockOnboardingProvider)
                                        .draft
                                        .baseTimeline;
                                    final freeStart =
                                        onboarding7FindFreeStartForSkinCareEdit(
                                          baseTimeline: base,
                                          block: candidate,
                                          preferredStartMinute:
                                              candidate.startMinute,
                                        );
                                    if (freeStart == null) {
                                      setError(
                                        'No free 15-minute skin-care slot was found.',
                                      );
                                      return;
                                    }
                                    setSheetState(() {
                                      sheetError = null;
                                      startTimeCtrl.text = onboardingTimeLabel(
                                        freeStart,
                                      );
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.manage_search_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Find free time'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: accent,
                                    side: BorderSide(
                                      color: accent.withValues(alpha: 0.55),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton(
                                  key: const ValueKey(
                                    'onboarding-step7-edit-save-button',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final candidate = candidateFromInputs();
                                    if (candidate == null) return;
                                    final base = ref
                                        .read(mockOnboardingProvider)
                                        .draft
                                        .baseTimeline;
                                    final conflicts =
                                        onboarding7SkinCareCandidateConflicts(
                                          baseTimeline: base,
                                          candidate: candidate,
                                          excludingBlockId: block.id,
                                        );
                                    if (conflicts) {
                                      setError(
                                        'That time overlaps another onboarding block. Choose a free 15-minute slot.',
                                      );
                                      return;
                                    }

                                    updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) => base.copyWith(
                                        blocks: [
                                          for (final item in base.blocks)
                                            if (item.id == block.id)
                                              candidate
                                            else
                                              item,
                                        ],
                                      ),
                                    );
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    titleCtrl.dispose();
    startTimeCtrl.dispose();
    productsCtrl.dispose();
    stepsCtrl.dispose();
  }
}

int? _parseClockMinute(String value) {
  final text = value.trim().toLowerCase();
  final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(text);
  if (match == null) return null;
  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0');
  final period = match.group(3);
  if (hour == null || minute == null || minute < 0 || minute > 59) {
    return null;
  }
  if (period != null) {
    if (hour < 1 || hour > 12) return null;
    if (period == 'am') {
      hour = hour == 12 ? 0 : hour;
    } else {
      hour = hour == 12 ? 12 : hour + 12;
    }
  } else if (hour > 23) {
    return null;
  }
  return hour * 60 + minute;
}

// ignore: unused_element
double _calculateRequiredSkinCareBlockHeight({
  required BuildContext context,
  required TimelineBlockDraft block,
  required String timeLabel,
  required double blockWidth,
}) {
  final steps = _skinCareInstructionLines(block);
  final products = block.skincareProducts
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final missingItems = block.skincareMissingItems
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final contentWidth = math.max(80.0, blockWidth - 34.0);
  var height = 20.0;
  height += _measureTextHeight(
    context: context,
    text: block.title,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
    width: contentWidth,
    maxLines: 2,
  );
  height += 5.0;
  height += _measureTextHeight(
    context: context,
    text: timeLabel,
    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
    width: contentWidth,
    maxLines: 1,
  );
  if (steps.isNotEmpty) {
    height += 7.0;
    for (var i = 0; i < steps.length; i += 1) {
      height += _measureTextHeight(
        context: context,
        text: '${i + 1}. ${steps[i]}',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        width: contentWidth,
        maxLines: 3,
      );
      if (i != steps.length - 1) height += 4.0;
    }
  }
  if (products.isNotEmpty) {
    height += 8.0;
    height += _measureTextHeight(
      context: context,
      text: products.join(', '),
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
      width: contentWidth,
      maxLines: 3,
    );
  }
  if (missingItems.isNotEmpty) {
    height += products.isNotEmpty ? 5.0 : 8.0;
    for (var i = 0; i < missingItems.length; i += 1) {
      height += _measureTextHeight(
        context: context,
        text: missingItems[i],
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        width: contentWidth - 18.0,
        maxLines: 2,
      );
      height += 10.0;
      if (i != missingItems.length - 1) height += 4.0;
    }
  }
  height += 40.0;
  return math.min(430.0, math.max(110.0, height));
}

double _measureTextHeight({
  required BuildContext context,
  required String text,
  required TextStyle style,
  required double width,
  int? maxLines,
}) {
  if (text.trim().isEmpty) return 0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
  )..layout(maxWidth: width);
  return painter.height;
}

List<String> _skinCareInstructionLines(TimelineBlockDraft block) {
  final source = block.skincareSteps.isNotEmpty
      ? block.skincareSteps
      : block.skincareProducts;
  return source
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

// ignore: unused_element
class _SkinCareBlockCard extends StatelessWidget {
  final TimelineBlockDraft item;
  final Color baseColor;
  final VoidCallback? onEditRequested;

  const _SkinCareBlockCard({
    required this.item,
    required this.baseColor,
    // ignore: unused_element_parameter
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final instructionLines = [
      if (item.skincareSteps.isNotEmpty)
        ...item.skincareSteps.map((i) => i.trim()).where((i) => i.isNotEmpty)
      else
        ...item.skincareProducts
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty),
    ];
    final productNames = item.skincareProducts
        .map((product) => product.trim())
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
    final missingItems = item.skincareMissingItems
        .map((product) => product.trim())
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
    final timeLabel = TimelineUtils.formatTimeRange(
      item.startMinute,
      item.endMinute,
    );

    return Container(
      key: ValueKey('onboarding-step7-block-${item.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.72),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.26),
            baseColor.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.96),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.face_retouching_natural_rounded,
                        color: baseColor,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F111A),
                          ),
                        ),
                      ),
                      if (onEditRequested != null) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            key: ValueKey('onboarding-step7-edit-${item.id}'),
                            tooltip: 'Edit',
                            padding: EdgeInsets.zero,
                            onPressed: onEditRequested,
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: baseColor.withValues(alpha: 0.82),
                    ),
                  ),
                  if (instructionLines.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    for (var i = 0; i < instructionLines.length; i += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == instructionLines.length - 1 ? 0 : 4,
                        ),
                        child: Text(
                          '${i + 1}. ${instructionLines[i]}',
                          key: ValueKey('onboarding-step7-step-${item.id}-$i'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary.withValues(
                              alpha: 0.86,
                            ),
                            height: 1.24,
                          ),
                        ),
                      ),
                  ],
                  if (productNames.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      productNames.join(', '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (missingItems.isNotEmpty) ...[
                    SizedBox(height: productNames.isNotEmpty ? 5 : 7),
                    for (var i = 0; i < missingItems.length; i += 1)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == missingItems.length - 1 ? 0 : 4,
                        ),
                        child: Container(
                          key: ValueKey(
                            'onboarding-step7-missing-item-${item.id}-$i',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: OptivusColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: OptivusColors.danger.withValues(
                                alpha: 0.22,
                              ),
                            ),
                          ),
                          child: Text(
                            missingItems[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.danger.withValues(
                                alpha: 0.92,
                              ),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinCareChipGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool compact;

  const _SkinCareChipGroup({
    required this.label,
    required this.children,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10.5 : 11,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Wrap(
          spacing: compact ? 6 : 8,
          runSpacing: compact ? 5 : 8,
          children: children,
        ),
      ],
    );
  }
}

class _SkinCarePreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;

  const _SkinCarePreferenceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : OptivusColors.textSecondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11.5 : 12,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? Colors.white : OptivusColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SkinOption {
  final String key;
  final String label;

  const _SkinOption(this.key, this.label);
}
