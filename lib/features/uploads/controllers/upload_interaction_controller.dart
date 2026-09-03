import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/config/upload_config.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/features/uploads/services/upload_permission_service.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/services/uploads/image_prepare_service.dart';
import 'package:optivus/state/upload_state.dart';

typedef UploadInteractionMap = Map<String, UploadSlotRuntimeState>;

class UploadInteractionController extends StateNotifier<UploadInteractionMap> {
  static const String _metadataSaveFailedMessage =
      'Photo upload could not be saved. Please try again.';

  final UploadShellConfig _shellConfig;
  final UploadedAssetRepository _assetRepository;
  final AuthRepository _authRepository;
  final ImagePrepareService _imagePrepareService;
  final R2UploadClient _r2UploadClient;
  final UploadPermissionService _permissionService;
  final RestoredUploadsController? _restoredController;

  // Per-slot generation tokens and mutex fences
  final Map<String, int> _slotGenerations = {};
  final Map<String, bool> _slotLocks = {};
  int _sessionGeneration = 0;
  String? _activeUid;

  UploadInteractionController({
    required UploadShellConfig shellConfig,
    required UploadedAssetRepository assetRepository,
    required AuthRepository authRepository,
    required ImagePrepareService imagePrepareService,
    required R2UploadClient r2UploadClient,
    required UploadPermissionService permissionService,
    RestoredUploadsController? restoredController,
  }) : _shellConfig = shellConfig,
       _assetRepository = assetRepository,
       _authRepository = authRepository,
       _imagePrepareService = imagePrepareService,
       _r2UploadClient = r2UploadClient,
       _permissionService = permissionService,
       _restoredController = restoredController,
       super(_initialStateFromConfig(shellConfig));

  static UploadInteractionMap _initialStateFromConfig(
    UploadShellConfig config,
  ) {
    final map = <String, UploadSlotRuntimeState>{};
    for (final slot in config.slots) {
      map[slot.key] = UploadSlotRuntimeState(
        slotKey: slot.key,
        purpose: slot.purpose,
        isHydrating: false,
        phase: UploadInteractionPhase.empty,
      );
    }
    return Map.unmodifiable(map);
  }

