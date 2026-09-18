/// Represents the type of active Eating asynchronous operation.
enum EatingOperationType { idle, uploading, extracting, generating }

/// Tracks the lifecycle and resource ownership of active AI operations in Eating setup.
///
/// Ensures candidate assets are owned by the specific UID that initiated the operation,
/// protecting against stale callbacks or account switching from retiring/modifying
/// assets belonging to other users.
class EatingOperationSession {
  final int generationId;
  final String ownerUid;
  final EatingOperationType type;
  final String? candidateAssetId;
  final String? candidateR2Key;

  const EatingOperationSession({
    this.generationId = 0,
    this.ownerUid = '',
    this.type = EatingOperationType.idle,
    this.candidateAssetId,
    this.candidateR2Key,
  });

  static const idle = EatingOperationSession();

  bool get isActive => type != EatingOperationType.idle;
  bool get hasCandidateAsset =>
      candidateAssetId != null && candidateAssetId!.trim().isNotEmpty;

  EatingOperationSession next({
    required String ownerUid,
    required EatingOperationType type,
    String? candidateAssetId,
    String? candidateR2Key,
  }) {
    return EatingOperationSession(
      generationId: generationId + 1,
      ownerUid: ownerUid,
      type: type,
      candidateAssetId: candidateAssetId ?? this.candidateAssetId,
      candidateR2Key: candidateR2Key ?? this.candidateR2Key,
    );
  }

  EatingOperationSession withCandidate({
    required String assetId,
    required String r2Key,
  }) {
    return EatingOperationSession(
      generationId: generationId,
      ownerUid: ownerUid,
      type: type,
      candidateAssetId: assetId,
      candidateR2Key: r2Key,
    );
  }

  EatingOperationSession toIdle() {
    return EatingOperationSession(
      generationId: generationId + 1,
      ownerUid: '',
      type: EatingOperationType.idle,
      candidateAssetId: null,
      candidateR2Key: null,
    );
  }
}
