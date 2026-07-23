import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/models/routine_projection_receipt.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/routine_firestore_codec.dart';
import 'package:optivus/repositories/routine_repository.dart';
import 'package:optivus/services/routine_onboarding_projection.dart';

abstract class OnboardingRepository {
  Future<OnboardingDraft?> fetchDraft(String uid);
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid);
  Future<void> saveDraft(OnboardingDraft draft);
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle);

  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  });
}

class FakeOnboardingRepository implements OnboardingRepository {
  final FakeRoutineDatabase routineDatabase;
  Map<String, OnboardingDraft> _drafts = {};
  Map<String, OnboardingCompletionBundle> _bundles = {};
  bool _failNextCompletionBeforeCommit = false;

  FakeOnboardingRepository({FakeRoutineDatabase? routineDatabase})
    : routineDatabase = routineDatabase ?? FakeRoutineDatabase();

  void failNextCompletionBeforeCommit() {
    _failNextCompletionBeforeCommit = true;
  }

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    return _drafts[uid];
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    return _bundles[uid];
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _drafts[draft.uid] = draft;
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) async {
    _bundles[bundle.uid] = bundle;
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    _validateCompletion(finalDraft, bundle);
    final plan = RoutineOnboardingProjection.build(bundle);
    final existingReceipt =
        routineDatabase.receiptsByUid[bundle.uid]?[plan.projectionId];
    if (existingReceipt != null) {
      return RoutineProjectionResult(
        outcome: RoutineProjectionOutcome.noOp,
        receipt: existingReceipt,
      );
    }

    final nextDrafts = Map<String, OnboardingDraft>.from(_drafts);
    final nextBundles = Map<String, OnboardingCompletionBundle>.from(_bundles);
    final nextItemsByUid = _copyRoutineItems(routineDatabase.itemsByUid);
    final nextReceiptsByUid = _copyReceipts(routineDatabase.receiptsByUid);
    nextDrafts[bundle.uid] = finalDraft;
    nextBundles[bundle.uid] = bundle;
    final userItems = nextItemsByUid.putIfAbsent(bundle.uid, () => {});
    const codec = RoutineTemplateFirestoreCodec();
    for (final item in plan.items) {
      if (userItems.containsKey(item.id)) continue;
      codec.toFirestore(ownerUid: bundle.uid, item: item);
      userItems[item.id] = item;
    }
    nextReceiptsByUid.putIfAbsent(bundle.uid, () => {})[plan.projectionId] =
        plan.receipt;

    if (_failNextCompletionBeforeCommit) {
      _failNextCompletionBeforeCommit = false;
      throw const RoutineProjectionRetryRequiredException(
        'Injected atomic onboarding completion failure.',
      );
    }

    _drafts = nextDrafts;
    _bundles = nextBundles;
    routineDatabase.itemsByUid = nextItemsByUid;
    routineDatabase.receiptsByUid = nextReceiptsByUid;
    return RoutineProjectionResult(
      outcome: RoutineProjectionOutcome.projected,
      receipt: plan.receipt,
    );
  }

  OnboardingCompletionBundle? savedCompletionBundle(String uid) {
    return _bundles[uid];
  }
}

class FirestoreOnboardingRepository implements OnboardingRepository {
  final FirebaseFirestore? _injectedFirestore;
  final RoutineTemplateFirestoreCodec _routineCodec;
  final RoutineProjectionReceiptFirestoreCodec _receiptCodec;

