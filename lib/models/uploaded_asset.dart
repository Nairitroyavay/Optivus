import 'package:cloud_firestore/cloud_firestore.dart';

enum UploadedAssetPurpose {
  classTimetable,
  workSchedule,
  eatingMenu,
  skinCare,
  profilePhoto,
  skinFace,
  skinProducts,
}

enum UploadedAssetStatus { pending, uploading, uploaded, failed, deleted }

extension UploadedAssetPurposeWireName on UploadedAssetPurpose {
  String get wireName {
    return switch (this) {
      UploadedAssetPurpose.classTimetable => 'class_timetable',
      UploadedAssetPurpose.workSchedule => 'work_schedule',
      UploadedAssetPurpose.eatingMenu => 'eating_menu',
      UploadedAssetPurpose.skinCare => 'skin_care',
      UploadedAssetPurpose.profilePhoto => 'profile_photo',
      UploadedAssetPurpose.skinFace => 'skin_face',
      UploadedAssetPurpose.skinProducts => 'skin_products',
    };
  }
}

extension UploadedAssetStatusWireName on UploadedAssetStatus {
  String get wireName {
    return switch (this) {
      UploadedAssetStatus.pending => 'pending',
      UploadedAssetStatus.uploading => 'uploading',
      UploadedAssetStatus.uploaded => 'uploaded',
      UploadedAssetStatus.failed => 'failed',
      UploadedAssetStatus.deleted => 'deleted',
    };
  }
}

class UploadedAsset {
  final String assetId;
  final String ownerUid;
  final String sourceFeature;
  final UploadedAssetPurpose purpose;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String r2Key;
  final String? localPreviewPath;
  final UploadedAssetStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;

  const UploadedAsset({
    required this.assetId,
    required this.ownerUid,
    required this.sourceFeature,
    required this.purpose,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.r2Key,
    this.localPreviewPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'assetId': assetId,
      'ownerUid': ownerUid,
      'sourceFeature': sourceFeature,
      'purpose': purpose.wireName,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'r2Key': r2Key,
      'localPreviewPath': localPreviewPath,
      'status': status.wireName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'assetId': assetId,
      'ownerUid': ownerUid,
      'sourceFeature': sourceFeature,
      'purpose': purpose.wireName,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'r2Key': r2Key,
      'status': status.wireName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'errorMessage': errorMessage,
    };
  }

