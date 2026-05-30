import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/core/widgets/liquid_settings_row.dart';

import 'package:optivus/features/profile/widgets/profile_header_card.dart';
import 'package:optivus/features/profile/widgets/profile_setting_group.dart';
import 'package:optivus/features/profile/widgets/profile_status_chip.dart';
import 'package:optivus/features/profile/screens/profile_sub_screens.dart';
import 'package:optivus/features/profile/screens/placeholder_sheets.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/features/profile/widgets/profile_components.dart';
import 'package:optivus/features/profile/providers/profile_mock_data.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);
    final identityStatement = ref.watch(mockIdentityStatementProvider);
    final focusAreas = ref.watch(mockFocusAreasProvider);
    final habitsToBreak = ref.watch(mockHabitsToBreakProvider);

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
                    onPressed: () => showPlaceholderSheet(
                      context,
                      title: 'App Preferences',
                      message: 'Full settings screen coming soon.',
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
                    // 2. Profile Identity Card
                    ProfileHeaderCard(
                      profile: profile,
                      onEditTap: () => showEditProfileSheet(context, ref),
                    ),
                    const SizedBox(height: 24),

                    // 3. Identity Statement
                    ProfileIdentityCard(
                      identityStatement: identityStatement,
                      onTap: () {
                        showPlaceholderSheet(
                          context,
                          title: 'Identity Goals',
                          message:
                              'Identity logic is owned by Goals. This will open Identity Goals.',
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 4. Focus Areas
                    ProfileChipsCard(
                      title: 'Focus Areas',
                      items: focusAreas,
                      emptyMessage: 'No focus areas selected.',
                      actionButtonText: 'Add Focus Area',
                      onActionTap: () => showPlaceholderSheet(
                        context,
                        title: 'Add Focus Area',
                        message: 'Selector coming soon.',
                      ),
                      accentColor: OptivusColors.profileAccent,
                    ),
                    const SizedBox(height: 24),

                    // 5. Habits to Break
                    ProfileChipsCard(
                      title: 'Habits to Break',
                      items: habitsToBreak,
                      emptyMessage: 'No habits selected.',
                      actionButtonText: 'Add Habit to Break',
                      onActionTap: () => showPlaceholderSheet(
                        context,
                        title: 'Add Habit',
                        message: 'Selector coming soon.',
                      ),
                      accentColor: OptivusColors.danger,
                    ),
                    const SizedBox(height: 24),

                    // 6. System Setup
                    ProfileSettingGroup(
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
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'System Setup',
                            message: 'Opens full System Setup details screen.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.work_outline,
                          title: 'Life Role & Lifestyle',
                          subtitle: 'Student + Working',
                          iconColor: OptivusColors.info,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'System Setup',
                            message: 'Opens full System Setup details screen.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.monitor_weight_outlined,
                          title: 'Body Basics',
                          subtitle: '52 kg · 5\'9"',
                          iconColor: OptivusColors.roseAccent,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'System Setup',
                            message: 'Opens full System Setup details screen.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.schedule,
                          title: 'Base Timeline',
                          subtitle: 'Classes + Eating + Fixed',
                          iconColor: OptivusColors.purpleAccent,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'System Setup',
                            message: 'Opens full System Setup details screen.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.flag_outlined,
                          title: 'Goals Setup',
                          subtitle: '3 active goals',
                          iconColor: OptivusColors.profileAccent,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'System Setup',
                            message: 'Opens full System Setup details screen.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.psychology_outlined,
                          title: 'Coach Setup',
                          subtitle: 'Sensei · Direct but kind',
                          iconColor: OptivusColors.mintAccent,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'System Setup',
                            message: 'Opens full System Setup details screen.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.refresh,
                          title: 'Reset / Re-run Setup',
                          iconColor: OptivusColors.textSecondary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Re-run Setup',
                            message: 'Warning dialog to reset setup state.',
                          ),
                        ),
                      ],
                    ),

                    // 7. Account
                    ProfileSettingGroup(
                      title: 'Account',
                      children: [
                        const LiquidSettingsRow(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          subtitle: 'nairitgpt@gmail.com',
                          iconColor: OptivusColors.textPrimary,
                        ),
                        LiquidSettingsRow(
                          icon: Icons.archive_outlined,
                          title: 'Archived Identities',
                          iconColor: OptivusColors.textSecondary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Archived Identities',
                            message: 'List of past identities.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.notifications_active_outlined,
                          title: 'Notifications',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Notification Settings',
                            message:
                                'Detailed toggles for Morning Start, Weekly Review, Quiet Hours, etc.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.download_outlined,
                          title: 'Export Account Data',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Data Control',
                            message: 'Navigate to Export Data flow.',
                          ),
                        ),
                      ],
                    ),

                    // 8. Permissions & Data Sources
                    ProfileSettingGroup(
                      title: 'Permissions & Data Sources',
                      children: [
                        LiquidSettingsRow(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          iconColor: OptivusColors.textPrimary,
                          trailing: const ProfileStatusChip(
                            label: 'Connected',
                            type: ProfileStatusType.success,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Permission Detail',
                            message:
                                'Status, why needed, action button to Allow/Settings.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.data_usage,
                          title: 'Usage Access',
                          iconColor: OptivusColors.textPrimary,
                          trailing: const ProfileStatusChip(
                            label: 'Not connected',
                            type: ProfileStatusType.muted,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Permission Detail',
                            message:
                                'Status, why needed, action button to Allow/Settings.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.location_on_outlined,
                          title: 'Location',
                          iconColor: OptivusColors.textPrimary,
                          trailing: const ProfileStatusChip(
                            label: 'Connected',
                            type: ProfileStatusType.success,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Permission Detail',
                            message:
                                'Status, why needed, action button to Allow/Settings.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.monitor_heart_outlined,
                          title: 'Health Connect',
                          iconColor: OptivusColors.textPrimary,
                          trailing: const ProfileStatusChip(
                            label: 'Not connected',
                            type: ProfileStatusType.muted,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Permission Detail',
                            message:
                                'Status, why needed, action button to Allow/Settings.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.camera_alt_outlined,
                          title: 'Camera / Photos',
                          iconColor: OptivusColors.textPrimary,
                          trailing: const ProfileStatusChip(
                            label: 'Not connected',
                            type: ProfileStatusType.muted,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Permission Detail',
                            message:
                                'Status, why needed, action button to Allow/Settings.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.mic_none,
                          title: 'Microphone',
                          iconColor: OptivusColors.textPrimary,
                          trailing: const ProfileStatusChip(
                            label: 'Not connected',
                            type: ProfileStatusType.muted,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Permission Detail',
                            message:
                                'Status, why needed, action button to Allow/Settings.',
                          ),
                        ),
                      ],
                    ),

                    // 9. Connected Services
                    ProfileSettingGroup(
                      title: 'Connected Services',
                      children: [
                        LiquidSettingsRow(
                          icon: Icons.upload_file,
                          title: 'Cloudflare R2 Uploads',
                          iconColor: OptivusColors.info,
                          trailing: const ProfileStatusChip(
                            label: 'Connected',
                            type: ProfileStatusType.success,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Service Detail',
                            message:
                                'Status, what it powers (Profile photos/uploads), troubleshooting.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.map_outlined,
                          title: 'Mapbox',
                          iconColor: OptivusColors.brandAccent,
                          trailing: const ProfileStatusChip(
                            label: 'Connected',
                            type: ProfileStatusType.success,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Service Detail',
                            message:
                                'Status, what it powers (Walk/Run maps), troubleshooting.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Health Connect',
                          iconColor: OptivusColors.textSecondary,
                          trailing: const ProfileStatusChip(
                            label: 'Not connected',
                            type: ProfileStatusType.muted,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Service Detail',
                            message: 'Status, what it powers, troubleshooting.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.phone_android,
                          title: 'Android Usage Access',
                          iconColor: OptivusColors.textSecondary,
                          trailing: const ProfileStatusChip(
                            label: 'Not connected',
                            type: ProfileStatusType.muted,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Service Detail',
                            message: 'Status, what it powers, troubleshooting.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.cloud_outlined,
                          title: 'Cloudflare Workers',
                          iconColor: OptivusColors.info,
                          trailing: const ProfileStatusChip(
                            label: 'Connected',
                            type: ProfileStatusType.success,
                          ),
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Service Detail',
                            message:
                                'Status, what it powers (Coach AI, import), troubleshooting.',
                          ),
                        ),
                      ],
                    ),

                    // 10. App Preferences
                    ProfileSettingGroup(
                      title: 'App Preferences',
                      children: [
                        LiquidSettingsRow(
                          icon: Icons.vibration,
                          title: 'Haptic Feedback',
                          iconColor: OptivusColors.textPrimary,
                          trailing: Switch(
                            value: true,
                            onChanged: (val) {},
                            activeThumbColor: OptivusColors.profileAccent,
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.spellcheck,
                          title: 'Correct Spelling',
                          iconColor: OptivusColors.textPrimary,
                          trailing: Switch(
                            value: true,
                            onChanged: (val) {},
                            activeThumbColor: OptivusColors.profileAccent,
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.palette_outlined,
                          title: 'Theme',
                          subtitle: 'System',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Theme Selection',
                            message: 'System / Light / Dark',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.format_paint_outlined,
                          title: 'Accent Color',
                          subtitle: 'Yellow',
                          iconColor: OptivusColors.profileAccent,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Accent Color',
                            message: 'Select theme accent color.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.settings_suggest_outlined,
                          title: 'Routine Settings',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Routine Settings',
                            message:
                                'Timeline Display, Bottom Tab Layout, etc.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.language,
                          title: 'Language',
                          subtitle: 'English',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Language',
                            message: 'Language selector.',
                          ),
                        ),
                      ],
                    ),

                    // 11. Privacy & Security
                    ProfileSettingGroup(
                      title: 'Privacy & Security',
                      children: [
                        LiquidSettingsRow(
                          icon: Icons.security,
                          title: 'Security',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Privacy & Security',
                            message: 'Manage Security controls.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.lock_outline,
                          title: 'Mind Notebook Privacy',
                          subtitle: 'Private',
                          iconColor: OptivusColors.success,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Privacy & Security',
                            message: 'Manage Mind Notebook Privacy.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.psychology,
                          title: 'Coach Context Access',
                          subtitle: 'Limited',
                          iconColor: OptivusColors.warning,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Coach Context Controls',
                            message:
                                'Select what Coach can read: Routine, Tracker, Goal, Screen time, Money, Notes.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.visibility_off_outlined,
                          title: 'Screen Time Privacy',
                          subtitle: 'Show app names',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Privacy & Security',
                            message: 'Manage Screen Time Privacy.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Data Privacy',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Privacy & Security',
                            message: 'Manage Data Privacy.',
                          ),
                        ),
                      ],
                    ),

                    // 12. Data Control
                    ProfileSettingGroup(
                      title: 'Data Control',
                      children: [
                        LiquidSettingsRow(
                          icon: Icons.download_outlined,
                          title: 'Export Data',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Export Data',
                            message:
                                'Export: Profile, Onboarding, Routine, Goals, Trackers, Money, Coach, Mind, files.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.delete_sweep_outlined,
                          title: 'Delete Selected Data',
                          iconColor: OptivusColors.danger,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Delete Selected Data',
                            message:
                                'Delete: Notes, Coach sessions, Trackers, Routine history, files.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.person_remove_outlined,
                          title: 'Delete Account Request',
                          iconColor: OptivusColors.danger,
                          onTap: () => showDeleteAccountFlow(context),
                        ),
                      ],
                    ),

                    // 13. Support & About
                    ProfileSettingGroup(
                      title: 'Support & About',
                      children: [
                        LiquidSettingsRow(
                          icon: Icons.bug_report_outlined,
                          title: 'Report Bug',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Report Bug',
                            message: 'Bug reporter flow.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.help_outline,
                          title: 'Help Center',
                          iconColor: OptivusColors.textPrimary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Help Center',
                            message: 'FAQ and support.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.description_outlined,
                          title: 'Terms of Use',
                          iconColor: OptivusColors.textSecondary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Terms of Use',
                            message: 'Legal terms.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          iconColor: OptivusColors.textSecondary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Privacy Policy',
                            message: 'Legal policy.',
                          ),
                        ),
                        LiquidSettingsRow(
                          icon: Icons.auto_delete_outlined,
                          title: 'Delete Account Instructions',
                          iconColor: OptivusColors.textSecondary,
                          onTap: () => showPlaceholderSheet(
                            context,
                            title: 'Deletion Instructions',
                            message: 'How to delete account.',
                          ),
                        ),
                        const LiquidSettingsRow(
                          icon: Icons.info_outline,
                          title: 'Version',
                          subtitle:
                              'Optivus v1.0.0 • Build 1 • Environment: internal testing',
                          iconColor: OptivusColors.textMuted,
                        ),
                      ],
                    ),

                    // 14. Log out & 15. Delete account
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
                    // Serious Delete Account at the bottom
                    GestureDetector(
                      onTap: () => showDeleteAccountFlow(context),
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
}
