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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OptivusColors.profileTop,
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.4],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'one',
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
                          color: OptivusColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: OptivusColors.textPrimary),
                    onPressed: () {},
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 1. Profile Identity Hero Card
              ProfileHeaderCard(
                profile: profile,
                onEditTap: () => showEditProfileSheet(context, ref),
              ),
              const SizedBox(height: 24),

              // 2. Identity Statement
              ProfileIdentityCard(
                identityStatement: identityStatement,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Navigate to Identity Goals')),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 3. Focus Areas
              ProfileChipsCard(
                title: 'Focus Areas',
                items: focusAreas,
                emptyMessage: 'No focus areas selected.',
                actionButtonText: 'Add Focus Area',
                onActionTap: () {},
                accentColor: OptivusColors.profileAccent,
              ),
              const SizedBox(height: 24),

              // 4. Habits to Break
              ProfileChipsCard(
                title: 'Habits to Break',
                items: habitsToBreak,
                emptyMessage: 'No habits selected.',
                actionButtonText: 'Add Habit to Break',
                onActionTap: () {},
                accentColor: OptivusColors.danger,
              ),
              const SizedBox(height: 24),

              // 5. System Setup Card
              ProfileSettingGroup(
                title: 'System Setup',
                children: [
                  const LiquidSettingsRow(
                    icon: Icons.check_circle_outline,
                    title: 'Onboarding Setup',
                    iconColor: OptivusColors.success,
                    trailing: ProfileStatusChip(
                      label: 'Completed',
                      type: ProfileStatusType.success,
                    ),
                  ),
                  const LiquidSettingsRow(
                    icon: Icons.work_outline,
                    title: 'Life Role & Lifestyle',
                    subtitle: 'Student + Working',
                    iconColor: OptivusColors.info,
                  ),
                  const LiquidSettingsRow(
                    icon: Icons.monitor_weight_outlined,
                    title: 'Body Basics',
                    subtitle: '52 kg · 5\'9"',
                    iconColor: OptivusColors.roseAccent,
                  ),
                  const LiquidSettingsRow(
                    icon: Icons.schedule,
                    title: 'Base Timeline',
                    subtitle: 'Classes + Eating + Fixed',
                    iconColor: OptivusColors.purpleAccent,
                  ),
                  const LiquidSettingsRow(
                    icon: Icons.flag_outlined,
                    title: 'Goals Setup',
                    subtitle: '3 active goals',
                    iconColor: OptivusColors.profileAccent,
                  ),
                  const LiquidSettingsRow(
                    icon: Icons.psychology_outlined,
                    title: 'Coach Setup',
                    subtitle: 'Sensei · Direct but kind',
                    iconColor: OptivusColors.mintAccent,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.refresh,
                    title: 'Reset / Re-run Setup',
                    iconColor: OptivusColors.textSecondary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Re-run setup placeholder')),
                      );
                    },
                  ),
                ],
              ),

              // 6. Account Card
              const ProfileSettingGroup(
                title: 'Account',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'nairitgpt@gmail.com',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.archive_outlined,
                    title: 'Archived Identities',
                    iconColor: OptivusColors.textSecondary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notifications',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.download_outlined,
                    title: 'Export Account Data',
                    iconColor: OptivusColors.textPrimary,
                  ),
                ],
              ),

              // 7. Permissions & Data Sources Card
              const ProfileSettingGroup(
                title: 'Permissions & Data Sources',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    iconColor: OptivusColors.textPrimary,
                    trailing: ProfileStatusChip(label: 'Connected', type: ProfileStatusType.success),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.data_usage,
                    title: 'Usage Access',
                    iconColor: OptivusColors.textPrimary,
                    trailing: ProfileStatusChip(label: 'Not connected', type: ProfileStatusType.muted),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    iconColor: OptivusColors.textPrimary,
                    trailing: ProfileStatusChip(label: 'Connected', type: ProfileStatusType.success),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Health Connect',
                    iconColor: OptivusColors.textPrimary,
                    trailing: ProfileStatusChip(label: 'Not connected', type: ProfileStatusType.muted),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.camera_alt_outlined,
                    title: 'Camera / Photos',
                    iconColor: OptivusColors.textPrimary,
                    trailing: ProfileStatusChip(label: 'Not connected', type: ProfileStatusType.muted),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.mic_none,
                    title: 'Microphone',
                    iconColor: OptivusColors.textPrimary,
                    trailing: ProfileStatusChip(label: 'Not connected', type: ProfileStatusType.muted),
                  ),
                ],
              ),

              // 8. Connected Services Card
              const ProfileSettingGroup(
                title: 'Connected Services',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.upload_file,
                    title: 'Cloudflare R2 Uploads',
                    iconColor: OptivusColors.info,
                    trailing: ProfileStatusChip(label: 'Connected', type: ProfileStatusType.success),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.map_outlined,
                    title: 'Mapbox',
                    iconColor: OptivusColors.brandAccent,
                    trailing: ProfileStatusChip(label: 'Connected', type: ProfileStatusType.success),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Health Connect',
                    iconColor: OptivusColors.textSecondary,
                    trailing: ProfileStatusChip(label: 'Not connected', type: ProfileStatusType.muted),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.phone_android,
                    title: 'Android Usage Access',
                    iconColor: OptivusColors.textSecondary,
                    trailing: ProfileStatusChip(label: 'Not connected', type: ProfileStatusType.muted),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.cloud_outlined,
                    title: 'Cloudflare Workers',
                    iconColor: OptivusColors.info,
                    trailing: ProfileStatusChip(label: 'Connected', type: ProfileStatusType.success),
                  ),
                ],
              ),

              // 9. App Preferences Card
              ProfileSettingGroup(
                title: 'App Preferences',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.vibration,
                    title: 'Haptic Feedback',
                    iconColor: OptivusColors.textPrimary,
                    trailing: Switch(
                      value: true,
                      onChanged: null,
                      activeThumbColor: OptivusColors.profileAccent,
                    ),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.spellcheck,
                    title: 'Correct Spelling',
                    iconColor: OptivusColors.textPrimary,
                    trailing: Switch(
                      value: true,
                      onChanged: null,
                      activeThumbColor: OptivusColors.profileAccent,
                    ),
                  ),
                  LiquidSettingsRow(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'System',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.format_paint_outlined,
                    title: 'Accent Color',
                    subtitle: 'Yellow',
                    iconColor: OptivusColors.profileAccent,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.settings_suggest_outlined,
                    title: 'Routine Settings',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    iconColor: OptivusColors.textPrimary,
                  ),
                ],
              ),

              // 10. Privacy & Security Card
              const ProfileSettingGroup(
                title: 'Privacy & Security',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.security,
                    title: 'Security',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.lock_outline,
                    title: 'Mind Notebook Privacy',
                    subtitle: 'Private',
                    iconColor: OptivusColors.success,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.psychology,
                    title: 'Coach Context Access',
                    subtitle: 'Limited',
                    iconColor: OptivusColors.warning,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.visibility_off_outlined,
                    title: 'Screen Time Privacy',
                    subtitle: 'Show app names',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Data Privacy',
                    iconColor: OptivusColors.textPrimary,
                  ),
                ],
              ),

              // 11. Data Control Card
              const ProfileSettingGroup(
                title: 'Data Control',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.download_outlined,
                    title: 'Export Data',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Delete Selected Data',
                    iconColor: OptivusColors.danger,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.person_remove_outlined,
                    title: 'Delete Account Request',
                    iconColor: OptivusColors.danger,
                  ),
                ],
              ),

              // 12. Support & About Card
              const ProfileSettingGroup(
                title: 'Support & About',
                children: [
                  LiquidSettingsRow(
                    icon: Icons.bug_report_outlined,
                    title: 'Report Bug',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    iconColor: OptivusColors.textPrimary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.description_outlined,
                    title: 'Terms of Use',
                    iconColor: OptivusColors.textSecondary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    iconColor: OptivusColors.textSecondary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.auto_delete_outlined,
                    title: 'Delete Account Instructions',
                    iconColor: OptivusColors.textSecondary,
                  ),
                  LiquidSettingsRow(
                    icon: Icons.info_outline,
                    title: 'Version',
                    subtitle: 'Optivus v1.0.0',
                    iconColor: OptivusColors.textMuted,
                  ),
                ],
              ),

              // 13. Log out & 14. Delete account
              const SizedBox(height: 16),
              LiquidGlassPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    LiquidSettingsRow(
                      icon: Icons.logout,
                      title: 'Log out',
                      iconColor: OptivusColors.textSecondary,
                      onTap: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Serious Delete Account at the bottom
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete account request placeholder')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OptivusColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OptivusColors.danger.withValues(alpha: 0.3)),
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
    );
  }
}
