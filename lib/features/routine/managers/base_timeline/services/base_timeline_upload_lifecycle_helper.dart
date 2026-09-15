import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/auth_repository.dart';
import 'package:optivus/repositories/uploaded_asset_repository.dart';
import 'package:optivus/services/cloudflare/cloudflare_clients.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

/// Coordinates lifecycle cleanups for Base Timeline upload assets.
///
/// Responsibilities:
/// 1. Retiring uncommitted uploads: marks Firestore asset deleted FIRST, then
///    performs best-effort Cloudflare R2 object deletion.
/// 2. Retiring replaced assets: post-commit cleanup when a section setup replaces
///    an older photo asset with a new one.
/// 3. Cleaning up stale uncommitted uploads left after an app kill or crash.
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
  ///
  /// Authoritative order:
  /// 1. Marks the asset document as deleted in Firestore FIRST. If this fails,
  ///    throws so the caller can retry without orphaning metadata.
  /// 2. Best-effort deletes the Cloudflare R2 object (if objectKey provided).
  Future<void> retireUncommittedUpload({
    required String uid,
    String? assetId,
    String? objectKey,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;

    // 1. Authoritative Firestore tombstone FIRST
    final trimmedAssetId = assetId?.trim();
    if (trimmedAssetId != null && trimmedAssetId.isNotEmpty) {
      await _assetRepository.markDeleted(
        uid: normalizedUid,
        assetId: trimmedAssetId,
      );
    }

    // 2. Best-effort Cloudflare R2 object deletion
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
        // Safe fail: firestore tombstone already recorded deletion intent
      }
    }
  }

  /// Retires an asset that was replaced by a new photo in a committed setup.
  Future<void> retireReplacedAsset({
    required String uid,
    String? oldAssetId,
    String? oldObjectKey,
  }) async {
    await retireUncommittedUpload(
      uid: uid,
      assetId: oldAssetId,
      objectKey: oldObjectKey,
    );
  }

  /// Recovers and retires orphaned temporary uploads older than [graceWindow].
  ///
  /// Strictly protects [committedAssetIds] / [committedAssetId] and
  /// [committedR2Keys] / [committedR2Key] (and any [activeSessionAssetIds] /
  /// [activeSessionR2Keys]) so current setup photos and in-flight session
  /// uploads are never deleted.
  ///
  /// [purposes] explicitly declares the upload purpose(s) being cleaned.
  /// Each requested purpose is fetched independently to prevent purpose starvation.
  Future<int> cleanupStaleUncommittedAssets({
    required String uid,
    required Set<UploadedAssetPurpose> purposes,
    Set<String> committedAssetIds = const {},
    Set<String> committedR2Keys = const {},
    String? committedAssetId,
    String? committedR2Key,
    Set<String> activeSessionAssetIds = const {},
    Set<String> activeSessionR2Keys = const {},
    Duration graceWindow = const Duration(minutes: 15),
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty || purposes.isEmpty) return 0;

    final protectedAssetIds = {
      ...committedAssetIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
      if (committedAssetId != null && committedAssetId.trim().isNotEmpty)
        committedAssetId.trim(),
    };
    final protectedR2Keys = {
      ...committedR2Keys.map((k) => k.trim()).where((k) => k.isNotEmpty),
      if (committedR2Key != null && committedR2Key.trim().isNotEmpty)
        committedR2Key.trim(),
    };

    var cleaned = 0;
    try {
      final discoveredAssets = <String, UploadedAsset>{};
      for (final purpose in purposes) {
        final recent = await _assetRepository.fetchRecentAssets(
          uid: normalizedUid,
          sourceFeature: UploadSourceFeature.routineBaseTimeline,
          purpose: purpose,
          limit: 20,
        );
        for (final asset in recent) {
          discoveredAssets[asset.assetId] = asset;
        }
      }

      final now = DateTime.now();
      for (final asset in discoveredAssets.values) {
        // Only consider assets belonging to requested owner and source feature
        if (asset.ownerUid != normalizedUid) continue;
        if (asset.sourceFeature != UploadSourceFeature.routineBaseTimeline) {
          continue;
        }
        if (!purposes.contains(asset.purpose)) continue;
        if (asset.status == UploadedAssetStatus.deleted) continue;

        // Strictly protect current committed source asset identity and R2 key
        if (protectedAssetIds.contains(asset.assetId)) continue;
        if (protectedR2Keys.contains(asset.r2Key)) continue;

        // Strictly protect active-session uploads
        if (activeSessionAssetIds.contains(asset.assetId)) continue;
        if (activeSessionR2Keys.contains(asset.r2Key)) continue;

        final age = now.difference(asset.updatedAt);
        if (age >= graceWindow) {
          try {
            await retireUncommittedUpload(
              uid: normalizedUid,
              assetId: asset.assetId,
              objectKey: asset.r2Key,
            );
            cleaned++;
          } catch (_) {
            // Safe fail per asset: failure to retire one does not abort cleanup
          }
        }
      }
    } catch (_) {
      // Best-effort cleanup: never throw to caller
    }
    return cleaned;
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
