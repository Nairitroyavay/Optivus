import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/auth_state.dart';

enum UploadFlowStatus {
  idle,
  picking,
  preparing,
  signing,
  uploading,
  savingMetadata,
  uploaded,
  failed,
}

class UploadState {
  final UploadFlowStatus status;
  final UploadedAsset? asset;
  final String? errorMessage;
  final String? uid;
  final UploadedAssetPurpose? purpose;
  final String? sourceFeature;

  const UploadState({
    this.status = UploadFlowStatus.idle,
    this.asset,
    this.errorMessage,
    this.uid,
    this.purpose,
    this.sourceFeature,
  });

  bool get isBusy {
    return switch (status) {
      UploadFlowStatus.picking ||
      UploadFlowStatus.preparing ||
      UploadFlowStatus.signing ||
      UploadFlowStatus.uploading ||
      UploadFlowStatus.savingMetadata => true,
      _ => false,
    };
  }

  UploadState copyWith({
    UploadFlowStatus? status,
    UploadedAsset? asset,
    String? errorMessage,
    String? uid,
    UploadedAssetPurpose? purpose,
    String? sourceFeature,
    bool clearAsset = false,
    bool clearError = false,
  }) {
    return UploadState(
      status: status ?? this.status,
      asset: clearAsset ? null : (asset ?? this.asset),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uid: uid ?? this.uid,
      purpose: purpose ?? this.purpose,
      sourceFeature: sourceFeature ?? this.sourceFeature,
    );
  }
}

class UploadController extends StateNotifier<UploadState> {
  static const String _metadataSaveFailedMessage =
      'Photo upload could not be saved. Please try again.';

  final UploadedAssetRepository _assetRepository;
  final AuthRepository _authRepository;
  final ImagePrepareService _imagePrepareService;
  final R2UploadClient _r2UploadClient;
  int _operationGeneration = 0;

  UploadController({
    required UploadedAssetRepository assetRepository,
    required AuthRepository authRepository,
    required ImagePrepareService imagePrepareService,
    required R2UploadClient r2UploadClient,
  }) : _assetRepository = assetRepository,
       _authRepository = authRepository,
       _imagePrepareService = imagePrepareService,
       _r2UploadClient = r2UploadClient,
       super(const UploadState());

  void resetForSignedOut() {
    _operationGeneration++;
    state = const UploadState();
  }

