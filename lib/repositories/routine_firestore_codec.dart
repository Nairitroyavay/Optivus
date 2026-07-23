import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_occurrence.dart';
import 'package:optivus/models/routine_projection_receipt.dart';

class RoutineTemplateFirestoreCodec {
  const RoutineTemplateFirestoreCodec();

  static const Set<String> allowedFields = {
    'id',
    'ownerUid',
    'title',
    'category',
    'source',
    'blockType',
    'priority',
    'startMinute',
    'endMinute',
    'repeatRule',
    'repeatDays',
    'dateKey',
    'endDateKey',
    'crossesMidnight',
    'endsNextDay',
    'location',
    'isTrackerLinked',
    'trackerType',
    'notes',
    'bestTime',
    'subtasks',
    'steps',
    'mealCategory',
    'dishes',
    'caloriesEstimate',
    'proteinEstimate',
    'hardBlock',
    'allowOverlap',
    'onboardingProjectionId',
    'onboardingSourceItemId',
    'createdAt',
    'updatedAt',
    'schemaVersion',
    'createdByOperationId',
    'lastMutationOperationId',
  };

  Map<String, dynamic> toFirestore({
    required String ownerUid,
    required RoutineItem item,
  }) {
    validateOwnerUid(ownerUid);
    validateDocumentId(item.id);
    if (item.userId != null && item.userId != ownerUid) {
      throw ArgumentError('Routine owner UID does not match the write owner.');
    }
    _validateTemplate(item);

    return {
      'id': item.id,
      'ownerUid': ownerUid,
      'title': item.title.trim(),
      'category': item.category.name,
      'source': item.source.name,
      'blockType': item.blockType.name,
      'priority': item.priority.name,
      'startMinute': item.startMinute,
      'endMinute': item.endMinute,
      'repeatRule': _normalizedRepeatRule(item),
      'repeatDays': [...item.repeatDays]..sort(),
      if (item.date != null) 'dateKey': routineLocalDateKey(item.date!),
      if (item.endDate != null)
        'endDateKey': routineLocalDateKey(item.endDate!),
      'crossesMidnight': item.crossesMidnight,
      'endsNextDay': item.endsNextDay,
      if (_notBlank(item.location)) 'location': item.location!.trim(),
      'isTrackerLinked': item.isTrackerLinked,
      'trackerType': item.trackerType.name,
      if (_notBlank(item.notes)) 'notes': item.notes!.trim(),
      if (_notBlank(item.bestTime)) 'bestTime': item.bestTime!.trim(),
      if (item.subtasks != null) 'subtasks': List<String>.from(item.subtasks!),
      if (item.steps != null) 'steps': List<String>.from(item.steps!),
      if (_notBlank(item.mealCategory))
        'mealCategory': item.mealCategory!.trim(),
      if (item.dishes != null) 'dishes': List<String>.from(item.dishes!),
      if (item.caloriesEstimate != null)
        'caloriesEstimate': item.caloriesEstimate,
      if (item.proteinEstimate != null) 'proteinEstimate': item.proteinEstimate,
      'hardBlock': item.hardBlock,
      'allowOverlap': item.allowOverlap,
      if (_notBlank(item.onboardingProjectionId))
        'onboardingProjectionId': item.onboardingProjectionId,
      if (_notBlank(item.onboardingSourceItemId))
        'onboardingSourceItemId': item.onboardingSourceItemId,
      if (_notBlank(item.createdByOperationId))
        'createdByOperationId': item.createdByOperationId,
      if (_notBlank(item.lastMutationOperationId))
        'lastMutationOperationId': item.lastMutationOperationId,
      'createdAt': Timestamp.fromDate(item.createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(item.updatedAt.toUtc()),
      'schemaVersion': RoutineItem.currentSchemaVersion,
    };
  }

  RoutineItem fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    validateDocumentId(documentId);
    final schemaVersion = (data['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion < 0 || schemaVersion > RoutineItem.currentSchemaVersion) {
      throw FormatException(
        'Unsupported Routine template schema version: $schemaVersion.',
      );
    }
    final strict = schemaVersion == RoutineItem.currentSchemaVersion;
    final id = _requiredString(data, 'id', fallback: documentId);
    if (id != documentId) {
      throw const FormatException(
        'Routine document ID does not match its id field.',
      );
    }
    final ownerUid =
        _optionalString(data['ownerUid']) ??
        _optionalString(data['userId']) ??
        '';
    validateOwnerUid(ownerUid);

    final repeatDays = _readRepeatDays(
      data['repeatDays'],
      strict: strict,
      legacyDefault: data['date'] == null && data['dateKey'] == null,
    );
    final date = _readLocalDate(data['dateKey'] ?? data['date']);
    final endDate = _readLocalDate(data['endDateKey'] ?? data['endDate']);
    final startMinute = _readInt(data['startMinute'], fallback: 0);
    final endMinute = _readInt(data['endMinute'], fallback: 0);
    final crossesMidnight =
        data['crossesMidnight'] as bool? ?? endMinute < startMinute;
    final endsNextDay = data['endsNextDay'] as bool? ?? crossesMidnight;

    final item = RoutineItem(
      id: id,
      userId: ownerUid,
      schemaVersion: schemaVersion == 0
          ? RoutineItem.currentSchemaVersion
          : schemaVersion,
      onboardingProjectionId: _optionalString(data['onboardingProjectionId']),
      onboardingSourceItemId: _optionalString(data['onboardingSourceItemId']),
      createdByOperationId: _optionalString(data['createdByOperationId']),
      lastMutationOperationId: _optionalString(data['lastMutationOperationId']),
      title: _requiredString(data, 'title'),
      date: date,
      endDate: endDate,
      startMinute: startMinute,
      endMinute: endMinute,
      crossesMidnight: crossesMidnight,
      endsNextDay: endsNextDay,
      repeatDays: repeatDays,
      location: _optionalString(data['location']),
      blockType: _readEnum(
        RoutineBlockType.values,
        data['blockType'],
        strict: strict,
        fallback: RoutineBlockType.flexibleTask,
        field: 'blockType',
      ),
      category: _readEnum(
        RoutineCategory.values,
        data['category'],
        strict: strict,
        fallback: RoutineCategory.fixed,
        field: 'category',
      ),
      source: _readEnum(
        RoutineSource.values,
        data['source'],
        strict: strict,
        fallback: RoutineSource.manual,
        field: 'source',
      ),
      priority: _readEnum(
        RoutinePriority.values,
        data['priority'],
        strict: strict,
        fallback: RoutinePriority.goodToDo,
        field: 'priority',
      ),
      trackerType: _readEnum(
        TrackerType.values,
        data['trackerType'],
        strict: strict,
        fallback: TrackerType.none,
        field: 'trackerType',
      ),
      isTrackerLinked: data['isTrackerLinked'] as bool? ?? false,
      notes: _optionalString(data['notes']),
      bestTime: _optionalString(data['bestTime']),
      subtasks: _readStringList(data['subtasks']),
      steps:
          _readStringList(data['steps']) ??
          _readStringList(data['skincareProducts']),
      mealCategory: _optionalString(data['mealCategory']),
      dishes: _readStringList(data['dishes']),
      caloriesEstimate:
          (data['caloriesEstimate'] as num?)?.toDouble() ??
          (data['calories'] as num?)?.toDouble(),
      proteinEstimate:
          (data['proteinEstimate'] as num?)?.toDouble() ??
          (data['protein'] as num?)?.toDouble(),
      skincareProducts: _readStringList(data['skincareProducts']),
      hardBlock:
          data['hardBlock'] as bool? ??
          data['blockType'] == RoutineBlockType.hardBlock.name,
      allowOverlap: data['allowOverlap'] as bool? ?? false,
      repeatRule:
          _optionalString(data['repeatRule']) ??
          (date != null && repeatDays.isEmpty ? 'once' : 'weekly'),
      // Legacy daily state is intentionally not promoted into the template.
      status: RoutineStatus.planned,
      isCompleted: false,
      isMissed: false,
      hasConflict: false,
      conflictMessage: null,
      createdAt:
          readRoutineDateTime(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          readRoutineDateTime(data['updatedAt']) ??
          readRoutineDateTime(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    _validateTemplate(item);
    return item;
  }

  void _validateTemplate(RoutineItem item) {
    if (item.title.trim().isEmpty || item.title.trim().length > 200) {
      throw ArgumentError('Routine title must contain 1-200 characters.');
    }
    final uniqueDays = item.repeatDays.toSet();
    if (uniqueDays.length != item.repeatDays.length ||
        uniqueDays.any(
          (day) => day < DateTime.monday || day > DateTime.sunday,
        )) {
      throw ArgumentError('Routine repeat days must be unique values 1-7.');
    }
    if (item.startMinute < 0 || item.startMinute > 1439) {
      throw ArgumentError('Routine startMinute must be between 0 and 1439.');
    }
    if (item.endMinute < 0 || item.endMinute > 1440) {
      throw ArgumentError('Routine endMinute must be between 0 and 1440.');
    }
    if (item.startMinute == item.endMinute) {
      throw ArgumentError('Routine start and end times must differ.');
    }
    final overnight = item.crossesMidnight || item.endsNextDay;
    if (overnight && item.endMinute >= item.startMinute) {
      throw ArgumentError('Overnight Routine end time must be before start.');
    }
    if (!overnight && item.endMinute <= item.startMinute) {
      throw ArgumentError('Routine end time must be after start.');
    }
    if (item.endDate != null && item.date == null) {
      throw ArgumentError('Routine endDate requires a start date.');
    }
    if (item.date != null &&
        item.endDate != null &&
        routineLocalDateKey(
              item.endDate!,
            ).compareTo(routineLocalDateKey(item.date!)) <
            0) {
      throw ArgumentError('Routine endDate cannot precede date.');
    }
    final rule = _normalizedRepeatRule(item);
    const allowedRules = {'once', 'daily', 'weekly', 'weekdays', 'weekends'};
    if (!allowedRules.contains(rule)) {
      throw ArgumentError('Unsupported Routine repeat rule: $rule');
    }
    if (rule == 'once' && item.date == null) {
      throw ArgumentError('One-time Routine items require a local date.');
    }
    if (rule != 'once' && item.repeatDays.isEmpty) {
      throw ArgumentError('Repeating Routine items require repeat days.');
    }
    _validateStringList(item.subtasks, 'subtasks');
    _validateStringList(item.steps, 'steps');
    _validateStringList(item.dishes, 'dishes');
    if (item.createdByOperationId != null) {
      _validateOperationId(item.createdByOperationId!);
    }
    if (item.lastMutationOperationId != null) {
      _validateOperationId(item.lastMutationOperationId!);
    }
  }

  void _validateOperationId(String opId) {
    if (opId.trim().isEmpty || opId.length > 128) {
      throw ArgumentError('Invalid operation ID.');
    }
  }

  String _normalizedRepeatRule(RoutineItem item) {
    final value = item.repeatRule?.trim().toLowerCase();
    if (value == null || value.isEmpty || value == 'none') {
      return item.date != null && item.repeatDays.isEmpty ? 'once' : 'weekly';
    }
    if (value == 'everyday') return 'daily';
    return value;
  }
}

class RoutineProjectionReceiptFirestoreCodec {
  const RoutineProjectionReceiptFirestoreCodec();

  Map<String, dynamic> toFirestore(RoutineProjectionReceipt receipt) {
    validateOwnerUid(receipt.ownerUid);
    validateDocumentId(receipt.id);
    if (receipt.schemaVersion !=
        RoutineProjectionReceipt.currentSchemaVersion) {
      throw ArgumentError('Unsupported Routine projection receipt schema.');
    }
    if (receipt.status != 'completed' || receipt.source != 'onboarding') {
      throw ArgumentError('Invalid Routine projection receipt status/source.');
    }
    if (receipt.sourceBundleSchemaVersion < 1 ||
        receipt.sourceBundleId.trim().isEmpty ||
        receipt.sourceBundleId.length > 128) {
      throw ArgumentError('Invalid Routine projection source bundle.');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(receipt.sourceBundleFingerprint)) {
      throw ArgumentError('Invalid Routine projection fingerprint.');
    }
    if (receipt.projectedItemIds.length > 450 ||
        receipt.projectedItemIds.toSet().length !=
            receipt.projectedItemIds.length) {
      throw ArgumentError('Invalid Routine projection item IDs.');
    }
    for (final itemId in receipt.projectedItemIds) {
      validateDocumentId(itemId);
    }
    return {
      'id': receipt.id,
      'ownerUid': receipt.ownerUid,
      'source': receipt.source,
      'sourceBundleSchemaVersion': receipt.sourceBundleSchemaVersion,
      'sourceBundleId': receipt.sourceBundleId,
      'sourceBundleFingerprint': receipt.sourceBundleFingerprint,
      'projectedItemIds': receipt.projectedItemIds,
      'status': receipt.status,
      'createdAt': Timestamp.fromDate(receipt.createdAt.toUtc()),
      'completedAt': Timestamp.fromDate(receipt.completedAt.toUtc()),
      'schemaVersion': receipt.schemaVersion,
    };
  }

  RoutineProjectionReceipt fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    validateDocumentId(documentId);
    final id = _requiredString(data, 'id', fallback: documentId);
    if (id != documentId) {
      throw const FormatException('Projection receipt ID mismatch.');
    }
    final receipt = RoutineProjectionReceipt(
      id: id,
      ownerUid: _requiredString(data, 'ownerUid'),
      source: _requiredString(data, 'source'),
      sourceBundleSchemaVersion: _readInt(
        data['sourceBundleSchemaVersion'],
        fallback: 0,
      ),
      sourceBundleId: _requiredString(data, 'sourceBundleId'),
      sourceBundleFingerprint: _requiredString(data, 'sourceBundleFingerprint'),
      projectedItemIds: _readStringList(data['projectedItemIds']) ?? const [],
      status: _requiredString(data, 'status'),
      createdAt:
          readRoutineDateTime(data['createdAt']) ??
          (throw const FormatException('Projection createdAt is required.')),
      completedAt:
          readRoutineDateTime(data['completedAt']) ??
          (throw const FormatException('Projection completedAt is required.')),
      schemaVersion: _readInt(data['schemaVersion'], fallback: 0),
    );
    // Reuse write validation without retaining its result.
    toFirestore(receipt);
    return receipt;
  }
}

DateTime? readRoutineDateTime(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  return null;
}

void validateOwnerUid(String uid) {
  final value = uid.trim();
  if (value.isEmpty ||
      value.length > 128 ||
      value.contains('/') ||
      value != uid) {
    throw ArgumentError('Invalid Routine owner UID.');
  }
}

void validateDocumentId(String id) {
  final value = id.trim();
  if (value.isEmpty ||
      value.length > 128 ||
      value.contains('/') ||
      value == '.' ||
      value == '..' ||
      value != id) {
    throw ArgumentError('Invalid Routine document ID.');
  }
}

T _readEnum<T extends Enum>(
  List<T> values,
  Object? raw, {
  required bool strict,
  required T fallback,
  required String field,
}) {
  if (raw is String) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
  }
  if (strict) throw FormatException('Invalid Routine enum field: $field');
  return fallback;
}

List<int> _readRepeatDays(
  Object? raw, {
  required bool strict,
  required bool legacyDefault,
}) {
  if (raw is! List) {
    if (strict) {
      throw const FormatException('Routine repeatDays must be a list.');
    }
    return legacyDefault ? const [1, 2, 3, 4, 5, 6, 7] : const [];
  }
  final values = <int>[];
  for (final value in raw) {
    if (value is! num) {
      if (strict) {
        throw const FormatException(
          'Routine repeatDays must contain integers.',
        );
      }
      continue;
    }
    final day = value.toInt();
    if (day != value || day < 1 || day > 7 || values.contains(day)) {
      if (strict) {
        throw const FormatException('Invalid Routine repeat day.');
      }
      continue;
    }
    values.add(day);
  }
  values.sort();
  return values;
}

DateTime? _readLocalDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) {
    final date = value.toDate();
    return DateTime(date.year, date.month, date.day);
  }
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is String) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return parseRoutineLocalDateKey(value);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  throw const FormatException('Invalid Routine local date.');
}

String _requiredString(
  Map<String, dynamic> data,
  String key, {
  String? fallback,
}) {
  final value = _optionalString(data[key]) ?? fallback;
  if (value == null || value.isEmpty) {
    throw FormatException('Routine field $key is required.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _readInt(Object? value, {required int fallback}) {
  if (value is num && value.toInt() == value) return value.toInt();
  return fallback;
}

List<String>? _readStringList(Object? value) {
  if (value == null) return null;
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Routine string-list field is malformed.');
  }
  return value.cast<String>().toList(growable: false);
}

void _validateStringList(List<String>? values, String field) {
  if (values == null) return;
  if (values.length > 100 ||
      values.any((value) => value.trim().isEmpty || value.length > 500)) {
    throw ArgumentError('Invalid Routine $field.');
  }
}

bool _notBlank(String? value) => value != null && value.trim().isNotEmpty;
