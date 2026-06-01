import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/core/widgets/liquid_inputs.dart';
import 'package:optivus/features/profile/providers/profile_navigation_provider.dart';
import 'package:optivus/models/coach_models.dart';
import 'package:optivus/state/app_state.dart';

class CoachSessionHistoryScreen extends ConsumerWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewSession;

  const CoachSessionHistoryScreen({
    super.key,
    required this.onBack,
    required this.onSelectSession,
    required this.onNewSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(mockCoachProvider);

    return LiquidDetailScaffold(
      eyebrow: 'Coach',
      title: 'Session History',
      subtitle: 'Select, create, export, or delete coach sessions.',
      accentColor: OptivusColors.coachAccent,
      onBack: onBack,
      trailing: LiquidGlassIconButton(
        icon: Icons.add_rounded,
        color: OptivusColors.coachAccent,
        onTap: onNewSession,
      ),
      children: [
        if (sessions.isEmpty)
          LiquidDetailSection(
            children: const [
              Text(
                'No coach sessions yet.',
                style: TextStyle(color: OptivusColors.textSecondary),
              ),
            ],
          )
        else
          ...sessions.map(
            (session) => LiquidDetailSection(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${session.messages.length} messages · ${session.createdAt}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LiquidPill(
                      label: session.type.name,
                      color: OptivusColors.coachAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CoachTextButton(
                      label: 'Select',
                      color: OptivusColors.coachAccent,
                      onTap: () => onSelectSession(session.id),
                    ),
                    _CoachTextButton(
                      label: 'Export',
                      color: OptivusColors.info,
                      onTap: () => _showCoachSheet(
                        context,
                        'Export session',
                        'Coach session export metadata will be stored later. Generated files use Cloudflare R2 or local share.',
                      ),
                    ),
                    _CoachTextButton(
                      label: 'Delete',
                      color: OptivusColors.danger,
                      onTap: () =>
                          _confirmDeleteSession(context, ref, session.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CoachSettingsInlineScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const CoachSettingsInlineScreen({super.key, required this.onBack});

  @override
  ConsumerState<CoachSettingsInlineScreen> createState() =>
      _CoachSettingsInlineScreenState();
}

class _CoachSettingsInlineScreenState
    extends ConsumerState<CoachSettingsInlineScreen> {
  late final TextEditingController _name;
  String _style = 'Supportive';
  String _slipUp = 'Balanced';
  String _voice = 'Text first';
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(mockCoachPreferencesProvider);
    _name = TextEditingController(text: prefs.name);
    _style = prefs.style;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(mockCoachPreferencesProvider);

    return LiquidDetailScaffold(
      eyebrow: 'Coach',
      title: 'Coach Settings',
      subtitle: 'Persona, style, slip-up handling, voice, and context access.',
      accentColor: OptivusColors.coachAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Persona',
          children: [
            LiquidInput(
              controller: _name,
              labelText: 'Coach name',
              accentColor: OptivusColors.coachAccent,
            ),
            const SizedBox(height: 14),
            _CoachSegment(
              label: 'Coach style',
              options: const ['Supportive', 'Direct', 'Balanced'],
              selected: _style,
              onSelected: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: 14),
            _CoachSegment(
              label: 'Slip-up handling',
              options: const ['Gentle', 'Balanced', 'Strict'],
              selected: _slipUp,
              onSelected: (v) => setState(() => _slipUp = v),
            ),
            const SizedBox(height: 14),
            _CoachSegment(
              label: 'Voice preference',
              options: const ['Text first', 'Voice later', 'Muted'],
              selected: _voice,
              onSelected: (v) => setState(() => _voice = v),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Context access',
          children: [
            LiquidActionRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Open Profile Privacy',
              subtitle:
                  'Profile controls what Coach can read. Mind Notes are selected-only.',
              accentColor: OptivusColors.coachAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToProfile();
                ref
                    .read(profileDetailViewRequestProvider.notifier)
                    .state = const ProfileDetailTarget(
                  view: ProfileDetailView.privacySecurity,
                );
              },
            ),
            Text(
              'Current: routine ${prefs.allowRoutineContext ? 'on' : 'off'}, tracker ${prefs.allowTrackerContext ? 'on' : 'off'}, goals ${prefs.allowGoalsContext ? 'on' : 'off'}, selected notes only ${prefs.shareSelectedNotesOnly ? 'on' : 'off'}.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ),
        if (_saved)
          LiquidDetailSection(
            tint: OptivusColors.success.withValues(alpha: 0.08),
            children: const [
              Text(
                'Settings saved locally.',
                style: TextStyle(
                  color: OptivusColors.success,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        _CoachPrimaryButton(
          label: 'Save settings',
          onTap: () {
            ref
                .read(mockCoachPreferencesProvider.notifier)
                .updatePreferences(
                  prefs.copyWith(
                    name: _name.text.trim().isEmpty
                        ? prefs.name
                        : _name.text.trim(),
                    style: _style,
                  ),
                );
            ref
                .read(mockUserProfileProvider.notifier)
                .updateCoachPreferences(
                  coachName: _name.text.trim().isEmpty
                      ? prefs.name
                      : _name.text.trim(),
                  coachStyle: _style,
                  slipUpStyle: _slipUp,
                );
            setState(() => _saved = true);
          },
        ),
      ],
    );
  }
}

class CoachNewSessionScreen extends StatelessWidget {
  final VoidCallback onBack;
  final ValueChanged<CoachSessionOption> onCreate;

  const CoachNewSessionScreen({
    super.key,
    required this.onBack,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidDetailScaffold(
      eyebrow: 'Coach',
      title: 'New Session',
      subtitle: 'Create and select a local Coach session.',
      accentColor: OptivusColors.coachAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Session type',
          children: _sessionOptions
              .map(
                (option) => LiquidActionRow(
                  icon: option.icon,
                  title: option.title,
                  subtitle: option.subtitle,
                  accentColor: OptivusColors.coachAccent,
                  onTap: () => onCreate(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class CoachPrivacyDataScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const CoachPrivacyDataScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiquidDetailScaffold(
      eyebrow: 'Coach',
      title: 'Privacy / Export / Delete',
      subtitle: 'Coach uses only allowed contexts and selected Mind Notes.',
      accentColor: OptivusColors.coachAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Context reminder',
          children: const [
            Text(
              'Coach can use routine data, tracker data, goal data, screen-time data, money data, and selected mind notes only when Profile privacy allows it.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Actions',
          children: [
            LiquidActionRow(
              icon: Icons.download_outlined,
              title: 'Export coach sessions',
              subtitle:
                  'Cloudflare R2 or local share later. No Firebase Storage.',
              accentColor: OptivusColors.info,
              onTap: () => _showCoachSheet(
                context,
                'Export coach sessions',
                'Export request metadata can be stored later; generated files use Cloudflare R2 or local share.',
              ),
            ),
            LiquidActionRow(
              icon: Icons.delete_outline_rounded,
              title: 'Delete coach sessions',
              subtitle: 'Confirmation required before clearing local sessions.',
              accentColor: OptivusColors.danger,
              destructive: true,
              onTap: () => _confirmDeleteAllSessions(context, ref),
            ),
            LiquidActionRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Profile Privacy & Security',
              subtitle: 'Edit Coach Context Access in Profile.',
              accentColor: OptivusColors.coachAccent,
              onTap: () {
                ref.read(appNavigationProvider.notifier).goToProfile();
                ref
                    .read(profileDetailViewRequestProvider.notifier)
                    .state = const ProfileDetailTarget(
                  view: ProfileDetailView.privacySecurity,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class CoachSessionOption {
  final String title;
  final String subtitle;
  final CoachSessionType type;
  final IconData icon;

  const CoachSessionOption({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.icon,
  });
}

const _sessionOptions = [
  CoachSessionOption(
    title: 'Today\'s Plan',
    subtitle: 'Audit today and decide the next move.',
    type: CoachSessionType.todayPlan,
    icon: Icons.wb_sunny_outlined,
  ),
  CoachSessionOption(
    title: 'Recover from slip-up',
    subtitle: 'Get back into the system without spiral thinking.',
    type: CoachSessionType.recoverMissedTask,
    icon: Icons.healing_outlined,
  ),
  CoachSessionOption(
    title: 'Improve Routine',
    subtitle: 'Tune timeline blocks and friction points.',
    type: CoachSessionType.improveRoutine,
    icon: Icons.tune_rounded,
  ),
  CoachSessionOption(
    title: 'Calm / Stress',
    subtitle: 'Downshift mental load and choose a tiny next step.',
    type: CoachSessionType.calmSupport,
    icon: Icons.self_improvement_rounded,
  ),
  CoachSessionOption(
    title: 'Focus',
    subtitle: 'Protect the next deep work block.',
    type: CoachSessionType.focusSupport,
    icon: Icons.center_focus_strong_rounded,
  ),
  CoachSessionOption(
    title: 'Money discipline',
    subtitle: 'Review saving proof and spending triggers.',
    type: CoachSessionType.trackerInsight,
    icon: Icons.savings_outlined,
  ),
  CoachSessionOption(
    title: 'Goal review',
    subtitle: 'Audit daily proofs and identity direction.',
    type: CoachSessionType.goalReview,
    icon: Icons.flag_outlined,
  ),
  CoachSessionOption(
    title: 'Custom',
    subtitle: 'Start an open Coach session.',
    type: CoachSessionType.askAnything,
    icon: Icons.add_circle_outline_rounded,
  ),
];

class _CoachSegment extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CoachSegment({
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = selected == option;
            return GestureDetector(
              onTap: () => onSelected(option),
              child: LiquidPill(
                label: option,
                color: OptivusColors.coachAccent,
                filled: active,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CoachPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CoachPrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: OptivusColors.coachAccent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.coachAccent.withValues(alpha: 0.22),
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
    );
  }
}

class _CoachTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CoachTextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
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

void _confirmDeleteSession(
  BuildContext context,
  WidgetRef ref,
  String sessionId,
) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Delete session?'),
      content: const Text('This clears the selected local coach session.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(mockCoachProvider.notifier).deleteSession(sessionId);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _confirmDeleteAllSessions(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Delete all coach sessions?'),
      content: const Text(
        'This clears all local coach sessions after confirmation.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(mockCoachProvider.notifier).replaceWith(const []);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete all'),
        ),
      ],
    ),
  );
}

void _showCoachSheet(BuildContext context, String title, String body) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
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
              backgroundColor: OptivusColors.coachAccent,
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
  );
}
