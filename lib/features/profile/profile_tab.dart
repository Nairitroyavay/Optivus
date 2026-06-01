import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/widgets/liquid_settings_row.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/profile/screens/logout_dialog.dart'
    show showLogoutDialog;
import 'package:optivus/features/profile/screens/profile_control_screens.dart';
import 'package:optivus/features/profile/screens/region_localization_screen.dart';
import 'package:optivus/features/profile/widgets/profile_header_card.dart';
import 'package:optivus/features/profile/widgets/profile_setting_group.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  ProfileDetailTarget _activeDetail = ProfileDetailTarget.none;

  void _openDetail(ProfileDetailTarget target) {
    setState(() => _activeDetail = target);
  }

  void _closeDetail() {
    setState(() => _activeDetail = ProfileDetailTarget.none);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileDetailViewRequestProvider, (previous, next) {
      if (next.view == ProfileDetailView.none) return;
      _openDetail(next);
      ref.read(profileDetailViewRequestProvider.notifier).state =
          ProfileDetailTarget.none;
    });

    final pending = ref.watch(profileDetailViewRequestProvider);
    if (pending.view != ProfileDetailView.none &&
        _activeDetail.view != pending.view) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openDetail(pending);
        ref.read(profileDetailViewRequestProvider.notifier).state =
            ProfileDetailTarget.none;
      });
    }

    return PopScope(
      canPop: _activeDetail.view == ProfileDetailView.none,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeDetail.view != ProfileDetailView.none) {
          _closeDetail();
        }
      },
      child: _activeDetail.view == ProfileDetailView.none
          ? _ProfileMainScreen(onOpenDetail: _openDetail)
          : _buildDetailScreen(),
    );
  }

  Widget _buildDetailScreen() {
    return switch (_activeDetail.view) {
      ProfileDetailView.editProfile => EditProfileScreen(onBack: _closeDetail),
      ProfileDetailView.systemSetup => SystemSetupScreen(
        onBack: _closeDetail,
        onOpenProfileDetail: _openDetail,
      ),
      ProfileDetailView.notificationSettings => NotificationSettingsScreen(
        onBack: _closeDetail,
      ),
      ProfileDetailView.permissionsDataSources => PermissionsDataSourcesScreen(
        onBack: _closeDetail,
        onOpenProfileDetail: _openDetail,
      ),
      ProfileDetailView.permissionDetail => PermissionDetailScreen(
        onBack: _closeDetail,
        permissionType:
            _activeDetail.permissionType ?? ProfilePermissionType.usageAccess,
      ),
      ProfileDetailView.connectedServices => ConnectedServicesScreen(
        onBack: _closeDetail,
        onOpenProfileDetail: _openDetail,
      ),
      ProfileDetailView.connectedServiceDetail => ConnectedServiceDetailScreen(
        onBack: _closeDetail,
        serviceType:
            _activeDetail.serviceType ?? ConnectedServiceType.cloudflareR2,
      ),
      ProfileDetailView.appPreferences => AppPreferencesScreen(
        onBack: _closeDetail,
        onOpenProfileDetail: _openDetail,
      ),
      ProfileDetailView.privacySecurity => PrivacySecurityScreen(
        onBack: _closeDetail,
      ),
      ProfileDetailView.dataControl => DataControlScreen(
        onBack: _closeDetail,
        onOpenProfileDetail: _openDetail,
      ),
      ProfileDetailView.exportData => ExportDataScreen(onBack: _closeDetail),
      ProfileDetailView.deleteSelectedData => DeleteSelectedDataScreen(
        onBack: _closeDetail,
      ),
      ProfileDetailView.deleteAccountRequest => DeleteAccountRequestScreen(
        onBack: _closeDetail,
        onOpenProfileDetail: _openDetail,
      ),
      ProfileDetailView.archivedIdentities => ArchivedIdentitiesScreen(
        onBack: _closeDetail,
      ),
      ProfileDetailView.reportBug => ReportBugScreen(onBack: _closeDetail),
      ProfileDetailView.helpCenter => HelpCenterScreen(onBack: _closeDetail),
      ProfileDetailView.aboutVersion => AboutVersionScreen(
        onBack: _closeDetail,
      ),
      ProfileDetailView.regionLocalization => RegionLocalizationScreen(
        onBack: _closeDetail,
      ),
      ProfileDetailView.none => _ProfileMainScreen(onOpenDetail: _openDetail),
    };
  }
}

