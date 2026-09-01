import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum UploadPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

abstract interface class UploadPermissionService {
  Future<UploadPermissionStatus> checkOrRequest(ImageSource source);
  UploadPermissionStatus mapPickerException(Object exception, ImageSource source);
  String permissionGuidanceMessage(ImageSource source, {bool isPermanent = false});
}

class DefaultUploadPermissionService implements UploadPermissionService {
  const DefaultUploadPermissionService();

  @override
  Future<UploadPermissionStatus> checkOrRequest(ImageSource source) async {
    // image_picker automatically requests the necessary platform permissions
    // on invocation. Standard platform permission resolution is handled
    // without requiring unnecessary broad permissions on newer Android / iOS.
    return UploadPermissionStatus.granted;
  }

  @override
  UploadPermissionStatus mapPickerException(
    Object exception,
    ImageSource source,
  ) {
    if (exception is PlatformException) {
      final code = exception.code.toLowerCase().trim();
      final message = (exception.message ?? '').toLowerCase().trim();

      // Reliable restricted / permanently denied indicators from native platform
      if (code == 'camera_access_restricted' ||
          code == 'photo_access_restricted' ||
          message.contains('restricted') ||
          message.contains('parental')) {
        return UploadPermissionStatus.restricted;
      }

      if (code == 'camera_access_denied_permanent' ||
          code == 'photo_access_denied_permanent' ||
          message.contains('permanently denied') ||
          message.contains('denied_permanently')) {
        return UploadPermissionStatus.permanentlyDenied;
      }

      if (code == 'camera_access_denied' ||
          code == 'photo_access_denied' ||
          code == 'permission_denied') {
        return UploadPermissionStatus.denied;
      }
    }
    return UploadPermissionStatus.denied;
  }

  @override
  String permissionGuidanceMessage(
    ImageSource source, {
    bool isPermanent = false,
  }) {
    final typeName = source == ImageSource.camera ? 'Camera' : 'Photos';
    if (isPermanent) {
      return '$typeName access was previously denied. Please open device Settings to allow $typeName access for Optivus.';
    }
    return '$typeName permission is needed to choose your photo.';
  }
}

final uploadPermissionServiceProvider = Provider<UploadPermissionService>((ref) {
  return const DefaultUploadPermissionService();
});
