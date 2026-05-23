import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/mock_app_state.dart';
import 'package:optivus/state/mock_auth_state.dart';
import 'package:optivus/models/permission_status.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/core/widgets/liquid_settings_row.dart';

// Phase 8 Components
import 'package:optivus/features/profile/widgets/profile_header_card.dart';
import 'package:optivus/features/profile/widgets/profile_setting_group.dart';
import 'package:optivus/features/profile/widgets/profile_system_shortcut_card.dart';
import 'package:optivus/features/profile/screens/profile_sub_screens.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);
    final permissions = ref.watch(mockPermissionProvider);

    // Count active permissions/connections
    int activePermissions = 0;
    if (permissions.notifications == PermissionConnectionState.mockConnected) activePermissions++;
    if (permissions.usageAccess == PermissionConnectionState.mockConnected) activePermissions++;
    if (permissions.locationGps == PermissionConnectionState.mockConnected) activePermissions++;
    if (permissions.healthConnect == PermissionConnectionState.mockConnected) activePermissions++;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Bio Identity Card
          ProfileHeaderCard(
            profile: profile,
            onEditTap: () => showEditProfileSheet(context, ref),
          ),
          const SizedBox(height: 24),

          // 2. Quick System Shortcuts Grid
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: OptivusColors.brandAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'QUICK SYSTEM PORTAL',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 10,
                      color: OptivusColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.25,
            children: [
              ProfileSystemShortcutCard(
                icon: Icons.bluetooth_searching_rounded,
                title: 'Wearable Sync',
                description: 'Manage Health SDK & smart watch tracking ($activePermissions/4 connected)',
                accentColor: OptivusColors.brandAccent,
                statusWidget: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: permissions.healthConnect == PermissionConnectionState.mockConnected
                        ? OptivusColors.success
                        : OptivusColors.textMuted,
                  ),
                ),
                onTap: () => showWearableConnectSheet(context, ref),
              ),
              ProfileSystemShortcutCard(
                icon: Icons.developer_mode_rounded,
                title: 'Diagnostics Logs',
                description: 'State nodes, system health, FPS rendering rate',
                accentColor: const Color(0xFF6C5CE7),
                statusWidget: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OptivusColors.success,
                  ),
                ),
                onTap: () => showSystemDiagnosticsSheet(context, ref),
              ),
              ProfileSystemShortcutCard(
                icon: Icons.palette_outlined,
                title: 'Theme Customizer',
                description: 'Adjust gradients, dark mode, card styles',
                accentColor: const Color(0xFFFF7675),
                statusWidget: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: Colors.amber,
                ),
                onTap: () => showThemeCustomizerSheet(context, ref),
              ),
              ProfileSystemShortcutCard(
                icon: Icons.fingerprint_rounded,
                title: 'Secure Gate',
                description: 'Biometrics face lock and passcode keys',
                accentColor: const Color(0xFF00B894),
                statusWidget: const Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: Color(0xFF00B894),
                ),
                onTap: () => showBiometricSecuritySheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. Preferences & Alerts Group
          ProfileSettingGroup(
            title: 'Preferences & Routine Alarms',
            children: [
              LiquidSettingsRow(
                icon: Icons.notifications_active_outlined,
                title: 'Nudges & Alert Pacing',
                subtitle: 'Manage dynamic micro-reminders & frequency',
                iconColor: const Color(0xFFFF7675),
                onTap: () => showAlertPacingSheet(context, ref),
              ),
              LiquidSettingsRow(
                icon: Icons.wb_twighlight,
                title: 'Circadian Rhythm Setup',
                subtitle: 'Optimize sleep cycles & routine offsets',
                iconColor: const Color(0xFFECCC68),
                onTap: () => showCircadianScheduleSheet(context, ref),
              ),
              LiquidSettingsRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'AI Coach Quick Replies',
                subtitle: 'Customize prompt shortcut context templates',
                iconColor: const Color(0xFF70A1FF),
                onTap: () => showQuickRepliesSheet(context, ref),
              ),
            ],
          ),

          // 4. Guardrails & Privacy Group
          ProfileSettingGroup(
            title: 'Safety Guardrails & Privacy',
            children: [
              LiquidSettingsRow(
                icon: Icons.security_rounded,
                title: 'Habit Overload Shield',
                subtitle: 'Prevent burnout by setting hard target caps',
                iconColor: const Color(0xFF2ED573),
                onTap: () => showOverloadLimitsSheet(context, ref),
              ),
              LiquidSettingsRow(
                icon: Icons.savings_outlined,
                title: 'Financial Savings Sweep',
                subtitle: 'Rule models for auto penalty bad habit sweeps',
                iconColor: const Color(0xFFFFA502),
                onTap: () => showSavingsSweepSheet(context, ref),
              ),
              LiquidSettingsRow(
                icon: Icons.delete_forever_outlined,
                title: 'Account Data Control',
                subtitle: 'Export state logs, purge local database Cache',
                iconColor: OptivusColors.danger,
                onTap: () => showDataExportPurgeSheet(context, ref),
              ),
            ],
          ),

          // 5. Visual App Layout Settings
          ProfileSettingGroup(
            title: 'Interactive System Toggles',
            children: [
              SwitchListTile.adaptive(
                activeTrackColor: OptivusColors.brandAccent,
                title: const Text('Edge-to-edge UI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.textPrimary)),
                subtitle: const Text('Transparent system status bars matching gradients', style: TextStyle(fontSize: 10, color: OptivusColors.textSecondary)),
                value: true,
                onChanged: (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('App Preferences: Edge-to-edge UI locked ON by default.'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              SwitchListTile.adaptive(
                activeTrackColor: OptivusColors.brandAccent,
                title: const Text('Fullscreen Immersive Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.textPrimary)),
                subtitle: const Text('Hides top system status bar completely', style: TextStyle(fontSize: 10, color: OptivusColors.textSecondary)),
                value: false,
                onChanged: (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Immersive mode ${val ? "Activated" : "Deactivated"}!'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              SwitchListTile.adaptive(
                activeTrackColor: OptivusColors.brandAccent,
                title: const Text('Compact Cards Layout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.textPrimary)),
                subtitle: const Text('Tightens heights on timeline routine items', style: TextStyle(fontSize: 10, color: OptivusColors.textSecondary)),
                value: false,
                onChanged: (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Compact view ${val ? "Enabled" : "Disabled"}.'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ],
          ),

          // 6. Help & Support
          ProfileSettingGroup(
            title: 'Help, Support & Legal',
            children: [
              LiquidSettingsRow(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support Portal',
                subtitle: 'Submit tickets, browse documentation FAQs',
                iconColor: const Color(0xFF6C5CE7),
                onTap: () => _showSupportPortalSheet(context),
              ),
              LiquidSettingsRow(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Read privacy policies & legal conditions',
                iconColor: OptivusColors.textSecondary,
                onTap: () => _showLegalLinksSheet(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 7. Premium Sign Out
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.danger.withValues(alpha: 0.1),
              foregroundColor: OptivusColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: OptivusColors.danger, width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              ref.read(mockAuthProvider.notifier).logout();
              context.go('/');
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }

  // Elegant mock support portal bottom sheet
  void _showSupportPortalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFEEF3FE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SUPPORT PORTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Submit Ticket & Help',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LiquidGlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Need assistance with your Optivus profile?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Submit a detailed ticket below, and our team will analyze it alongside your mock logs.',
                          style: TextStyle(fontSize: 11, color: OptivusColors.textSecondary, height: 1.3),
                        ),
                        const SizedBox(height: 16),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Subject / Issue Category',
                            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TextField(
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Describe the issue...',
                            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OptivusColors.brandAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Support Ticket submitted successfully! Mock Ticket #8928'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Text('Submit Mock Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'FREQUENTLY ASKED QUESTIONS',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: OptivusColors.textSecondary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  _buildFaqItem('How do I sync my active outdoor GPS runs?', 'Go to Wearable Sync in your System Portal, and tap "Grant GPS Location Permission".'),
                  const SizedBox(height: 10),
                  _buildFaqItem('What is the Habit Overload Shield?', 'A safeguard designed to prevent burnout by letting you set custom target limits on daily active goals.'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: OptivusColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(fontSize: 11, color: OptivusColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  // Elegant mock legal links bottom sheet
  void _showLegalLinksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFEEF3FE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'LEGAL INFORMATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LiquidGlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Mock Service Operations',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: OptivusColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Optivus operates entirely as a high-fidelity frontend simulation layout. All data is stored transiently using mock Riverpod states and local memory controls.',
                          style: TextStyle(fontSize: 11, color: OptivusColors.textSecondary, height: 1.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '2. Privacy and Safe Health Sync',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: OptivusColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your native health integrations (Health Connect / location logs) are simulated sandbox entities. No telemetry or location logs are transmitted out of your device sandbox.',
                          style: TextStyle(fontSize: 11, color: OptivusColors.textSecondary, height: 1.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '3. End-User License Agreement (EULA)',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: OptivusColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'By proceeding to use the simulation, you agree to experience high-framerate glassmorphic layouts, consistent habit building systems, and comprehensive AI coaching context models.',
                          style: TextStyle(fontSize: 11, color: OptivusColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.brandAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Accept & Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
