import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step_7_skin_care_scheduler.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_timeline_preview.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

const String onboardingSkinCareGeneratedSource = 'ai_skin_care_setup';
const String onboarding7CompactPayloadFinalMessage =
    'AI read too much product detail. Try typing only your main products or upload a clearer single photo.';
const int _onboarding7SpecialCareNoteMaxLength = 180;
const String _onboarding7NoTypedProductsMessage =
    'Type one product per line, for example "Minimalist SPF 50 - sunscreen".';
const String _onboarding7AiEmptyMessage =
    'AI returned no usable routine. Try clearer product names or 2 times/day.';
const String _onboarding7AiFewerRoutinesMessage =
    'AI returned fewer routines than requested. Try again or choose fewer times per day.';
const String _onboarding7PhotoUnreadableMessage =
    'AI could not read your products. Upload a clearer photo or use typed product names.';

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

  for (final raw in text.split(RegExp(r'[\n,]+'))) {
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
  if (text.contains('provider_quota_exceeded') ||
      text.contains('provider_high_demand') ||
      text.contains('provider_request_failed') ||
      text.contains('rate_limit')) {
    return 'AI is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_invalid_response') ||
      text.contains('provider_invalid_json')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (text.contains('unsafe_frequency') ||
      text.contains('may not safely support')) {
    return onboarding7UnsafeFrequencyMessage;
  }
  if (text.contains('unavailable') || text.contains('provider_timeout')) {
    return 'AI skin care service is unavailable. Try again later.';
  }
  if (messages.isNotEmpty && !messages.first.startsWith('provider_')) {
    return messages.first;
  }
  return 'AI failed to generate a routine. Try adding more details.';
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

  return SkinCareDetectedProduct(
    name: name,
    category: category,
    source: 'typed',
  );
}

