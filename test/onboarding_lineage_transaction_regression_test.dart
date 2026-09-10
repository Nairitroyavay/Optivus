import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/repositories/firestore_paths.dart';
import 'package:optivus/repositories/onboarding_repository.dart';
import 'package:optivus/repositories/profile_repository.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_setup_lineage_migration_coordinator.dart';
import 'package:optivus/services/server_reconstructor.dart';

void main() {
  const uid = 'lineage-transaction-owner';
  test(
    'Firestore migration repairs legacy draft beside modern profile',
    () async {
      final profile = UserProfile.empty(
        uid: uid,
      ).copyWith(currentSetupGeneration: 1);
      final draft = OnboardingDraft.freshForSetup(
        uid: uid,
        setupGeneration: 0,
      ).copyWith(setupLineageVersion: 0, patiencePledgeAccepted: true);
      final database = _Database({
        FirestoreUserPaths.user(uid): profile.toFirestoreMap(),
        FirestoreUserPaths.onboardingDraft(uid): draft.toFirestoreMap(),
      });
      final source = _Source(database);
      final coordinator = OnboardingSetupLineageMigrationCoordinator(
        firestore: database,
        profileRepository: FakeProfileRepository(),
        onboardingRepository: FakeOnboardingRepository(),
      );
      final before = await source.load(uid);
      expect(coordinator.shouldMigrate(before), isTrue);
      final after = await coordinator.migrate(before, source: source);
      expect(after.draft!.setupLineageVersion, 1);
      expect(after.draft!.setupGeneration, 1);
      expect(after.draft!.patiencePledgeAccepted, isTrue);
      expect(coordinator.shouldMigrate(after), isFalse);
      final writes = database.writes;
      await coordinator.migrate(before, source: source);
      expect(database.writes, writes, reason: 'response-loss retry is a no-op');
    },
  );
}

class _Database implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> documents;
  int writes = 0;
  _Database(this.documents);
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _Document(path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await handler(transaction);
    documents.addAll(transaction.pending);
    writes += transaction.pending.length;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  final _Database database;
  final pending = <String, Map<String, dynamic>>{};
  _Transaction(this.database);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async => _Snapshot<T>(database.documents[ref.path] as T?);
  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    pending[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Document implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;
  _Document(this.path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Snapshot<T extends Object?> implements DocumentSnapshot<T> {
  final T? value;
  _Snapshot(this.value);
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Source implements ServerReconstructionSource {
  final _Database database;
  _Source(this.database);
  @override
  Future<ServerReconstructionSnapshot> load(
    String uid, {
    void Function(UserProfile? profile)? onProfileLoaded,
  }) async => ServerReconstructionSnapshot(
    profile: UserProfile.fromFirestoreMap(
      database.documents[FirestoreUserPaths.user(uid)]!,
    ),
    draft: OnboardingDraft.fromMap(
      database.documents[FirestoreUserPaths.onboardingDraft(uid)]!,
    ),
    completionBundle: null,
    currentRun: const OnboardingCurrentRunSnapshot(hasPointer: false),
  );
  @override
  Future<void> createProfileShell(UserProfile profile) async =>
      throw UnimplementedError();
}