class _ProfileMainScreen extends ConsumerWidget {
  final OpenProfileDetail onOpenDetail;

  const _ProfileMainScreen({required this.onOpenDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);
    final settings = ref.watch(profileSettingsProvider);
    final auth = ref.watch(authProvider);
    final region = ref.watch(regionSettingsProvider);
    final routineItems = ref.watch(mockRoutineProvider);
    final bottomReserve = liquidTabBarReserve(context) + 16;
    final displayName = settings.profile.name.trim().isNotEmpty
        ? settings.profile.name.trim()
        : profile.displayName;
    final usernameLabel = settings.profile.username.trim().isEmpty
        ? null
        : '@${settings.profile.username.trim()}';
    final emailLabel = _accountEmail(auth.user?.email, profile.email);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your Life OS control center',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: OptivusColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: OptivusColors.textPrimary,
                    ),
                    onPressed: () => onOpenDetail(
                      const ProfileDetailTarget(
                        view: ProfileDetailView.appPreferences,
                      ),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomReserve),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileHeaderCard(
                      profile: profile.copyWith(displayName: displayName),
                      usernameLabel: usernameLabel,
                      onEditTap: () => onOpenDetail(
                        const ProfileDetailTarget(
                          view: ProfileDetailView.editProfile,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSystemSetupGroup(
                      profile: profile,
                      baseTimelineReady: routineItems.isNotEmpty,
                    ),
                    _buildAccountGroup(settings, emailLabel),
                    _buildPermissionsGroup(settings),
                    _buildServicesGroup(settings),
                    _buildPreferencesGroup(settings, region),
                    _buildPrivacyGroup(settings),
                    _buildDataControlGroup(),
                    _buildSupportGroup(),
                    const SizedBox(height: 16),
                    LiquidGlassPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          LiquidSettingsRow(
                            icon: Icons.logout,
                            title: 'Log out',
                            iconColor: OptivusColors.textSecondary,
                            onTap: () => showLogoutDialog(context, () async {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/');
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSetupGroup({
    required UserProfile profile,
    required bool baseTimelineReady,
  }) {
    return ProfileSettingGroup(
      title: 'System Setup',
      children: [
        LiquidSettingsRow(
          icon: Icons.tune_rounded,
          title: 'System Setup',
          subtitle: _systemSetupSummary(profile, baseTimelineReady),
          iconColor: OptivusColors.profileAccent,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.systemSetup),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountGroup(ProfileSettingsState settings, String emailLabel) {
    return ProfileSettingGroup(
      title: 'Account',
      children: [
        LiquidSettingsRow(
          icon: Icons.email_outlined,
          title: 'Email',
          subtitle: emailLabel,
          iconColor: OptivusColors.textPrimary,
        ),
        LiquidSettingsRow(
          icon: Icons.archive_outlined,
          title: 'Archived Identities',
          subtitle: '${settings.archivedIdentities.length} archived',
          iconColor: OptivusColors.textSecondary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.archivedIdentities,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsGroup(ProfileSettingsState settings) {
    final connected = settings.permissions
        .where(
          (permission) =>
              permission.status == ProfileConnectionStatus.connected,
        )
        .length;
    final needsReview = settings.permissions.length - connected;
    return ProfileSettingGroup(
      title: 'Permissions & Data Sources',
      children: [
        LiquidSettingsRow(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Permissions & Data Sources',
          subtitle:
              '$connected connected · $needsReview need review · last known status',
          iconColor: OptivusColors.info,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.permissionsDataSources,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesGroup(ProfileSettingsState settings) {
    final connected = settings.services
        .where((service) => service.status == ProfileConnectionStatus.connected)
        .length;
    final notConfigured = settings.services
        .where(
          (service) => service.status == ProfileConnectionStatus.notConfigured,
        )
        .length;
    return ProfileSettingGroup(
      title: 'Connected Services',
      children: [
        LiquidSettingsRow(
          icon: Icons.hub_outlined,
          title: 'Connected Services',
          subtitle:
              '$connected connected · $notConfigured not configured · service status',
          iconColor: notConfigured > 0
              ? OptivusColors.warning
              : OptivusColors.success,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.connectedServices,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesGroup(
    ProfileSettingsState settings,
    RegionSettings region,
  ) {
    return ProfileSettingGroup(
      title: 'App Preferences',
      children: [
        LiquidSettingsRow(
          icon: Icons.settings_suggest_outlined,
          title: 'App Preferences',
          subtitle:
              '${settings.preferences.themeMode} theme · ${_languageName(region.languageCode)} · ${settings.preferences.haptics ? 'Haptics on' : 'Haptics off'}',
          iconColor: OptivusColors.profileAccent,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.public_rounded,
          title: 'Region & Localization',
          subtitle:
              '${region.countryName} · ${region.currencyCode} · ${region.heightWeightLabel}',
          iconColor: OptivusColors.info,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.regionLocalization,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyGroup(ProfileSettingsState settings) {
    return ProfileSettingGroup(
      title: 'Privacy & Security',
      children: [
        LiquidSettingsRow(
          icon: Icons.security,
          title: 'Privacy & Security',
          subtitle:
              '${settings.privacy.hideMindPreviews ? 'Mind previews hidden' : 'Mind previews visible'} · ${settings.privacy.screenTimePrivacyMode}',
          iconColor: OptivusColors.profileAccent,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.privacySecurity),
          ),
        ),
      ],
    );
  }

  Widget _buildDataControlGroup() {
    return ProfileSettingGroup(
      title: 'Data Control',
      children: [
        LiquidSettingsRow(
          icon: Icons.storage_outlined,
          title: 'Data Control',
          subtitle: 'Export, delete selected data, account deletion request',
          iconColor: OptivusColors.danger,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.dataControl),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportGroup() {
    return ProfileSettingGroup(
      title: 'Support & About',
      children: [
        LiquidSettingsRow(
          icon: Icons.bug_report_outlined,
          title: 'Report Bug',
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.reportBug),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.help_outline,
          title: 'Help Center',
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.helpCenter),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.info_outline,
          title: 'Version',
          subtitle: 'Optivus v1.0.0 · Build 1 · internal testing',
          iconColor: OptivusColors.textMuted,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.aboutVersion),
          ),
        ),
      ],
    );
  }
}

String _accountEmail(String? authEmail, String profileEmail) {
  final email = authEmail?.trim().isNotEmpty == true
      ? authEmail!.trim()
      : profileEmail.trim();
  return email.isEmpty ? 'Signed in' : email;
}

String _systemSetupSummary(UserProfile profile, bool baseTimelineReady) {
  final status = profile.onboardingCompleted ? 'Completed' : 'Not completed';
  final role = _roleLabel(profile);
  final timeline = baseTimelineReady
      ? 'Base timeline ready'
      : 'Base timeline not set';
  return '$status · $role · $timeline';
}

String _roleLabel(UserProfile profile) {
  final parts = <String>[
    if (profile.lifeRole.trim().isNotEmpty) profile.lifeRole.trim(),
    if (profile.workingExtra?.trim().isNotEmpty == true)
      profile.workingExtra!.trim(),
    if (profile.businessMode?.trim().isNotEmpty == true)
      profile.businessMode!.trim(),
  ];
  return parts.isEmpty ? 'Setup summary' : parts.join(' + ');
}

String _languageName(String code) {
  return switch (code.toLowerCase()) {
    'en' => 'English',
    'hi' => 'Hindi',
    'bn' => 'Bengali',
    'ja' => 'Japanese',
    'de' => 'German',
    'es' => 'Spanish',
    'fr' => 'French',
    'ko' => 'Korean',
    'zh' => 'Chinese',
    _ => code.toUpperCase(),
  };
}
