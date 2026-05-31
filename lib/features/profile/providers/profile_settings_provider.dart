import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';

class ProfileSettingsState {
  final UserProfileSettings profile;
  final NotificationSettingsModel notifications;
  final UserPreferences preferences;
  final PrivacySettings privacy;
  final List<PermissionStatusModel> permissions;
  final List<ConnectedServiceStatusModel> services;
  final DataExportRequestModel? exportRequest;
  final DeletionRequestModel deletionRequest;
  final Set<String> selectedDeleteScopes;
  final List<String> archivedIdentities;
  final List<String> bugReports;

  const ProfileSettingsState({
    required this.profile,
    required this.notifications,
    required this.preferences,
    required this.privacy,
    required this.permissions,
    required this.services,
    this.exportRequest,
    required this.deletionRequest,
    required this.selectedDeleteScopes,
    required this.archivedIdentities,
    required this.bugReports,
  });

  factory ProfileSettingsState.defaults() {
    return ProfileSettingsState(
      profile: const UserProfileSettings(),
      notifications: NotificationSettingsModel.defaults(),
      preferences: const UserPreferences(),
      privacy: const PrivacySettings(),
      permissions: const [
        PermissionStatusModel(
          type: ProfilePermissionType.notifications,
          status: ProfileConnectionStatus.connected,
          lastChecked: 'Today',
        ),
        PermissionStatusModel(
          type: ProfilePermissionType.usageAccess,
          status: ProfileConnectionStatus.notConnected,
          lastChecked: 'Not checked',
        ),
        PermissionStatusModel(
          type: ProfilePermissionType.location,
          status: ProfileConnectionStatus.connected,
          lastChecked: 'Today',
        ),
        PermissionStatusModel(
          type: ProfilePermissionType.healthConnect,
          status: ProfileConnectionStatus.notConnected,
          lastChecked: 'Not checked',
        ),
        PermissionStatusModel(
          type: ProfilePermissionType.cameraPhotos,
          status: ProfileConnectionStatus.notConnected,
          lastChecked: 'Not checked',
        ),
        PermissionStatusModel(
          type: ProfilePermissionType.microphone,
          status: ProfileConnectionStatus.notConnected,
          lastChecked: 'Not checked',
        ),
      ],
      services: const [
        ConnectedServiceStatusModel(
          type: ConnectedServiceType.cloudflareR2,
          status: ProfileConnectionStatus.connected,
          lastChecked: 'Today',
        ),
        ConnectedServiceStatusModel(
          type: ConnectedServiceType.mapbox,
          status: ProfileConnectionStatus.connected,
          lastChecked: 'Today',
          selectedStyle: 'Optivus route style',
        ),
        ConnectedServiceStatusModel(
          type: ConnectedServiceType.healthConnect,
          status: ProfileConnectionStatus.notConnected,
          lastChecked: 'Not checked',
        ),
        ConnectedServiceStatusModel(
          type: ConnectedServiceType.androidUsageAccess,
          status: ProfileConnectionStatus.notConnected,
          lastChecked: 'Not checked',
        ),
        ConnectedServiceStatusModel(
          type: ConnectedServiceType.cloudflareWorkers,
          status: ProfileConnectionStatus.connected,
          lastChecked: 'Today',
        ),
      ],
      deletionRequest: const DeletionRequestModel(),
      selectedDeleteScopes: const <String>{},
      archivedIdentities: const [
        'Focused Student with stable study systems',
        'Early Fitness Reset identity',
      ],
      bugReports: const [],
    );
  }

  ProfileSettingsState copyWith({
    UserProfileSettings? profile,
    NotificationSettingsModel? notifications,
    UserPreferences? preferences,
    PrivacySettings? privacy,
    List<PermissionStatusModel>? permissions,
    List<ConnectedServiceStatusModel>? services,
    DataExportRequestModel? exportRequest,
    bool clearExportRequest = false,
    DeletionRequestModel? deletionRequest,
    Set<String>? selectedDeleteScopes,
    List<String>? archivedIdentities,
    List<String>? bugReports,
  }) {
    return ProfileSettingsState(
      profile: profile ?? this.profile,
      notifications: notifications ?? this.notifications,
      preferences: preferences ?? this.preferences,
      privacy: privacy ?? this.privacy,
      permissions: permissions ?? this.permissions,
      services: services ?? this.services,
      exportRequest: clearExportRequest
          ? null
          : (exportRequest ?? this.exportRequest),
      deletionRequest: deletionRequest ?? this.deletionRequest,
      selectedDeleteScopes: selectedDeleteScopes ?? this.selectedDeleteScopes,
      archivedIdentities: archivedIdentities ?? this.archivedIdentities,
      bugReports: bugReports ?? this.bugReports,
    );
  }
}

