import 'dart:io';
import 'package:optivus/core/errors/diagnostic_codes.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/services/uploads/r2_upload_service.dart';

abstract final class UploadErrorMapper {
  /// Maps upload and image preparation errors into a contextual [RecoverableError].
  static RecoverableError map(
    Object error, {
    bool isRequiredSlot = true,
    bool isMetadataPersistenceFailure = false,
  }) {
    if (error is RecoverableError) {
      return error.copyWith(isBlocking: isRequiredSlot);
    }

    if (isMetadataPersistenceFailure) {
      return RecoverableError(
        category: RecoverableErrorCategory.cloudPersistence,
        publicMessage:
            'Photo upload could not be saved yet. Please try again.',
        severity: isRequiredSlot
            ? RecoverableErrorSeverity.error
            : RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: RecoverableRetryAction.retrySave,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.uploadMetadataSaveFailed,
      );
    }

    if (error is ImagePreparationException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('too large') || msg.contains('exceeds')) {
        return RecoverableError(
          category: RecoverableErrorCategory.upload,
          publicMessage:
              'This photo is too large. Please select a photo under the file size limit.',
          severity: isRequiredSlot
              ? RecoverableErrorSeverity.error
              : RecoverableErrorSeverity.warning,
          isBlocking: isRequiredSlot,
          retryAction: RecoverableRetryAction.chooseAnother,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.uploadImageTooLarge,
        );
      }
      final defaultMessage = 'That image couldn’t be read. Choose another photo.';
      final safeMessage = _isCleanPublicMessage(error.message)
          ? error.message
          : defaultMessage;
      return RecoverableError(
        category: RecoverableErrorCategory.upload,
        publicMessage: safeMessage,
        severity: isRequiredSlot
            ? RecoverableErrorSeverity.error
            : RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: RecoverableRetryAction.chooseAnother,
        retrySafe: false,
        diagnosticCode: DiagnosticCodes.uploadInvalidImage,
      );
    }

    if (error is R2UploadExpiredUrlException) {
      return RecoverableError(
        category: RecoverableErrorCategory.upload,
        publicMessage:
            'Upload session expired. Tap retry to get a fresh link.',
        severity: isRequiredSlot
            ? RecoverableErrorSeverity.error
            : RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: RecoverableRetryAction.retryUpload,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.uploadUrlExpired,
      );
    }

    if (error is R2UploadNetworkException ||
        error is SocketException) {
      return RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'Network connection failed during photo upload. Check your connection and retry.',
        severity: isRequiredSlot
            ? RecoverableErrorSeverity.error
            : RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: RecoverableRetryAction.retryUpload,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    if (error is CloudflareClientException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return RecoverableError(
          category: RecoverableErrorCategory.authentication,
          publicMessage: 'Please sign in again before uploading a photo.',
          severity: RecoverableErrorSeverity.error,
          isBlocking: true,
          retryAction: RecoverableRetryAction.reauthenticate,
          retrySafe: false,
          diagnosticCode: DiagnosticCodes.authSessionExpired,
        );
      }
      return RecoverableError(
        category: RecoverableErrorCategory.upload,
        publicMessage: 'We couldn’t upload this photo. Please try again.',
        severity: isRequiredSlot
            ? RecoverableErrorSeverity.error
            : RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: RecoverableRetryAction.retryUpload,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.uploadBinaryFailed,
      );
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('permission') || raw.contains('denied')) {
      final isPermanent = raw.contains('permanently') || raw.contains('restricted');
      return RecoverableError(
        category: RecoverableErrorCategory.permission,
        publicMessage: 'Camera or photo access is needed to select a photo.',
        severity: RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: isPermanent
            ? RecoverableRetryAction.openSettings
            : RecoverableRetryAction.retry,
        retrySafe: false,
        diagnosticCode: isPermanent
            ? DiagnosticCodes.permissionPermanentlyDenied
            : DiagnosticCodes.permissionPhotosDenied,
      );
    }

    if (raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('connection refused') ||
        raw.contains('connection abort')) {
      return RecoverableError(
        category: RecoverableErrorCategory.network,
        publicMessage:
            'Network connection failed during photo upload. Check your connection and retry.',
        severity: isRequiredSlot
            ? RecoverableErrorSeverity.error
            : RecoverableErrorSeverity.warning,
        isBlocking: isRequiredSlot,
        retryAction: RecoverableRetryAction.retryUpload,
        retrySafe: true,
        diagnosticCode: DiagnosticCodes.networkUnavailable,
      );
    }

    return RecoverableError(
      category: RecoverableErrorCategory.upload,
      publicMessage: 'We couldn’t upload this photo. Please try again.',
      severity: isRequiredSlot
          ? RecoverableErrorSeverity.error
          : RecoverableErrorSeverity.warning,
      isBlocking: isRequiredSlot,
      retryAction: RecoverableRetryAction.retryUpload,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.uploadBinaryFailed,
    );
  }

  /// Special mapper for remote preview loading failure (always non-blocking).
  static RecoverableError previewUnavailable({
    bool isNetworkFailure = false,
  }) {
    return RecoverableError(
      category: isNetworkFailure
          ? RecoverableErrorCategory.network
          : RecoverableErrorCategory.upload,
      publicMessage:
          'Photo preview could not be loaded. Your uploaded photo is still safe.',
      severity: RecoverableErrorSeverity.info,
      isBlocking: false,
      retryAction: RecoverableRetryAction.retry,
      retrySafe: true,
      diagnosticCode: DiagnosticCodes.uploadPreviewUnavailable,
    );
  }

  static bool _isCleanPublicMessage(String? msg) {
    if (msg == null || msg.trim().isEmpty) return false;
    final lower = msg.toLowerCase();
    if (lower.contains('raw_') ||
        lower.contains('secret') ||
        lower.contains('exception:') ||
        lower.contains('token') ||
        lower.contains('{') ||
        lower.contains('}') ||
        lower.startsWith('provider_')) {
      return false;
    }
    return true;
  }
}
