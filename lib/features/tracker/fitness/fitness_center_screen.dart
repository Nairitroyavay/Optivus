import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/fitness/fitness_activity_detail_screen.dart';
import 'package:optivus/features/tracker/fitness/fitness_activity_session_screen.dart';
import 'package:optivus/features/tracker/fitness/providers/fitness_provider.dart';
import 'package:optivus/features/tracker/fitness/widgets/fitness_center_widgets.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/models/tracker_models.dart';

class FitnessCenterScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const FitnessCenterScreen({super.key, this.onBack});

  void _showPlaceholder(BuildContext context, String title) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title is prepared for the next integration pass.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: OptivusColors.trackerAccent,
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
              onSettings: () => _showPlaceholder(context, 'Fitness settings'),
              onHistory: () => _showPlaceholder(context, 'Fitness history'),
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
                    onEditGoals: () => _showPlaceholder(context, 'Edit goals'),
                    onTinyVersion: () =>
                        _showPlaceholder(context, 'Tiny version'),
                  ),
                  const SizedBox(height: 24),
                  FitnessInsightsCard(insights: state.insights),
                  const SizedBox(height: 24),
                  FitnessDataSourcesCard(
                    onLocation: () =>
                        _showPlaceholder(context, 'Location permission'),
                    onHealthConnect: () =>
                        _showPlaceholder(context, 'Health Connect'),
                    onManual: () =>
                        _showPlaceholder(context, 'Manual activity entry'),
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
