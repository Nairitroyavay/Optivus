import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
import 'package:optivus/config/upload_policy.dart';
import 'package:optivus/models/uploaded_asset.dart';

class ImagePreparationException implements Exception {
  final String message;

  const ImagePreparationException(this.message);

  @override
  String toString() => message;
}

class PreparedUploadImage {
  final String fileName;
  final String contentType;
  final Uint8List bytes;
  final int sizeBytes;
  final String? localPreviewPath;

  const PreparedUploadImage({
    required this.fileName,
    required this.contentType,
    required this.bytes,
    required this.sizeBytes,
    this.localPreviewPath,
  });
}

class ImagePrepareService {
  final ImagePicker _picker;

  ImagePrepareService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  Future<XFile?> pickImageFile({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(source: source);
  }

  Future<PreparedUploadImage?> pickAndPrepareImage({
    ImageSource source = ImageSource.gallery,
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    final picked = await pickImageFile(source: source);
    return preparePickedFile(picked, purpose: purpose);
  }

  Future<PreparedUploadImage?> preparePickedFile(
    XFile? picked, {
    UploadedAssetPurpose purpose = UploadedAssetPurpose.profilePhoto,
  }) async {
    if (picked == null) return null;

    final policy = UploadImagePolicy.forPurpose(purpose);
    final contentType = UploadImagePolicy.normalizeContentType(
      _inputContentType(picked),
    );
    if (!policy.supportsContentType(contentType)) {
      throw ImagePreparationException(policy.unsupportedContentTypeMessage);
    }

    final sourceBytes = await picked.readAsBytes();
    final transformed = await Isolate.run(
      () => _transformImageBytes(
        sourceBytes,
        policy.maxBytes,
        policy.maxLongestSide,
        policy.minLongestSideAfterResize,
        policy.initialJpegQuality,
        policy.minJpegQuality,
        policy.canPreserveContentType(contentType),
      ),
    );
    if (transformed.status == _ImageTransformStatus.unreadable) {
      throw const ImagePreparationException(
        'This image could not be read. Please choose another photo.',
      );
    }
    if (transformed.status == _ImageTransformStatus.preserved) {
      return PreparedUploadImage(
        fileName: _fileNameForContentType(picked.name, contentType),
        contentType: contentType,
        bytes: sourceBytes,
        sizeBytes: sourceBytes.length,
        localPreviewPath: picked.path.trim().isEmpty ? null : picked.path,
      );
    }

    final output = transformed.bytes;
    if (output == null) {
      throw ImagePreparationException(policy.tooLargeMessage);
    }

    return PreparedUploadImage(
      fileName: _jpegFileName(picked.name),
      contentType: 'image/jpeg',
      bytes: output,
      sizeBytes: output.length,
      localPreviewPath: picked.path.trim().isEmpty ? null : picked.path,
    );
  }
}

enum _ImageTransformStatus { preserved, transformed, unreadable, tooLarge }

class _ImageTransformResult {
  final _ImageTransformStatus status;
  final Uint8List? bytes;

  const _ImageTransformResult(this.status, [this.bytes]);
}

/// Pure image work. This function receives only isolate-sendable byte/config
/// values and never touches ImagePicker/XFile or platform APIs.
_ImageTransformResult _transformImageBytes(
  Uint8List sourceBytes,
  int maxBytes,
  int maxLongestSide,
  int minLongestSideAfterResize,
  int initialJpegQuality,
  int minJpegQuality,
  bool canPreserveContentType,
) {
  var decoded = image_lib.decodeImage(sourceBytes);
  if (decoded == null) {
    return const _ImageTransformResult(_ImageTransformStatus.unreadable);
  }
  decoded = image_lib.bakeOrientation(decoded);
  if (sourceBytes.length <= maxBytes &&
      _longestSide(decoded) <= maxLongestSide &&
      canPreserveContentType) {
    return const _ImageTransformResult(_ImageTransformStatus.preserved);
  }

  var targetLongestSide = _longestSide(
    decoded,
  ).clamp(1, maxLongestSide).toInt();
  while (targetLongestSide >= minLongestSideAfterResize) {
    final resized = _resizeIfNeeded(decoded, targetLongestSide);
    final qualityStep = initialJpegQuality > 95 ? 3 : 5;
    for (
      var quality = initialJpegQuality;
      quality >= minJpegQuality;
      quality -= qualityStep
    ) {
      final candidate = Uint8List.fromList(
        image_lib.encodeJpg(resized, quality: quality),
      );
      if (candidate.length <= maxBytes) {
        return _ImageTransformResult(
          _ImageTransformStatus.transformed,
          candidate,
        );
      }
    }
    final nextLongestSide = (targetLongestSide * 0.9).floor();
    if (nextLongestSide == targetLongestSide) break;
    targetLongestSide = nextLongestSide;
  }
  return const _ImageTransformResult(_ImageTransformStatus.tooLarge);
}

image_lib.Image _resizeIfNeeded(image_lib.Image source, int maxLongestSide) {
  final longestSide = _longestSide(source);
  if (longestSide <= maxLongestSide) return source;
  if (source.width >= source.height) {
    return image_lib.copyResize(source, width: maxLongestSide);
  }
  return image_lib.copyResize(source, height: maxLongestSide);
}

int _longestSide(image_lib.Image source) {
  return source.width > source.height ? source.width : source.height;
}

extension on ImagePrepareService {
  String _inputContentType(XFile file) {
    final mime = file.mimeType?.toLowerCase().trim();
    if (mime == 'image/jpeg' ||
        mime == 'image/jpg' ||
        mime == 'image/png' ||
        mime == 'image/webp') {
      return mime!;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return mime ?? '';
  }

  String _fileNameForContentType(String originalName, String contentType) {
    return '${_safeBaseName(originalName)}.${_extensionForContentType(contentType)}';
  }

  String _jpegFileName(String originalName) {
    return '${_safeBaseName(originalName)}.jpg';
  }

  String _safeBaseName(String originalName) {
    final trimmed = originalName.trim().isEmpty
        ? 'upload'
        : originalName.trim();
    final withoutExtension = trimmed.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final safeBase = withoutExtension
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safeBase.isEmpty ? 'upload' : safeBase;
  }

  String _extensionForContentType(String contentType) {
    return switch (UploadImagePolicy.normalizeContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }
}
