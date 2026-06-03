import 'package:cloud_firestore/cloud_firestore.dart';

enum RoutineImportReviewSource { classes, work, eating, skinCare }

enum RoutineImportReviewStatus {
  draft,
  needsReview,
  accepted,
  partiallyAccepted,
  rejected,
}

enum RoutineImportCandidateType {
  block,
  flexibleTask,
  checklistStep,
  note,
  unknown,
}

class RoutineImportReviewDraft {
  final String id;
  final String uid;
  final RoutineImportReviewSource source;
  final RoutineImportReviewStatus status;
  final String sourceLabel;
  final String? onboardingPendingImportId;
  final String? uploadedAssetId;
  final String? uploadedAssetR2Key;
  final String? uploadedAssetStatus;
  final List<RoutineImportCandidateBlock> candidateBlocks;
  final List<String> warnings;
  final List<String> acceptedCandidateIds;
  final List<String> rejectedCandidateIds;
  final List<String> appliedRoutineItemIds;
  final DateTime? appliedAt;
  final String? extractionEngine;
  final String? extractionVersion;
  final DateTime? lastExtractedAt;
  final List<String> extractionWarnings;
  final int extractionAttemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoutineImportReviewDraft({
    required this.id,
    required this.uid,
    required this.source,
    required this.status,
    required this.sourceLabel,
    this.onboardingPendingImportId,
    this.uploadedAssetId,
    this.uploadedAssetR2Key,
    this.uploadedAssetStatus,
    this.candidateBlocks = const [],
    this.warnings = const [],
    this.acceptedCandidateIds = const [],
    this.rejectedCandidateIds = const [],
    this.appliedRoutineItemIds = const [],
    this.appliedAt,
    this.extractionEngine,
    this.extractionVersion,
    this.lastExtractedAt,
    this.extractionWarnings = const [],
    this.extractionAttemptCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get blocksDuplicateApply {
    return (status == RoutineImportReviewStatus.accepted ||
            status == RoutineImportReviewStatus.partiallyAccepted) &&
        appliedRoutineItemIds.isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'source': source.name,
      'status': status.name,
      'sourceLabel': sourceLabel,
      'onboardingPendingImportId': onboardingPendingImportId,
      'uploadedAssetId': uploadedAssetId,
      'uploadedAssetR2Key': uploadedAssetR2Key,
      'uploadedAssetStatus': uploadedAssetStatus,
      'candidateBlocks': candidateBlocks
          .map((candidate) => candidate.toMap())
          .toList(growable: false),
      'warnings': warnings,
      'acceptedCandidateIds': acceptedCandidateIds,
      'rejectedCandidateIds': rejectedCandidateIds,
      'appliedRoutineItemIds': appliedRoutineItemIds,
      'appliedAt': appliedAt?.toIso8601String(),
      'extractionEngine': extractionEngine,
      'extractionVersion': extractionVersion,
      'lastExtractedAt': lastExtractedAt?.toIso8601String(),
      'extractionWarnings': extractionWarnings,
      'extractionAttemptCount': extractionAttemptCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'uid': uid,
      'source': source.name,
      'status': status.name,
      'sourceLabel': sourceLabel,
      'onboardingPendingImportId': onboardingPendingImportId,
      'uploadedAssetId': uploadedAssetId,
      'uploadedAssetR2Key': uploadedAssetR2Key,
      'uploadedAssetStatus': uploadedAssetStatus,
      'candidateBlocks': candidateBlocks
          .map((candidate) => candidate.toMap())
          .toList(growable: false),
      'warnings': warnings,
      'acceptedCandidateIds': acceptedCandidateIds,
      'rejectedCandidateIds': rejectedCandidateIds,
      'appliedRoutineItemIds': appliedRoutineItemIds,
      'appliedAt': appliedAt == null ? null : Timestamp.fromDate(appliedAt!),
      'extractionEngine': extractionEngine,
      'extractionVersion': extractionVersion,
      'lastExtractedAt': lastExtractedAt == null
          ? null
          : Timestamp.fromDate(lastExtractedAt!),
      'extractionWarnings': extractionWarnings,
      'extractionAttemptCount': extractionAttemptCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RoutineImportReviewDraft.fromMap(Map<String, dynamic> map) {
    final createdAt = _dateTimeFromValue(map['createdAt']);
    final updatedAt = _dateTimeFromValue(map['updatedAt']);
    return RoutineImportReviewDraft(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      source: _reviewSourceFromString(map['source'] as String?),
      status: _reviewStatusFromString(map['status'] as String?),
      sourceLabel: map['sourceLabel'] as String? ?? '',
      onboardingPendingImportId: map['onboardingPendingImportId'] as String?,
      uploadedAssetId: map['uploadedAssetId'] as String?,
      uploadedAssetR2Key: map['uploadedAssetR2Key'] as String?,
      uploadedAssetStatus: map['uploadedAssetStatus'] as String?,
      candidateBlocks: _readList(
        map['candidateBlocks'],
        (value) => RoutineImportCandidateBlock.fromMap(value),
      ),
      warnings: _readStringList(map['warnings']),
      acceptedCandidateIds: _readStringList(map['acceptedCandidateIds']),
      rejectedCandidateIds: _readStringList(map['rejectedCandidateIds']),
      appliedRoutineItemIds: _readStringList(map['appliedRoutineItemIds']),
      appliedAt: _dateTimeFromValue(map['appliedAt']),
      extractionEngine: map['extractionEngine'] as String?,
      extractionVersion: map['extractionVersion'] as String?,
      lastExtractedAt: _dateTimeFromValue(map['lastExtractedAt']),
      extractionWarnings: _readStringList(map['extractionWarnings']),
      extractionAttemptCount:
          (map['extractionAttemptCount'] as num?)?.toInt() ?? 0,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory RoutineImportReviewDraft.fromFirestoreMap(Map<String, dynamic> map) {
    return RoutineImportReviewDraft.fromMap(map);
  }

  RoutineImportReviewDraft copyWith({
    String? id,
    String? uid,
    RoutineImportReviewSource? source,
    RoutineImportReviewStatus? status,
    String? sourceLabel,
    String? onboardingPendingImportId,
    String? uploadedAssetId,
    String? uploadedAssetR2Key,
    String? uploadedAssetStatus,
    List<RoutineImportCandidateBlock>? candidateBlocks,
    List<String>? warnings,
    List<String>? acceptedCandidateIds,
    List<String>? rejectedCandidateIds,
    List<String>? appliedRoutineItemIds,
    DateTime? appliedAt,
    String? extractionEngine,
    String? extractionVersion,
    DateTime? lastExtractedAt,
    List<String>? extractionWarnings,
    int? extractionAttemptCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearOnboardingPendingImportId = false,
    bool clearUploadedAssetReference = false,
    bool clearAppliedAt = false,
    bool clearExtractionEngine = false,
    bool clearExtractionVersion = false,
    bool clearLastExtractedAt = false,
  }) {
    return RoutineImportReviewDraft(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      source: source ?? this.source,
      status: status ?? this.status,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      onboardingPendingImportId: clearOnboardingPendingImportId
          ? null
          : (onboardingPendingImportId ?? this.onboardingPendingImportId),
      uploadedAssetId: clearUploadedAssetReference
          ? null
          : (uploadedAssetId ?? this.uploadedAssetId),
      uploadedAssetR2Key: clearUploadedAssetReference
          ? null
          : (uploadedAssetR2Key ?? this.uploadedAssetR2Key),
      uploadedAssetStatus: clearUploadedAssetReference
          ? null
          : (uploadedAssetStatus ?? this.uploadedAssetStatus),
      candidateBlocks: candidateBlocks ?? this.candidateBlocks,
      warnings: warnings ?? this.warnings,
      acceptedCandidateIds: acceptedCandidateIds ?? this.acceptedCandidateIds,
      rejectedCandidateIds: rejectedCandidateIds ?? this.rejectedCandidateIds,
      appliedRoutineItemIds:
          appliedRoutineItemIds ?? this.appliedRoutineItemIds,
      appliedAt: clearAppliedAt ? null : (appliedAt ?? this.appliedAt),
      extractionEngine: clearExtractionEngine
          ? null
          : (extractionEngine ?? this.extractionEngine),
      extractionVersion: clearExtractionVersion
          ? null
          : (extractionVersion ?? this.extractionVersion),
      lastExtractedAt: clearLastExtractedAt
          ? null
          : (lastExtractedAt ?? this.lastExtractedAt),
      extractionWarnings: extractionWarnings ?? this.extractionWarnings,
      extractionAttemptCount:
          extractionAttemptCount ?? this.extractionAttemptCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoutineImportCandidateBlock {
  final String id;
  final String title;
  final int startMinute;
  final int endMinute;
  final bool hasFixedTime;
  final int? suggestedStartMinute;
  final int? suggestedEndMinute;
  final List<int> repeatDays;
  final String blockType;
  final String category;
  final bool hardBlock;
  final bool selected;
  final bool needsManualReview;
  final RoutineImportCandidateType candidateType;
  final double? confidenceScore;
  final String? confidenceLabel;
  final List<String> validationIssues;
  final String? sourceAssetId;
  final String? sourceR2Key;
  final String? sourceTextSnippet;
  final int? sourcePageIndex;
  final int? sourceImageIndex;
  final String? sourceRowLabel;
  final String? sourceColumnLabel;
  final Map<String, dynamic>? sourceBoundingBox;
  final String extractionEngine;
  final String? extractionVersion;
  final String? location;
  final String? notes;
  final String? mealCategory;
  final List<String> steps;

  RoutineImportCandidateBlock({
    required this.id,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    this.hasFixedTime = true,
    this.suggestedStartMinute,
    this.suggestedEndMinute,
    required this.repeatDays,
    required this.blockType,
    required this.category,
    required this.hardBlock,
    this.selected = true,
    bool needsManualReview = false,
    this.candidateType = RoutineImportCandidateType.block,
    this.confidenceScore,
    this.confidenceLabel,
    this.validationIssues = const [],
    this.sourceAssetId,
    this.sourceR2Key,
    this.sourceTextSnippet,
    this.sourcePageIndex,
    this.sourceImageIndex,
    this.sourceRowLabel,
    this.sourceColumnLabel,
    this.sourceBoundingBox,
    this.extractionEngine = 'manualSeed',
    this.extractionVersion,
    this.location,
    this.notes,
    this.mealCategory,
    this.steps = const [],
  }) : needsManualReview =
           needsManualReview ||
           confidenceLabel == 'low' ||
           candidateType == RoutineImportCandidateType.unknown;

  bool get hasValidFixedTime {
    return startMinute >= 0 &&
        startMinute < 24 * 60 &&
        endMinute > 0 &&
        endMinute <= 24 * 60 &&
        startMinute < endMinute;
  }

  bool get isUnplaced {
    return !hasFixedTime || !hasValidFixedTime || repeatDays.isEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'hasFixedTime': hasFixedTime,
      'suggestedStartMinute': suggestedStartMinute,
      'suggestedEndMinute': suggestedEndMinute,
      'repeatDays': repeatDays,
      'blockType': blockType,
      'category': category,
      'hardBlock': hardBlock,
      'selected': selected,
      'needsManualReview': needsManualReview,
      'candidateType': candidateType.name,
      'confidenceScore': confidenceScore,
      'confidenceLabel': confidenceLabel,
      'validationIssues': validationIssues,
      'sourceAssetId': sourceAssetId,
      'sourceR2Key': sourceR2Key,
      'sourceTextSnippet': sourceTextSnippet,
      'sourcePageIndex': sourcePageIndex,
      'sourceImageIndex': sourceImageIndex,
      'sourceRowLabel': sourceRowLabel,
      'sourceColumnLabel': sourceColumnLabel,
      'sourceBoundingBox': sourceBoundingBox,
      'extractionEngine': extractionEngine,
      'extractionVersion': extractionVersion,
      'location': location,
      'notes': notes,
      'mealCategory': mealCategory,
      'steps': steps,
    };
  }

  factory RoutineImportCandidateBlock.fromMap(Map<String, dynamic> map) {
    return RoutineImportCandidateBlock(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      hasFixedTime: map['hasFixedTime'] as bool? ?? true,
      suggestedStartMinute: (map['suggestedStartMinute'] as num?)?.toInt(),
      suggestedEndMinute: (map['suggestedEndMinute'] as num?)?.toInt(),
      repeatDays: _readIntList(map['repeatDays']),
      blockType: map['blockType'] as String? ?? 'soft_block',
      category: map['category'] as String? ?? 'fixed',
      hardBlock: map['hardBlock'] as bool? ?? false,
      selected: map['selected'] as bool? ?? true,
      needsManualReview: map['needsManualReview'] as bool? ?? false,
      candidateType: _candidateTypeFromString(map['candidateType'] as String?),
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble(),
      confidenceLabel: map['confidenceLabel'] as String?,
      validationIssues: _readStringList(map['validationIssues']),
      sourceAssetId: map['sourceAssetId'] as String?,
      sourceR2Key: map['sourceR2Key'] as String?,
      sourceTextSnippet: map['sourceTextSnippet'] as String?,
      sourcePageIndex: (map['sourcePageIndex'] as num?)?.toInt(),
      sourceImageIndex: (map['sourceImageIndex'] as num?)?.toInt(),
      sourceRowLabel: map['sourceRowLabel'] as String?,
      sourceColumnLabel: map['sourceColumnLabel'] as String?,
      sourceBoundingBox: map['sourceBoundingBox'] is Map
          ? Map<String, dynamic>.from(map['sourceBoundingBox'] as Map)
          : null,
      extractionEngine: map['extractionEngine'] as String? ?? 'manualSeed',
      extractionVersion: map['extractionVersion'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      mealCategory: map['mealCategory'] as String?,
      steps: _readStringList(map['steps']),
    );
  }

  Map<String, dynamic> toFirestoreMap() => toMap();

  factory RoutineImportCandidateBlock.fromFirestoreMap(
    Map<String, dynamic> map,
  ) {
    return RoutineImportCandidateBlock.fromMap(map);
  }

  RoutineImportCandidateBlock copyWith({
    String? id,
    String? title,
    int? startMinute,
    int? endMinute,
    bool? hasFixedTime,
    int? suggestedStartMinute,
    int? suggestedEndMinute,
    List<int>? repeatDays,
    String? blockType,
    String? category,
    bool? hardBlock,
    bool? selected,
    bool? needsManualReview,
    RoutineImportCandidateType? candidateType,
    double? confidenceScore,
    String? confidenceLabel,
    List<String>? validationIssues,
    String? sourceAssetId,
    String? sourceR2Key,
    String? sourceTextSnippet,
    int? sourcePageIndex,
    int? sourceImageIndex,
    String? sourceRowLabel,
    String? sourceColumnLabel,
    Map<String, dynamic>? sourceBoundingBox,
    String? extractionEngine,
    String? extractionVersion,
    String? location,
    String? notes,
    String? mealCategory,
    List<String>? steps,
    bool clearConfidenceScore = false,
    bool clearConfidenceLabel = false,
    bool clearSourceAssetId = false,
    bool clearSourceR2Key = false,
    bool clearSourceTextSnippet = false,
    bool clearSuggestedStartMinute = false,
    bool clearSuggestedEndMinute = false,
    bool clearSourcePageIndex = false,
    bool clearSourceImageIndex = false,
    bool clearSourceRowLabel = false,
    bool clearSourceColumnLabel = false,
    bool clearSourceBoundingBox = false,
    bool clearExtractionVersion = false,
    bool clearLocation = false,
    bool clearNotes = false,
    bool clearMealCategory = false,
  }) {
    return RoutineImportCandidateBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      hasFixedTime: hasFixedTime ?? this.hasFixedTime,
      suggestedStartMinute: clearSuggestedStartMinute
          ? null
          : (suggestedStartMinute ?? this.suggestedStartMinute),
      suggestedEndMinute: clearSuggestedEndMinute
          ? null
          : (suggestedEndMinute ?? this.suggestedEndMinute),
      repeatDays: repeatDays ?? this.repeatDays,
      blockType: blockType ?? this.blockType,
      category: category ?? this.category,
      hardBlock: hardBlock ?? this.hardBlock,
      selected: selected ?? this.selected,
      needsManualReview: needsManualReview ?? this.needsManualReview,
      candidateType: candidateType ?? this.candidateType,
      confidenceScore: clearConfidenceScore
          ? null
          : (confidenceScore ?? this.confidenceScore),
      confidenceLabel: clearConfidenceLabel
          ? null
          : (confidenceLabel ?? this.confidenceLabel),
      validationIssues: validationIssues ?? this.validationIssues,
      sourceAssetId: clearSourceAssetId
          ? null
          : (sourceAssetId ?? this.sourceAssetId),
      sourceR2Key: clearSourceR2Key ? null : (sourceR2Key ?? this.sourceR2Key),
      sourceTextSnippet: clearSourceTextSnippet
          ? null
          : (sourceTextSnippet ?? this.sourceTextSnippet),
      sourcePageIndex: clearSourcePageIndex
          ? null
          : (sourcePageIndex ?? this.sourcePageIndex),
      sourceImageIndex: clearSourceImageIndex
          ? null
          : (sourceImageIndex ?? this.sourceImageIndex),
      sourceRowLabel: clearSourceRowLabel
          ? null
          : (sourceRowLabel ?? this.sourceRowLabel),
      sourceColumnLabel: clearSourceColumnLabel
          ? null
          : (sourceColumnLabel ?? this.sourceColumnLabel),
      sourceBoundingBox: clearSourceBoundingBox
          ? null
          : (sourceBoundingBox ?? this.sourceBoundingBox),
      extractionEngine: extractionEngine ?? this.extractionEngine,
      extractionVersion: clearExtractionVersion
          ? null
          : (extractionVersion ?? this.extractionVersion),
      location: clearLocation ? null : (location ?? this.location),
      notes: clearNotes ? null : (notes ?? this.notes),
      mealCategory: clearMealCategory
          ? null
          : (mealCategory ?? this.mealCategory),
      steps: steps ?? this.steps,
    );
  }
}

class RoutineImportExtractionResult {
  final String id;
  final String uid;
  final RoutineImportReviewSource source;
  final String engine;
  final String engineVersion;
  final String? sourceAssetId;
  final String? sourceR2Key;
  final String? rawText;
  final List<RoutineImportCandidateBlock> candidates;
  final List<String> warnings;
  final DateTime createdAt;

  const RoutineImportExtractionResult({
    required this.id,
    required this.uid,
    required this.source,
    this.engine = 'manualSeed',
    this.engineVersion = 'phase2c',
    this.sourceAssetId,
    this.sourceR2Key,
    this.rawText,
    this.candidates = const [],
    this.warnings = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'source': source.name,
      'engine': engine,
      'engineVersion': engineVersion,
      'sourceAssetId': sourceAssetId,
      'sourceR2Key': sourceR2Key,
      'rawText': rawText,
      'candidates': candidates
          .map((candidate) => candidate.toMap())
          .toList(growable: false),
      'warnings': warnings,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'uid': uid,
      'source': source.name,
      'engine': engine,
      'engineVersion': engineVersion,
      'sourceAssetId': sourceAssetId,
      'sourceR2Key': sourceR2Key,
      'rawText': rawText,
      'candidates': candidates
          .map((candidate) => candidate.toMap())
          .toList(growable: false),
      'warnings': warnings,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RoutineImportExtractionResult.fromMap(Map<String, dynamic> map) {
    return RoutineImportExtractionResult(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      source: _reviewSourceFromString(map['source'] as String?),
      engine: map['engine'] as String? ?? 'manualSeed',
      engineVersion: map['engineVersion'] as String? ?? 'phase2c',
      sourceAssetId: map['sourceAssetId'] as String?,
      sourceR2Key: map['sourceR2Key'] as String?,
      rawText: map['rawText'] as String?,
      candidates: _readList(
        map['candidates'],
        (value) => RoutineImportCandidateBlock.fromMap(value),
      ),
      warnings: _readStringList(map['warnings']),
      createdAt:
          _dateTimeFromValue(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory RoutineImportExtractionResult.fromFirestoreMap(
    Map<String, dynamic> map,
  ) {
    return RoutineImportExtractionResult.fromMap(map);
  }
}

RoutineImportReviewSource _reviewSourceFromString(String? value) {
  return switch (value) {
    'work' => RoutineImportReviewSource.work,
    'eating' => RoutineImportReviewSource.eating,
    'skinCare' => RoutineImportReviewSource.skinCare,
    _ => RoutineImportReviewSource.classes,
  };
}

RoutineImportReviewStatus _reviewStatusFromString(String? value) {
  return switch (value) {
    'needsReview' => RoutineImportReviewStatus.needsReview,
    'accepted' => RoutineImportReviewStatus.accepted,
    'partiallyAccepted' => RoutineImportReviewStatus.partiallyAccepted,
    'rejected' => RoutineImportReviewStatus.rejected,
    _ => RoutineImportReviewStatus.draft,
  };
}

RoutineImportCandidateType _candidateTypeFromString(String? value) {
  return switch (value) {
    'flexibleTask' => RoutineImportCandidateType.flexibleTask,
    'checklistStep' => RoutineImportCandidateType.checklistStep,
    'note' => RoutineImportCandidateType.note,
    'unknown' => RoutineImportCandidateType.unknown,
    _ => RoutineImportCandidateType.block,
  };
}

DateTime? _dateTimeFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<T> _readList<T>(dynamic value, T Function(Map<String, dynamic>) mapper) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
  return [];
}

List<int> _readIntList(dynamic value) {
  if (value is List) {
    return value
        .whereType<num>()
        .map((item) => item.toInt())
        .where((item) => item >= 1 && item <= 7)
        .toSet()
        .toList(growable: false)
      ..sort();
  }
  return const [1, 2, 3, 4, 5, 6, 7];
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}