  Future<UploadedAsset?> startUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
  }) async {
    if (state.isBusy) return null;
    final currentAuthUser = _authRepository.currentUser;
    if (uid.trim().isEmpty ||
        currentAuthUser == null ||
        currentAuthUser.uid.trim().isEmpty ||
        currentAuthUser.uid != uid) {
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        errorMessage: 'Please sign in before uploading a photo.',
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
      );
      return null;
    }
    final operationGeneration = ++_operationGeneration;
    if (OptivusUploadConfig.mode == OptivusUploadMode.disabled) {
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        errorMessage: 'Photo uploads are disabled in this build.',
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
      );
      return null;
    }
    if (OptivusUploadConfig.useR2 && !OptivusUploadConfig.hasWorkerUrl) {
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        errorMessage: 'Cloudflare R2 uploads are not configured yet.',
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
      );
      return null;
    }

    PreparedUploadImage? preparedImage;
    R2SignedUpload? signedUpload;
    String? uploadIdToken;
    var uploadCompleted = false;
    var savingMetadata = false;
    try {
      state = state.copyWith(
        status: UploadFlowStatus.picking,
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
        clearAsset: true,
        clearError: true,
      );
      final pickedFile = await _imagePrepareService.pickImageFile();
      if (!_isCurrentOperation(uid, operationGeneration)) return null;
      if (pickedFile == null) {
        state = state.copyWith(status: UploadFlowStatus.idle, clearError: true);
        return null;
      }

      state = state.copyWith(status: UploadFlowStatus.preparing);
      preparedImage = await _imagePrepareService.preparePickedFile(
        pickedFile,
        purpose: purpose,
      );
      if (!_isCurrentOperation(uid, operationGeneration)) return null;
      if (preparedImage == null) {
        state = state.copyWith(status: UploadFlowStatus.idle, clearError: true);
        return null;
      }

      uploadIdToken = await _authRepository.currentIdToken();
      if (!_isCurrentOperation(uid, operationGeneration)) return null;
      if (uploadIdToken == null || uploadIdToken.trim().isEmpty) {
        throw const CloudflareClientException(
          'Please sign in again before uploading a photo.',
        );
      }

      state = state.copyWith(status: UploadFlowStatus.signing);
      signedUpload = await _r2UploadClient.signUpload(
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
        contentType: preparedImage.contentType,
        sizeBytes: preparedImage.sizeBytes,
        idToken: uploadIdToken,
      );
      if (!_isCurrentOperation(uid, operationGeneration)) return null;

      state = state.copyWith(status: UploadFlowStatus.uploading);
      await _r2UploadClient.uploadBytes(
        uploadUrl: signedUpload.uploadUrl,
        contentType: preparedImage.contentType,
        bytes: preparedImage.bytes,
      );
      if (!_isCurrentOperation(uid, operationGeneration)) return null;
      await _r2UploadClient.markUploadComplete(
        assetId: signedUpload.assetId,
        objectKey: signedUpload.objectKey,
        sizeBytes: preparedImage.sizeBytes,
        idToken: uploadIdToken,
      );
      if (!_isCurrentOperation(uid, operationGeneration)) return null;
      uploadCompleted = true;

      final now = DateTime.now();
      final asset = UploadedAsset(
        assetId: signedUpload.assetId,
        ownerUid: uid,
        sourceFeature: sourceFeature,
        purpose: purpose,
        fileName: preparedImage.fileName,
        contentType: preparedImage.contentType,
        sizeBytes: preparedImage.sizeBytes,
        r2Key: signedUpload.objectKey,
        localPreviewPath: preparedImage.localPreviewPath,
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      final activeUser = _authRepository.currentUser;
      if (activeUser == null ||
          activeUser.uid.trim().isEmpty ||
          activeUser.uid != uid) {
        return null;
      }

      state = state.copyWith(status: UploadFlowStatus.savingMetadata);
      savingMetadata = true;
      await _assetRepository.saveAsset(asset);
      savingMetadata = false;
      if (!_isCurrentOperation(uid, operationGeneration)) return null;

      final postSaveActiveUser = _authRepository.currentUser;
      if (postSaveActiveUser == null ||
          postSaveActiveUser.uid.trim().isEmpty ||
          postSaveActiveUser.uid != uid) {
        return null;
      }

      state = state.copyWith(
        status: UploadFlowStatus.uploaded,
        asset: asset,
        clearError: true,
      );
      return asset;
    } catch (error) {
      final metadataSaveFailedAfterR2 =
          savingMetadata &&
          uploadCompleted &&
          signedUpload != null &&
          _isRemoteCompletedUpload(signedUpload) &&
          uploadIdToken != null &&
          uploadIdToken.trim().isNotEmpty;
      if (metadataSaveFailedAfterR2) {
        final cleanupSucceeded = await _tryCleanupCompletedR2Upload(
          objectKey: signedUpload.objectKey,
          idToken: uploadIdToken,
        );
        if (cleanupSucceeded) {
          if (!_isCurrentOperation(uid, operationGeneration)) return null;
          state = state.copyWith(
            status: UploadFlowStatus.failed,
            errorMessage: _metadataSaveFailedMessage,
            clearAsset: true,
          );
          return null;
        }
      }

      final message = metadataSaveFailedAfterR2
          ? _metadataSaveFailedMessage
          : _friendlyUploadError(error);
      final failedAsset = signedUpload == null || preparedImage == null
          ? null
          : _failedAsset(
              uid: uid,
              sourceFeature: sourceFeature,
              purpose: purpose,
              image: preparedImage,
              signedUpload: signedUpload,
              errorMessage: message,
            );
      if (failedAsset != null) {
        try {
          await _assetRepository.saveAsset(failedAsset);
        } catch (_) {
          // Metadata was already the failing step; keep the UI error generic.
        }
      }
      if (!_isCurrentOperation(uid, operationGeneration)) return null;
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        asset: failedAsset,
        errorMessage: message,
      );
      return null;
    }
  }

  Future<bool> _tryCleanupCompletedR2Upload({
    required String objectKey,
    required String idToken,
  }) async {
    try {
      await _r2UploadClient.deleteUpload(
        objectKey: objectKey,
        idToken: idToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isRemoteCompletedUpload(R2SignedUpload signedUpload) {
    return !signedUpload.uploadUrl.startsWith('r2://fake-r2/');
  }

  Future<UploadedAsset?> retryFailedUpload() {
    final uid = state.uid;
    final purpose = state.purpose;
    final sourceFeature = state.sourceFeature;
    if (uid == null || purpose == null || sourceFeature == null) {
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        errorMessage: 'Choose a photo to upload first.',
      );
      return Future.value(null);
    }
    return startUpload(
      uid: uid,
      purpose: purpose,
      sourceFeature: sourceFeature,
    );
  }

  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    if (_authRepository.currentUser?.uid != uid) return;
    final operationGeneration = ++_operationGeneration;
    final current = state.asset;
    try {
      final asset =
          current != null &&
              current.ownerUid == uid &&
              current.assetId == assetId
          ? current
          : await _assetRepository.fetchAsset(uid: uid, assetId: assetId);
      if (!_isCurrentOperation(uid, operationGeneration)) return;

      state = asset == null
          ? state.copyWith(
              status: UploadFlowStatus.savingMetadata,
              uid: uid,
              clearError: true,
            )
          : state.copyWith(
              status: UploadFlowStatus.savingMetadata,
              asset: asset,
              uid: uid,
              purpose: asset.purpose,
              sourceFeature: asset.sourceFeature,
              clearError: true,
            );
      final objectKey = asset?.r2Key.trim() ?? '';
      if (objectKey.isNotEmpty) {
        final idToken = await _authRepository.currentIdToken();
        if (!_isCurrentOperation(uid, operationGeneration)) return;
        if (idToken == null || idToken.trim().isEmpty) {
          throw const CloudflareClientException(
            'Please sign in again before removing the photo.',
          );
        }
        await _r2UploadClient.deleteUpload(
          objectKey: objectKey,
          idToken: idToken,
        );
        if (!_isCurrentOperation(uid, operationGeneration)) return;
      }

      await _assetRepository.markDeleted(uid: uid, assetId: assetId);
      if (!_isCurrentOperation(uid, operationGeneration)) return;
      final deletedAsset = asset?.copyWith(
        status: UploadedAssetStatus.deleted,
        updatedAt: DateTime.now(),
        clearErrorMessage: true,
      );
      state = deletedAsset == null
          ? state.copyWith(status: UploadFlowStatus.idle, clearError: true)
          : state.copyWith(
              status: UploadFlowStatus.idle,
              asset: deletedAsset,
              clearError: true,
            );
    } catch (error) {
      if (!_isCurrentOperation(uid, operationGeneration)) return;
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        errorMessage: _friendlyUploadError(error),
      );
    }
  }

  void clear() {
    _operationGeneration++;
    state = const UploadState();
  }

  bool _isCurrentOperation(String uid, int operationGeneration) {
    return _operationGeneration == operationGeneration &&
        _authRepository.currentUser?.uid == uid;
  }

  UploadedAsset _failedAsset({
    required String uid,
    required String sourceFeature,
    required UploadedAssetPurpose purpose,
    required PreparedUploadImage image,
    required R2SignedUpload signedUpload,
    required String errorMessage,
  }) {
    final now = DateTime.now();
    return UploadedAsset(
      assetId: signedUpload.assetId,
      ownerUid: uid,
      sourceFeature: sourceFeature,
      purpose: purpose,
      fileName: image.fileName,
      contentType: image.contentType,
      sizeBytes: image.sizeBytes,
      r2Key: signedUpload.objectKey,
      localPreviewPath: image.localPreviewPath,
      status: UploadedAssetStatus.failed,
      createdAt: now,
      updatedAt: now,
      errorMessage: errorMessage,
    );
  }

  String _friendlyUploadError(Object error) {
    if (error is ImagePreparationException) return error.message;
    if (error is CloudflareClientException) return error.message;
    return 'Photo upload failed. Please try again.';
  }
}

final imagePrepareServiceProvider = Provider<ImagePrepareService>((ref) {
  return ImagePrepareService();
});

final r2UploadClientProvider = Provider<R2UploadClient>((ref) {
  if (OptivusUploadConfig.useR2 && OptivusUploadConfig.hasWorkerUrl) {
    return RealR2UploadClient();
  }
  return FakeR2UploadClient();
});

final uploadControllerProvider =
    StateNotifierProvider<UploadController, UploadState>((ref) {
      return UploadController(
        assetRepository: ref.watch(uploadedAssetRepositoryProvider),
        authRepository: ref.watch(authRepositoryProvider),
        imagePrepareService: ref.watch(imagePrepareServiceProvider),
        r2UploadClient: ref.watch(r2UploadClientProvider),
      );
    });
