import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class UploadedAssetRepository {
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  });

  Future<void> saveAsset(UploadedAsset asset);

  Future<void> markDeleted({required String uid, required String assetId});

  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  });
}

class FakeUploadedAssetRepository implements UploadedAssetRepository {
  final Map<String, Map<String, UploadedAsset>> _assetsByUid = {};

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async {
    return _assetsByUid[uid]?[assetId];
  }

  @override
  Future<void> saveAsset(UploadedAsset asset) async {
    final userAssets = _assetsByUid.putIfAbsent(asset.ownerUid, () => {});
    userAssets[asset.assetId] = asset;
  }

  @override
  Future<void> markDeleted({
    required String uid,
    required String assetId,
  }) async {
    final asset = _assetsByUid[uid]?[assetId];
    if (asset == null) return;
    _assetsByUid[uid]![assetId] = asset.copyWith(
      status: UploadedAssetStatus.deleted,
      updatedAt: DateTime.now(),
      clearErrorMessage: true,
    );
  }

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async {
    final assets = _assetsByUid[uid]?.values.toList() ?? const [];
    final filtered = assets.where((asset) {
      final sourceMatches =
          sourceFeature == null || asset.sourceFeature == sourceFeature;
      final purposeMatches = purpose == null || asset.purpose == purpose;
      return sourceMatches && purposeMatches;
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return filtered.take(limit.clamp(1, 100)).toList(growable: false);
  }
}

class FirestoreUploadedAssetRepository implements UploadedAssetRepository {
  final FirebaseFirestore _firestore;

  FirestoreUploadedAssetRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UploadedAsset?> fetchAsset({
    required String uid,
    required String assetId,
  }) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.uploadedAsset(uid, assetId))
        .get();
    final data = doc.data();
    return data == null ? null : UploadedAsset.fromFirestoreMap(data);
  }

  @override
  Future<void> saveAsset(UploadedAsset asset) {
    return _firestore
        .doc(FirestoreUserPaths.uploadedAsset(asset.ownerUid, asset.assetId))
        .set(asset.toFirestoreMap(), SetOptions(merge: true));
  }

  @override
  Future<void> markDeleted({required String uid, required String assetId}) {
    return _firestore.doc(FirestoreUserPaths.uploadedAsset(uid, assetId)).set({
      'status': UploadedAssetStatus.deleted.wireName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'errorMessage': null,
    }, SetOptions(merge: true));
  }

  @override
  Future<List<UploadedAsset>> fetchRecentAssets({
    required String uid,
    String? sourceFeature,
    UploadedAssetPurpose? purpose,
    int limit = 20,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final fetchLimit = (safeLimit * 4).clamp(20, 100);
    final snapshot = await _firestore
        .collection(FirestoreUserPaths.uploadedAssets(uid))
        .orderBy('updatedAt', descending: true)
        .limit(fetchLimit)
        .get();

    final assets = snapshot.docs
        .map((doc) => UploadedAsset.fromFirestoreMap(doc.data()))
        .where((asset) {
          final sourceMatches =
              sourceFeature == null || asset.sourceFeature == sourceFeature;
          final purposeMatches = purpose == null || asset.purpose == purpose;
          return sourceMatches && purposeMatches;
        })
        .take(safeLimit)
        .toList(growable: false);
    return assets;
  }
}

final uploadedAssetRepositoryProvider = Provider<UploadedAssetRepository>((
  ref,
) {
  if (OptivusBackendConfig.useFirebase) {
    return FirestoreUploadedAssetRepository();
  }
  return FakeUploadedAssetRepository();
});