String _normalizeTypedProductCategory(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 /_-]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return '';

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
    'retinol',
  };
  if (!known.contains(normalized)) return '';
  return switch (normalized) {
    'face wash' => 'cleanser',
    'moisturiser' => 'moisturizer',
    'spf' => 'sunscreen',
    'exfoliator' => 'exfoliant',
    'mask' => 'face mask',
    'retinol' => 'serum',
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
  if (lower.contains('serum') ||
      lower.contains('vitamin c') ||
      lower.contains('alpha arbutin') ||
      lower.contains('niacinamide')) {
    return 'serum';
  }
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

bool _hasUnsafeFrequencyWarning(Iterable<String> warnings) {
  return warnings.any((warning) {
    final lower = warning.toLowerCase();
    return lower.contains('unsafe_frequency') ||
        lower.contains('may not safely support') ||
        lower.contains('try 2 times per day');
  });
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
  if (lower.contains('heic') ||
      lower.contains('heif') ||
      lower.contains('format') ||
      lower.contains('content type')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  return value;
}

String _skinCareUploadStatusLabel(UploadFlowStatus status) {
  return switch (status) {
    UploadFlowStatus.picking => 'Picking...',
    UploadFlowStatus.preparing => 'Preparing...',
    UploadFlowStatus.signing => 'Preparing...',
    UploadFlowStatus.uploading => 'Uploading...',
    UploadFlowStatus.savingMetadata => 'Saving...',
    _ => 'Uploading...',
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
  if (key.endsWith('.jpg') || key.endsWith('.jpeg')) return 'image/jpeg';
  if (key.endsWith('.png')) return 'image/png';
  if (key.endsWith('.webp')) return 'image/webp';
  if (key.endsWith('.heic')) return 'image/heic';
  if (key.endsWith('.heif')) return 'image/heif';
  if (key.endsWith('.gif')) return 'image/gif';
  if (key.endsWith('.pdf')) return 'application/pdf';
  return '';
}

UploadedAsset? _skinCareProductPhotoAssetFromDraft(OnboardingDraft draft) {
  final base = draft.baseTimeline;
  final r2Key = base.skinCareProductPhotoR2Key?.trim();
  if (r2Key == null || r2Key.isEmpty) return null;
  final createdAt =
      base.skinCareProductPhotoCreatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final updatedAt = base.skinCareProductPhotoUpdatedAt ?? createdAt;
  final fileName = r2Key.split('/').where((part) => part.isNotEmpty).lastOrNull;
  return UploadedAsset(
    assetId: base.skinCareProductPhotoAssetId?.trim().isNotEmpty == true
        ? base.skinCareProductPhotoAssetId!.trim()
        : r2Key,
    ownerUid: draft.uid,
    sourceFeature: OnboardingDraft.sourceOnboarding,
    purpose: UploadedAssetPurpose.skinCare,
    fileName: fileName ?? 'skin-care-products',
    contentType: _skinCareImageContentTypeFromR2Key(r2Key),
    sizeBytes: 0,
    r2Key: r2Key,
    status: uploadedAssetStatusFromString(
      base.skinCareProductPhotoStatus?.trim().isNotEmpty == true
          ? base.skinCareProductPhotoStatus
          : 'uploaded',
    ),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
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
          const _SkinCareHeader(),
          const SizedBox(height: 18),
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
    void select(String value) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final isSkip = value == 'skip';
        final switchedPath = base.skinCareSetupPath != value;
        final clearProductData =
            isSkip ||
            (switchedPath && base.skinCareSetupPath == 'has_products');
        final clearNoProductsData =
            isSkip || (switchedPath && base.skinCareSetupPath == 'no_products');
        final blocks = switchedPath || isSkip
            ? base.blocks.where((b) => b.section != 'skin_care').toList()
            : base.blocks;
        return base.copyWith(
          blocks: blocks,
          skinCareSetupPath: value,
          skinCareSetupStep: 1,
          skinCareSkipped: isSkip,
          skinCareSpecialCareNotes: clearProductData
              ? const []
              : base.skinCareSpecialCareNotes,
          clearSkinCareProductNames: clearProductData,
          clearSkinCareProductPhoto: clearProductData,
          clearSkinCareSkinType: clearNoProductsData,
          clearSkinCareProblems: clearNoProductsData,
          clearSkinCareBudget: clearNoProductsData,
          clearSkinCarePreference: clearNoProductsData,
        );
      });
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: OnboardingStepShell.bottomCtaHeight + 40,
      ),
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
            title: 'Build routine for me',
            subtitle: 'Answer skin details to generate a routine.',
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
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  bool _generating = false;
  String? _generationError;
  late _ProductInputSource _inputSource;
  int _selectedDay = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.base.skinCareProductNames);
    _inputSource = _initialProductInputSource(widget.base);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    if (_inputSource == _ProductInputSource.typed) return;
    final uploadState = ref.read(uploadControllerProvider);
    if (uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare &&
        uploadState.isBusy) {
      return;
    }
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    UploadedAsset? asset;
    try {
      final uid =
          ref.read(authProvider).user?.uid ??
          ref.read(mockOnboardingProvider).draft.uid;
      asset = await ref
          .read(uploadControllerProvider.notifier)
          .startUpload(
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            purpose: UploadedAssetPurpose.skinCare,
          );
    } catch (_) {}
    if (!mounted) return;

    final latestUploadState = ref.read(uploadControllerProvider);
    final latestAsset = asset ?? latestUploadState.asset;
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
      } else if (_inputSource == _ProductInputSource.photo) {
        _inputSource = _ProductInputSource.none;
      }
      _uploadError = latestUploadState.status == UploadFlowStatus.failed
          ? _friendlySkinCareUploadMessage(latestUploadState.errorMessage)
          : null;
      _generationError = null;
    });
  }

  void _removeUploadedAsset() {
    final uploadState = ref.read(uploadControllerProvider);
    final uploadBusy =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare &&
        uploadState.isBusy;
    if (uploadBusy) return;
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
      _generationError = null;
      _inputSource = _ProductInputSource.none;
    });
    updateBaseTimelineDraft(
      ref,
      onboardingSkinCareStepIndex,
      (base) => base.copyWith(
        clearSkinCareProductPhoto: true,
        skinCareSkipped: false,
      ),
    );
  }

  Future<void> _generate() async {
    if (_generating) return;
    final uploadState = ref.read(uploadControllerProvider);
    final uploadBusy =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare &&
        uploadState.isBusy;
    if (uploadBusy) return;

    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final activeSource = _inputSource;
    final asset =
        _uploadedAsset ??
        _skinCareProductPhotoAssetFromDraft(
          ref.read(mockOnboardingProvider).draft,
        );
    final typedProductDetails = onboarding7ParseTypedProductDetails(
      _controller.text,
    );
    if (activeSource == _ProductInputSource.none) {
      setState(() {
        _generationError = _onboarding7NoTypedProductsMessage;
        _uploadError = null;
      });
      return;
    }
    if (activeSource == _ProductInputSource.typed &&
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

    setState(() {
      _generating = true;
      _generationError = null;
      _uploadError = null;
    });

    try {
      if (kDebugMode) {
        debugPrint(
          '[Onboarding7] skinCareWorkerUrlPresent='
          '${OptivusAiWorkersConfig.skinCareWorkerUrl.trim().isNotEmpty} '
          'mode=${OptivusAiWorkersConfig.mode.name} '
          'activeSource=${activeSource.name} '
          'productPhotoPresent=${asset != null} '
          'r2KeyPresent=${asset?.r2Key.trim().isNotEmpty == true}',
        );
        if (OptivusAiWorkersConfig.useWorker &&
            OptivusAiWorkersConfig.skinCareWorkerUrl.trim().isEmpty) {
          debugPrint(
            '[Onboarding7] Missing OPTIVUS_SKIN_CARE_WORKER_URL for Skin Care AI.',
          );
        }
      }
      final user = ref.read(authProvider).user;
      final idToken =
          await ref.read(authRepositoryProvider).currentIdToken() ?? '';
      final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
      final client = ref.read(skinCareAiClientProvider);
      final desiredApplicationsPerDay = ref
          .read(mockOnboardingProvider)
          .draft
          .baseTimeline
          .skinCareDesiredApplicationsPerDay;

      List<SkinCareDetectedProduct> photoProductDetails = [];
      List<String> photoProductNames = [];
      List<SkinCareDetectedProduct> ownedProductDetails = [];
      List<String> ownedProductNames = [];
      Map<String, dynamic> routineParams;

      if (activeSource == _ProductInputSource.photo) {
        final analysis = await client.analyzeProducts(
          uid: uid,
          idToken: idToken,
          productPhotos: [asset!.r2Key.trim()],
        );
        if (kDebugMode) {
          debugPrint(
            '[Onboarding7] product-analysis status='
            '${analysis.hasError ? 'error:${analysis.errorMessage}' : 'ok'} '
            'warnings=${analysis.warnings.join('|')} '
            'products=${analysis.products.length}',
          );
        }
        if (analysis.hasError) {
          if (!mounted) return;
          setState(() {
            _generating = false;
            _generationError = onboarding7FriendlyAiMessage(
              analysis.errorMessage,
              analysis.warnings,
            );
          });
          return;
        }
        photoProductDetails = analysis.detectedProducts;
        photoProductNames = onboarding7ExtractPhotoProductNames(
          analysis.products,
        );
        final hasMeaningfulPhotoProducts = photoProductDetails.any(
          (product) => product.hasMeaningfulData,
        );
        if (photoProductNames.isEmpty && !hasMeaningfulPhotoProducts) {
          if (!mounted) return;
          setState(() {
            _generating = false;
            _generationError = _onboarding7PhotoUnreadableMessage;
          });
          return;
        }
        ownedProductDetails = photoProductDetails;
        ownedProductNames = photoProductNames;
        routineParams = {
          'productInputSource': 'photo',
          'productsFromPhoto': photoProductDetails
              .map((product) => product.toMap())
              .toList(),
          'photoProductNames': photoProductNames,
          'desiredApplicationsPerDay': desiredApplicationsPerDay,
          'skinType': 'unknown',
          'mainProblem': 'none',
          'budget': 'medium',
          'routinePreference': 'balanced',
        };
      } else {
        ownedProductDetails = typedProductDetails;
        ownedProductNames = typedProductDetails
            .map((product) => product.displayName.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
        routineParams = {
          'productInputSource': 'typed',
          'typedProductDetails': typedProductDetails
              .map((product) => product.toMap())
              .toList(),
          'desiredApplicationsPerDay': desiredApplicationsPerDay,
          'skinType': 'unknown',
          'mainProblem': 'none',
          'budget': 'medium',
          'routinePreference': 'balanced',
        };
      }

      if (kDebugMode) {
        debugPrint(
          '[Onboarding7] activeSource=${activeSource.name} '
          'typedProductDetails=${typedProductDetails.map((e) => e.toMap()).toList()} '
          'photoProductsDetected=${photoProductDetails.map((e) => e.toMap()).toList()}',
        );
      }

      var result = await client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: routineParams,
      );

      var didCompactPayloadRetry = false;
      if (result.hasError && result.errorCode == 'json_payload_too_large') {
        didCompactPayloadRetry = true;
        if (kDebugMode) {
          debugPrint(
            '[Onboarding7] Payload too large, retrying with compact payload...',
          );
        }
        result = await client.generateRoutine(
          uid: uid,
          idToken: idToken,
          params: {
            ...routineParams,
            if (activeSource == _ProductInputSource.photo)
              'productsFromPhoto': photoProductDetails
                  .map((product) => product.toCompactRoutinePayload())
                  .toList(),
            if (activeSource == _ProductInputSource.typed)
              'typedProductDetails': typedProductDetails
                  .map((product) => product.toCompactRoutinePayload())
                  .toList(),
            'compact': true,
          },
        );
      }

      if (kDebugMode) {
        debugPrint(
          '[Onboarding7] routine-generate status='
          '${result.hasError ? 'error:${result.errorMessage}' : 'ok'} '
          'warnings=${result.warnings.join('|')} '
          'routinePlans=${result.routinePlans.length} '
          'timelineBlocks=${result.timelineBlocks.length}',
        );
        debugPrint(
          '[Onboarding7] routinePlansReturned='
          '${result.routinePlans.map((plan) => plan.toMap()).toList()}',
        );
        debugPrint('[Onboarding7] weeklyRoutine=${result.weeklyRoutine}');
        debugPrint(
          '[Onboarding7] suggestedProducts=${result.suggestedProducts}',
        );
        debugPrint('[Onboarding7] warnings=${result.warnings}');
        debugPrint(
          '[Onboarding7] rejectedPlanReasons=${result.rejectedPlanReasons}',
        );
      }
      final routinePlans = result.routinePlans;

      if (result.hasError || routinePlans.isEmpty) {
        if (!mounted) return;
        setState(() {
          _generating = false;
          if (routinePlans.isEmpty && !result.hasError) {
            _generationError = _onboarding7AiEmptyMessage;
          } else {
            _generationError =
                didCompactPayloadRetry &&
                    result.errorCode == 'json_payload_too_large'
                ? onboarding7CompactPayloadFinalMessage
                : onboarding7FriendlyAiMessage(
                    result.errorMessage,
                    result.warnings,
                  );
          }
        });
        return;
      }

      final partitioned = onboarding7PartitionRoutinePlans(routinePlans);
      final dailyPlans = partitioned.dailyPlans;
      final specialPlans = partitioned.specialCarePlans;
      final aiReturnedFewerDailyPlans =
          dailyPlans.length < desiredApplicationsPerDay;
      final unsafeFrequencyReturned =
          aiReturnedFewerDailyPlans &&
          dailyPlans.isNotEmpty &&
          _hasUnsafeFrequencyWarning(result.warnings);
      final specialCareNotesForResult = () {
        final missingProductNotes = onboarding7MissingBasicProductNotes(
          productNames: ownedProductNames,
          productDetails: ownedProductDetails,
        );
        return onboarding7SpecialCareNotesFromAiResult(
          suggestedProducts: [
            ...result.suggestedProducts,
            ...missingProductNotes,
          ],
          weeklyRoutine: result.weeklyRoutine,
          specialCarePlans: specialPlans,
          ownedProductNames: ownedProductNames,
        );
      }();

      if (aiReturnedFewerDailyPlans && !unsafeFrequencyReturned) {
        updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
          return base.copyWith(
            blocks: base.blocks.where((b) => b.section != 'skin_care').toList(),
            skinCareProductNames: _controller.text,
            skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
            skinCareSkipped: false,
            skinCareSpecialCareNotes: specialCareNotesForResult,
          );
        });
        if (!mounted) return;
        setState(() {
          _generating = false;
          _generationError = dailyPlans.isEmpty
              ? _onboarding7AiEmptyMessage
              : _onboarding7AiFewerRoutinesMessage;
        });
        return;
      }

      final scheduleApplicationsPerDay = unsafeFrequencyReturned
          ? dailyPlans.length
          : desiredApplicationsPerDay;

      final schedule = onboarding7ScheduleSkinCareRoutine(
        baseTimeline: ref.read(mockOnboardingProvider).draft.baseTimeline,
        routinePlans: dailyPlans,
        desiredApplicationsPerDay: scheduleApplicationsPerDay,
        ownedProductNames: ownedProductNames,
        ownedProductDetails: ownedProductDetails,
        forceEveryDay: true,
      );
      if (schedule.hasError || schedule.blocks.isEmpty) {
        updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
          return base.copyWith(
            blocks: base.blocks.where((b) => b.section != 'skin_care').toList(),
            skinCareProductNames: _controller.text,
            skinCareDesiredApplicationsPerDay: desiredApplicationsPerDay,
            skinCareSkipped: false,
            skinCareSpecialCareNotes: specialCareNotesForResult,
          );
        });
        if (!mounted) return;
        setState(() {
          _generating = false;
          _generationError = unsafeFrequencyReturned
              ? onboarding7UnsafeFrequencyMessage
              : schedule.errorMessage ?? _onboarding7AiEmptyMessage;
        });
        return;
      }

      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final List<TimelineBlockDraft> nextBlocks =
            base.blocks.where((b) => b.section != 'skin_care').toList()
              ..addAll(schedule.blocks);
        return base.copyWith(
          blocks: nextBlocks,
          skinCareProductNames: _controller.text,
          skinCareDesiredApplicationsPerDay: scheduleApplicationsPerDay,
          skinCareSkipped: false,
          skinCareSpecialCareNotes: specialCareNotesForResult,
        );
      });

      if (!mounted) return;
      setState(() {
        _generating = false;
        _generationError = unsafeFrequencyReturned
            ? onboarding7UnsafeFrequencyMessage
            : null;
      });
    } catch (e, st) {
      debugPrint('Error generating routine (Products): $e\n$st');
      setState(() {
        _generating = false;
        _generationError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;
    final draft = ref.watch(mockOnboardingProvider).draft;
    final effectiveAsset =
        _uploadedAsset ?? _skinCareProductPhotoAssetFromDraft(draft);
    final uploadState = ref.watch(uploadControllerProvider);
    final uploadApplies =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare;
    final uploadBusy = uploadApplies && uploadState.isBusy;
    final uploadError =
        _uploadError ??
        (uploadApplies && uploadState.status == UploadFlowStatus.failed
            ? _friendlySkinCareUploadMessage(uploadState.errorMessage)
            : null);
    final busy = uploadBusy || _generating;
    final sourceLabel = _productInputSourceLabel(_inputSource);
    final textInputEnabled = !busy && _inputSource != _ProductInputSource.photo;
    final photoUploadEnabled =
        !busy && _inputSource != _ProductInputSource.typed;
    final typedPreviewProducts = _inputSource == _ProductInputSource.typed
        ? onboarding7ParseTypedProductDetails(_controller.text)
        : const <SkinCareDetectedProduct>[];

    final setupCard = _HasProductsSetupCard(
      controller: _controller,
      asset: effectiveAsset,
      tileHeight: _setupTileHeight,
      sourceLabel: sourceLabel,
      typedPreviewProducts: typedPreviewProducts,
      desiredApplicationsPerDay: widget.base.skinCareDesiredApplicationsPerDay,
      uploadBusy: uploadBusy,
      uploadStatusLabel: uploadBusy
          ? _skinCareUploadStatusLabel(uploadState.status)
          : null,
      busy: busy,
      generating: _generating,
      photoEnabled: photoUploadEnabled,
      textInputEnabled: textInputEnabled,
      photoHelper: _inputSource == _ProductInputSource.typed
          ? 'Clear product names to upload a photo.'
          : null,
      textHelper: _inputSource == _ProductInputSource.photo
          ? 'Remove photo to type products manually.'
          : null,
      onUpload: photoUploadEnabled ? _startUpload : null,
      onRemove: busy ? null : _removeUploadedAsset,
      onGenerate: busy ? null : _generate,
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
      onChanged: (value) {
        final hasText = value.trim().isNotEmpty;
        setState(() {
          _generationError = null;
          if (_inputSource == _ProductInputSource.none && hasText) {
            _inputSource = _ProductInputSource.typed;
          } else if (_inputSource == _ProductInputSource.typed && !hasText) {
            _inputSource = _ProductInputSource.none;
          }
        });
        updateBaseTimelineDraft(
          ref,
          onboardingSkinCareStepIndex,
          (base) => base.copyWith(
            skinCareProductNames: value,
            skinCareSkipped: false,
          ),
        );
      },
    );
    final message = uploadError ?? _generationError;

    if (_generating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiThinkingCard(
            title: 'Skin Care AI',
            detail: 'Building your routine from product names and labels',
            accent: OptivusColors.roseAccent,
            isActive: true,
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            _SkinCareInlineMessage(message: message),
          ],
        ],
      );
    }

    if (!generated) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom:
              OnboardingStepShell.bottomCtaHeight +
              MediaQuery.viewInsetsOf(context).bottom +
              40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            setupCard,
            if (widget.base.skinCareSpecialCareNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SkinCareSpecialCareNotesButton(
                notes: widget.base.skinCareSpecialCareNotes,
                accent: OptivusColors.roseAccent,
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 10),
              _SkinCareInlineMessage(message: message),
            ],
          ],
        ),
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
                      icon: Icons.refresh_rounded,
                      accent: OptivusColors.roseAccent,
                      compact: true,
                      onTap: () => updateBaseTimelineDraft(
                        ref,
                        onboardingSkinCareStepIndex,
                        (base) => base.copyWith(
                          blocks: base.blocks
                              .where((b) => b.section != 'skin_care')
                              .toList(),
                          skinCareSpecialCareNotes: const [],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.base.skinCareSpecialCareNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _SkinCareSpecialCareNotesButton(
              notes: widget.base.skinCareSpecialCareNotes,
              accent: OptivusColors.roseAccent,
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
          onDayChanged: (d) => setState(() => _selectedDay = d),
          emptyLabel: 'Build your skin-care routine first.',
          accent: OptivusColors.roseAccent,
        ),
      ],
    );
  }
}