  FirestoreOnboardingRepository({
    FirebaseFirestore? firestore,
    RoutineTemplateFirestoreCodec routineCodec =
        const RoutineTemplateFirestoreCodec(),
    RoutineProjectionReceiptFirestoreCodec receiptCodec =
        const RoutineProjectionReceiptFirestoreCodec(),
  }) : _injectedFirestore = firestore,
       _routineCodec = routineCodec,
       _receiptCodec = receiptCodec;

  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<OnboardingDraft?> fetchDraft(String uid) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.onboardingDraft(uid))
        .get();
    final data = doc.data();
    return data == null ? null : OnboardingDraft.fromMap(data);
  }

  @override
  Future<OnboardingCompletionBundle?> fetchCompletionBundle(String uid) async {
    final doc = await _firestore
        .doc(FirestoreUserPaths.onboardingCompletionBundle(uid))
        .get();
    final data = doc.data();
    return data == null ? null : OnboardingCompletionBundle.fromMap(data);
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) {
    return _firestore
        .doc(FirestoreUserPaths.onboardingDraft(draft.uid))
        .set(draft.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveCompletionBundle(OnboardingCompletionBundle bundle) {
    return _firestore
        .doc(FirestoreUserPaths.onboardingCompletionBundle(bundle.uid))
        .set(bundle.toMap(), SetOptions(merge: true));
  }

  @override
  Future<RoutineProjectionResult> completeOnboarding({
    required OnboardingDraft finalDraft,
    required OnboardingCompletionBundle bundle,
  }) async {
    _validateCompletion(finalDraft, bundle);
    final plan = RoutineOnboardingProjection.build(bundle);
    if (plan.items.length > 450) {
      throw StateError('Onboarding produced too many Routine templates.');
    }
    final receiptReference = _firestore.doc(
      FirestoreUserPaths.routineProjection(bundle.uid, plan.projectionId),
    );
    final itemReferences = plan.items
        .map(
          (item) => _firestore.doc(
            FirestoreUserPaths.routineItem(bundle.uid, item.id),
          ),
        )
        .toList(growable: false);

    try {
      return await _firestore.runTransaction((transaction) async {
        final receiptSnapshot = await transaction.get(receiptReference);
        if (receiptSnapshot.exists) {
          final data = receiptSnapshot.data();
          if (data == null) {
            throw const FormatException('Projection receipt data is missing.');
          }
          final receipt = _receiptCodec.fromFirestore(
            documentId: receiptSnapshot.id,
            data: data,
          );
          return RoutineProjectionResult(
            outcome: RoutineProjectionOutcome.noOp,
            receipt: receipt,
          );
        }

        final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final reference in itemReferences) {
          itemSnapshots.add(await transaction.get(reference));
        }

        transaction.set(
          _firestore.doc(FirestoreUserPaths.onboardingDraft(bundle.uid)),
          finalDraft.toMap(),
        );
        transaction.set(
          _firestore.doc(
            FirestoreUserPaths.onboardingCompletionBundle(bundle.uid),
          ),
          bundle.toMap(),
        );
        transaction.set(
          _firestore.doc(FirestoreUserPaths.profile(bundle.uid)),
          bundle.userProfilePatch,
          SetOptions(merge: true),
        );
        for (var index = 0; index < plan.items.length; index++) {
          if (itemSnapshots[index].exists) continue;
          final data = _routineCodec.toFirestore(
            ownerUid: bundle.uid,
            item: plan.items[index],
          );
          data['createdAt'] = FieldValue.serverTimestamp();
          data['updatedAt'] = FieldValue.serverTimestamp();
          transaction.set(itemReferences[index], data);
        }
        final receiptData = _receiptCodec.toFirestore(plan.receipt);
        receiptData['createdAt'] = FieldValue.serverTimestamp();
        receiptData['completedAt'] = FieldValue.serverTimestamp();
        transaction.set(receiptReference, receiptData);

        return RoutineProjectionResult(
          outcome: RoutineProjectionOutcome.projected,
          receipt: plan.receipt,
        );
      });
    } on RoutineProjectionRetryRequiredException {
      rethrow;
    } on FormatException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (error) {
      throw RoutineProjectionRetryRequiredException(error);
    }
  }
}

void _validateCompletion(
  OnboardingDraft finalDraft,
  OnboardingCompletionBundle bundle,
) {
  if (finalDraft.uid != bundle.uid) {
    throw ArgumentError('Final draft and completion bundle uid mismatch.');
  }
  validateOwnerUid(bundle.uid);
  if (!finalDraft.onboardingCompleted) {
    throw ArgumentError('Final onboarding draft is not marked complete.');
  }
}

Map<String, Map<String, RoutineItem>> _copyRoutineItems(
  Map<String, Map<String, RoutineItem>> source,
) {
  return {
    for (final entry in source.entries)
      entry.key: Map<String, RoutineItem>.from(entry.value),
  };
}

Map<String, Map<String, RoutineProjectionReceipt>> _copyReceipts(
  Map<String, Map<String, RoutineProjectionReceipt>> source,
) {
  return {
    for (final entry in source.entries)
      entry.key: Map<String, RoutineProjectionReceipt>.from(entry.value),
  };
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  if (ref.watch(optivusBackendModeProvider) == OptivusBackendMode.firebase) {
    return FirestoreOnboardingRepository();
  }
  return FakeOnboardingRepository(
    routineDatabase: ref.watch(fakeRoutineDatabaseProvider),
  );
});
