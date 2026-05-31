import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_settings_row.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/profile/providers/profile_mock_data.dart';
import 'package:optivus/features/profile/screens/logout_dialog.dart'
    show showLogoutDialog;
import 'package:optivus/features/profile/screens/profile_control_screens.dart';
import 'package:optivus/features/profile/widgets/profile_components.dart';
import 'package:optivus/features/profile/widgets/profile_header_card.dart';
import 'package:optivus/features/profile/widgets/profile_setting_group.dart';
import 'package:optivus/features/profile/widgets/profile_status_chip.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
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
    final identityStatement = ref.watch(mockIdentityStatementProvider);
    final focusAreas = ref.watch(mockFocusAreasProvider);
    final habitsToBreak = ref.watch(mockHabitsToBreakProvider);
    final settings = ref.watch(profileSettingsProvider);

    final media = MediaQuery.of(context);
    final bottomReserve =
        76.0 + media.padding.bottom + media.viewInsets.bottom + 48.0;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile',
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
                      profile: profile.copyWith(
                        displayName: settings.profile.name,
                      ),
                      onEditTap: () => onOpenDetail(
                        const ProfileDetailTarget(
                          view: ProfileDetailView.editProfile,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ProfileIdentityCard(
                      identityStatement: identityStatement,
                      onTap: () =>
                          ref.read(appNavigationProvider.notifier).goToGoals(),
                    ),
                    const SizedBox(height: 24),
                    ProfileChipsCard(
                      title: 'Focus Areas',
                      items: focusAreas,
                      emptyMessage: 'No focus areas selected.',
                      actionButtonText: 'Open Goals',
                      onActionTap: () =>
                          ref.read(appNavigationProvider.notifier).goToGoals(),
                      accentColor: OptivusColors.profileAccent,
                    ),
                    const SizedBox(height: 24),
                    ProfileChipsCard(
                      title: 'Habits to Break',
                      items: habitsToBreak,
                      emptyMessage: 'No habits selected.',
                      actionButtonText: 'Open Routine',
                      onActionTap: () => ref
                          .read(appNavigationProvider.notifier)
                          .goToRoutine(),
                      accentColor: OptivusColors.danger,
                    ),
                    const SizedBox(height: 24),
                    _buildSystemSetupGroup(ref),
                    _buildAccountGroup(settings),
                    _buildPermissionsGroup(settings),
                    _buildServicesGroup(settings),
                    _buildPreferencesGroup(settings),
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
                    GestureDetector(
                      onTap: () => onOpenDetail(
                        const ProfileDetailTarget(
                          view: ProfileDetailView.deleteAccountRequest,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: OptivusColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: OptivusColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: OptivusColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSetupGroup(WidgetRef ref) {
    return ProfileSettingGroup(
      title: 'System Setup',
      children: [
        LiquidSettingsRow(
          icon: Icons.check_circle_outline,
          title: 'Onboarding Setup',
          iconColor: OptivusColors.success,
          trailing: const ProfileStatusChip(
            label: 'Completed',
            type: ProfileStatusType.success,
          ),
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.systemSetup),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.work_outline,
          title: 'Life Role & Lifestyle',
          subtitle: 'Student + Working',
          iconColor: OptivusColors.info,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.systemSetup),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.monitor_weight_outlined,
          title: 'Body Basics',
          subtitle: '52 kg · 5\'9"',
          iconColor: OptivusColors.roseAccent,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.systemSetup),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.schedule,
          title: 'Base Timeline',
          subtitle: 'Classes + Eating + Fixed',
          iconColor: OptivusColors.purpleAccent,
          onTap: () {
            ref.read(appNavigationProvider.notifier).goToRoutine();
            ref
                .read(routineDetailViewRequestProvider.notifier)
                .state = const RoutineDetailTarget(
              view: RoutineDetailView.baseTimelineManager,
            );
          },
        ),
        LiquidSettingsRow(
          icon: Icons.flag_outlined,
          title: 'Goals Setup',
          subtitle: '3 active goals',
          iconColor: OptivusColors.profileAccent,
          onTap: () => ref.read(appNavigationProvider.notifier).goToGoals(),
        ),
        LiquidSettingsRow(
          icon: Icons.psychology_outlined,
          title: 'Coach Setup',
          subtitle: 'Sensei · Direct but kind',
          iconColor: OptivusColors.mintAccent,
          onTap: () => ref.read(appNavigationProvider.notifier).goToCoach(),
        ),
        LiquidSettingsRow(
          icon: Icons.refresh,
          title: 'Reset / Re-run Setup',
          iconColor: OptivusColors.textSecondary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.systemSetup),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountGroup(ProfileSettingsState settings) {
    return ProfileSettingGroup(
      title: 'Account',
      children: [
        const LiquidSettingsRow(
          icon: Icons.email_outlined,
          title: 'Email',
          subtitle: 'roy@optivus.app',
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
        LiquidSettingsRow(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
          subtitle: settings.notifications.intensity,
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.notificationSettings,
            ),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.download_outlined,
          title: 'Export Account Data',
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.exportData),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsGroup(ProfileSettingsState settings) {
    return ProfileSettingGroup(
      title: 'Permissions & Data Sources',
      children: settings.permissions.map((permission) {
        return LiquidSettingsRow(
          icon: _permissionIcon(permission.type),
          title: permission.type.label,
          iconColor: _statusColor(permission.status),
          trailing: ProfileStatusChip(
            label: permission.status.label,
            type: _statusType(permission.status),
          ),
          onTap: () => onOpenDetail(
            ProfileDetailTarget(
              view: ProfileDetailView.permissionDetail,
              permissionType: permission.type,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicesGroup(ProfileSettingsState settings) {
    return ProfileSettingGroup(
      title: 'Connected Services',
      children: settings.services.map((service) {
        return LiquidSettingsRow(
          icon: _serviceIcon(service.type),
          title: service.type.label,
          subtitle: service.type == ConnectedServiceType.cloudflareR2
              ? 'No Firebase Storage'
              : service.type == ConnectedServiceType.cloudflareWorkers
              ? 'No Firebase Functions'
              : null,
          iconColor: _statusColor(service.status),
          trailing: ProfileStatusChip(
            label: service.status.label,
            type: _statusType(service.status),
          ),
          onTap: () => onOpenDetail(
            ProfileDetailTarget(
              view: ProfileDetailView.connectedServiceDetail,
              serviceType: service.type,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreferencesGroup(ProfileSettingsState settings) {
    return ProfileSettingGroup(
      title: 'App Preferences',
      children: [
        LiquidSettingsRow(
          icon: Icons.vibration,
          title: 'Haptic Feedback',
          iconColor: OptivusColors.textPrimary,
          trailing: Switch(
            value: settings.preferences.haptics,
            activeThumbColor: OptivusColors.profileAccent,
            onChanged: (_) => onOpenDetail(
              const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
            ),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.spellcheck,
          title: 'Correct Spelling',
          iconColor: OptivusColors.textPrimary,
          trailing: Switch(
            value: settings.preferences.autoCorrect,
            activeThumbColor: OptivusColors.profileAccent,
            onChanged: (_) => onOpenDetail(
              const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
            ),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.palette_outlined,
          title: 'Theme',
          subtitle: settings.preferences.themeMode,
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.format_paint_outlined,
          title: 'Accent Color',
          subtitle: settings.preferences.accentColor,
          iconColor: OptivusColors.profileAccent,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.settings_suggest_outlined,
          title: 'Routine Settings',
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.language,
          title: 'Language',
          subtitle: settings.preferences.language,
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.appPreferences),
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
          title: 'Security',
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.privacySecurity),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.lock_outline,
          title: 'Mind Notebook Privacy',
          subtitle: settings.privacy.hideMindPreviews
              ? 'Private'
              : 'Visible previews',
          iconColor: OptivusColors.success,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.privacySecurity),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.psychology,
          title: 'Coach Context Access',
          subtitle: 'Selected notes only',
          iconColor: OptivusColors.warning,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.privacySecurity),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.visibility_off_outlined,
          title: 'Screen Time Privacy',
          subtitle: settings.privacy.screenTimePrivacyMode,
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.privacySecurity),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Data Privacy',
          iconColor: OptivusColors.textPrimary,
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
          icon: Icons.download_outlined,
          title: 'Export Data',
          iconColor: OptivusColors.textPrimary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.exportData),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.delete_sweep_outlined,
          title: 'Delete Selected Data',
          iconColor: OptivusColors.danger,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.deleteSelectedData,
            ),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.person_remove_outlined,
          title: 'Delete Account Request',
          iconColor: OptivusColors.danger,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.deleteAccountRequest,
            ),
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
          icon: Icons.description_outlined,
          title: 'Terms of Use',
          iconColor: OptivusColors.textSecondary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.helpCenter),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          iconColor: OptivusColors.textSecondary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(view: ProfileDetailView.helpCenter),
          ),
        ),
        LiquidSettingsRow(
          icon: Icons.auto_delete_outlined,
          title: 'Delete Account Instructions',
          iconColor: OptivusColors.textSecondary,
          onTap: () => onOpenDetail(
            const ProfileDetailTarget(
              view: ProfileDetailView.deleteAccountRequest,
            ),
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

Color _statusColor(ProfileConnectionStatus status) {
  return switch (status) {
    ProfileConnectionStatus.connected => OptivusColors.success,
    ProfileConnectionStatus.notConnected => OptivusColors.textSecondary,
    ProfileConnectionStatus.notConfigured => OptivusColors.warning,
    ProfileConnectionStatus.error => OptivusColors.danger,
  };
}

ProfileStatusType _statusType(ProfileConnectionStatus status) {
  return switch (status) {
    ProfileConnectionStatus.connected => ProfileStatusType.success,
    ProfileConnectionStatus.notConnected => ProfileStatusType.muted,
    ProfileConnectionStatus.notConfigured => ProfileStatusType.warning,
    ProfileConnectionStatus.error => ProfileStatusType.danger,
  };
}

IconData _permissionIcon(ProfilePermissionType type) {
  return switch (type) {
    ProfilePermissionType.notifications => Icons.notifications_outlined,
    ProfilePermissionType.usageAccess => Icons.data_usage_rounded,
    ProfilePermissionType.location => Icons.location_on_outlined,
    ProfilePermissionType.healthConnect => Icons.monitor_heart_outlined,
    ProfilePermissionType.cameraPhotos => Icons.camera_alt_outlined,
    ProfilePermissionType.microphone => Icons.mic_none_rounded,
  };
}

IconData _serviceIcon(ConnectedServiceType type) {
  return switch (type) {
    ConnectedServiceType.cloudflareR2 => Icons.upload_file_rounded,
    ConnectedServiceType.mapbox => Icons.map_outlined,
    ConnectedServiceType.healthConnect => Icons.health_and_safety_outlined,
    ConnectedServiceType.androidUsageAccess => Icons.phone_android_rounded,
    ConnectedServiceType.cloudflareWorkers => Icons.cloud_outlined,
  };
}