class ProfileSettingsNotifier extends StateNotifier<ProfileSettingsState> {
  ProfileSettingsNotifier() : super(ProfileSettingsState.defaults());

  void updateProfile(UserProfileSettings profile) {
    state = state.copyWith(profile: profile);
  }

  void setProfilePhotoState(String photoState) {
    state = state.copyWith(
      profile: state.profile.copyWith(photoState: photoState),
    );
  }

  void toggleReminderType(String label) {
    final updated = Map<String, bool>.from(state.notifications.reminderTypes);
    updated[label] = !(updated[label] ?? false);
    state = state.copyWith(
      notifications: state.notifications.copyWith(reminderTypes: updated),
    );
  }

  void setReminderIntensity(String intensity) {
    state = state.copyWith(
      notifications: state.notifications.copyWith(intensity: intensity),
    );
  }

  void setQuietHours({
    bool? quietAfter11,
    bool? quietDuringHardBlocks,
    bool? quietDuringSleep,
  }) {
    state = state.copyWith(
      notifications: state.notifications.copyWith(
        quietAfter11: quietAfter11,
        quietDuringHardBlocks: quietDuringHardBlocks,
        quietDuringSleep: quietDuringSleep,
      ),
    );
  }

  void togglePermission(ProfilePermissionType type) {
    state = state.copyWith(
      permissions: [
        for (final permission in state.permissions)
          if (permission.type == type)
            permission.copyWith(
              status: permission.status == ProfileConnectionStatus.connected
                  ? ProfileConnectionStatus.notConnected
                  : ProfileConnectionStatus.connected,
              lastChecked: 'Just now',
            )
          else
            permission,
      ],
    );
  }

  void recheckService(ConnectedServiceType type) {
    state = state.copyWith(
      services: [
        for (final service in state.services)
          if (service.type == type)
            service.copyWith(lastChecked: 'Just now')
          else
            service,
      ],
    );
  }

  void updatePreferences(UserPreferences preferences) {
    state = state.copyWith(preferences: preferences);
  }

  void updatePrivacy(PrivacySettings privacy) {
    state = state.copyWith(privacy: privacy);
  }

  void createExportRequest(Set<String> scopes, String format) {
    if (scopes.isEmpty) return;
    final now = DateTime.now();
    state = state.copyWith(
      exportRequest: DataExportRequestModel(
        id: 'export-${now.millisecondsSinceEpoch}',
        scopes: scopes,
        format: format,
        status: DataExportStatus.requested,
        requestedAt: now,
      ),
    );
  }

  void setExportStatus(DataExportStatus status) {
    final current = state.exportRequest;
    if (current == null) return;
    state = state.copyWith(
      exportRequest: current.copyWith(
        status: status,
        expiresAt: status == DataExportStatus.ready
            ? DateTime.now().add(const Duration(days: 7))
            : null,
      ),
    );
  }

  void toggleDeleteScope(String scope) {
    final scopes = Set<String>.from(state.selectedDeleteScopes);
    if (scopes.contains(scope)) {
      scopes.remove(scope);
    } else {
      scopes.add(scope);
    }
    state = state.copyWith(selectedDeleteScopes: scopes);
  }

  void clearSelectedDeleteScopes() {
    state = state.copyWith(selectedDeleteScopes: const <String>{});
  }

  void createDeletionRequest() {
    final now = DateTime.now();
    state = state.copyWith(
      deletionRequest: DeletionRequestModel(
        pending: true,
        requestedAt: now,
        cancellationDeadline: now.add(const Duration(days: 7)),
      ),
    );
  }

  void cancelDeletionRequest() {
    state = state.copyWith(deletionRequest: const DeletionRequestModel());
  }

  void submitBugReport(String title) {
    if (title.trim().isEmpty) return;
    state = state.copyWith(
      bugReports: ['${title.trim()} · submitted just now', ...state.bugReports],
    );
  }
}

final profileSettingsProvider =
    StateNotifierProvider<ProfileSettingsNotifier, ProfileSettingsState>((ref) {
      return ProfileSettingsNotifier();
    });
