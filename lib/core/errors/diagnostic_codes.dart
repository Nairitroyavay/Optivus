/// Centralized, stable diagnostic codes across Optivus.
///
/// Diagnostic codes are non-sensitive, searchable, stable across versions,
/// and safe for logs and telemetry. They must never contain user IDs, emails,
/// tokens, file paths, Worker secrets, or raw exception strings.
abstract final class DiagnosticCodes {
  // Validation
  static const String validationMissingField = 'VALIDATION_MISSING_FIELD';
  static const String validationInvalidFormat = 'VALIDATION_INVALID_FORMAT';
  static const String validationIncompleteStep = 'VALIDATION_INCOMPLETE_STEP';
  static const String validationMissingTimetable =
      'VALIDATION_MISSING_TIMETABLE';
  static const String validationMissingPhoto = 'VALIDATION_MISSING_PHOTO';

  // Network
  static const String networkUnavailable = 'NETWORK_UNAVAILABLE';
  static const String networkTimeout = 'NETWORK_TIMEOUT';
  static const String networkConnectionReset = 'NETWORK_CONNECTION_RESET';

  // Authentication
  static const String authInvalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const String authInvalidEmail = 'AUTH_INVALID_EMAIL';
  static const String authSessionExpired = 'AUTH_SESSION_EXPIRED';
  static const String authMissingUser = 'AUTH_MISSING_USER';
  static const String authUserNotFound = 'AUTH_USER_NOT_FOUND';
  static const String authEmailInUse = 'AUTH_EMAIL_IN_USE';
  static const String authWeakPassword = 'AUTH_WEAK_PASSWORD';
  static const String authUserDisabled = 'AUTH_USER_DISABLED';
  static const String authRequiresRecentLogin = 'AUTH_REQUIRES_RECENT_LOGIN';
  static const String authRateLimited = 'AUTH_RATE_LIMITED';
  static const String authAccountCollision = 'AUTH_ACCOUNT_COLLISION';
  static const String authUnknown = 'AUTH_UNKNOWN';
  static const String verifyEmailRateLimited = 'VERIFY_EMAIL_RATE_LIMITED';
  static const String verifyEmailSessionExpired =
      'VERIFY_EMAIL_SESSION_EXPIRED';
  static const String verifyEmailCheckFailed = 'VERIFY_EMAIL_CHECK_FAILED';
  static const String verifyEmailResendFailed = 'VERIFY_EMAIL_RESEND_FAILED';

  // Permission
  static const String permissionCameraDenied = 'PERMISSION_CAMERA_DENIED';
  static const String permissionPhotosDenied = 'PERMISSION_PHOTOS_DENIED';
  static const String permissionPermanentlyDenied =
      'PERMISSION_PERMANENTLY_DENIED';

  // Upload
  static const String uploadInvalidImage = 'UPLOAD_INVALID_IMAGE';
  static const String uploadImageTooLarge = 'UPLOAD_IMAGE_TOO_LARGE';
  static const String uploadPreparationFailed = 'UPLOAD_PREPARATION_FAILED';
  static const String uploadSignFailed = 'UPLOAD_SIGN_FAILED';
  static const String uploadBinaryFailed = 'UPLOAD_BINARY_FAILED';
  static const String uploadConfirmFailed = 'UPLOAD_CONFIRM_FAILED';
  static const String uploadUrlExpired = 'UPLOAD_URL_EXPIRED';
  static const String uploadRemoveFailed = 'UPLOAD_REMOVE_FAILED';
  static const String uploadPreviewUnavailable = 'UPLOAD_PREVIEW_UNAVAILABLE';

  // AI Timeout
  static const String aiRoutineTimeout = 'AI_ROUTINE_TIMEOUT';
  static const String aiNutritionTimeout = 'AI_NUTRITION_TIMEOUT';
  static const String aiSkinCareTimeout = 'AI_SKIN_CARE_TIMEOUT';
  static const String aiCoachTimeout = 'AI_COACH_TIMEOUT';

  // AI Quota
  static const String aiRoutineQuota = 'AI_ROUTINE_QUOTA';
  static const String aiNutritionQuota = 'AI_NUTRITION_QUOTA';
  static const String aiSkinCareQuota = 'AI_SKIN_CARE_QUOTA';
  static const String aiCoachQuota = 'AI_COACH_QUOTA';

  // AI Malformed Response
  static const String aiRoutineResponseInvalid = 'AI_ROUTINE_RESPONSE_INVALID';
  static const String aiNutritionResponseInvalid =
      'AI_NUTRITION_RESPONSE_INVALID';
  static const String aiSkinCareResponseInvalid =
      'AI_SKIN_CARE_RESPONSE_INVALID';
  static const String aiCoachResponseInvalid = 'AI_COACH_RESPONSE_INVALID';
  static const String aiServiceUnavailable = 'AI_SERVICE_UNAVAILABLE';

  // Cloud Persistence
  static const String firestoreDraftWriteFailed =
      'FIRESTORE_DRAFT_WRITE_FAILED';
  static const String firestoreProfileWriteFailed =
      'FIRESTORE_PROFILE_WRITE_FAILED';
  static const String uploadMetadataSaveFailed = 'UPLOAD_METADATA_SAVE_FAILED';
  static const String timelineSyncFailed = 'TIMELINE_SYNC_FAILED';

  // Conflict
  static const String timelineUnresolvedConflict =
      'TIMELINE_UNRESOLVED_CONFLICT';
  static const String scheduleOverlapDecisionNeeded =
      'SCHEDULE_OVERLAP_DECISION_NEEDED';

  // Recovery Required
  static const String recoverySchemaUnsupported = 'RECOVERY_SCHEMA_UNSUPPORTED';
  static const String recoveryOwnerMismatch = 'RECOVERY_OWNER_MISMATCH';
  static const String recoveryMissingCurrentRun =
      'RECOVERY_MISSING_CURRENT_RUN';
  static const String recoveryDanglingRunReference =
      'RECOVERY_DANGLING_RUN_REFERENCE';
  static const String recoveryDurableStateConflict =
      'RECOVERY_DURABLE_STATE_CONFLICT';
  static const String recoveryInvalidCompletionBundle =
      'RECOVERY_INVALID_COMPLETION_BUNDLE';
  static const String recoveryCompletionFatal = 'RECOVERY_COMPLETION_FATAL';
  static const String recoveryCorruptDraft = 'RECOVERY_CORRUPT_DRAFT';

  // Completion Retry
  static const String completionVerifyFailed = 'COMPLETION_VERIFY_FAILED';
  static const String completionRoutineAccountingFailed =
      'COMPLETION_ROUTINE_ACCOUNTING_FAILED';
  static const String completionHabitReadbackFailed =
      'COMPLETION_HABIT_READBACK_FAILED';
  static const String completionTerminalizationPending =
      'COMPLETION_TERMINALIZATION_PENDING';
  static const String completionResumeRequired = 'COMPLETION_RESUME_REQUIRED';
}
