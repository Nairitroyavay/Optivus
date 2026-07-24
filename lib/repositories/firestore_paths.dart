class FirestoreUserPaths {
  const FirestoreUserPaths._();

  static String user(String uid) => 'users/$uid';

  static String profile(String uid) => 'users/$uid/profile/main';

  static String regionSettings(String uid) {
    return 'users/$uid/settings/regionLocalization';
  }

  static String appPreferences(String uid) {
    return 'users/$uid/settings/appPreferences';
  }

  static String permissionStatus(String uid) {
    return 'users/$uid/settings/permissionStatus';
  }

  static String connectedServices(String uid) {
    return 'users/$uid/settings/connectedServices';
  }

  static String dataControl(String uid) {
    return 'users/$uid/settings/dataControl';
  }

  static String onboardingDraft(String uid) => 'users/$uid/onboarding/draft';

  static String onboardingCompletionBundle(String uid) {
    return 'users/$uid/onboarding/completionBundle';
  }

  static String uploadedAsset(String uid, String assetId) {
    return 'users/$uid/uploads/$assetId';
  }

  static String uploadedAssets(String uid) {
    return 'users/$uid/uploads';
  }

  static String routineImportReviews(String uid) {
    return 'users/$uid/routineImportReviews';
  }

  static String routineImportReview(String uid, String reviewId) {
    return 'users/$uid/routineImportReviews/$reviewId';
  }

  static String onboardingSetupVersion(String uid, int version) {
    return 'users/$uid/onboarding/setupVersions/$version';
  }

  static String routineItem(String uid, String itemId) {
    return 'users/$uid/routineItems/$itemId';
  }

  static String routineItems(String uid) {
    return 'users/$uid/routineItems';
  }

  static String routineHistoryEvent(String uid, String eventId) {
    return 'users/$uid/routineHistory/$eventId';
  }

  static String routineHistory(String uid) {
    return 'users/$uid/routineHistory';
  }

  static String routineEvent(String uid, String eventId) {
    return 'users/$uid/routineEvents/$eventId';
  }

  static String routineEvents(String uid) {
    return 'users/$uid/routineEvents';
  }

  static String routineProjection(String uid, String projectionId) {
    return 'users/$uid/routineProjections/$projectionId';
  }

  static String routineProjections(String uid) {
    return 'users/$uid/routineProjections';
  }

  static String habitSystem(String uid, String systemId) {
    return 'users/$uid/habitSystems/$systemId';
  }

  static String goal(String uid, String goalId) {
    return 'users/$uid/goals/$goalId';
  }

  static String habitTemplate(String uid, String habitId) {
    return 'users/$uid/habitTemplates/$habitId';
  }

  static String badHabitCheckIn(String uid, String habitId) {
    return 'users/$uid/badHabitCheckins/$habitId';
  }

  static String trackerConfig(String uid) {
    return 'users/$uid/tracker/config';
  }

  static String trackerHistoryEvent(String uid, String eventId) {
    return 'users/$uid/trackerHistory/$eventId';
  }

  static String moneyGoal(String uid, String goalId) {
    return 'users/$uid/money/goals/$goalId';
  }

  static String savingEntry(String uid, String entryId) {
    return 'users/$uid/money/savingEntries/$entryId';
  }

  static String focusSession(String uid, String sessionId) {
    return 'users/$uid/focusSessions/$sessionId';
  }

  static String sleepLog(String uid, String logId) {
    return 'users/$uid/sleepLogs/$logId';
  }

  static String nutritionLog(String uid, String logId) {
    return 'users/$uid/nutritionLogs/$logId';
  }

  static String fitnessSession(String uid, String sessionId) {
    return 'users/$uid/fitnessSessions/$sessionId';
  }

  static String homeDashboard(String uid) {
    return 'users/$uid/home/dashboard';
  }

  static String mindNote(String uid, String noteId) {
    return 'users/$uid/mindNotes/$noteId';
  }

  static String coachSession(String uid, String sessionId) {
    return 'users/$uid/coach/sessions/$sessionId';
  }

  static String coachPreferences(String uid) {
    return 'users/$uid/coach/preferences/main';
  }

  static String notificationPreferences(String uid) {
    return 'users/$uid/notifications/preferences/main';
  }
}