  void syncWithDurableState(
    RestoredUploadsState restoredState, {
    required String uid,
  }) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      resetForSignedOut();
      return;
    }
    _activeUid = normalizedUid;

    final next = Map<String, UploadSlotRuntimeState>.from(state);
    var changed = false;

    for (final slot in _shellConfig.slots) {
      final current = next[slot.key];
      if (current == null) continue;

      final restored = restoredState.forPurpose(slot.purpose);
      final hasMatchingRestored =
          restored != null &&
          restored.asset.ownerUid == normalizedUid &&
          uploadedAssetIsDurablyUploadedForSlot(
            asset: restored.asset,
            uid: normalizedUid,
            purpose: slot.purpose,
          );

      // If there is an active in-flight transient attempt for this slot, preserve attempt state
      if (current.isBusy) {
        if (current.isHydrating != restoredState.isHydrating) {
          next[slot.key] = current.copyWith(
            isHydrating: restoredState.isHydrating,
          );
          changed = true;
        }
        continue;
      }

      if (hasMatchingRestored) {
        final updated = current.copyWith(
          isHydrating: restoredState.isHydrating,
          phase:
              current.phase == UploadInteractionPhase.failed &&
                  current.attemptError != null
              ? UploadInteractionPhase.failed
              : UploadInteractionPhase.restored,
          durableAsset: restored.asset,
          previewStatus: restored.previewStatus,
          remotePreviewUri: restored.previewUri,
        );
        if (updated != current) {
          next[slot.key] = updated;
          changed = true;
        }
      } else {
        if (!restoredState.isHydrating &&
            current.durableAsset != null &&
            current.phase == UploadInteractionPhase.restored) {
          next[slot.key] = current.copyWith(
            isHydrating: false,
            phase: UploadInteractionPhase.empty,
            clearDurableAsset: true,
            clearRemotePreviewUri: true,
            previewStatus: UploadedAssetPreviewStatus.unavailable,
          );
          changed = true;
        } else if (current.isHydrating != restoredState.isHydrating) {
          next[slot.key] = current.copyWith(
            isHydrating: restoredState.isHydrating,
          );
          changed = true;
        }
      }
    }

    if (changed) {
      state = Map.unmodifiable(next);
    }
  }

  Future<UploadedAsset?> takePhoto(
    String slotKey, {
    required String uid,
    required String sourceFeature,
  }) {
    return pickAndUpload(
      slotKey,
      source: ImageSource.camera,
      uid: uid,
      sourceFeature: sourceFeature,
    );
  }

  Future<UploadedAsset?> chooseFromGallery(
    String slotKey, {
    required String uid,
    required String sourceFeature,
  }) {
    return pickAndUpload(
      slotKey,
      source: ImageSource.gallery,
      uid: uid,
      sourceFeature: sourceFeature,
    );
  }

  Future<UploadedAsset?> pickAndUpload(
    String slotKey, {
    required ImageSource source,
    required String uid,
    required String sourceFeature,
  }) async {
    final current = state[slotKey];
    if (current == null) return null;

    // Invariant 10 & 28: Per-slot lock
    if (_slotLocks[slotKey] == true || current.isBusy) return null;
    _slotLocks[slotKey] = true;

    final sessionGeneration = _sessionGeneration;
    final slotGeneration = _nextSlotGeneration(slotKey);
    _activeUid = uid;

    _setSlotState(slotKey, (s) => s.copyWith(phase: UploadInteractionPhase.preparing, clearAttemptError: true));

    try {
      // Permission check (Invariant 9 & 18)
      try {
        final permStatus = await _permissionService.checkOrRequest(source);
        if (permStatus == UploadPermissionStatus.permanentlyDenied ||
            permStatus == UploadPermissionStatus.restricted) {
          _setSlotState(
            slotKey,
            (s) => s.copyWith(
              phase: UploadInteractionPhase.failed,
              attemptError: _permissionService.permissionGuidanceMessage(
                source,
                isPermanent: true,
              ),
            ),
          );
          return null;
        }
      } catch (permError) {
        final mapped = _permissionService.mapPickerException(permError, source);
        _setSlotState(
          slotKey,
          (s) => s.copyWith(
            phase: UploadInteractionPhase.failed,
            attemptError: _permissionService.permissionGuidanceMessage(
              source,
              isPermanent: mapped == UploadPermissionStatus.permanentlyDenied,
            ),
          ),
        );
        return null;
      }

      // Launch picker
      XFile? picked;
      try {
        picked = await _imagePrepareService.pickImageFile(source: source);
      } catch (pickerError) {
        if (!_isCurrentOperation(
          slotKey,
          uid,
          sessionGeneration,
          slotGeneration,
        )) {
          return null;
        }
        final mapped = _permissionService.mapPickerException(
          pickerError,
          source,
        );
        _setSlotState(
          slotKey,
          (s) => s.copyWith(
            phase: UploadInteractionPhase.failed,
            attemptError: _permissionService.permissionGuidanceMessage(
              source,
              isPermanent: mapped == UploadPermissionStatus.permanentlyDenied,
            ),
          ),
        );
        return null;
      }

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }

      // Invariant 14: Picker cancellation is not failure
      if (picked == null) {
        _setSlotState(
          slotKey,
          (s) => s.copyWith(
            phase: s.hasDurableAsset
                ? (s.previewStatus == UploadedAssetPreviewStatus.available
                      ? UploadInteractionPhase.uploaded
                      : UploadInteractionPhase.restored)
                : UploadInteractionPhase.empty,
            clearAttemptError: true,
          ),
        );
        return null;
      }

      return await _executeUploadPipeline(
        slotKey: slotKey,
        pickedFile: picked,
        uid: uid,
        purpose: current.purpose,
        sourceFeature: sourceFeature,
        sessionGeneration: sessionGeneration,
        slotGeneration: slotGeneration,
      );
    } finally {
      if ((_slotGenerations[slotKey] ?? 0) == slotGeneration) {
        _slotLocks[slotKey] = false;
      }
    }
  }

  Future<UploadedAsset?> uploadPreselectedFile(
    String slotKey, {
    required XFile file,
    required String uid,
    required String sourceFeature,
  }) async {
    final current = state[slotKey];
    if (current == null) return null;
    _slotLocks[slotKey] = true;

    final sessionGeneration = _sessionGeneration;
    final slotGeneration = _nextSlotGeneration(slotKey);
    _activeUid = uid;

    try {
      return await _executeUploadPipeline(
        slotKey: slotKey,
        pickedFile: file,
        uid: uid,
        purpose: current.purpose,
        sourceFeature: sourceFeature,
        sessionGeneration: sessionGeneration,
        slotGeneration: slotGeneration,
      );
    } finally {
      if ((_slotGenerations[slotKey] ?? 0) == slotGeneration) {
        _slotLocks[slotKey] = false;
      }
    }
  }

  Future<UploadedAsset?> retry(
    String slotKey, {
    required String uid,
    required String sourceFeature,
  }) async {
    final current = state[slotKey];
    if (current == null) return null;
    if (current.transientFile != null) {
      return uploadPreselectedFile(
        slotKey,
        file: current.transientFile!,
        uid: uid,
        sourceFeature: sourceFeature,
      );
    }
    return chooseFromGallery(slotKey, uid: uid, sourceFeature: sourceFeature);
  }

  Future<bool> remove(String slotKey, {required String uid}) async {
    final current = state[slotKey];
    if (current == null) return false;
    if (!current.hasDurableAsset) {
      dismissAttemptError(slotKey);
      return true;
    }

    // Invariant 25: Rapid remove lock
    if (_slotLocks[slotKey] == true || current.isBusy) return false;
    _slotLocks[slotKey] = true;

    final sessionGeneration = _sessionGeneration;
    final slotGeneration = _nextSlotGeneration(slotKey);
    final asset = current.durableAsset!;

    _setSlotState(slotKey, (s) => s.copyWith(phase: UploadInteractionPhase.preparing, clearAttemptError: true));

    try {
      if (asset.r2Key.trim().isNotEmpty) {
        final idToken = await _authRepository.currentIdToken();
        if (!_isCurrentOperation(
          slotKey,
          uid,
          sessionGeneration,
          slotGeneration,
        )) {
          return false;
        }
        if (idToken != null && idToken.trim().isNotEmpty) {
          try {
            await _r2UploadClient.deleteUpload(
              objectKey: asset.r2Key,
              idToken: idToken,
            );
          } catch (_) {
            // Durable deletion remains authoritative; repository deletion handles cleanup
          }
        }
      }

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return false;
      }

      // Invariant 6 & 21: Durable removal authority
      await _assetRepository.markDeleted(uid: uid, assetId: asset.assetId);

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return false;
      }

      _restoredController?.removePurpose(uid: uid, purpose: current.purpose);

      _setSlotState(
        slotKey,
        (s) => s.copyWith(
          phase: UploadInteractionPhase.empty,
          clearDurableAsset: true,
          clearTransientFile: true,
          clearPreparedImage: true,
          clearAttemptError: true,
          clearRemotePreviewUri: true,
          previewStatus: UploadedAssetPreviewStatus.unavailable,
        ),
      );
      return true;
    } catch (error) {
      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return false;
      }
      // Invariant 24: Failed remove keeps durable asset authoritative
      _setSlotState(
        slotKey,
        (s) => s.copyWith(
          phase: s.previewStatus == UploadedAssetPreviewStatus.available
              ? UploadInteractionPhase.uploaded
              : UploadInteractionPhase.restored,
          attemptError: "Couldn't remove the photo. Try again.",
        ),
      );
      return false;
    } finally {
      _slotLocks[slotKey] = false;
    }
  }

  void dismissAttemptError(String slotKey) {
    _setSlotState(
      slotKey,
      (s) => s.copyWith(
        clearAttemptError: true,
        clearTransientFile: true,
        clearPreparedImage: true,
        phase: s.hasDurableAsset
            ? (s.previewStatus == UploadedAssetPreviewStatus.available
                  ? UploadInteractionPhase.uploaded
                  : UploadInteractionPhase.restored)
            : UploadInteractionPhase.empty,
      ),
    );
  }

  void resetForSignedOut() {
    _sessionGeneration++;
    _slotGenerations.clear();
    _slotLocks.clear();
    _activeUid = null;
    state = _initialStateFromConfig(_shellConfig);
  }

  Future<UploadedAsset?> _executeUploadPipeline({
    required String slotKey,
    required XFile pickedFile,
    required String uid,
    required UploadedAssetPurpose purpose,
    required String sourceFeature,
    required int sessionGeneration,
    required int slotGeneration,
  }) async {
    _setSlotState(
      slotKey,
      (s) => s.copyWith(
        phase: UploadInteractionPhase.preparing,
        transientFile: pickedFile,
        clearAttemptError: true,
      ),
    );

    PreparedUploadImage? prepared;
    R2SignedUpload? signedUpload;
    String? uploadIdToken;
    var uploadCompleted = false;
    var savingMetadata = false;

    try {
      // 1. Prepare (EXIF baked once, compressed if needed)
      prepared = await _imagePrepareService.preparePickedFile(
        pickedFile,
        purpose: purpose,
      );

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }

      if (prepared == null) {
        _setSlotState(
          slotKey,
          (s) => s.copyWith(
            phase: s.hasDurableAsset
                ? UploadInteractionPhase.uploaded
                : UploadInteractionPhase.empty,
            clearAttemptError: true,
          ),
        );
        return null;
      }

      _setSlotState(
        slotKey,
        (s) => s.copyWith(
          phase: UploadInteractionPhase.uploading,
          preparedImage: prepared,
        ),
      );

      uploadIdToken = await _authRepository.currentIdToken();
      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }
      if (uploadIdToken == null || uploadIdToken.trim().isEmpty) {
        throw const CloudflareClientException(
          'Please sign in again before uploading a photo.',
        );
      }

      // Check upload config
      if (OptivusUploadConfig.mode == OptivusUploadMode.disabled) {
        throw const ImagePreparationException(
          'Photo uploads are disabled in this build.',
        );
      }
      if (OptivusUploadConfig.useR2 && !OptivusUploadConfig.hasWorkerUrl) {
        throw const CloudflareClientException(
          'Cloudflare R2 uploads are not configured yet.',
        );
      }

      // 2. Sign
      signedUpload = await _r2UploadClient.signUpload(
        uid: uid,
        purpose: purpose,
        sourceFeature: sourceFeature,
        contentType: prepared.contentType,
        sizeBytes: prepared.sizeBytes,
        idToken: uploadIdToken,
      );

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }

      // 3. Upload bytes
      await _r2UploadClient.uploadBytes(
        uploadUrl: signedUpload.uploadUrl,
        contentType: prepared.contentType,
        bytes: prepared.bytes,
      );

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }

      // 4. Mark complete
      await _r2UploadClient.markUploadComplete(
        assetId: signedUpload.assetId,
        objectKey: signedUpload.objectKey,
        sizeBytes: prepared.sizeBytes,
        idToken: uploadIdToken,
      );

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }
      uploadCompleted = true;

      // 5. Durable metadata write (Invariant 5)
      final now = DateTime.now();
      final asset = UploadedAsset(
        assetId: signedUpload.assetId,
        ownerUid: uid,
        sourceFeature: sourceFeature,
        purpose: purpose,
        fileName: prepared.fileName,
        contentType: prepared.contentType,
        sizeBytes: prepared.sizeBytes,
        r2Key: signedUpload.objectKey,
        localPreviewPath: prepared.localPreviewPath,
        status: UploadedAssetStatus.uploaded,
        createdAt: now,
        updatedAt: now,
      );

      savingMetadata = true;
      await _assetRepository.saveAsset(asset);
      savingMetadata = false;

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }

      // Register with durable restored controller (Invariant 1)
      _restoredController?.registerUploaded(asset);

      // Transition to uploaded (Invariant 5)
      _setSlotState(
        slotKey,
        (s) => s.copyWith(
          phase: UploadInteractionPhase.uploaded,
          durableAsset: asset,
          previewStatus: UploadedAssetPreviewStatus.available,
          clearAttemptError: true,
          clearTransientFile: true,
          clearPreparedImage: true,
        ),
      );

      return asset;
    } catch (error) {
      final metadataSaveFailedAfterR2 =
          savingMetadata &&
          uploadCompleted &&
          signedUpload != null &&
          !signedUpload.uploadUrl.startsWith('r2://fake-r2/') &&
          uploadIdToken != null &&
          uploadIdToken.trim().isNotEmpty;

      if (metadataSaveFailedAfterR2) {
        try {
          await _r2UploadClient.deleteUpload(
            objectKey: signedUpload.objectKey,
            idToken: uploadIdToken,
          );
        } catch (_) {}
      }

      if (!_isCurrentOperation(
        slotKey,
        uid,
        sessionGeneration,
        slotGeneration,
      )) {
        return null;
      }

      final friendlyMsg = metadataSaveFailedAfterR2
          ? _metadataSaveFailedMessage
          : _friendlyErrorMessage(error);

      // Invariant 4 & 15: Failed attempt preserves previous durable asset
      _setSlotState(
        slotKey,
        (s) => s.copyWith(
          phase: UploadInteractionPhase.failed,
          attemptError: friendlyMsg,
        ),
      );
      return null;
    }
  }

  void _setSlotState(
    String slotKey,
    UploadSlotRuntimeState Function(UploadSlotRuntimeState) updater,
  ) {
    final current = state[slotKey];
    if (current == null) return;
    final updated = updater(current);
    final next = Map<String, UploadSlotRuntimeState>.from(state);
    next[slotKey] = updated;
    state = Map.unmodifiable(next);
  }

  int _nextSlotGeneration(String slotKey) {
    final next = (_slotGenerations[slotKey] ?? 0) + 1;
    _slotGenerations[slotKey] = next;
    return next;
  }

  bool _isCurrentOperation(
    String slotKey,
    String uid,
    int sessionGeneration,
    int slotGeneration,
  ) {
    return _sessionGeneration == sessionGeneration &&
        (_slotGenerations[slotKey] ?? 0) == slotGeneration &&
        _authRepository.currentUser?.uid == uid &&
        _activeUid == uid;
  }

  String _friendlyErrorMessage(Object error) {
    if (error is ImagePreparationException) return error.message;
    if (error is CloudflareClientException) return error.message;
    return 'Photo upload failed. Please try again.';
  }
}