class _HasProductsSetupCard extends StatelessWidget {
  final TextEditingController controller;
  final UploadedAsset? asset;
  final double tileHeight;
  final String? sourceLabel;
  final List<SkinCareDetectedProduct> typedPreviewProducts;
  final int desiredApplicationsPerDay;
  final bool uploadBusy;
  final String? uploadStatusLabel;
  final bool busy;
  final bool generating;
  final bool photoEnabled;
  final bool textInputEnabled;
  final String? photoHelper;
  final String? textHelper;
  final VoidCallback? onUpload;
  final VoidCallback? onRemove;
  final VoidCallback? onGenerate;
  final ValueChanged<int>? onFrequencyChanged;
  final ValueChanged<String> onChanged;

  const _HasProductsSetupCard({
    required this.controller,
    required this.asset,
    required this.tileHeight,
    required this.sourceLabel,
    required this.typedPreviewProducts,
    required this.desiredApplicationsPerDay,
    required this.uploadBusy,
    required this.uploadStatusLabel,
    required this.busy,
    required this.generating,
    required this.photoEnabled,
    required this.textInputEnabled,
    required this.photoHelper,
    required this.textHelper,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
    required this.onFrequencyChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'I have products',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
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
          if (sourceLabel != null) ...[
            const SizedBox(height: 7),
            Text(
              sourceLabel!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: OptivusColors.roseAccent,
              ),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 280;
              final photo = SizedBox(
                height: tileHeight,
                child: _SkinCarePhotoTarget(
                  asset: asset,
                  busy: uploadBusy,
                  busyLabel: uploadStatusLabel,
                  enabled: photoEnabled,
                  helperText: photoHelper,
                  onRemove: onRemove,
                  onTap: onUpload,
                ),
              );
              final input = SizedBox(
                height: tileHeight,
                child: _SkinCareProductNamesTarget(
                  controller: controller,
                  enabled: textInputEnabled,
                  helperText: textHelper,
                  onChanged: onChanged,
                ),
              );

              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [photo, const SizedBox(height: 10), input],
                );
              }

              return SizedBox(
                height: tileHeight,
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
          if (typedPreviewProducts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TypedProductPreviewChips(products: typedPreviewProducts),
          ],
          const SizedBox(height: 12),
          _SkinCareFrequencySelector(
            value: desiredApplicationsPerDay,
            onChanged: onFrequencyChanged,
          ),
          const SizedBox(height: 12),
          _SkinCareGenerateRoutineButton(
            label: uploadBusy ? 'Uploading photo...' : 'Build skin routine',
            busy: generating,
            onTap: onGenerate,
            accent: OptivusColors.roseAccent,
          ),
        ],
      ),
    );
  }
}