  factory UploadedAsset.fromMap(Map<String, dynamic> map) {
    final createdAt = _dateTimeFromValue(map['createdAt']);
    final updatedAt = _dateTimeFromValue(map['updatedAt']);
    return UploadedAsset(
      assetId: map['assetId'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      sourceFeature: map['sourceFeature'] as String? ?? '',
      purpose: uploadedAssetPurposeFromString(map['purpose'] as String?),
      fileName: map['fileName'] as String? ?? '',
      contentType: map['contentType'] as String? ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      r2Key: map['r2Key'] as String? ?? '',
      localPreviewPath: map['localPreviewPath'] as String?,
      status: uploadedAssetStatusFromString(map['status'] as String?),
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      errorMessage: map['errorMessage'] as String?,
    );
  }

  factory UploadedAsset.fromFirestoreMap(Map<String, dynamic> map) {
    return UploadedAsset.fromMap(map);
  }

  UploadedAsset copyWith({
    String? assetId,
    String? ownerUid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    String? fileName,
    String? contentType,
    int? sizeBytes,
    String? r2Key,
    String? localPreviewPath,
    UploadedAssetStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? errorMessage,
    bool clearLocalPreviewPath = false,
    bool clearErrorMessage = false,
  }) {
    return UploadedAsset(
      assetId: assetId ?? this.assetId,
      ownerUid: ownerUid ?? this.ownerUid,
      sourceFeature: sourceFeature ?? this.sourceFeature,
      purpose: purpose ?? this.purpose,
      fileName: fileName ?? this.fileName,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      r2Key: r2Key ?? this.r2Key,
      localPreviewPath: clearLocalPreviewPath
          ? null
          : (localPreviewPath ?? this.localPreviewPath),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

UploadedAssetPurpose uploadedAssetPurposeFromString(String? value) {
  return switch (value) {
    'work_schedule' => UploadedAssetPurpose.workSchedule,
    'eating_menu' => UploadedAssetPurpose.eatingMenu,
    'skin_face' => UploadedAssetPurpose.skinFace,
    'skin_products' => UploadedAssetPurpose.skinProducts,
    'skin_care' => UploadedAssetPurpose.skinCare,
    'profile_photo' => UploadedAssetPurpose.profilePhoto,
    _ => UploadedAssetPurpose.classTimetable,
  };
}

UploadedAssetStatus uploadedAssetStatusFromString(String? value) {
  return switch (value) {
    'uploading' => UploadedAssetStatus.uploading,
    'uploaded' => UploadedAssetStatus.uploaded,
    'failed' => UploadedAssetStatus.failed,
    'deleted' => UploadedAssetStatus.deleted,
    _ => UploadedAssetStatus.pending,
  };
}

DateTime? _dateTimeFromValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

abstract final class UploadSourceFeature {
  static const String onboarding = 'onboarding';
  static const String routineBaseTimeline = 'routine_base_timeline';

  static bool isValid(String value) {
    return value == onboarding || value == routineBaseTimeline;
  }
}

bool isUsableSkinUpload({
  required UploadedAsset? asset,
  required String uid,
  required UploadedAssetPurpose expectedPurpose,
  String expectedSourceFeature = UploadSourceFeature.onboarding,
}) {
  return asset != null &&
      uploadedAssetFieldsAreDurablyUploadedForSlot(
        assetId: asset.assetId,
        ownerUid: asset.ownerUid,
        sourceFeature: asset.sourceFeature,
        purpose: asset.purpose,
        r2Key: asset.r2Key,
        status: asset.status,
        uid: uid,
        expectedSourceFeature: expectedSourceFeature,
        expectedPurpose: expectedPurpose,
      );
}

bool uploadedAssetFieldsAreDurablyUploadedForSlot({
  required String assetId,
  required String ownerUid,
  required String sourceFeature,
  required UploadedAssetPurpose purpose,
  required String r2Key,
  required UploadedAssetStatus status,
  required String uid,
  required String expectedSourceFeature,
  required UploadedAssetPurpose expectedPurpose,
}) {
  final normalizedAssetId = assetId.trim();
  final normalizedUid = uid.trim();
  final key = r2Key.trim();
  if (status != UploadedAssetStatus.uploaded ||
      normalizedUid.isEmpty ||
      ownerUid != normalizedUid ||
      sourceFeature != expectedSourceFeature ||
      purpose != expectedPurpose ||
      normalizedAssetId.isEmpty ||
      key.contains('..') ||
      key.contains(r'\') ||
      key.contains('//')) {
    return false;
  }
  final parts = key.split('/');
  if (parts.length != 5 ||
      parts[0] != 'users' ||
      parts[1] != normalizedUid ||
      parts[2] != expectedSourceFeature ||
      parts[3] != expectedPurpose.wireName) {
    return false;
  }
  final fileName = parts[4];
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || fileName.substring(0, dot) != normalizedAssetId) {
    return false;
  }
  return const {
    'jpg',
    'jpeg',
    'png',
    'webp',
  }.contains(fileName.substring(dot + 1).toLowerCase());
}

/// Explicit read/delete-only compatibility check for pre-slot skin_care data.
bool legacySkinCareUploadHasOwnedExactIdentity({
  required String assetId,
  required String ownerUid,
  required String r2Key,
  required UploadedAssetStatus status,
  required String uid,
}) {
  if (status != UploadedAssetStatus.uploaded || ownerUid != uid) return false;
  final parts = r2Key.split('/');
  final name = parts.isEmpty ? '' : parts.last;
  final dot = name.lastIndexOf('.');
  final extension = dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  return uid.trim().isNotEmpty &&
      assetId.trim().isNotEmpty &&
      dot > 0 &&
      name.substring(0, dot) == assetId.trim() &&
      const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) &&
      r2Key == 'users/$uid/onboarding/skin_care/$name';
}
