import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/fitness/fitness_activity_detail_screen.dart';
import 'package:optivus/features/tracker/fitness/fitness_activity_session_screen.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/fitness/widgets/fitness_center_widgets.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';

class FitnessCenterScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  final ValueChanged<TrackerDetailTarget>? onOpenDetail;

  const FitnessCenterScreen({super.key, this.onBack, this.onOpenDetail});

  void _showFitnessPanel(
    BuildContext context, {
    required String title,
    required String message,
    List<Widget> actions = const [],
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
            if (actions.isNotEmpty) ...[const SizedBox(height: 14), ...actions],
          ],
        ),
      ),
    );
  }

  void _openSession(
    BuildContext context,
    WidgetRef ref, {
    FitnessActivityType? overrideType,
  }) {
    ref
        .read(fitnessCenterProvider.notifier)
        .startSelectedActivity(overrideType: overrideType);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FitnessActivitySessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final bottomReserve =
        76.0 + media.padding.bottom + media.viewInsets.bottom + 48.0;
    final state = ref.watch(fitnessCenterProvider);
    final notifier = ref.read(fitnessCenterProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: _FitnessHeader(
              onBack: onBack,
              onSettings: () => _showFitnessPanel(
                context,
                title: 'Fitness settings',
                message:
                    'Weekly distance, active minutes, map style, and activity source settings are editable in local mock state.',
              ),
              onHistory: () => onOpenDetail?.call(
                TrackerDetailTarget.view(TrackerDetailView.trackerHistory),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FitnessSummaryCard(state: state),
                  const SizedBox(height: 24),
                  StartActivityCard(
                    state: state,
                    onSelectType: notifier.selectActivityType,
                    onSelectMapStyle: notifier.selectMapStyle,
                    onStart: () => _openSession(context, ref),
                    onStartIndoor: () {
                      final selected = ref
                          .read(fitnessCenterProvider)
                          .selectedActivityType;
                      final type = selected.isOutdoor
                          ? FitnessActivityType.indoorWalk
                          : selected;
                      _openSession(context, ref, overrideType: type);
                    },
                  ),
                  const SizedBox(height: 28),
                  const TrackerSectionHeader(title: 'ACTIVITY TYPES'),
                  ActivityTypeCards(
                    selectedType: state.selectedActivityType,
                    onSelect: notifier.selectActivityType,
                  ),
                  const SizedBox(height: 28),
                  MovementGraphCard(
                    state: state,
                    onMetricSelected: notifier.selectGraphMetric,
                  ),
                  const SizedBox(height: 28),
                  const TrackerSectionHeader(title: 'RECENT ACTIVITIES'),
                  ...state.recentActivities.map(
                    (activity) => RecentActivityCard(
                      activity: activity,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FitnessActivityDetailScreen(activity: activity),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  PersonalRecordsCard(records: state.records),
                  const SizedBox(height: 24),
                  FitnessGoalsCard(
                    goals: state.goals,
                    onEditGoals: () => _showFitnessPanel(
                      context,
                      title: 'Fitness goals',
                      message:
                          'Current mock goals are distance, active minutes, and workout sessions. Backend persistence will store goal period, target, unit, and progress.',
                    ),
                    onTinyVersion: () => _showFitnessPanel(
                      context,
                      title: 'Tiny version',
                      message:
                          'Tiny workout version selected: 5 minute mobility or indoor walk. Routine can store this as a moved/tiny tracker task.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FitnessInsightsCard(insights: state.insights),
                  const SizedBox(height: 24),
                  FitnessDataSourcesCard(
                    onLocation: () => onOpenDetail?.call(
                      TrackerDetailTarget.view(
                        TrackerDetailView.locationMapboxSetup,
                      ),
                    ),
                    onHealthConnect: () => onOpenDetail?.call(
                      TrackerDetailTarget.view(
                        TrackerDetailView.healthConnectSetup,
                      ),
                    ),
                    onManual: () => _openSession(
                      context,
                      ref,
                      overrideType: FitnessActivityType.freeWorkout,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitnessHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  const _FitnessHeader({
    required this.onBack,
    required this.onSettings,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          TrackerHeaderButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FITNESS CENTER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: OptivusColors.sub,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fitness Center',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ) ??
                    const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Move your body. Build your proof.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.sub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TrackerHeaderButton(
          icon: Icons.calendar_month_rounded,
          onTap: onHistory,
        ),
        const SizedBox(width: 8),
        TrackerHeaderButton(icon: Icons.settings_rounded, onTap: onSettings),
      ],
    );
  }
}
