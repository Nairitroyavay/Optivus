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
    var decoded = image_lib.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const ImagePreparationException(
        'This image could not be read. Please choose another photo.',
      );
    }
    decoded = image_lib.bakeOrientation(decoded);

    if (_canPreserveSourceBytes(
      bytes: sourceBytes,
      decoded: decoded,
      contentType: contentType,
      policy: policy,
    )) {
      return PreparedUploadImage(
        fileName: _fileNameForContentType(picked.name, contentType),
        contentType: contentType,
        bytes: sourceBytes,
        sizeBytes: sourceBytes.length,
        localPreviewPath: picked.path.trim().isEmpty ? null : picked.path,
      );
    }

    final output = _compressToJpegUnderLimit(decoded, policy);
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

  bool _canPreserveSourceBytes({
    required Uint8List bytes,
    required image_lib.Image decoded,
    required String contentType,
    required UploadImagePolicy policy,
  }) {
    return bytes.length <= policy.maxBytes &&
        _longestSide(decoded) <= policy.maxLongestSide &&
        policy.canPreserveContentType(contentType);
  }

  Uint8List? _compressToJpegUnderLimit(
    image_lib.Image source,
    UploadImagePolicy policy,
  ) {
    var targetLongestSide = _longestSide(
      source,
    ).clamp(1, policy.maxLongestSide).toInt();
    while (targetLongestSide >= policy.minLongestSideAfterResize) {
      final resized = _resizeIfNeeded(source, targetLongestSide);
      final qualityStep = policy.initialJpegQuality > 95 ? 3 : 5;
      for (
        var quality = policy.initialJpegQuality;
        quality >= policy.minJpegQuality;
        quality -= qualityStep
      ) {
        final candidate = Uint8List.fromList(
          image_lib.encodeJpg(resized, quality: quality),
        );
        if (candidate.length <= policy.maxBytes) return candidate;
      }
      final nextLongestSide = (targetLongestSide * 0.9).floor();
      if (nextLongestSide == targetLongestSide) break;
      targetLongestSide = nextLongestSide;
    }
    return null;
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
