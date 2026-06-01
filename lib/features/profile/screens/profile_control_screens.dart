import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/widgets/liquid_inputs.dart';
import 'package:optivus/features/coach/providers/coach_navigation_provider.dart';
import 'package:optivus/features/profile/models/profile_settings_models.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/features/profile/providers/profile_settings_provider.dart';
import 'package:optivus/features/profile/providers/profile_mock_data.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/state/app_state.dart';

typedef OpenProfileDetail = void Function(ProfileDetailTarget target);

const _profileAccent = OptivusColors.profileAccent;

class EditProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const EditProfileScreen({super.key, required this.onBack});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileSettingsProvider).profile;
    _name = TextEditingController(text: profile.name);
    _username = TextEditingController(text: profile.username);
    _bio = TextEditingController(text: profile.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(profileSettingsProvider).profile;
    final identity = ref.watch(mockIdentityStatementProvider);

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Edit Profile',
      subtitle:
          'Identity statement is generated from Goals unless custom display is enabled.',
      accentColor: _profileAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Profile photo',
          children: [
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [OptivusColors.profileTop, _profileAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _profileAccent.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.photoState,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Upload path is designed for Cloudflare R2. No Firebase Storage.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SmallActionButton(
                  label: 'Upload photo',
                  color: _profileAccent,
                  onTap: () => ref
                      .read(profileSettingsProvider.notifier)
                      .setProfilePhotoState('Photo upload queued for R2'),
                ),
                _SmallActionButton(
                  label: 'Remove',
                  color: OptivusColors.danger,
                  onTap: () => ref
                      .read(profileSettingsProvider.notifier)
                      .setProfilePhotoState('No photo uploaded'),
                ),
              ],
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Basic details',
          children: [
            LiquidInput(
              controller: _name,
              labelText: 'Name',
              accentColor: _profileAccent,
            ),
            const SizedBox(height: 12),
            LiquidInput(
              controller: _username,
              labelText: 'Username',
              prefixIcon: Icons.alternate_email_rounded,
              accentColor: _profileAccent,
            ),
            const SizedBox(height: 12),
            LiquidInput(
              controller: _bio,
              labelText: 'Short bio',
              maxLines: 3,
              accentColor: _profileAccent,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Identity statement',
          children: [
            Text(
              identity,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.4,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LiquidActionRow(
              icon: Icons.flag_outlined,
              title: 'Edit in Goals',
              subtitle: 'Goals owns identity logic and archived identities.',
              accentColor: OptivusColors.goalsAccent,
              onTap: () => ref.read(appNavigationProvider.notifier).goToGoals(),
            ),
          ],
        ),
        _PrimaryFooterButton(
          label: 'Save profile',
          onTap: () {
            ref
                .read(profileSettingsProvider.notifier)
                .updateProfile(
                  settings.copyWith(
                    name: _name.text.trim().isEmpty
                        ? settings.name
                        : _name.text.trim(),
                    username: _username.text.trim().isEmpty
                        ? settings.username
                        : _username.text.trim(),
                    bio: _bio.text.trim(),
                  ),
                );
            widget.onBack();
          },
        ),
      ],
    );
  }
}

class SystemSetupScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final OpenProfileDetail onOpenProfileDetail;

  const SystemSetupScreen({
    super.key,
    required this.onBack,
    required this.onOpenProfileDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(mockUserProfileProvider);

    return LiquidDetailScaffold(
      eyebrow: 'Setup',
      title: 'System Setup',
      subtitle:
          'Changing setup affects the future system only. Past history stays intact.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Onboarding setup',
          children: [
            LiquidActionRow(
              icon: Icons.work_outline,
              title: 'Life Role & Lifestyle',
              subtitle: profile.lifeRole.isEmpty
                  ? 'Student + Working · setup shortcut'
                  : profile.lifeRole,
              accentColor: OptivusColors.info,
              onTap: () => _showSetupReview(
                context,
                'Life Role & Lifestyle',
                'Review role, work mode, exercise level, stress, sleep quality, and water intake. A later backend pass can reopen the exact onboarding step.',
              ),
            ),
            LiquidActionRow(
              icon: Icons.monitor_weight_outlined,
              title: 'Body Basics',
              subtitle: profile.weight > 0
                  ? '${profile.weight.toStringAsFixed(0)} kg · ${profile.height.toStringAsFixed(0)} cm'
                  : '52 kg · 5\'9" · setup shortcut',
              accentColor: OptivusColors.roseAccent,
              onTap: () => _showSetupReview(
                context,
                'Body Basics',
                'Body basics power calories, protein, fitness setup, and coach context. Past estimates are kept historically stable.',
              ),
            ),
            LiquidActionRow(
              icon: Icons.schedule_rounded,
              title: 'Base Timeline',
              subtitle: 'Classes, work, eating, fixed, and skin care blocks.',
              accentColor: OptivusColors.routineAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToRoutine();
                ref
                    .read(routineDetailViewRequestProvider.notifier)
                    .state = const RoutineDetailTarget(
                  view: RoutineDetailView.baseTimelineManager,
                );
              },
            ),
            LiquidActionRow(
              icon: Icons.restaurant_rounded,
              title: 'Eating Setup',
              subtitle: 'Open Routine eating timeline setup.',
              accentColor: OptivusColors.roseAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToRoutine();
                ref
                    .read(routineDetailViewRequestProvider.notifier)
                    .state = const RoutineDetailTarget(
                  view: RoutineDetailView.eatingSetup,
                );
              },
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'System owners',
          children: [
            LiquidActionRow(
              icon: Icons.flag_outlined,
              title: 'Goals Setup',
              subtitle: 'Goals owns identity logic and active proof load.',
              accentColor: OptivusColors.goalsAccent,
              onTap: () => ref.read(appNavigationProvider.notifier).goToGoals(),
            ),
            LiquidActionRow(
              icon: Icons.psychology_outlined,
              title: 'Coach Setup',
              subtitle: 'Open Coach Settings inside Coach tab.',
              accentColor: OptivusColors.coachAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToCoach();
                ref.read(coachDetailViewRequestProvider.notifier).state =
                    CoachDetailView.coachSettings;
              },
            ),
            LiquidActionRow(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Reminder types, intensity, quiet hours.',
              accentColor: _profileAccent,
              onTap: () => onOpenProfileDetail(
                const ProfileDetailTarget(
                  view: ProfileDetailView.notificationSettings,
                ),
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Reset',
          children: [
            LiquidActionRow(
              icon: Icons.refresh_rounded,
              title: 'Reset / Re-run Setup',
              subtitle: 'Confirmation required. Current history is preserved.',
              accentColor: OptivusColors.danger,
              destructive: true,
              onTap: () => _showResetSetupDialog(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const NotificationSettingsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(profileSettingsProvider).notifications;
    final notifier = ref.read(profileSettingsProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Notifications',
      subtitle: 'Reminder types, intensity, quiet hours, and Android status.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Reminder types',
          children: settings.reminderTypes.entries.map((entry) {
            return _SwitchRow(
              icon: Icons.notifications_none_rounded,
              title: entry.key,
              value: entry.value,
              color: _profileAccent,
              onChanged: (_) => notifier.toggleReminderType(entry.key),
            );
          }).toList(),
        ),
        LiquidDetailSection(
          title: 'Reminder intensity',
          children: [
            _SegmentRow(
              options: const ['Low', 'Medium', 'High'],
              selected: settings.intensity,
              color: _profileAccent,
              onSelected: notifier.setReminderIntensity,
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Quiet hours',
          children: [
            _SwitchRow(
              icon: Icons.nights_stay_outlined,
              title: 'Do not disturb after 11 PM',
              value: settings.quietAfter11,
              color: _profileAccent,
              onChanged: (v) => notifier.setQuietHours(quietAfter11: v),
            ),
            _SwitchRow(
              icon: Icons.block_outlined,
              title: 'Do not disturb during class/job hard blocks',
              value: settings.quietDuringHardBlocks,
              color: _profileAccent,
              onChanged: (v) =>
                  notifier.setQuietHours(quietDuringHardBlocks: v),
            ),
            _SwitchRow(
              icon: Icons.bedtime_outlined,
              title: 'Do not disturb during sleep block',
              value: settings.quietDuringSleep,
              color: _profileAccent,
              onChanged: (v) => notifier.setQuietHours(quietDuringSleep: v),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Permission status',
          children: [
            LiquidActionRow(
              icon: Icons.android_rounded,
              title: settings.permissionStatus.label,
              subtitle:
                  'If missing, use the Android settings action when native wiring is added.',
              accentColor:
                  settings.permissionStatus == ProfileConnectionStatus.connected
                  ? OptivusColors.success
                  : OptivusColors.warning,
            ),
            _SmallActionButton(
              label: 'Open Android Settings',
              color: _profileAccent,
              onTap: () => _showSetupReview(
                context,
                'Android Settings',
                'Native Android notification settings intent will connect here.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PermissionsDataSourcesScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final OpenProfileDetail onOpenProfileDetail;

  const PermissionsDataSourcesScreen({
    super.key,
    required this.onBack,
    required this.onOpenProfileDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(profileSettingsProvider).permissions;

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Permissions & Data Sources',
      subtitle:
          'Android live status is the source of truth. Firestore stores last known status only.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Live-check capable',
          children: permissions.map((permission) {
            return LiquidActionRow(
              icon: _permissionIcon(permission.type),
              title: permission.type.label,
              subtitle: permission.type.reason,
              accentColor: _statusColor(permission.status),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidPill(
                    label: permission.status.label,
                    color: _statusColor(permission.status),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: OptivusColors.textMuted,
                  ),
                ],
              ),
              onTap: () => onOpenProfileDetail(
                ProfileDetailTarget(
                  view: ProfileDetailView.permissionDetail,
                  permissionType: permission.type,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class PermissionDetailScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final ProfilePermissionType permissionType;

  const PermissionDetailScreen({
    super.key,
    required this.onBack,
    required this.permissionType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref
        .watch(profileSettingsProvider)
        .permissions
        .firstWhere((p) => p.type == permissionType);

    return LiquidDetailScaffold(
      eyebrow: 'Permission',
      title: permissionType.label,
      subtitle: permissionType.reason,
      accentColor: _statusColor(permission.status),
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Current status',
          children: [
            LiquidActionRow(
              icon: _permissionIcon(permissionType),
              title: permission.status.label,
              subtitle:
                  '${permission.sourceOfTruth} · last checked ${permission.lastChecked}',
              accentColor: _statusColor(permission.status),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Used by',
          children: [
            Text(
              permissionType.systems,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Action',
          children: [
            LiquidActionRow(
              icon: Icons.open_in_new_rounded,
              title: permissionType.primaryAction,
              subtitle:
                  'Mock action now. Native Android permission flow can connect later.',
              accentColor: _profileAccent,
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .togglePermission(permissionType),
            ),
          ],
        ),
      ],
    );
  }
}

class ConnectedServicesScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final OpenProfileDetail onOpenProfileDetail;

  const ConnectedServicesScreen({
    super.key,
    required this.onBack,
    required this.onOpenProfileDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(profileSettingsProvider).services;
    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Connected Services',
      subtitle:
          'Spark-only service guardrails and last known connection state.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Services',
          children: services.map((service) {
            return LiquidActionRow(
              icon: _serviceIcon(service.type),
              title: service.type.label,
              subtitle: service.type.powers,
              accentColor: _statusColor(service.status),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidPill(
                    label: service.status.label,
                    color: _statusColor(service.status),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: OptivusColors.textMuted,
                  ),
                ],
              ),
              onTap: () => onOpenProfileDetail(
                ProfileDetailTarget(
                  view: ProfileDetailView.connectedServiceDetail,
                  serviceType: service.type,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class ConnectedServiceDetailScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final ConnectedServiceType serviceType;

  const ConnectedServiceDetailScreen({
    super.key,
    required this.onBack,
    required this.serviceType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref
        .watch(profileSettingsProvider)
        .services
        .firstWhere((s) => s.type == serviceType);

    return LiquidDetailScaffold(
      eyebrow: 'Service',
      title: serviceType.label,
      subtitle: serviceType.powers,
      accentColor: _statusColor(service.status),
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Status',
          children: [
            LiquidActionRow(
              icon: _serviceIcon(serviceType),
              title: service.status.label,
              subtitle:
                  'Last checked ${service.lastChecked}${service.selectedStyle == null ? '' : ' · ${service.selectedStyle}'}',
              accentColor: _statusColor(service.status),
              onTap: () => ref
                  .read(profileSettingsProvider.notifier)
                  .recheckService(serviceType),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Architecture rule',
          children: [
            Text(
              switch (serviceType) {
                ConnectedServiceType.cloudflareR2 =>
                  'Uploads and generated export files use Cloudflare R2. No Firebase Storage.',
                ConnectedServiceType.cloudflareWorkers =>
                  'Coach AI and Routine import AI use Cloudflare Workers. No Firebase Functions.',
                ConnectedServiceType.mapbox =>
                  'Mapbox powers route tracking and selected style previews.',
                _ =>
                  'Native Android service status remains live-check capable and backend-ready.',
              },
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AppPreferencesScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final OpenProfileDetail? onOpenProfileDetail;

  const AppPreferencesScreen({
    super.key,
    required this.onBack,
    this.onOpenProfileDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(profileSettingsProvider).preferences;
    final notifier = ref.read(profileSettingsProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'App Preferences',
      subtitle:
          'Theme, tab layout, timeline display, coach voice, and language.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'General',
          children: [
            _SwitchRow(
              icon: Icons.vibration_rounded,
              title: 'Haptic Feedback',
              value: prefs.haptics,
              color: _profileAccent,
              onChanged: (v) =>
                  notifier.updatePreferences(prefs.copyWith(haptics: v)),
            ),
            _SwitchRow(
              icon: Icons.spellcheck_rounded,
              title: 'Correct Spelling Automatically',
              value: prefs.autoCorrect,
              color: _profileAccent,
              onChanged: (v) =>
                  notifier.updatePreferences(prefs.copyWith(autoCorrect: v)),
            ),
            LiquidActionRow(
              icon: Icons.public_rounded,
              title: 'Region & Localization',
              subtitle: 'Currency, units, date format, food vocabulary.',
              accentColor: _profileAccent,
              onTap: () {
                final target = const ProfileDetailTarget(
                  view: ProfileDetailView.regionLocalization,
                );
                if (onOpenProfileDetail != null) {
                  onOpenProfileDetail!(target);
                } else {
                  ref.read(profileDetailViewRequestProvider.notifier).state =
                      target;
                }
              },
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Appearance',
          children: [
            _LabeledSegment(
              label: 'Theme / Appearance',
              options: const ['System', 'Light', 'Dark'],
              selected: prefs.themeMode,
              onSelected: (v) =>
                  notifier.updatePreferences(prefs.copyWith(themeMode: v)),
            ),
            const SizedBox(height: 14),
            _LabeledSegment(
              label: 'Accent Color',
              options: const ['Yellow', 'Green', 'Purple', 'Blue'],
              selected: prefs.accentColor,
              onSelected: (v) =>
                  notifier.updatePreferences(prefs.copyWith(accentColor: v)),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Routine and Coach',
          children: [
            LiquidActionRow(
              icon: Icons.settings_suggest_outlined,
              title: 'Routine Settings',
              subtitle: 'Profile links here. Routine owns timeline logic.',
              accentColor: OptivusColors.routineAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToRoutine();
                ref
                    .read(routineDetailViewRequestProvider.notifier)
                    .state = const RoutineDetailTarget(
                  view: RoutineDetailView.routineSettings,
                );
              },
            ),
            _LabeledSegment(
              label: 'Timeline Display',
              options: const ['Timeline', 'Compact', 'Full day'],
              selected: prefs.timelineDisplay,
              onSelected: (v) => notifier.updatePreferences(
                prefs.copyWith(timelineDisplay: v),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledSegment(
              label: 'Coach Voice',
              options: const ['Text first', 'Voice later', 'Muted'],
              selected: prefs.coachVoice,
              onSelected: (v) =>
                  notifier.updatePreferences(prefs.copyWith(coachVoice: v)),
            ),
            const SizedBox(height: 14),
            _LabeledSegment(
              label: 'Language',
              options: const [
                'English',
                'Hindi',
                'Bengali',
                'Japanese',
                'German',
                'Spanish',
                'French',
                'Korean',
                'Chinese',
                'Custom',
              ],
              selected: prefs.language,
              onSelected: (v) =>
                  notifier.updatePreferences(prefs.copyWith(language: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class PrivacySecurityScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const PrivacySecurityScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(profileSettingsProvider).privacy;
    final notifier = ref.read(profileSettingsProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Privacy & Security',
      subtitle:
          'Coach can read selected Mind Notes only. Never all notebook content.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Security',
          children: [
            const LiquidActionRow(
              icon: Icons.login_rounded,
              title: 'Login method',
              subtitle: 'Email/password or connected Google account.',
              accentColor: _profileAccent,
            ),
            _SwitchRow(
              icon: Icons.lock_outline_rounded,
              title: 'App lock optional',
              value: privacy.appLock,
              color: _profileAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(appLock: v)),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Mind Notebook Privacy',
          children: [
            _SwitchRow(
              icon: Icons.visibility_off_outlined,
              title: 'Hide note previews',
              value: privacy.hideMindPreviews,
              color: _profileAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(hideMindPreviews: v)),
            ),
            _SwitchRow(
              icon: Icons.lock_person_outlined,
              title: 'Lock Mind Notebook optional',
              value: privacy.lockMindNotebook,
              color: _profileAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(lockMindNotebook: v)),
            ),
            const Text(
              'Mind Notebook is private by default. Coach can read selected notes only when shared by the user.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: OptivusColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Coach Context Access',
          children: [
            _SwitchRow(
              icon: Icons.calendar_month_outlined,
              title: 'Use routine data',
              value: privacy.coachRoutine,
              color: OptivusColors.coachAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(coachRoutine: v)),
            ),
            _SwitchRow(
              icon: Icons.insights_outlined,
              title: 'Use tracker data',
              value: privacy.coachTracker,
              color: OptivusColors.coachAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(coachTracker: v)),
            ),
            _SwitchRow(
              icon: Icons.flag_outlined,
              title: 'Use goal data',
              value: privacy.coachGoals,
              color: OptivusColors.coachAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(coachGoals: v)),
            ),
            _SwitchRow(
              icon: Icons.phone_android_outlined,
              title: 'Use screen-time data',
              value: privacy.coachScreenTime,
              color: OptivusColors.coachAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(coachScreenTime: v)),
            ),
            _SwitchRow(
              icon: Icons.savings_outlined,
              title: 'Use money data',
              value: privacy.coachMoney,
              color: OptivusColors.coachAccent,
              onChanged: (v) =>
                  notifier.updatePrivacy(privacy.copyWith(coachMoney: v)),
            ),
            _SwitchRow(
              icon: Icons.note_alt_outlined,
              title: 'Use selected mind notes only',
              value: privacy.coachSelectedNotesOnly,
              color: OptivusColors.coachAccent,
              onChanged: (v) => notifier.updatePrivacy(
                privacy.copyWith(coachSelectedNotesOnly: v),
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Screen Time Privacy',
          children: [
            _LabeledSegment(
              label: 'Display mode',
              options: const [
                'Show app names',
                'Hide app names',
                'Categories only',
              ],
              selected: privacy.screenTimePrivacyMode,
              onSelected: (v) => notifier.updatePrivacy(
                privacy.copyWith(screenTimePrivacyMode: v),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              privacy.screenTimePrivacyMode == 'Show app names'
                  ? 'Example: Instagram 3h 20m'
                  : 'Example: Social app 3h 20m',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DataControlScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final OpenProfileDetail onOpenProfileDetail;

  const DataControlScreen({
    super.key,
    required this.onBack,
    required this.onOpenProfileDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletion = ref.watch(profileSettingsProvider).deletionRequest;

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Data Control',
      subtitle:
          'Export account data, delete selected data, or request account deletion.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Controls',
          children: [
            LiquidActionRow(
              icon: Icons.download_outlined,
              title: 'Export Data',
              subtitle: 'JSON now, CSV where useful, PDF later optional.',
              accentColor: _profileAccent,
              onTap: () => onOpenProfileDetail(
                const ProfileDetailTarget(view: ProfileDetailView.exportData),
              ),
            ),
            LiquidActionRow(
              icon: Icons.delete_sweep_outlined,
              title: 'Delete Selected Data',
              subtitle: 'Requires checkbox selection and confirmation.',
              accentColor: OptivusColors.danger,
              destructive: true,
              onTap: () => onOpenProfileDetail(
                const ProfileDetailTarget(
                  view: ProfileDetailView.deleteSelectedData,
                ),
              ),
            ),
            LiquidActionRow(
              icon: Icons.person_remove_outlined,
              title: 'Delete Account Request',
              subtitle:
                  'Requires export offer, re-auth preview, and typing DELETE.',
              accentColor: OptivusColors.danger,
              destructive: true,
              onTap: () => onOpenProfileDetail(
                const ProfileDetailTarget(
                  view: ProfileDetailView.deleteAccountRequest,
                ),
              ),
            ),
          ],
        ),
        if (deletion.pending)
          LiquidDetailSection(
            title: 'Deletion status',
            tint: OptivusColors.danger.withValues(alpha: 0.08),
            children: [
              const Text(
                'Account deletion request pending.',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.danger,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cancellation window ends ${_dateLabel(deletion.cancellationDeadline)}.',
                style: const TextStyle(
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _SmallActionButton(
                label: 'Cancel deletion request',
                color: OptivusColors.danger,
                onTap: () => ref
                    .read(profileSettingsProvider.notifier)
                    .cancelDeletionRequest(),
              ),
            ],
          ),
      ],
    );
  }
}

class ExportDataScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ExportDataScreen({super.key, required this.onBack});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  final Set<String> _selected = {'All data'};
  String _format = 'JSON';

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(profileSettingsProvider).exportRequest;

    return LiquidDetailScaffold(
      eyebrow: 'Data Control',
      title: 'Export Data',
      subtitle:
          'Request metadata goes to Firestore later. Export files go to Cloudflare R2 or local share.',
      accentColor: _profileAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Export options',
          children: _exportScopes.map((scope) {
            final checked = _selected.contains(scope);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: checked,
              activeColor: _profileAccent,
              title: Text(
                scope,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (scope == 'All data') _selected.clear();
                    if (scope != 'All data') _selected.remove('All data');
                    _selected.add(scope);
                  } else {
                    _selected.remove(scope);
                  }
                });
              },
            );
          }).toList(),
        ),
        LiquidDetailSection(
          title: 'Format',
          children: [
            _SegmentRow(
              options: const ['JSON', 'CSV', 'PDF later'],
              selected: _format,
              color: _profileAccent,
              onSelected: (v) => setState(() => _format = v),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Request status',
          children: [
            if (request == null)
              const Text(
                'No export requested yet.',
                style: TextStyle(
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiquidPill(
                    label: request.status.label,
                    color: request.status == DataExportStatus.ready
                        ? OptivusColors.success
                        : _profileAccent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${request.scopes.join(', ')} · ${request.format}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  if (request.expiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Ready file expires ${_dateLabel(request.expiresAt)}.',
                      style: const TextStyle(
                        color: OptivusColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _SmallActionButton(
                    label: 'Mock generate',
                    color: _profileAccent,
                    onTap: () {
                      ref
                          .read(profileSettingsProvider.notifier)
                          .setExportStatus(DataExportStatus.ready);
                    },
                  ),
                ],
              ),
          ],
        ),
        _PrimaryFooterButton(
          label: 'Request export',
          onTap: () => ref
              .read(profileSettingsProvider.notifier)
              .createExportRequest(_selected, _format),
        ),
      ],
    );
  }
}

class DeleteSelectedDataScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const DeleteSelectedDataScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(profileSettingsProvider).selectedDeleteScopes;
    final notifier = ref.read(profileSettingsProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Data Control',
      title: 'Delete Selected Data',
      subtitle:
          'Select data categories, then confirm. Row taps never delete immediately.',
      accentColor: OptivusColors.danger,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Delete options',
          tint: OptivusColors.danger.withValues(alpha: 0.06),
          children: _deleteScopes.map((scope) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(scope),
              activeColor: OptivusColors.danger,
              title: Text(
                scope,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onChanged: (_) => notifier.toggleDeleteScope(scope),
            );
          }).toList(),
        ),
        _PrimaryFooterButton(
          label: selected.isEmpty
              ? 'Select data to delete'
              : 'Delete ${selected.length} selected categories',
          color: OptivusColors.danger,
          onTap: selected.isEmpty
              ? null
              : () => _confirmSelectedDelete(context, ref, selected),
        ),
      ],
    );
  }
}

class DeleteAccountRequestScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final OpenProfileDetail onOpenProfileDetail;

  const DeleteAccountRequestScreen({
    super.key,
    required this.onBack,
    required this.onOpenProfileDetail,
  });

  @override
  ConsumerState<DeleteAccountRequestScreen> createState() =>
      _DeleteAccountRequestScreenState();
}

class _DeleteAccountRequestScreenState
    extends ConsumerState<DeleteAccountRequestScreen> {
  final TextEditingController _confirm = TextEditingController();
  bool _reauthChecked = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deletion = ref.watch(profileSettingsProvider).deletionRequest;
    final canSubmit = _reauthChecked && _confirm.text.trim() == 'DELETE';

    return LiquidDetailScaffold(
      eyebrow: 'Data Control',
      title: 'Delete Account Request',
      subtitle:
          'Account deletion never happens from one tap. This creates a pending request.',
      accentColor: OptivusColors.danger,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'What will be deleted',
          tint: OptivusColors.danger.withValues(alpha: 0.06),
          children: const [
            Text(
              'Profile, onboarding setup, routine history, goals, tracker history, money system data, coach sessions, mind notebook metadata, and uploaded files metadata.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Before deleting',
          children: [
            LiquidActionRow(
              icon: Icons.download_outlined,
              title: 'Export Data first',
              subtitle: 'Recommended before submitting a deletion request.',
              accentColor: _profileAccent,
              onTap: () => widget.onOpenProfileDetail(
                const ProfileDetailTarget(view: ProfileDetailView.exportData),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _reauthChecked,
              activeColor: OptivusColors.danger,
              title: const Text(
                'Re-authenticate / re-login preview completed',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onChanged: (v) => setState(() => _reauthChecked = v ?? false),
            ),
            const SizedBox(height: 10),
            LiquidInput(
              controller: _confirm,
              labelText: 'Type DELETE',
              accentColor: OptivusColors.danger,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        if (deletion.pending)
          LiquidDetailSection(
            title: 'Pending deletion',
            tint: OptivusColors.danger.withValues(alpha: 0.08),
            children: [
              Text(
                'Cancellation window ends ${_dateLabel(deletion.cancellationDeadline)}.',
                style: const TextStyle(
                  color: OptivusColors.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _SmallActionButton(
                label: 'Cancel request',
                color: OptivusColors.danger,
                onTap: () => ref
                    .read(profileSettingsProvider.notifier)
                    .cancelDeletionRequest(),
              ),
            ],
          )
        else
          _PrimaryFooterButton(
            label: 'Create deletion request',
            color: OptivusColors.danger,
            onTap: canSubmit
                ? () {
                    ref
                        .read(profileSettingsProvider.notifier)
                        .createDeletionRequest();
                    setState(() {});
                  }
                : null,
          ),
      ],
    );
  }
}

class ArchivedIdentitiesScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const ArchivedIdentitiesScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(profileSettingsProvider).archivedIdentities;

    return LiquidDetailScaffold(
      eyebrow: 'Goals owned',
      title: 'Archived Identities',
      subtitle:
          'Profile displays old identity statements. Goals owns identity logic.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        if (archived.isEmpty)
          LiquidDetailSection(
            children: const [
              Text(
                'No archived identities yet.',
                style: TextStyle(color: OptivusColors.textSecondary),
              ),
            ],
          )
        else
          ...archived.map(
            (identity) => LiquidDetailSection(
              children: [
                Text(
                  identity,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Archived date: mock history · Restore / View in Goals',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ReportBugScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ReportBugScreen({super.key, required this.onBack});

  @override
  ConsumerState<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends ConsumerState<ReportBugScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _screen = TextEditingController();
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _screen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidDetailScaffold(
      eyebrow: 'Support',
      title: 'Report Bug',
      subtitle: 'Submit a frontend-ready bug report form.',
      accentColor: _profileAccent,
      onBack: widget.onBack,
      children: [
        if (_submitted)
          LiquidDetailSection(
            tint: OptivusColors.success.withValues(alpha: 0.08),
            children: const [
              Text(
                'Bug report submitted locally.',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.success,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Backend issue creation can connect later without changing this flow.',
                style: TextStyle(color: OptivusColors.textSecondary),
              ),
            ],
          )
        else ...[
          LiquidDetailSection(
            title: 'Details',
            children: [
              LiquidInput(
                controller: _title,
                labelText: 'Bug title',
                accentColor: _profileAccent,
              ),
              const SizedBox(height: 12),
              LiquidInput(
                controller: _body,
                labelText: 'What happened?',
                maxLines: 4,
                accentColor: _profileAccent,
              ),
              const SizedBox(height: 12),
              LiquidInput(
                controller: _screen,
                labelText: 'Which screen?',
                accentColor: _profileAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Screenshot optional · Device info optional · Logs optional later',
                style: TextStyle(
                  fontSize: 12,
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: OptivusColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          _PrimaryFooterButton(
            label: 'Submit bug report',
            onTap: () {
              if (_title.text.trim().isEmpty ||
                  _body.text.trim().isEmpty ||
                  _screen.text.trim().isEmpty) {
                setState(
                  () => _error = 'Title, details, and screen are required.',
                );
                return;
              }
              ref
                  .read(profileSettingsProvider.notifier)
                  .submitBugReport(_title.text);
              setState(() {
                _submitted = true;
                _error = null;
              });
            },
          ),
        ],
      ],
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  final VoidCallback onBack;

  const HelpCenterScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LiquidDetailScaffold(
      eyebrow: 'Support',
      title: 'Help Center',
      subtitle:
          'Topics and legal link cards. Cloudflare Pages can host final docs later.',
      accentColor: _profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Topics',
          children: _helpTopics
              .map(
                (topic) => LiquidActionRow(
                  icon: Icons.help_outline_rounded,
                  title: topic,
                  subtitle: 'Open ${topic.toLowerCase()} guide.',
                  accentColor: _profileAccent,
                  onTap: () => _showSetupReview(
                    context,
                    topic,
                    'This guide opens as an in-app local draft. Final hosted articles can live on Cloudflare Pages.',
                  ),
                ),
              )
              .toList(),
        ),
        LiquidDetailSection(
          title: 'Legal pages',
          children: [
            LiquidActionRow(
              icon: Icons.description_outlined,
              title: 'Terms of Use',
              subtitle: 'Cloudflare Pages legal link later.',
              accentColor: _profileAccent,
              onTap: () => _showSetupReview(
                context,
                'Terms of Use',
                'The production Terms of Use will be hosted on Cloudflare Pages. This local draft keeps the link path reserved for backend handoff.',
              ),
            ),
            LiquidActionRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Cloudflare Pages legal link later.',
              accentColor: _profileAccent,
              onTap: () => _showSetupReview(
                context,
                'Privacy Policy',
                'The production Privacy Policy will be hosted on Cloudflare Pages. This local draft keeps the link path reserved for backend handoff.',
              ),
            ),
            LiquidActionRow(
              icon: Icons.auto_delete_outlined,
              title: 'Delete Account Instructions',
              subtitle: 'Shows export-first and 7-day cancellation flow.',
              accentColor: _profileAccent,
              onTap: () => _showSetupReview(
                context,
                'Delete Account Instructions',
                'Export data first, submit a delete account request, then use the 7-day cancellation window if the request was accidental.',
              ),
            ),
            LiquidActionRow(
              icon: Icons.support_agent_outlined,
              title: 'Support',
              subtitle: 'Support link draft for the backend handoff.',
              accentColor: _profileAccent,
              onTap: () => _showSetupReview(
                context,
                'Support',
                'Support requests are handled in Profile > Report Bug for this build. Backend can later attach Cloudflare Pages and worker endpoints.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AboutVersionScreen extends StatelessWidget {
  final VoidCallback onBack;

  const AboutVersionScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return LiquidDetailScaffold(
      eyebrow: 'About',
      title: 'Optivus v1.0.0',
      subtitle: 'Build 1 · Environment: internal testing',
      accentColor: _profileAccent,
      onBack: onBack,
      children: const [
        LiquidDetailSection(
          title: 'Architecture notes',
          children: [
            Text(
              'Optivus is a liquid glassmorphic Life OS built around Home, Routine, Tracker, Coach, Goals, and Profile. Profile acts as System Control Center, while each domain keeps ownership of its own logic.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Spark-only guardrail',
          children: [
            Text(
              'No Firebase Functions. No Firebase Storage. No paid Google APIs. Upload/export previews are designed around Cloudflare R2 or local share. AI previews are designed around Cloudflare Workers.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Credits / Legal',
          children: [
            Text(
              'Internal testing build. Terms, privacy policy, support, and delete-account docs can move to Cloudflare Pages.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
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

void _showSetupReview(BuildContext context, String title, String body) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(
          22,
          18,
          22,
          22 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _profileAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showResetSetupDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Re-run setup?'),
      content: const Text(
        'This local setup flow preserves history and only affects future setup defaults.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final profile = ref.read(mockUserProfileProvider);
            ref
                .read(mockUserProfileProvider.notifier)
                .updateProfile(
                  profile.copyWith(
                    onboardingCompleted: false,
                    onboardingStep: 0,
                  ),
                );
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

void _confirmSelectedDelete(
  BuildContext context,
  WidgetRef ref,
  Set<String> selected,
) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Delete selected data?'),
      content: Text(
        'This local deletion request will clear the selected categories from this build:\n\n${selected.join(', ')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref
                .read(profileSettingsProvider.notifier)
                .clearSelectedDeleteScopes();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm delete'),
        ),
      ],
    ),
  );
}

String _dateLabel(DateTime? date) {
  if (date == null) return 'not set';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidActionRow(
      icon: icon,
      title: title,
      accentColor: color,
      trailing: Switch(
        value: value,
        activeThumbColor: color,
        onChanged: onChanged,
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  const _SegmentRow({
    required this.options,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final active = option == selected;
        return GestureDetector(
          onTap: () => onSelected(option),
          child: LiquidPill(label: option, color: color, filled: active),
        );
      }).toList(),
    );
  }
}

class _LabeledSegment extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _LabeledSegment({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _SegmentRow(
          options: options,
          selected: selected,
          color: _profileAccent,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PrimaryFooterButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _PrimaryFooterButton({
    required this.label,
    this.onTap,
    this.color = _profileAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.48 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _exportScopes = [
  'Profile data',
  'Onboarding setup',
  'Routine data',
  'Goals data',
  'Tracker data',
  'Money System data',
  'Coach sessions',
  'Mind Notebook',
  'Uploaded files metadata',
  'All data',
];

const _deleteScopes = [
  'Mind Notebook notes',
  'Coach sessions',
  'Tracker history',
  'Routine history',
  'Money System history',
  'Uploaded files metadata',
];

const _helpTopics = [
  'Getting started',
  'Routine setup',
  'Tracker permissions',
  'Money System',
  'Coach privacy',
  'Mind Notebook privacy',
  'Export data',
  'Delete account',
];
