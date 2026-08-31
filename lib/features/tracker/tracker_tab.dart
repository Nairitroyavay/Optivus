import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/backend_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/utils/currency_formatter.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/tracker/bad_habits/bad_habit_tracker_screen.dart';
import 'package:optivus/features/tracker/focus/focus_timer_screen.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/tracker/fitness/fitness_center_screen.dart';
import 'package:optivus/features/tracker/hydration/hydration_tracker_screen.dart';
import 'package:optivus/features/tracker/meditation/meditation_tracker_screen.dart';
import 'package:optivus/features/tracker/money/global_money_setup_screen.dart';
import 'package:optivus/features/tracker/money/money_system_screen.dart';
import 'package:optivus/features/tracker/money/money_system_widgets.dart';
import 'package:optivus/features/tracker/providers/tracker_navigation_provider.dart';
import 'package:optivus/features/tracker/providers/tracker_settings_provider.dart';
import 'package:optivus/features/tracker/screens/health_connect_setup_screen.dart';
import 'package:optivus/features/tracker/screens/location_mapbox_setup_screen.dart';
import 'package:optivus/features/tracker/screens/tracker_activation_screen.dart';
import 'package:optivus/features/tracker/screens/tracker_history_screen.dart';
import 'package:optivus/features/tracker/screens/tracker_settings_screen.dart';
import 'package:optivus/features/tracker/screens/usage_access_setup_screen.dart';
import 'package:optivus/features/tracker/sleep/sleep_tracker_screen.dart';
import 'package:optivus/features/tracker/nutrition/nutrition_tracker_screen.dart';
import 'package:optivus/features/tracker/screen_time/screen_time_screen.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/region_settings_provider.dart';

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  String _activeMetricView = 'Daily';
  TrackerDetailTarget _activeDetail = TrackerDetailTarget.none;

  TrackerDetailView get _activeDetailView => _activeDetail.view;

  void _openDetail(TrackerDetailTarget target) {
    if (target.view == TrackerDetailView.none) {
      _closeDetail();
      return;
    }
    setState(() => _activeDetail = target);
  }

  void _openView(TrackerDetailView view) {
    _openDetail(TrackerDetailTarget.view(view));
  }

  void _closeDetail() {
    setState(() => _activeDetail = TrackerDetailTarget.none);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      routineNotifierProvider.select((s) => s.activeTrackerLaunchIntent),
      (prev, intent) {
        if (intent != null && intent.trackerType == TrackerType.money) {
          if (_activeDetailView != TrackerDetailView.money) {
            _openView(TrackerDetailView.money);
          }
        } else if (intent != null &&
            intent.trackerType == TrackerType.meditation) {
          if (_activeDetailView != TrackerDetailView.meditation) {
            _openView(TrackerDetailView.meditation);
          }
        } else if (intent != null &&
            intent.trackerType == TrackerType.workout) {
          if (_activeDetailView != TrackerDetailView.fitness) {
            _openView(TrackerDetailView.fitness);
          }
        } else if (intent != null && intent.trackerType == TrackerType.focus) {
          if (_activeDetailView != TrackerDetailView.focusTimer) {
            _openView(TrackerDetailView.focusTimer);
          }
        }
      },
    );
    ref.listen(trackerDetailViewRequestProvider, (prev, request) {
      if (request.view == TrackerDetailView.none) return;
      _openDetail(request);
      ref.read(trackerDetailViewRequestProvider.notifier).state =
          TrackerDetailTarget.none;
    });
    final pendingDetailRequest = ref.watch(trackerDetailViewRequestProvider);
    if (pendingDetailRequest.view != TrackerDetailView.none &&
        _activeDetailView != pendingDetailRequest.view) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openDetail(pendingDetailRequest);
        ref.read(trackerDetailViewRequestProvider.notifier).state =
            TrackerDetailTarget.none;
      });
    }

    final bottomReserve = liquidTabBarReserve(context);
    final trackerState = ref.watch(mockTrackerProvider);
    final region = ref.watch(regionSettingsProvider);
    final snapshot = _TrackerUiSnapshot.fromState(trackerState, region);

    return PopScope(
      canPop: _activeDetailView == TrackerDetailView.none,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeDetailView != TrackerDetailView.none) {
          _closeDetail();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: switch (_activeDetailView) {
            TrackerDetailView.meditation => MeditationTrackerScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.money => MoneySystemScreen(onBack: _closeDetail),
            TrackerDetailView.fitness => FitnessCenterScreen(
              onBack: _closeDetail,
              onOpenDetail: _openDetail,
            ),
            TrackerDetailView.screenTime => ScreenTimeScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.hydration => HydrationTrackerScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.trackerSettings => TrackerSettingsScreen(
              onBack: _closeDetail,
              onOpenDetail: _openDetail,
            ),
            TrackerDetailView.usageAccessSetup => UsageAccessSetupScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.healthConnectSetup => HealthConnectSetupScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.locationMapboxSetup => LocationMapboxSetupScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.trackerActivation => TrackerActivationScreen(
              onBack: _closeDetail,
              trackerType: _activeDetail.trackerType ?? 'Custom',
              badHabitType: _activeDetail.badHabitType,
              onActivated: (target) {
                if (target.view == TrackerDetailView.none) {
                  _closeDetail();
                } else {
                  _openDetail(target);
                }
              },
            ),
            TrackerDetailView.trackerHistory => TrackerHistoryScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.focusTimer => FocusTimerScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.badHabit => BadHabitTrackerScreen(
              onBack: _closeDetail,
              title: _activeDetail.trackerType ?? 'Smoking',
              badHabitType: _activeDetail.badHabitType ?? 'smoking',
              onOpenDetail: _openDetail,
            ),
            TrackerDetailView.sleep => SleepTrackerScreen(onBack: _closeDetail),
            TrackerDetailView.nutrition => NutritionTrackerScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.globalMoneySetup => GlobalMoneySetupScreen(
              onBack: _closeDetail,
            ),
            TrackerDetailView.none => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _buildHeader(context),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPeriodSelector(),
                        const SizedBox(height: 20),
                        _buildProgressCarousel(snapshot),
                        const SizedBox(height: 28),
                        _buildTodayProgressHero(context, snapshot),
                        const SizedBox(height: 36),
                        const TrackerSectionHeader(title: 'ACTIVE TRACKERS'),
                        _buildActiveTrackers(snapshot),
                        const SizedBox(height: 32),
                        const TrackerSectionHeader(title: 'DISCOVER TRACKERS'),
                        _buildDiscoverTrackers(),
                        const SizedBox(height: 32),
                        const TrackerSectionHeader(title: 'PHONE DATA SOURCES'),
                        _buildPhoneDataSources(snapshot),
                        const SizedBox(height: 32),
                        const TrackerSectionHeader(title: 'RECENT ACTIVITY'),
                        _buildRecentActivity(snapshot),
                        const SizedBox(height: 48),
                        _buildTrackerSettingsTeaser(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TRACK • MEASURE • IMPROVE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: OptivusColors.sub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tracking Center',
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
          ],
        ),
        TrackerHeaderButton(
          icon: Icons.settings,
          onTap: () => _openView(TrackerDetailView.trackerSettings),
        ),
      ],
    );
  }

  Widget _buildTodayProgressHero(
    BuildContext context,
    _TrackerUiSnapshot snapshot,
  ) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(18),
      radius: 28,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Progress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${snapshot.lifeScorePercent}% Life System Completed\n${snapshot.activeSystemCount} systems active today',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OptivusColors.sub,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      OptivusColors.brandAccent,
                      OptivusColors.roseAccent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OptivusColors.brandAccent.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${snapshot.lifeScorePercent}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              TrackerMetricChip(
                category: 'Mind',
                value: 'Meditation ${snapshot.meditationMinutes}m',
              ),
              TrackerMetricChip(
                category: 'Body',
                value: 'Water ${snapshot.hydrationLabel} / 2.5L',
              ),
              TrackerMetricChip(
                category: 'Focus',
                value: 'Screen time risk ${snapshot.screenRisk}',
              ),
              TrackerMetricChip(
                category: 'Finance',
                value: '${snapshot.todaySavedLabel} saved',
              ),
              TrackerMetricChip(
                category: 'Movement',
                value:
                    '${snapshot.weeklyDistanceLabel} km • ${snapshot.workoutSessionCount} sessions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrackerSegmentedControl(
          segments: const ['Daily', 'Weekly', 'Monthly', 'Yearly'],
          selectedSegment: _activeMetricView,
          onSegmentSelected: (view) {
            setState(() => _activeMetricView = view);
          },
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _periodUnlockCopy(_activeMetricView),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: OptivusColors.sub,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCarousel(_TrackerUiSnapshot snapshot) {
    return _TrackerGraphCarouselCard(
      activePeriod: _activeMetricView,
      snapshot: snapshot,
      showDemoData: ref.watch(fakeDataAllowedProvider),
    );
  }

  Widget _buildActiveTrackers(_TrackerUiSnapshot snapshot) {
    final settings = ref.watch(trackerSettingsProvider);
    final trackers = <_ActiveTrackerConfig>[
      _ActiveTrackerConfig(
        title: 'Meditation',
        status: '${snapshot.meditationMinutes} / 5 min today',
        iconEmoji: '🧘',
        buttonText: 'View',
        accentColor: OptivusColors.purpleAccent,
        activationSource: 'onboarding',
        target: TrackerDetailTarget.view(TrackerDetailView.meditation),
      ),
      _ActiveTrackerConfig(
        title: 'Money System',
        status: '${snapshot.todaySavedLabel} saved today',
        iconEmoji: '💰',
        buttonText: 'View',
        accentColor: OptivusColors.trackerAccent,
        activationSource: 'routine',
        target: TrackerDetailTarget.view(TrackerDetailView.money),
      ),
      _ActiveTrackerConfig(
        title: 'Screen Time',
        status:
            '${snapshot.screenTimeLabel} total\nRisk: ${snapshot.screenRisk}',
        iconEmoji: '📱',
        buttonText: 'View',
        accentColor: OptivusColors.roseAccent,
        activationSource: 'permission',
        target: TrackerDetailTarget.view(TrackerDetailView.screenTime),
      ),
      _ActiveTrackerConfig(
        title: 'Fitness Center',
        status:
            'Walk • Run • Cycling • Workout\n${snapshot.weeklyDistanceLabel} km this week • ${snapshot.workoutSessionCount} sessions',
        iconEmoji: '🏃',
        buttonText: 'Open',
        accentColor: OptivusColors.trackerAccent,
        activationSource: 'body',
        target: TrackerDetailTarget.view(TrackerDetailView.fitness),
      ),
      _ActiveTrackerConfig(
        title: 'Hydration',
        status: '${snapshot.hydrationLabel} / 2.5L',
        iconEmoji: '💧',
        buttonText: '+250ml',
        accentColor: OptivusColors.blueAccent,
        activationSource: 'manual',
        target: TrackerDetailTarget.view(TrackerDetailView.hydration),
      ),
    ];
    final optionalTrackers = <_ActiveTrackerConfig>[
      _ActiveTrackerConfig(
        title: 'Focus Timer',
        status: 'Deep work sessions ready',
        iconEmoji: '🎯',
        buttonText: 'Start',
        accentColor: OptivusColors.trackerAccent,
        activationSource: 'manual',
        target: TrackerDetailTarget.view(TrackerDetailView.focusTimer),
      ),
      _ActiveTrackerConfig(
        title: 'Sleep',
        status: 'Manual sleep log and Health Connect path',
        iconEmoji: '😴',
        buttonText: 'Log',
        accentColor: OptivusColors.purpleAccent,
        activationSource: 'manual',
        target: TrackerDetailTarget.view(TrackerDetailView.sleep),
      ),
      _ActiveTrackerConfig(
        title: 'Nutrition',
        status: 'Meals, calories, protein, and source',
        iconEmoji: '🍽',
        buttonText: 'Open',
        accentColor: OptivusColors.roseAccent,
        activationSource: 'routine',
        target: TrackerDetailTarget.view(TrackerDetailView.nutrition),
      ),
      ...['Smoking', 'Alcohol', 'Junk Food', 'Custom Bad Habit']
          .where((title) => settings.activeTrackers[title] == true)
          .map(
            (title) => _ActiveTrackerConfig(
              title: title,
              status: 'Check-in ready · avoided, craving, relapse',
              iconEmoji: _badHabitEmoji(title),
              buttonText: 'Check in',
              accentColor: OptivusColors.danger,
              activationSource: 'setup',
              target: TrackerDetailTarget(
                view: TrackerDetailView.badHabit,
                trackerType: title,
                badHabitType: _badHabitKey(title),
              ),
            ),
          ),
    ];

    for (final tracker in optionalTrackers) {
      if (settings.activeTrackers[tracker.title] == true &&
          !trackers.any((item) => item.title == tracker.title)) {
        trackers.add(tracker);
      }
    }

    return Column(
      children: trackers
          .map(
            (tracker) => TrackerActiveCard(
              title: tracker.title,
              status: tracker.status,
              iconEmoji: tracker.iconEmoji,
              buttonText: tracker.buttonText,
              accentColor: tracker.accentColor,
              onAction: () => _openDetail(tracker.target),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDiscoverTrackers() {
    final discoverGroups = [
      _DiscoverTrackerGroup(
        title: 'Mind',
        trackers: const [
          _DiscoverTrackerConfig(
            title: 'Journaling',
            description: 'Not set up\nTrack thoughts and mood.',
            iconEmoji: '✍️',
          ),
        ],
      ),
      _DiscoverTrackerGroup(
        title: 'Focus',
        trackers: const [
          _DiscoverTrackerConfig(
            title: 'Focus Timer',
            description: 'Not set up\nTrack deep work sessions.',
            iconEmoji: '🎯',
          ),
        ],
      ),
      _DiscoverTrackerGroup(
        title: 'Body',
        trackers: const [
          _DiscoverTrackerConfig(
            title: 'Workout',
            description: 'Not set up\nTrack workouts, sets, progress.',
            iconEmoji: '🏋️',
          ),
          _DiscoverTrackerConfig(
            title: 'Nutrition',
            description: 'Not set up\nTrack meals, protein, calories.',
            iconEmoji: '🍽',
          ),
          _DiscoverTrackerConfig(
            title: 'Sleep',
            description: 'Not set up\nTrack sleep quality and energy.',
            iconEmoji: '😴',
          ),
          _DiscoverTrackerConfig(
            title: 'Skin Care',
            description: 'Not set up\nTrack morning/night routine.',
            iconEmoji: '✨',
          ),
        ],
      ),
      _DiscoverTrackerGroup(
        title: 'Finance',
        trackers: const [
          _DiscoverTrackerConfig(
            title: 'Junk Food',
            description: 'Not set up\nTrack cravings and money saved.',
            iconEmoji: '🍔',
          ),
        ],
      ),
      _DiscoverTrackerGroup(
        title: 'Bad Habits',
        trackers: const [
          _DiscoverTrackerConfig(
            title: 'Smoking',
            description: 'Not set up\nTrack cravings, relapses, money saved.',
            iconEmoji: '🚭',
          ),
          _DiscoverTrackerConfig(
            title: 'Alcohol',
            description: 'Not set up\nTrack clean days and recovery.',
            iconEmoji: '🍺',
          ),
          _DiscoverTrackerConfig(
            title: 'Custom Bad Habit',
            description: 'Not set up\nTrack any habit you want to quit.',
            iconEmoji: '🚫',
          ),
        ],
      ),
      _DiscoverTrackerGroup(
        title: 'Skill / Growth',
        trackers: const [
          _DiscoverTrackerConfig(
            title: 'Reading',
            description: 'Not set up\nTrack pages and consistency.',
            iconEmoji: '📚',
          ),
          _DiscoverTrackerConfig(
            title: 'Language Learning',
            description: 'Not set up\nTrack learning practice.',
            iconEmoji: '🗣️',
          ),
          _DiscoverTrackerConfig(
            title: 'Skill Practice',
            description: 'Not set up\nTrack daily skill progress.',
            iconEmoji: '🛠️',
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: discoverGroups
              .map((group) => _TrackerCategoryChip(label: group.title))
              .toList(),
        ),
        const SizedBox(height: 16),
        ...discoverGroups.map(
          (group) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrackerGroupLabel(label: group.title),
                const SizedBox(height: 10),
                _buildDiscoverGrid(group.trackers),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverGrid(List<_DiscoverTrackerConfig> discoverTrackers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 640;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useTwoColumns ? 2 : 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent:
                _discoverTileWidth(constraints.maxWidth, useTwoColumns) < 300
                ? 174
                : (useTwoColumns ? 150 : 142),
          ),
          itemCount: discoverTrackers.length,
          itemBuilder: (context, index) {
            final tracker = discoverTrackers[index];
            return TrackerDiscoverCard(
              title: tracker.title,
              description: tracker.description,
              iconEmoji: tracker.iconEmoji,
              onActivate: () => _openDetail(
                TrackerDetailTarget(
                  view: TrackerDetailView.trackerActivation,
                  trackerType: tracker.title,
                  badHabitType: _badHabitKey(tracker.title),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhoneDataSources(_TrackerUiSnapshot snapshot) {
    return Column(
      children: [
        TrackerDataSourceCard(
          title: 'Screen Time / App Usage',
          subtitle: 'Usage Access needed',
          iconEmoji: '📱',
          status: 'Not connected',
          isConnected: false,
          onConnect: () => _openView(TrackerDetailView.usageAccessSetup),
        ),
        TrackerDataSourceCard(
          title: 'Fitness GPS',
          subtitle: 'Location permission needed',
          iconEmoji: '📍',
          status: 'Not connected',
          isConnected: false,
          onConnect: () => _openView(TrackerDetailView.locationMapboxSetup),
        ),
        TrackerDataSourceCard(
          title: 'Health Connect',
          subtitle: 'Optional health data',
          iconEmoji: '❤️',
          status: 'Not connected',
          isConnected: false,
          onConnect: () => _openView(TrackerDetailView.healthConnectSetup),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            snapshot.screenInsight,
            style: const TextStyle(
              color: OptivusColors.sub,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(_TrackerUiSnapshot snapshot) {
    final activities = <Map<String, Object>>[
      if (snapshot.hasMeditationActivity)
        {
          'title': 'Meditation completed',
          'subtitle': '${snapshot.meditationMinutes} min',
          'color': OptivusColors.purpleAccent,
        },
      if (snapshot.hasSavingsActivity)
        {
          'title': 'Saved ${snapshot.todaySavedLabel}',
          'subtitle': 'Money System',
          'color': OptivusColors.mintAccent,
        },
      if (snapshot.hasHydrationActivity)
        {
          'title': 'Water logged',
          'subtitle': snapshot.hydrationLabel,
          'color': OptivusColors.blueAccent,
        },
      if (snapshot.hasFitnessActivity)
        {
          'title': 'Fitness Center activity',
          'subtitle':
              '${snapshot.weeklyDistanceLabel} km • ${snapshot.workoutSessionCount} sessions',
          'color': OptivusColors.trackerAccent,
        },
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openView(TrackerDetailView.trackerHistory),
      child: TrackerActivityTimeline(activities: activities),
    );
  }

  Widget _buildTrackerSettingsTeaser() {
    return GestureDetector(
      onTap: () => _openView(TrackerDetailView.trackerSettings),
      child: TrackerGlassCard(
        padding: const EdgeInsets.all(20),
        radius: 20,
        opacity: 0.7,
        child: Row(
          children: [
            TrackerHeaderButton(
              icon: Icons.settings,
              onTap: () => _openView(TrackerDetailView.trackerSettings),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracker Settings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: OptivusColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage active trackers, permissions, goals, reminders, and data sources.',
                    style: TextStyle(
                      fontSize: 12,
                      color: OptivusColors.sub,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: OptivusColors.sub,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerGraphCarouselCard extends StatefulWidget {
  final String activePeriod;
  final _TrackerUiSnapshot snapshot;
  final bool showDemoData;

  const _TrackerGraphCarouselCard({
    required this.activePeriod,
    required this.snapshot,
    required this.showDemoData,
  });

  @override
  State<_TrackerGraphCarouselCard> createState() =>
      _TrackerGraphCarouselCardState();
}

class _TrackerGraphCarouselCardState extends State<_TrackerGraphCarouselCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = _TrackerPeriodData.forPeriod(widget.activePeriod);
    final graphs = _buildGraphConfigs(period, widget.snapshot);

    return TrackerGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Column(
        children: [
          SizedBox(
            height: 224,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: graphs.length,
              itemBuilder: (context, index) {
                final graph = graphs[index];
                return _buildInnerGraph(graph: graph, period: period);
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(graphs.length, (index) {
              final isSelected = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected
                      ? OptivusColors.ink
                      : OptivusColors.ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerGraph({
    required _TrackerGraphConfig graph,
    required _TrackerPeriodData period,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                graph.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                  letterSpacing: 0,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: graph.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: graph.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                graph.badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: graph.accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          graph.subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: OptivusColors.sub,
            height: 1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Opacity(
            opacity: period.isLocked ? 0.5 : 1,
            child: _TrackerMiniChart(
              labels: period.labels,
              values: graph.values,
              accentColor: graph.accentColor,
              showLineOverlay: graph.showLineOverlay,
            ),
          ),
        ),
        if (period.isLocked) ...[
          const SizedBox(height: 10),
          _TrackerLockNotice(message: period.unlockCopy),
        ],
      ],
    );
  }

  List<_TrackerGraphConfig> _buildGraphConfigs(
    _TrackerPeriodData period,
    _TrackerUiSnapshot snapshot,
  ) {
    final emptyValues = List<double>.filled(period.labels.length, 0);
    List<double> demoOrEmpty(List<double> values) =>
        widget.showDemoData ? values : emptyValues;

    return [
      _TrackerGraphConfig(
        title: '${period.name} Performance',
        subtitle: widget.showDemoData
            ? 'Energy vs Habits Completed'
            : 'No performance history recorded',
        badgeText: widget.showDemoData ? '+12%' : 'No data',
        accentColor: OptivusColors.trackerAccent,
        values: demoOrEmpty(period.performanceValues),
        showLineOverlay: true,
      ),
      _TrackerGraphConfig(
        title: 'Life Balance',
        subtitle: widget.showDemoData
            ? 'Body 72% • Mind 80% • Focus 45%\nFinance 90% • Growth 60%'
            : 'No balance history recorded',
        badgeText: widget.showDemoData ? 'Stable' : 'No data',
        accentColor: OptivusColors.blueAccent,
        values: demoOrEmpty(period.lifeBalanceValues),
      ),
      _TrackerGraphConfig(
        title: 'Screen Time',
        subtitle:
            '${snapshot.screenTimeLabel} total • Risk: ${snapshot.screenRisk}\n${snapshot.screenInsight}',
        badgeText: widget.showDemoData ? '-45m' : 'No data',
        accentColor: OptivusColors.roseAccent,
        values: demoOrEmpty(period.screenTimeValues),
      ),
      _TrackerGraphConfig(
        title: 'Money Progress',
        subtitle:
            '${snapshot.confirmedSavedLabel} confirmed • ${snapshot.potentialSavedLabel} potential\nNext level: ${snapshot.nextMoneyLevelLabel}',
        badgeText: snapshot.todaySavedLabel,
        accentColor: OptivusColors.mintAccent,
        values: widget.showDemoData
            ? snapshot.moneyValuesForPeriod(period)
            : snapshot.moneyValuesForPeriod(period, allowDemoFallback: false),
      ),
      _TrackerGraphConfig(
        title: 'Movement & Fitness',
        subtitle:
            '${snapshot.weeklyDistanceLabel} km this week • ${snapshot.activeMinutesLabel} active\n${snapshot.workoutSessionCount} sessions • Best pace ${snapshot.bestPaceLabel}',
        badgeText: '${snapshot.weeklyGoalProgressPercent}%',
        accentColor: OptivusColors.trackerAccent,
        values: demoOrEmpty(period.movementValues),
      ),
      _TrackerGraphConfig(
        title: 'Consistency',
        subtitle:
            'Meditation ${snapshot.meditationStreakDays}d • Saving ${snapshot.savingStreakDays}d\nWater ${snapshot.waterStreakDays}d • Workout ${snapshot.workoutStreakDays}d',
        badgeText: widget.showDemoData ? 'On track' : 'No data',
        accentColor: OptivusColors.purpleAccent,
        values: demoOrEmpty(period.consistencyValues),
      ),
    ];
  }
}

String _periodUnlockCopy(String period) {
  return switch (period) {
    'Weekly' => 'Complete 7 days to unlock your first weekly review.',
    'Monthly' => 'Complete 30 days to unlock monthly insights.',
    'Yearly' => 'Long-term review unlocks after consistent usage.',
    _ => 'Daily is available immediately.',
  };
}

double _discoverTileWidth(double maxWidth, bool useTwoColumns) {
  if (!useTwoColumns) return maxWidth;
  return (maxWidth - 12) / 2;
}

String? _badHabitKey(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('smoking')) return 'smoking';
  if (normalized.contains('alcohol')) return 'alcohol';
  if (normalized.contains('junk')) return 'junk_food';
  if (normalized.contains('custom bad')) return 'custom';
  return null;
}

String _badHabitEmoji(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('alcohol')) return '🍺';
  if (normalized.contains('junk')) return '🍔';
  if (normalized.contains('custom')) return '🚫';
  return '🚭';
}

class _TrackerUiSnapshot {
  final int hydrationMl;
  final int meditationMinutes;
  final int totalScreenMinutes;
  final String screenRisk;
  final String screenInsight;
  final double todaySaved;
  final double confirmedSaved;
  final double potentialSaved;
  final int savingStreakDays;
  final double weeklyDistanceKm;
  final double longestDistanceKm;
  final double bestPaceMinutesPerKm;
  final int activeMinutesThisWeek;
  final int workoutSessionCount;
  final int lifeScorePercent;
  final int activeSystemCount;
  final int waterStreakDays;
  final int workoutStreakDays;
  final int meditationStreakDays;
  final bool hasMeditationActivity;
  final bool hasSavingsActivity;
  final bool hasHydrationActivity;
  final bool hasFitnessActivity;
  final double nextMoneyLevel;
  final List<SavingEntry> savingsEntries;
  final RegionSettings regionSettings;

  const _TrackerUiSnapshot({
    required this.hydrationMl,
    required this.meditationMinutes,
    required this.totalScreenMinutes,
    required this.screenRisk,
    required this.screenInsight,
    required this.todaySaved,
    required this.confirmedSaved,
    required this.potentialSaved,
    required this.savingStreakDays,
    required this.weeklyDistanceKm,
    required this.longestDistanceKm,
    required this.bestPaceMinutesPerKm,
    required this.activeMinutesThisWeek,
    required this.workoutSessionCount,
    required this.lifeScorePercent,
    required this.activeSystemCount,
    required this.waterStreakDays,
    required this.workoutStreakDays,
    required this.meditationStreakDays,
    required this.hasMeditationActivity,
    required this.hasSavingsActivity,
    required this.hasHydrationActivity,
    required this.hasFitnessActivity,
    required this.nextMoneyLevel,
    required this.savingsEntries,
    required this.regionSettings,
  });

  factory _TrackerUiSnapshot.fromState(
    MockTrackerState state,
    RegionSettings regionSettings,
  ) {
    final hydrationMl = state.hydrationLogs.fold<int>(
      0,
      (total, log) => total + log.amountMl,
    );

    int meditationMinutes = 0;
    for (final session in state.trackerSessions) {
      final title = session.title.toLowerCase();
      final category = session.category.toLowerCase();
      if (title.contains('meditat') || category == 'mind') {
        meditationMinutes = session.value.clamp(0, 5).toInt();
        break;
      }
    }

    final screenMinutes = state.screenTimeApps.fold<int>(
      0,
      (total, app) => total + app.durationMinutes,
    );
    final screenRisk = _highestScreenRisk(state.screenTimeApps);
    final topScreenApp = state.screenTimeApps.isEmpty
        ? null
        : ([
                ...state.screenTimeApps,
              ]..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes)))
              .first;
    final screenInsight = topScreenApp == null
        ? 'No screen activity recorded'
        : '${topScreenApp.name} ${_formatMinutes(topScreenApp.durationMinutes)} → ${topScreenApp.distractionRisk.toLowerCase()} distraction risk';

    final today = DateTime.now();
    final todayKey = moneyDateKey(today);

    final confirmedEntries = state.savingsEntries
        .where((entry) => entry.isConfirmed)
        .toList(growable: false);
    final todayConfirmedEntries = confirmedEntries
        .where((entry) => entry.dateKey == todayKey)
        .toList(growable: false);
    final todaySaved = todayConfirmedEntries.isEmpty
        ? 0.0
        : todayConfirmedEntries.fold<double>(
            0,
            (total, entry) => total + entry.amount,
          );
    final confirmedSaved = state.moneyGoal.totalConfirmedSaved;
    final potentialSaved = state.moneyGoal.totalPotentialSaved;

    final activities = state.fitnessActivities;
    final weeklyDistanceKm = activities.fold<double>(
      0,
      (total, activity) => total + activity.distanceKm,
    );
    final longestDistanceKm = activities.isEmpty
        ? 0.0
        : activities
              .map((activity) => activity.distanceKm)
              .reduce((a, b) => a > b ? a : b);
    final validPaces = activities
        .map((activity) => activity.paceMinutesPerKm)
        .where((pace) => pace > 0)
        .toList(growable: false);
    final bestPaceMinutesPerKm = validPaces.isEmpty
        ? 0.0
        : validPaces.reduce((a, b) => a < b ? a : b);
    final activeMinutesThisWeek = activities.fold<int>(
      0,
      (total, activity) => total + activity.movingDuration.inMinutes,
    );
    final workoutSessionCount = activities.length;
    final activeSystemCount = [
      state.hydrationLogs.isNotEmpty,
      activities.isNotEmpty,
      state.trackerSessions.isNotEmpty,
      state.savingsEntries.isNotEmpty,
      state.screenTimeApps.isNotEmpty,
    ].where((active) => active).length;

    final lifeScorePercent = (activeSystemCount / 5 * 100).round();

    return _TrackerUiSnapshot(
      hydrationMl: hydrationMl,
      meditationMinutes: meditationMinutes,
      totalScreenMinutes: screenMinutes,
      screenRisk: screenRisk,
      screenInsight: screenInsight,
      todaySaved: todaySaved,
      confirmedSaved: confirmedSaved,
      potentialSaved: potentialSaved,
      savingStreakDays: state.moneyGoal.streakDays,
      weeklyDistanceKm: weeklyDistanceKm,
      longestDistanceKm: longestDistanceKm,
      bestPaceMinutesPerKm: bestPaceMinutesPerKm,
      activeMinutesThisWeek: activeMinutesThisWeek,
      workoutSessionCount: workoutSessionCount,
      lifeScorePercent: lifeScorePercent,
      activeSystemCount: activeSystemCount,
      waterStreakDays: state.hydrationLogs.length,
      workoutStreakDays: activities.length,
      meditationStreakDays: meditationMinutes > 0 ? 1 : 0,
      hasMeditationActivity: meditationMinutes > 0,
      hasSavingsActivity: state.savingsEntries.isNotEmpty,
      hasHydrationActivity: state.hydrationLogs.isNotEmpty,
      hasFitnessActivity: activities.isNotEmpty,
      nextMoneyLevel: state.moneyGoal.nextLevelAmount,
      savingsEntries: state.savingsEntries,
      regionSettings: regionSettings,
    );
  }

  String get hydrationLabel => _formatLiters(hydrationMl);
  String get screenTimeLabel => _formatMinutes(totalScreenMinutes);
  String get todaySavedLabel => formatMoney(todaySaved, regionSettings);
  String get confirmedSavedLabel => formatMoney(confirmedSaved, regionSettings);
  String get potentialSavedLabel => formatMoney(potentialSaved, regionSettings);
  String get weeklyDistanceLabel => _formatDistance(weeklyDistanceKm);
  String get longestDistanceLabel => _formatDistance(longestDistanceKm);
  String get bestPaceLabel =>
      bestPaceMinutesPerKm <= 0 ? '—' : _formatPace(bestPaceMinutesPerKm);
  String get activeMinutesLabel => '${activeMinutesThisWeek}m';
  int get weeklyGoalProgressPercent =>
      ((weeklyDistanceKm / 15).clamp(0.0, 1.0) * 100).round();
  String get nextMoneyLevelLabel => formatMoney(nextMoneyLevel, regionSettings);

  List<double> moneyValuesForPeriod(
    _TrackerPeriodData period, {
    bool allowDemoFallback = true,
  }) {
    if (savingsEntries.isEmpty) {
      return List<double>.filled(
        period.labels.length,
        allowDemoFallback ? 0.05 : 0,
      );
    }

    final now = DateTime.now();
    final totals = switch (period.name) {
      'Weekly' => _totalsForDailyWindow(
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
        7,
      ),
      'Monthly' => List.generate(4, (index) {
        final end = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: (3 - index) * 7));
        final start = end.subtract(const Duration(days: 6));
        return _confirmedBetween(start, end);
      }),
      'Yearly' => List.generate(12, (index) {
        final month = DateTime(now.year, index + 1);
        final nextMonth = index == 11
            ? DateTime(now.year + 1)
            : DateTime(now.year, index + 2);
        return _confirmedBetween(
          month,
          nextMonth.subtract(const Duration(days: 1)),
        );
      }),
      _ => _dailyPartsForToday(now),
    };

    final maxValue = totals.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    if (maxValue <= 0) return List<double>.filled(period.labels.length, 0.05);
    return totals
        .map((value) => (value / maxValue).clamp(0.05, 1.0).toDouble())
        .toList(growable: false);
  }

  List<double> _totalsForDailyWindow(DateTime start, int days) {
    return List.generate(days, (index) {
      final date = start.add(Duration(days: index));
      final key = moneyDateKey(date);
      return savingsEntries
          .where((entry) => entry.dateKey == key && entry.isConfirmed)
          .fold(0.0, (sum, entry) => sum + entry.amount);
    });
  }

  List<double> _dailyPartsForToday(DateTime now) {
    final todayKey = moneyDateKey(now);
    final buckets = List<double>.filled(4, 0);
    for (final entry in savingsEntries) {
      if (!entry.isConfirmed || entry.dateKey != todayKey) continue;
      final hour = entry.createdAt.hour;
      final index = hour < 12
          ? 0
          : hour < 17
          ? 1
          : hour < 21
          ? 2
          : 3;
      buckets[index] += entry.amount;
    }
    return buckets;
  }

  double _confirmedBetween(DateTime start, DateTime end) {
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return savingsEntries
        .where((entry) {
          if (!entry.isConfirmed) return false;
          final entryDate = DateTime(
            entry.createdAt.year,
            entry.createdAt.month,
            entry.createdAt.day,
          );
          return !entryDate.isBefore(startOnly) && !entryDate.isAfter(endOnly);
        })
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }
}

class _ActiveTrackerConfig {
  final String title;
  final String status;
  final String iconEmoji;
  final String buttonText;
  final Color accentColor;
  final String activationSource;
  final TrackerDetailTarget target;

  const _ActiveTrackerConfig({
    required this.title,
    required this.status,
    required this.iconEmoji,
    required this.buttonText,
    required this.accentColor,
    required this.activationSource,
    required this.target,
  });
}

class _DiscoverTrackerGroup {
  final String title;
  final List<_DiscoverTrackerConfig> trackers;

  const _DiscoverTrackerGroup({required this.title, required this.trackers});
}

class _DiscoverTrackerConfig {
  final String title;
  final String description;
  final String iconEmoji;

  const _DiscoverTrackerConfig({
    required this.title,
    required this.description,
    required this.iconEmoji,
  });
}

class _TrackerGraphConfig {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color accentColor;
  final List<double> values;
  final bool showLineOverlay;

  const _TrackerGraphConfig({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.accentColor,
    required this.values,
    this.showLineOverlay = false,
  });
}

class _TrackerPeriodData {
  final String name;
  final List<String> labels;
  final bool isLocked;
  final String unlockCopy;
  final List<double> performanceValues;
  final List<double> lifeBalanceValues;
  final List<double> screenTimeValues;
  final List<double> moneyValues;
  final List<double> movementValues;
  final List<double> consistencyValues;

  const _TrackerPeriodData({
    required this.name,
    required this.labels,
    required this.isLocked,
    required this.unlockCopy,
    required this.performanceValues,
    required this.lifeBalanceValues,
    required this.screenTimeValues,
    required this.moneyValues,
    required this.movementValues,
    required this.consistencyValues,
  });

  factory _TrackerPeriodData.forPeriod(String period) {
    return switch (period) {
      'Weekly' => const _TrackerPeriodData(
        name: 'Weekly',
        labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        isLocked: true,
        unlockCopy: 'Complete 7 days to unlock your first weekly review.',
        performanceValues: [0.48, 0.58, 0.72, 0.62, 0.78, 0.66, 0.74],
        lifeBalanceValues: [0.72, 0.80, 0.45, 0.90, 0.60, 0.68, 0.75],
        screenTimeValues: [0.82, 0.76, 0.68, 0.61, 0.58, 0.52, 0.49],
        moneyValues: [0.35, 0.42, 0.50, 0.56, 0.64, 0.72, 0.80],
        movementValues: [0.30, 0.44, 0.52, 0.61, 0.72, 0.68, 0.78],
        consistencyValues: [0.55, 0.65, 0.70, 0.76, 0.82, 0.80, 0.86],
      ),
      'Monthly' => const _TrackerPeriodData(
        name: 'Monthly',
        labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
        isLocked: true,
        unlockCopy: 'Complete 30 days to unlock monthly insights.',
        performanceValues: [0.52, 0.60, 0.73, 0.82],
        lifeBalanceValues: [0.62, 0.68, 0.74, 0.79],
        screenTimeValues: [0.78, 0.70, 0.62, 0.56],
        moneyValues: [0.38, 0.52, 0.68, 0.84],
        movementValues: [0.42, 0.57, 0.66, 0.76],
        consistencyValues: [0.58, 0.68, 0.78, 0.88],
      ),
      'Yearly' => const _TrackerPeriodData(
        name: 'Yearly',
        labels: [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ],
        isLocked: true,
        unlockCopy: 'Long-term review unlocks after consistent usage.',
        performanceValues: [
          0.34,
          0.40,
          0.45,
          0.52,
          0.58,
          0.62,
          0.66,
          0.70,
          0.73,
          0.78,
          0.82,
          0.86,
        ],
        lifeBalanceValues: [
          0.48,
          0.52,
          0.56,
          0.60,
          0.64,
          0.70,
          0.68,
          0.72,
          0.76,
          0.78,
          0.80,
          0.84,
        ],
        screenTimeValues: [
          0.88,
          0.84,
          0.80,
          0.78,
          0.74,
          0.70,
          0.66,
          0.62,
          0.58,
          0.54,
          0.50,
          0.46,
        ],
        moneyValues: [
          0.24,
          0.30,
          0.36,
          0.42,
          0.48,
          0.54,
          0.60,
          0.66,
          0.72,
          0.78,
          0.84,
          0.90,
        ],
        movementValues: [
          0.32,
          0.38,
          0.46,
          0.50,
          0.58,
          0.64,
          0.72,
          0.68,
          0.74,
          0.78,
          0.82,
          0.88,
        ],
        consistencyValues: [
          0.42,
          0.48,
          0.52,
          0.58,
          0.64,
          0.70,
          0.74,
          0.78,
          0.82,
          0.86,
          0.88,
          0.92,
        ],
      ),
      _ => const _TrackerPeriodData(
        name: 'Daily',
        labels: ['Morning', 'Afternoon', 'Evening', 'Night'],
        isLocked: false,
        unlockCopy: 'Daily is available immediately.',
        performanceValues: [0.38, 0.64, 0.82, 0.54],
        lifeBalanceValues: [0.72, 0.80, 0.45, 0.90],
        screenTimeValues: [0.28, 0.52, 0.82, 0.68],
        moneyValues: [0.24, 0.40, 0.68, 0.82],
        movementValues: [0.18, 0.30, 0.74, 0.42],
        consistencyValues: [0.80, 0.65, 0.75, 0.58],
      ),
    };
  }
}

class _TrackerMiniChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color accentColor;
  final bool showLineOverlay;

  const _TrackerMiniChart({
    required this.labels,
    required this.values,
    required this.accentColor,
    this.showLineOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final barWidth = labels.length > 7 ? 10.0 : 18.0;
    final labelSize = labels.length > 7 ? 8.5 : 10.0;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(labels.length, (index) {
                  final value = _valueAt(index);
                  return Expanded(
                    child: Center(
                      child: Container(
                        width: barWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.65),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              if (showLineOverlay)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrackerLineOverlayPainter(
                      values: List.generate(labels.length, _valueAt),
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: labels
              .map(
                (label) => Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: labelSize,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.ink,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  double _valueAt(int index) {
    if (values.length <= index) return 0.5;
    return values[index].clamp(0.12, 1.0).toDouble();
  }
}

class _TrackerLineOverlayPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _TrackerLineOverlayPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final path = Path();
    final segmentWidth = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final normalized = values[i].clamp(0.12, 1.0).toDouble();
      final x = segmentWidth * (i + 0.5);
      final y = size.height * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final rimPaint = Paint()..color = color.withValues(alpha: 0.9);
    for (var i = 0; i < values.length; i++) {
      final normalized = values[i].clamp(0.12, 1.0).toDouble();
      final x = segmentWidth * (i + 0.5);
      final y = size.height * (1 - normalized);
      canvas.drawCircle(Offset(x, y), 4, rimPaint);
      canvas.drawCircle(Offset(x, y), 2.3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackerLineOverlayPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _TrackerCategoryChip extends StatelessWidget {
  final String label;

  const _TrackerCategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OptivusColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TrackerGroupLabel extends StatelessWidget {
  final String label;

  const _TrackerGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: OptivusColors.sub,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _TrackerLockNotice extends StatelessWidget {
  final String message;

  const _TrackerLockNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 15,
            color: OptivusColors.sub.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: OptivusColors.sub,
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _highestScreenRisk(List<dynamic> apps) {
  var hasMedium = false;
  for (final app in apps) {
    final risk = app.distractionRisk.toString().toLowerCase();
    if (risk == 'high') return 'High';
    if (risk == 'medium') hasMedium = true;
  }
  return hasMedium ? 'Medium' : 'High';
}

String _formatLiters(int ml) {
  final liters = ml / 1000;
  return '${liters.toStringAsFixed(liters >= 10 ? 0 : 1)}L';
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours <= 0) return '${remaining}m';
  if (remaining == 0) return '${hours}h';
  return '${hours}h ${remaining}m';
}

String _formatDistance(double distanceKm) {
  if (distanceKm >= 10 || distanceKm == distanceKm.roundToDouble()) {
    return distanceKm.toStringAsFixed(0);
  }
  return distanceKm.toStringAsFixed(1);
}

String _formatPace(double paceMinutesPerKm) {
  var minutes = paceMinutesPerKm.floor();
  var seconds = ((paceMinutesPerKm - minutes) * 60).round();
  if (seconds == 60) {
    minutes += 1;
    seconds = 0;
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
}
