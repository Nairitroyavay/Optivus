import 'package:optivus/models/uploaded_asset.dart';

enum UploadImageProfileKind { normal, routineAiImport, skinFaceAi }

class UploadImagePolicy {
  final UploadImageProfileKind kind;
  final int maxBytes;
  final int maxLongestSide;
  final int minLongestSideAfterResize;
  final int initialJpegQuality;
  final int minJpegQuality;
  final Set<String> supportedContentTypes;
  final String tooLargeMessage;
  final String unsupportedContentTypeMessage;

  const UploadImagePolicy({
    required this.kind,
    required this.maxBytes,
    required this.maxLongestSide,
    required this.minLongestSideAfterResize,
    required this.initialJpegQuality,
    required this.minJpegQuality,
    required this.supportedContentTypes,
    required this.tooLargeMessage,
    required this.unsupportedContentTypeMessage,
  });

  static const int profilePhotoMaxBytes = 5 * 1024 * 1024;
  static const int routineAiImportMaxBytes = 15 * 1024 * 1024;
  static const int skinFaceAiMaxBytes = 4 * 1024 * 1024;

  static const normal = UploadImagePolicy(
    kind: UploadImageProfileKind.normal,
    maxBytes: profilePhotoMaxBytes,
    maxLongestSide: 3500,
    minLongestSideAfterResize: 1800,
    initialJpegQuality: 95,
    minJpegQuality: 80,
    supportedContentTypes: {'image/jpeg', 'image/png'},
    tooLargeMessage:
        'This photo is too large. Please upload a profile photo under 5 MB.',
    unsupportedContentTypeMessage:
        'Please upload JPEG or PNG for profile photos.',
  );

  static const routineAiImport = UploadImagePolicy(
    kind: UploadImageProfileKind.routineAiImport,
    maxBytes: routineAiImportMaxBytes,
    maxLongestSide: 4096,
    minLongestSideAfterResize: 2400,
    initialJpegQuality: 100,
    minJpegQuality: 88,
    supportedContentTypes: {'image/jpeg', 'image/png', 'image/webp'},
    tooLargeMessage:
        'This photo is too large. Please upload a clearer photo under 15 MB.',
    unsupportedContentTypeMessage: 'Please upload JPEG, PNG, or WEBP for now.',
  );

  static const skinFaceAi = UploadImagePolicy(
    kind: UploadImageProfileKind.skinFaceAi,
    maxBytes: skinFaceAiMaxBytes,
    maxLongestSide: 2048,
    minLongestSideAfterResize: 1200,
    initialJpegQuality: 92,
    minJpegQuality: 82,
    supportedContentTypes: {'image/jpeg', 'image/png', 'image/webp'},
    tooLargeMessage:
        'This face photo is too large. Please upload a clearer photo under 4 MB.',
    unsupportedContentTypeMessage: 'Please upload JPEG, PNG, or WEBP for now.',
  );

  static UploadImagePolicy forPurpose(UploadedAssetPurpose purpose) {
    return switch (purpose) {
      UploadedAssetPurpose.skinFace => skinFaceAi,
      UploadedAssetPurpose.classTimetable ||
      UploadedAssetPurpose.workSchedule ||
      UploadedAssetPurpose.eatingMenu ||
      UploadedAssetPurpose.skinCare ||
      UploadedAssetPurpose.skinProducts => routineAiImport,
      UploadedAssetPurpose.profilePhoto => normal,
    };
  }

  bool supportsContentType(String contentType) {
    return supportedContentTypes.contains(normalizeContentType(contentType));
  }

  bool canPreserveContentType(String contentType) {
    return supportsContentType(contentType);
  }

  static String normalizeContentType(String value) {
    final normalized = value.split(';').first.trim().toLowerCase();
    return normalized == 'image/jpg' ? 'image/jpeg' : normalized;
  }
}