class _SkinCareProductNamesTarget extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? helperText;
  final ValueChanged<String> onChanged;

  const _SkinCareProductNamesTarget({
    required this.controller,
    this.enabled = true,
    this.helperText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final child = OnboardingGlassCard(
      key: const ValueKey('onboarding-step7-product-names-tile'),
      tint: OptivusColors.roseAccent.withValues(alpha: enabled ? 0.06 : 0.025),
      padding: const EdgeInsets.all(11),
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product names',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: enabled
                  ? OptivusColors.textPrimary
                  : OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: TextField(
              key: const ValueKey('onboarding-step7-product-names-field'),
              controller: controller,
              minLines: null,
              maxLines: null,
              expands: true,
              enabled: enabled,
              textAlignVertical: TextAlignVertical.top,
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
    return Opacity(opacity: enabled ? 1 : 0.55, child: child);
  }
}

class _TypedProductPreviewChips extends StatelessWidget {
  final List<SkinCareDetectedProduct> products;

  const _TypedProductPreviewChips({required this.products});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChipWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 320.0;
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final product in products)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxChipWidth),
                child: Container(
                  key: ValueKey(
                    'onboarding-step7-typed-product-${product.displayName}-${product.category}',
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Text(
                    _typedProductChipLabel(product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _typedProductChipLabel(SkinCareDetectedProduct product) {
  final name = product.displayName.trim();
  final category = product.category.trim();
  if (category.isEmpty) return name;
  return '$name · $category';
}

class _SkinCareFrequencySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const _SkinCareFrequencySelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const label = Text(
      'How many times per day?',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: OptivusColors.textPrimary,
      ),
    );
    final selector = Container(
      padding: const EdgeInsets.all(3),
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
                width: 34,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == option
                      ? OptivusColors.roseAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$option',
                  style: TextStyle(
                    fontSize: 12,
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
            const Expanded(child: label),
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
  bool _generating = false;
  String? _generationError;
  int _selectedDay = DateTime.now().weekday;
  List<String> _suggestedProducts = [];

  Future<void> _startUpload() async {
    setState(() => _uploadError = null);
    try {
      final uid =
          ref.read(authProvider).user?.uid ??
          ref.read(mockOnboardingProvider).draft.uid;
      await ref
          .read(uploadControllerProvider.notifier)
          .startUpload(
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            purpose: UploadedAssetPurpose.skinCare,
          );
    } catch (_) {}

    final uploadState = ref.read(uploadControllerProvider);
    final asset = uploadState.asset;
    setState(() {
      _uploadedAsset = asset ?? uploadState.asset;
      _uploadError = uploadState.status == UploadFlowStatus.failed
          ? _friendlySkinCareUploadMessage(uploadState.errorMessage)
          : null;
    });
  }

  void _removeUploadedAsset() {
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
    });
  }

  Future<void> _generate() async {
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    setState(() {
      _generating = true;
      _generationError = null;
    });

    try {
      final user = ref.read(authProvider).user;
      final idToken =
          await ref.read(authRepositoryProvider).currentIdToken() ?? '';
      final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
      final client = ref.read(skinCareAiClientProvider);

      final result = await client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          'skinType': widget.base.skinCareSkinType,
          'mainProblem': widget.base.skinCareProblems.isNotEmpty
              ? widget.base.skinCareProblems.first
              : 'none',
          'budget': widget.base.skinCareBudget,
          'routinePreference': widget.base.skinCarePreference,
          'facePhotoR2Key': _uploadedAsset?.r2Key,
        },
      );

      if (result.hasError || result.timelineBlocks.isEmpty) {
        setState(() {
          _generating = false;
          _generationError = onboarding7FriendlyAiMessage(
            result.errorCode == 'json_payload_too_large'
                ? 'json_payload_too_large'
                : result.errorMessage,
            result.warnings,
          );
        });
        return;
      }

      final newBlocks = onboarding7TimelineBlocksFromWorkerBlocks(
        result.timelineBlocks,
      );
      if (newBlocks.isEmpty) {
        setState(() {
          _generating = false;
          _generationError = 'AI returned an empty routine. Please try again.';
        });
        return;
      }
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final List<TimelineBlockDraft> nextBlocks =
            base.blocks.where((b) => b.section != 'skin_care').toList()
              ..addAll(newBlocks);
        return base.copyWith(blocks: nextBlocks, skinCareSkipped: false);
      });

      setState(() {
        _generating = false;
        _suggestedProducts = result.suggestedProducts;
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _generationError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;
    final uploadState = ref.watch(uploadControllerProvider);
    final uploadApplies =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare;
    final uploadBusy = uploadApplies && uploadState.isBusy;
    final busy = uploadBusy || _generating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!generated || _generating)
          Expanded(
            child: OnboardingGlassCard(
              tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(12),
              radius: 18,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Build routine for me',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final photo = SizedBox(
                          height: 112,
                          child: _SkinCarePhotoTarget(
                            asset: _uploadedAsset,
                            busy: uploadBusy,
                            busyLabel: uploadBusy
                                ? _skinCareUploadStatusLabel(uploadState.status)
                                : null,
                            onRemove: busy ? null : _removeUploadedAsset,
                            onTap: busy ? null : _startUpload,
                          ),
                        );
                        final controls = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkinCareChipGroup(
                              label: 'Skin Type',
                              children: [
                                for (final option in const [
                                  _SkinOption('oily', 'Oily'),
                                  _SkinOption('dry', 'Dry'),
                                  _SkinOption('combination', 'Combination'),
                                  _SkinOption('not_sure', 'Not sure'),
                                ])
                                  _SkinCarePreferenceChip(
                                    label: option.label,
                                    selected:
                                        widget.base.skinCareSkinType ==
                                        option.key,
                                    accent: OptivusColors.purpleAccent,
                                    onTap: () => updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) => base.copyWith(
                                        skinCareSkinType: option.key,
                                        skinCareSkipped: false,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SkinCareChipGroup(
                              label: 'Concerns',
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
                                    selected: widget.base.skinCareProblems
                                        .contains(option.key),
                                    accent: OptivusColors.purpleAccent,
                                    onTap: () {
                                      final next = {
                                        ...widget.base.skinCareProblems,
                                      };
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
                                        (base) => base.copyWith(
                                          skinCareProblems: next.toList(),
                                          skinCareSkipped: false,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SkinCareChipGroup(
                              label: 'Budget',
                              children: [
                                for (final option in const [
                                  _SkinOption('low', 'Low'),
                                  _SkinOption('medium', 'Medium'),
                                  _SkinOption('high', 'High'),
                                ])
                                  _SkinCarePreferenceChip(
                                    label: option.label,
                                    selected:
                                        widget.base.skinCareBudget ==
                                        option.key,
                                    accent: OptivusColors.purpleAccent,
                                    onTap: () => updateBaseTimelineDraft(
                                      ref,
                                      onboardingSkinCareStepIndex,
                                      (base) => base.copyWith(
                                        skinCareBudget: option.key,
                                        skinCareSkipped: false,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );

                        if (constraints.maxWidth < 300) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              photo,
                              const SizedBox(height: 10),
                              controls,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: math.max(96, constraints.maxWidth * 0.30),
                              child: photo,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: controls),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OnboardingActionPill(
                            label: 'Build skin routine',
                            icon: Icons.auto_awesome_rounded,
                            accent: OptivusColors.purpleAccent,
                            selected: true,
                            onTap: busy ? null : _generate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OnboardingGlassCard(
                  tint: OptivusColors.purpleAccent.withValues(alpha: 0.12),
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
                              color: OptivusColors.purpleAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Routine built',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      OnboardingActionPill(
                        label: 'Rebuild',
                        icon: Icons.refresh_rounded,
                        accent: OptivusColors.purpleAccent,
                        compact: true,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingSkinCareStepIndex,
                          (base) => base.copyWith(
                            blocks: base.blocks
                                .where((b) => b.section != 'skin_care')
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (_uploadError != null || _generationError != null) ...[
          const SizedBox(height: 10),
          _SkinCareInlineMessage(message: _uploadError ?? _generationError!),
        ],
        const SizedBox(height: 12),
        if (_generating)
          AiThinkingCard(
            title: 'Skin Care',
            detail: 'Building routine...',
            accent: OptivusColors.purpleAccent,
            isActive: true,
          )
        else if (generated)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_suggestedProducts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Suggested: ${_suggestedProducts.join(", ")}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                _SkinCareTimelineSection(
                  selectedDay: _selectedDay,
                  blocks: widget.blocks,
                  onDayChanged: (d) => setState(() => _selectedDay = d),
                  emptyLabel: 'No skin care scheduled for this day.',
                  accent: OptivusColors.purpleAccent,
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

class _SkinCarePhotoTarget extends StatelessWidget {
  final UploadedAsset? asset;
  final bool busy;
  final String? busyLabel;
  final bool enabled;
  final String? helperText;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _SkinCarePhotoTarget({
    required this.asset,
    this.busy = false,
    this.busyLabel,
    this.enabled = true,
    this.helperText,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = asset?.localPreviewPath;
    final showFile = preview != null && File(preview).existsSync();
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
                  child: showFile
                      ? Image.file(File(preview), fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              asset == null
                                  ? Icons.add_photo_alternate_rounded
                                  : Icons.image_rounded,
                              color: enabled
                                  ? OptivusColors.roseAccent
                                  : OptivusColors.textSecondary,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              asset == null ? 'Add photo' : 'Photo uploaded',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: enabled
                                    ? OptivusColors.textPrimary
                                    : OptivusColors.textSecondary,
                              ),
                            ),
                            if (helperText != null) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  helperText!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: OptivusColors.textSecondary,
                                  ),
                                ),
                              ),
                            ] else if (asset != null &&
                                fileName != null &&
                                fileName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
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
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              if (busy)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.78),
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
}

class _SkinCareInlineMessage extends StatelessWidget {
  final String message;

  const _SkinCareInlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              style: const TextStyle(
                fontSize: 11.5,
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

class _SkinCareSpecialCareNotesButton extends StatelessWidget {
  final List<String> notes;
  final Color accent;

  const _SkinCareSpecialCareNotesButton({
    required this.notes,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final count = notes.length;
    final label = count == 1
        ? '1 special-care note'
        : '$count special-care notes';
    return GestureDetector(
      key: const ValueKey('onboarding-step7-special-care-notes-button'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSkinCareSpecialCareNotesSheet(context, notes, accent),
      child: OnboardingGlassCard(
        tint: accent.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        radius: 14,
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
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

  const _SkinCareTimelineSection({
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
    required this.emptyLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayBlocks =
        blocks
            .where((block) => block.repeatDays.contains(selectedDay))
            .toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Routine',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          OnboardingDayChips(
            selectedDay: selectedDay,
            onChanged: onDayChanged,
            accent: accent,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dayBlocks.isEmpty
                ? OnboardingTimelineEmptyCard(label: emptyLabel)
                : OnboardingVerticalTimeline(
                    key: const ValueKey('onboarding-step7-full-timeline'),
                    blocks: dayBlocks,
                    accent: accent,
                    requiredHeightBuilder: (context, block, blockWidth) =>
                        _calculateRequiredSkinCareBlockHeight(
                          context: context,
                          block: block,
                          timeLabel: TimelineUtils.formatTimeRange(
                            block.startMinute,
                            block.endMinute,
                          ),
                          blockWidth: blockWidth,
                        ),
                    blockBuilder: (ctx, block) {
                      return _SkinCareBlockCard(
                        item: block,
                        baseColor: accent,
                        onEditRequested: () => _showSkinCareBlockEditSheet(
                          context,
                          ref,
                          block,
                          accent,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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

class _SkinCareBlockCard extends StatelessWidget {
  final TimelineBlockDraft item;
  final Color baseColor;
  final VoidCallback? onEditRequested;

  const _SkinCareBlockCard({
    required this.item,
    required this.baseColor,
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

  const _SkinCareChipGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _SkinCarePreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SkinCarePreferenceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            fontSize: 12,
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
