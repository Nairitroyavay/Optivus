import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Coordinates lifecycle cleanups for Base Timeline upload assets.
///
/// Responsibilities:
/// 1. Retiring uncommitted uploads: when a user uploads a photo but cancels or
///    discards before saving, deletes the R2 object and marks the asset deleted
///    in Firestore.
/// 2. Retiring replaced assets: post-commit cleanup when a section setup replaces
///    an older photo asset with a new one.
class BaseTimelineUploadLifecycleHelper {
  final UploadedAssetRepository _assetRepository;
  final R2UploadClient _r2UploadClient;
  final AuthRepository _authRepository;

  const BaseTimelineUploadLifecycleHelper({
    required UploadedAssetRepository assetRepository,
    required R2UploadClient r2UploadClient,
    required AuthRepository authRepository,
  }) : _assetRepository = assetRepository,
       _r2UploadClient = r2UploadClient,
       _authRepository = authRepository;

  /// Retires an upload that was not committed to Base Timeline setup.
  /// Safely deletes the Cloudflare R2 object (if objectKey provided) and
  /// marks the asset document as deleted in Firestore.
  Future<void> retireUncommittedUpload({
    required String uid,
    String? assetId,
    String? objectKey,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    final trimmedKey = objectKey?.trim();
    if (trimmedKey != null && trimmedKey.isNotEmpty) {
      try {
        final idToken = await _authRepository.currentIdToken();
        if (idToken != null && idToken.isNotEmpty) {
          await _r2UploadClient.deleteUpload(
            objectKey: trimmedKey,
            idToken: idToken,
          );
        }
      } catch (_) {
        // Safe fail: firestore tombstone still records deletion intent
      }
    }

    final trimmedAssetId = assetId?.trim();
    if (trimmedAssetId != null && trimmedAssetId.isNotEmpty) {
      try {
        await _assetRepository.markDeleted(
          uid: normalizedUid,
          assetId: trimmedAssetId,
        );
      } catch (_) {
        // Safe fail
      }
    }
  }

  /// Retires an asset that was replaced by a new photo in a committed setup.
  Future<void> retireReplacedAsset({
    required String uid,
    required String oldAssetId,
    String? oldObjectKey,
  }) async {
    await retireUncommittedUpload(
      uid: uid,
      assetId: oldAssetId,
      objectKey: oldObjectKey,
    );
  }
}

final baseTimelineUploadLifecycleHelperProvider =
    Provider<BaseTimelineUploadLifecycleHelper>((ref) {
      return BaseTimelineUploadLifecycleHelper(
        assetRepository: ref.watch(uploadedAssetRepositoryProvider),
        r2UploadClient: ref.watch(r2UploadClientProvider),
        authRepository: ref.watch(authRepositoryProvider),
      );
    });
