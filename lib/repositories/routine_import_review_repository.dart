import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/repositories/firestore_paths.dart';

abstract class RoutineImportReviewRepository {
  Future<List<RoutineImportReviewDraft>> fetchReviews(String uid);

  Future<RoutineImportReviewDraft?> fetchReview({
    required String uid,
    required String reviewId,
  });

  Future<void> saveReview(RoutineImportReviewDraft review);

  Future<void> markAccepted({required String uid, required String reviewId});
}

class FakeRoutineImportReviewRepository
    implements RoutineImportReviewRepository {
  final Map<String, Map<String, RoutineImportReviewDraft>> _reviewsByUid = {};

  @override
  Future<List<RoutineImportReviewDraft>> fetchReviews(String uid) async {
    final reviews = _reviewsByUid[uid]?.values.toList() ?? const [];
    return List<RoutineImportReviewDraft>.from(reviews)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<RoutineImportReviewDraft?> fetchReview({
    required String uid,
    required String reviewId,
  }) async {
    return _reviewsByUid[uid]?[reviewId];
  }

  @override
  Future<void> saveReview(RoutineImportReviewDraft review) async {
    final userReviews = _reviewsByUid.putIfAbsent(review.uid, () => {});
    userReviews[review.id] = review;
  }

  @override
  Future<void> markAccepted({
    required String uid,
    required String reviewId,
  }) async {
    final review = _reviewsByUid[uid]?[reviewId];
    if (review == null) return;
    _reviewsByUid[uid]![reviewId] = review.copyWith(
      status: RoutineImportReviewStatus.accepted,
      updatedAt: DateTime.now(),
    );
  }
}

class FirestoreRoutineImportReviewRepository
    implements RoutineImportReviewRepository {
  final FirebaseFirestore _firestore;

  FirestoreRoutineImportReviewRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<RoutineImportReviewDraft>> fetchReviews(String uid) async {
    final snapshot = await _firestore
        .collection(FirestoreUserPaths.routineImportReviews(uid))
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => RoutineImportReviewDraft.fromFirestoreMap(doc.data()))
        .toList(growable: false);
  }

  @override
  Future<RoutineImportReviewDraft?> fetchReview({
    required String uid,
    required String reviewId,
  }) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.routineImportReview(uid, reviewId))
        .get();
    final data = doc.data();
    return data == null
        ? null
        : RoutineImportReviewDraft.fromFirestoreMap(data);
  }

  @override
  Future<void> saveReview(RoutineImportReviewDraft review) {
    return _firestore
        .doc(FirestoreUserPaths.routineImportReview(review.uid, review.id))
        .set(review.toFirestoreMap(), SetOptions(merge: true));
  }

  @override
  Future<void> markAccepted({required String uid, required String reviewId}) {
    return _firestore
        .doc(FirestoreUserPaths.routineImportReview(uid, reviewId))
        .set({
          'uid': uid,
          'id': reviewId,
          'status': RoutineImportReviewStatus.accepted.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
  }
}

final routineImportReviewRepositoryProvider =
    Provider<RoutineImportReviewRepository>((ref) {
      if (OptivusBackendConfig.useFirebase) {
        return FirestoreRoutineImportReviewRepository();
      }
      return FakeRoutineImportReviewRepository();
    });
