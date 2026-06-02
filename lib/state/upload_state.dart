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
  final UploadedAssetRepository _assetRepository;
  final AuthRepository _authRepository;
  final ImagePrepareService _imagePrepareService;
  final R2UploadClient _r2UploadClient;

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

  Future<UploadedAsset?> startUpload({
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
  }) async {
    if (state.isBusy) return null;
    if (uid.trim().isEmpty) {
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        errorMessage: 'Please sign in before uploading a photo.',
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
      );
      return null;
    }
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
      if (pickedFile == null) {
        state = state.copyWith(status: UploadFlowStatus.idle, clearError: true);
        return null;
      }

      state = state.copyWith(status: UploadFlowStatus.preparing);
      preparedImage = await _imagePrepareService.preparePickedFile(pickedFile);
      if (preparedImage == null) {
        state = state.copyWith(status: UploadFlowStatus.idle, clearError: true);
        return null;
      }

      final idToken = await _authRepository.currentIdToken();
      if (idToken == null || idToken.trim().isEmpty) {
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
        idToken: idToken,
      );

      state = state.copyWith(status: UploadFlowStatus.uploading);
      await _r2UploadClient.uploadBytes(
        uploadUrl: signedUpload.uploadUrl,
        contentType: preparedImage.contentType,
        bytes: preparedImage.bytes,
      );
      await _r2UploadClient.markUploadComplete(
        assetId: signedUpload.assetId,
        objectKey: signedUpload.objectKey,
        sizeBytes: preparedImage.sizeBytes,
        idToken: idToken,
      );

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

      state = state.copyWith(status: UploadFlowStatus.savingMetadata);
      await _assetRepository.saveAsset(asset);
      state = state.copyWith(
        status: UploadFlowStatus.uploaded,
        asset: asset,
        clearError: true,
      );
      return asset;
    } catch (error) {
      final message = _friendlyUploadError(error);
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
        await _assetRepository.saveAsset(failedAsset);
      }
      state = state.copyWith(
        status: UploadFlowStatus.failed,
        asset: failedAsset,
        errorMessage: message,
      );
      return null;
    }
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
    await _assetRepository.markDeleted(uid: uid, assetId: assetId);
    final current = state.asset;
    state = state.copyWith(
      status: UploadFlowStatus.idle,
      asset: current == null || current.assetId != assetId
          ? current
          : current.copyWith(
              status: UploadedAssetStatus.deleted,
              updatedAt: DateTime.now(),
              clearErrorMessage: true,
            ),
      clearError: true,
    );
  }

  void clear() {
    state = const UploadState();
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
