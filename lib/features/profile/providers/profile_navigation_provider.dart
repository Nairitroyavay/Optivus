import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';

enum ProfileDetailView {
  none,
  editProfile,
  systemSetup,
  notificationSettings,
  permissionsDataSources,
  permissionDetail,
  connectedServices,
  connectedServiceDetail,
  appPreferences,
  privacySecurity,
  dataControl,
  exportData,
  deleteSelectedData,
  deleteAccountRequest,
  archivedIdentities,
  reportBug,
  helpCenter,
  aboutVersion,
}

class ProfileDetailTarget {
  final ProfileDetailView view;
  final ProfilePermissionType? permissionType;
  final ConnectedServiceType? serviceType;

  const ProfileDetailTarget({
    required this.view,
    this.permissionType,
    this.serviceType,
  });

  static const none = ProfileDetailTarget(view: ProfileDetailView.none);
}

final profileDetailViewRequestProvider = StateProvider<ProfileDetailTarget>(
  (ref) => ProfileDetailTarget.none,
);
