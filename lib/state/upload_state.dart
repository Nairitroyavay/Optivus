import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_draft.dart';
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

enum UploadedAssetPreviewStatus { loading, available, unavailable }

bool uploadedAssetIsDurablyUploadedForSlot({
  required UploadedAsset asset,
  required String uid,
  required UploadedAssetPurpose purpose,
}) {
  return asset.ownerUid == uid &&
      asset.purpose == purpose &&
      asset.sourceFeature == OnboardingDraft.sourceOnboarding &&
      asset.assetId.trim().isNotEmpty &&
      asset.r2Key.trim().isNotEmpty &&
      _uploadedAssetR2IdentityMatches(asset) &&
      asset.status == UploadedAssetStatus.uploaded;
}

bool _uploadedAssetR2IdentityMatches(UploadedAsset asset) {
  final key = asset.r2Key.trim();
  if (key.contains('..') || key.contains(r'\') || key.contains('//')) {
    return false;
  }
  final parts = key.split('/');
  if (parts.length != 5 ||
      parts[0] != 'users' ||
      parts[1] != asset.ownerUid ||
      parts[2] != asset.sourceFeature) {
    return false;
  }
  final allowedPurposes = switch (asset.purpose) {
    UploadedAssetPurpose.skinFace => const {'skin_face', 'skin_care'},
    UploadedAssetPurpose.skinProducts => const {'skin_products', 'skin_care'},
    _ => {asset.purpose.wireName},
  };
  if (!allowedPurposes.contains(parts[3])) {
    return false;
  }
  final fileName = parts[4];
  final lastDot = fileName.lastIndexOf('.');
  return lastDot > 0 &&
      lastDot < fileName.length - 1 &&
      fileName.substring(0, lastDot) == asset.assetId;
}

String? usableUploadedAssetLocalPreviewPath(UploadedAsset asset) {
  final path = asset.localPreviewPath?.trim();
  if (path == null || path.isEmpty) return null;
  try {
    return File(path).existsSync() ? path : null;
  } on FileSystemException {
    return null;
  }
}

class RestoredUploadedAsset {
  final UploadedAsset asset;
  final UploadedAssetPreviewStatus previewStatus;
  final Uri? previewUri;

  const RestoredUploadedAsset({
    required this.asset,
    this.previewStatus = UploadedAssetPreviewStatus.loading,
    this.previewUri,
  });

  RestoredUploadedAsset copyWith({
    UploadedAssetPreviewStatus? previewStatus,
    Uri? previewUri,
    bool clearPreviewUri = false,
  }) {
    return RestoredUploadedAsset(
      asset: asset,
      previewStatus: previewStatus ?? this.previewStatus,
      previewUri: clearPreviewUri ? null : (previewUri ?? this.previewUri),
    );
  }
}

class RestoredUploadsState {
  final String? uid;
  final bool isHydrating;
  final Map<UploadedAssetPurpose, RestoredUploadedAsset> assetsByPurpose;
  final String? errorMessage;

  const RestoredUploadsState({
    this.uid,
    this.isHydrating = false,
    this.assetsByPurpose = const {},
    this.errorMessage,
  });

  RestoredUploadedAsset? forPurpose(UploadedAssetPurpose purpose) =>
      assetsByPurpose[purpose];
}

abstract interface class UploadedAssetPreviewResolver {
  Future<Uri?> resolvePreview({
    required String uid,
    required UploadedAsset asset,
  });
}

/// R2 objects are private and the current upload Worker has no authenticated
/// read endpoint. Keep durable presence truthful without inventing a public URL.
class UnavailableUploadedAssetPreviewResolver
    implements UploadedAssetPreviewResolver {
  const UnavailableUploadedAssetPreviewResolver();

  @override
  Future<Uri?> resolvePreview({
    required String uid,
    required UploadedAsset asset,
  }) async => null;
}

class RestoredUploadsController extends StateNotifier<RestoredUploadsState> {
  final UploadedAssetRepository _assetRepository;
  final UploadedAssetPreviewResolver _previewResolver;
  int _sessionGeneration = 0;
  final Map<UploadedAssetPurpose, int> _previewGenerations = {};
  Future<void>? _inFlightHydration;
  String? _inFlightHydrationUid;

  RestoredUploadsController({
    required UploadedAssetRepository assetRepository,
    required UploadedAssetPreviewResolver previewResolver,
  }) : _assetRepository = assetRepository,
       _previewResolver = previewResolver,
       super(const RestoredUploadsState());

  Future<void> hydrate({required String uid, bool force = false}) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      resetForSignedOut();
      return Future.value();
    }
    if (!force &&
        _inFlightHydrationUid == normalizedUid &&
        _inFlightHydration != null) {
      return _inFlightHydration!;
    }
    if (!force &&
        state.uid == normalizedUid &&
        !state.isHydrating &&
        state.errorMessage == null) {
      return Future.value();
    }

    final hydration = _hydrate(normalizedUid);
    _inFlightHydrationUid = normalizedUid;
    _inFlightHydration = hydration;
    hydration.whenComplete(() {
      if (identical(_inFlightHydration, hydration)) {
        _inFlightHydration = null;
        _inFlightHydrationUid = null;
      }
    });
    return hydration;
  }

  Future<void> _hydrate(String normalizedUid) async {
    final sessionGeneration = ++_sessionGeneration;
    _previewGenerations.clear();
    state = RestoredUploadsState(uid: normalizedUid, isHydrating: true);
    try {
      final candidates = [
        ...await _assetRepository.fetchRecentAssets(
          uid: normalizedUid,
          sourceFeature: OnboardingDraft.sourceOnboarding,
          limit: 100,
        ),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (sessionGeneration != _sessionGeneration ||
          state.uid != normalizedUid) {
        return;
      }

      final byPurpose = <UploadedAssetPurpose, RestoredUploadedAsset>{};
      final removedPurposes = <UploadedAssetPurpose>{};
      for (final asset in candidates) {
        if (asset.ownerUid != normalizedUid ||
            asset.sourceFeature != OnboardingDraft.sourceOnboarding ||
            removedPurposes.contains(asset.purpose) ||
            byPurpose.containsKey(asset.purpose)) {
          continue;
        }
        if (asset.status == UploadedAssetStatus.deleted) {
          removedPurposes.add(asset.purpose);
          continue;
        }
        if (!_isValidUploadedAsset(asset, normalizedUid)) continue;
        byPurpose[asset.purpose] = RestoredUploadedAsset(asset: asset);
      }
      state = RestoredUploadsState(
        uid: normalizedUid,
        assetsByPurpose: Map.unmodifiable(byPurpose),
      );
      for (final purpose in byPurpose.keys) {
        final previewGeneration = _nextPreviewGeneration(purpose);
        _resolvePreview(
          uid: normalizedUid,
          purpose: purpose,
          sessionGeneration: sessionGeneration,
          previewGeneration: previewGeneration,
        );
      }
    } catch (_) {
      if (sessionGeneration != _sessionGeneration ||
          state.uid != normalizedUid) {
        return;
      }
      state = RestoredUploadsState(
        uid: normalizedUid,
        errorMessage: 'Uploaded photos could not be restored yet.',
      );
    }
  }

  void registerUploaded(UploadedAsset asset) {
    final uid = state.uid;
    if (uid == null || !_isValidUploadedAsset(asset, uid)) return;
    final previewGeneration = _nextPreviewGeneration(asset.purpose);
    final next = Map<UploadedAssetPurpose, RestoredUploadedAsset>.from(
      state.assetsByPurpose,
    );
    next[asset.purpose] = RestoredUploadedAsset(asset: asset);
    state = RestoredUploadsState(
      uid: uid,
      assetsByPurpose: Map.unmodifiable(next),
    );
    _resolvePreview(
      uid: uid,
      purpose: asset.purpose,
      sessionGeneration: _sessionGeneration,
      previewGeneration: previewGeneration,
    );
  }

  void removePurpose({
    required String uid,
    required UploadedAssetPurpose purpose,
  }) {
    if (state.uid != uid) return;
    _nextPreviewGeneration(purpose);
    final next = Map<UploadedAssetPurpose, RestoredUploadedAsset>.from(
      state.assetsByPurpose,
    )..remove(purpose);
    state = RestoredUploadsState(
      uid: uid,
      assetsByPurpose: Map.unmodifiable(next),
    );
  }

  Future<void> retryPreview(UploadedAssetPurpose purpose) async {
    final uid = state.uid;
    if (uid == null || state.assetsByPurpose[purpose] == null) return;
    final previewGeneration = _nextPreviewGeneration(purpose);
    _setPreviewState(
      purpose,
      UploadedAssetPreviewStatus.loading,
      clearPreviewUri: true,
    );
    await _resolvePreview(
      uid: uid,
      purpose: purpose,
      sessionGeneration: _sessionGeneration,
      previewGeneration: previewGeneration,
    );
  }

  void resetForSignedOut() {
    _sessionGeneration++;
    _previewGenerations.clear();
    _inFlightHydration = null;
    _inFlightHydrationUid = null;
    state = const RestoredUploadsState();
  }

  int _nextPreviewGeneration(UploadedAssetPurpose purpose) {
    final next = (_previewGenerations[purpose] ?? 0) + 1;
    _previewGenerations[purpose] = next;
    return next;
  }

  Future<void> _resolvePreview({
    required String uid,
    required UploadedAssetPurpose purpose,
    required int sessionGeneration,
    required int previewGeneration,
  }) async {
    final current = state.assetsByPurpose[purpose];
    if (current == null) return;
    Uri? uri;
    try {
      uri = await _previewResolver.resolvePreview(
        uid: uid,
        asset: current.asset,
      );
    } catch (_) {
      uri = null;
    }
    if (sessionGeneration != _sessionGeneration ||
        _previewGenerations[purpose] != previewGeneration ||
        state.uid != uid) {
      return;
    }
    final latest = state.assetsByPurpose[purpose];
    if (latest == null || latest.asset.assetId != current.asset.assetId) return;
    _setPreviewState(
      purpose,
      uri == null
          ? UploadedAssetPreviewStatus.unavailable
          : UploadedAssetPreviewStatus.available,
      previewUri: uri,
      clearPreviewUri: uri == null,
    );
  }

  void _setPreviewState(
    UploadedAssetPurpose purpose,
    UploadedAssetPreviewStatus previewStatus, {
    Uri? previewUri,
    bool clearPreviewUri = false,
  }) {
    final current = state.assetsByPurpose[purpose];
    if (current == null) return;
    final next = Map<UploadedAssetPurpose, RestoredUploadedAsset>.from(
      state.assetsByPurpose,
    );
    next[purpose] = current.copyWith(
      previewStatus: previewStatus,
      previewUri: previewUri,
      clearPreviewUri: clearPreviewUri,
    );
    state = RestoredUploadsState(
      uid: state.uid,
      assetsByPurpose: Map.unmodifiable(next),
      errorMessage: state.errorMessage,
    );
  }

  static bool _isValidUploadedAsset(UploadedAsset asset, String uid) {
    return uploadedAssetIsDurablyUploadedForSlot(
      asset: asset,
      uid: uid,
      purpose: asset.purpose,
    );
  }
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
    if (error is ImagePreparationException) {
      final msg = error.message;
      final lower = msg.toLowerCase();
      if (lower.contains('raw_') ||
          lower.contains('secret') ||
          lower.contains('exception:') ||
          lower.contains('token') ||
          lower.contains('{') ||
          lower.contains('}')) {
        return 'That image couldn’t be read. Choose another photo.';
      }
      return msg;
    }
    if (error is CloudflareClientException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Please sign in again before uploading a photo.';
      }
      return 'We couldn’t upload this photo. Please try again.';
    }
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
  if (ref.watch(fakeDataAllowedProvider)) return FakeR2UploadClient();
  // The real client reports the existing typed missing-configuration/network
  // failure on use; Firebase mode must never simulate a successful upload.
  return RealR2UploadClient();
});

final uploadedAssetPreviewResolverProvider =
    Provider<UploadedAssetPreviewResolver>(
      (ref) => const UnavailableUploadedAssetPreviewResolver(),
    );

final restoredUploadsProvider =
    StateNotifierProvider<RestoredUploadsController, RestoredUploadsState>((
      ref,
    ) {
      return RestoredUploadsController(
        assetRepository: ref.watch(uploadedAssetRepositoryProvider),
        previewResolver: ref.watch(uploadedAssetPreviewResolverProvider),
      );
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
