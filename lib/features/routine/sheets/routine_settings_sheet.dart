import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';

/// Shows the Routine Settings bottom sheet.
void showRoutineSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoutineSettingsSheetBody(parentRef: ref),
  );
}

class _RoutineSettingsSheetBody extends StatelessWidget {
  final WidgetRef parentRef;
  const _RoutineSettingsSheetBody({required this.parentRef});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0FFF0), Color(0xFFDCFFCC)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              const Row(
                children: [
                  Icon(Icons.settings, size: 22, color: OptivusColors.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Routine Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Settings tiles
              _SettingsTile(
                icon: Icons.calendar_view_week,
                title: 'Week Planner',
                subtitle: 'Monday to Sunday planning',
                onTap: () => _showSubSheet(context, 'Week Planner'),
              ),
              _SettingsTile(
                icon: Icons.schedule,
                title: 'Base Timeline Manager',
                subtitle: 'Classes, Job, Eating, Fixed blocks',
                onTap: () => _showSubSheet(context, 'Base Timeline Manager'),
              ),
              _SettingsTile(
                icon: Icons.psychology,
                title: 'Habit Systems',
                subtitle: 'Good habits, Bad habits, Identity goals',
                onTap: () => _showSubSheet(context, 'Habit Systems'),
              ),
              _SettingsTile(
                icon: Icons.history,
                title: 'Routine History',
                subtitle: 'Completed, Skipped, Missed',
                onTap: () => _showSubSheet(context, 'Routine History'),
              ),

              const SizedBox(height: 16),
              const Text(
                'Timeline View',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Working toggles
              Consumer(
                builder: (ctx, ref, _) {
                  final showFullDay = ref.watch(showFullDayProvider);
                  return _ToggleTile(
                    title: 'Full 24h mode',
                    subtitle: 'Show all 24 hours',
                    value: showFullDay,
                    onChanged: (v) =>
                        ref.read(showFullDayProvider.notifier).state = v,
                  );
                },
              ),
              Consumer(
                builder: (ctx, ref, _) {
                  final showMinuteTicks = ref.watch(showMinuteTicksProvider);
                  return _ToggleTile(
                    title: 'Show minute ticks',
                    subtitle: '1-min and 5-min markers on ruler',
                    value: showMinuteTicks,
                    onChanged: (v) =>
                        ref.read(showMinuteTicksProvider.notifier).state = v,
                  );
                },
              ),
              Consumer(
                builder: (ctx, ref, _) {
                  final compactMode = ref.watch(compactModeProvider);
                  return _ToggleTile(
                    title: 'Compact mode',
                    subtitle: 'Smaller card heights',
                    value: compactMode,
                    onChanged: (v) =>
                        ref.read(compactModeProvider.notifier).state = v,
                  );
                },
              ),

              const SizedBox(height: 16),
              const Text(
                'Automation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.auto_fix_high,
                title: 'AI Suggestions',
                subtitle: 'Get smart suggestions for your routine',
                onTap: () => _showSubSheet(context, 'AI Suggestions'),
              ),
              _SettingsTile(
                icon: Icons.notifications_none,
                title: 'Notifications',
                subtitle: 'Task reminders and alerts',
                onTap: () => _showSubSheet(context, 'Notifications'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubSheet(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OptivusColors.routineAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.construction, size: 20, color: OptivusColors.routineAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$title is coming soon. This feature is part of the full Routine system.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: OptivusColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: OptivusColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: OptivusColors.routineAccent,
            ),
          ],
        ),
      ),
    );
  }
}
