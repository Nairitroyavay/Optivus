import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

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
  static const int maxOutputBytes = 1024 * 1024;
  static const int maxLongestSide = 1600;
  static const int initialJpegQuality = 82;
  static const int minJpegQuality = 42;

  final ImagePicker _picker;

  ImagePrepareService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  Future<XFile?> pickImageFile({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(source: source);
  }

  Future<PreparedUploadImage?> pickAndPrepareImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await pickImageFile(source: source);
    return preparePickedFile(picked);
  }

  Future<PreparedUploadImage?> preparePickedFile(XFile? picked) async {
    if (picked == null) return null;

    final contentType = _inputContentType(picked);
    if (contentType != 'image/jpeg' && contentType != 'image/png') {
      throw const ImagePreparationException(
        'Please choose a JPEG or PNG image.',
      );
    }

    final sourceBytes = await picked.readAsBytes();
    final decoded = image_lib.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const ImagePreparationException(
        'This image could not be read. Please choose another photo.',
      );
    }

    final resized = _resizeIfNeeded(decoded);
    Uint8List? output;
    for (
      var quality = initialJpegQuality;
      quality >= minJpegQuality;
      quality -= 6
    ) {
      final candidate = Uint8List.fromList(
        image_lib.encodeJpg(resized, quality: quality),
      );
      if (candidate.length <= maxOutputBytes) {
        output = candidate;
        break;
      }
    }

    if (output == null) {
      throw const ImagePreparationException(
        'This photo is too large to prepare for upload. Please choose a smaller image.',
      );
    }

    return PreparedUploadImage(
      fileName: _jpegFileName(picked.name),
      contentType: 'image/jpeg',
      bytes: output,
      sizeBytes: output.length,
      localPreviewPath: picked.path.trim().isEmpty ? null : picked.path,
    );
  }

  image_lib.Image _resizeIfNeeded(image_lib.Image source) {
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    if (longestSide <= maxLongestSide) return source;
    if (source.width >= source.height) {
      return image_lib.copyResize(source, width: maxLongestSide);
    }
    return image_lib.copyResize(source, height: maxLongestSide);
  }

  String _inputContentType(XFile file) {
    final mime = file.mimeType?.toLowerCase().trim();
    if (mime == 'image/jpeg' || mime == 'image/png') return mime!;
    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    return mime ?? '';
  }

  String _jpegFileName(String originalName) {
    final trimmed = originalName.trim().isEmpty
        ? 'upload'
        : originalName.trim();
    final withoutExtension = trimmed.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final safeBase = withoutExtension
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${safeBase.isEmpty ? 'upload' : safeBase}.jpg';
  }
}
