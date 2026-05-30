import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/features/tracker/meditation/meditation_tracker_screen.dart';

enum TrackerDetailView { none, meditation }

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  String _activeMetricView = 'Daily';
  TrackerDetailView _activeDetailView = TrackerDetailView.none;

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title: This detailed tracker screen will be built next.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: OptivusColors.trackerAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomReserve =
        76.0 + media.padding.bottom + media.viewInsets.bottom + 48.0;
    final trackerState = ref.watch(mockTrackerProvider);
    final snapshot = _TrackerUiSnapshot.fromState(trackerState);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: _activeDetailView == TrackerDetailView.meditation
            ? MeditationTrackerScreen(
                onBack: () {
                  setState(() => _activeDetailView = TrackerDetailView.none);
                },
              )
            : Column(
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
          onTap: () => _showPlaceholder('Tracker Settings'),
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
                    colors: [OptivusColors.brandAccent, OptivusColors.roseAccent],
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
                category: 'Walk',
                value: '${snapshot.weeklyDistanceLabel} km',
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
    );
  }

  Widget _buildActiveTrackers(_TrackerUiSnapshot snapshot) {
    final trackers = [
      _ActiveTrackerConfig(
        title: 'Meditation',
        status: '${snapshot.meditationMinutes} / 5 min today',
        iconEmoji: '🧘',
        buttonText: 'View',
        accentColor: OptivusColors.purpleAccent,
        activationSource: 'onboarding',
      ),
      _ActiveTrackerConfig(
        title: 'Money System',
        status: '${snapshot.todaySavedLabel} saved today',
        iconEmoji: '💰',
        buttonText: 'View',
        accentColor: OptivusColors.mintAccent,
        activationSource: 'routine',
      ),
      _ActiveTrackerConfig(
        title: 'Screen Time',
        status:
            '${snapshot.screenTimeLabel} total\nRisk: ${snapshot.screenRisk}',
        iconEmoji: '📱',
        buttonText: 'View',
        accentColor: OptivusColors.roseAccent,
        activationSource: 'mock permission',
      ),
      _ActiveTrackerConfig(
        title: 'Walk / Run',
        status: '${snapshot.weeklyDistanceLabel} km this week',
        iconEmoji: '🏃',
        buttonText: 'Start',
        accentColor: OptivusColors.brandAccent,
        activationSource: 'identity goal',
      ),
      _ActiveTrackerConfig(
        title: 'Hydration',
        status: '${snapshot.hydrationLabel} / 2.5L',
        iconEmoji: '💧',
        buttonText: '+250ml',
        accentColor: OptivusColors.blueAccent,
        activationSource: 'manual',
      ),
    ];

    return Column(
      children: trackers
          .map(
            (tracker) => TrackerActiveCard(
              title: tracker.title,
              status: tracker.status,
              iconEmoji: tracker.iconEmoji,
              buttonText: tracker.buttonText,
              accentColor: tracker.accentColor,
              onAction: () {
                if (tracker.title == 'Money System') {
                  context.push('/tracker/money');
                } else if (tracker.title == 'Screen Time') {
                  context.push('/tracker/screen-time');
                } else if (tracker.title == 'Meditation') {
                  setState(() => _activeDetailView = TrackerDetailView.meditation);
                } else {
                  _showPlaceholder(tracker.title);
                }
              },
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
            title: 'Language',
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
              onActivate: () => _showPlaceholder(tracker.title),
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
          onConnect: () => _showPlaceholder('Screen Time / App Usage'),
        ),
        TrackerDataSourceCard(
          title: 'Walk / Run GPS',
          subtitle: 'Location permission needed',
          iconEmoji: '📍',
          status: 'Not connected',
          isConnected: false,
          onConnect: () => _showPlaceholder('Walk / Run GPS'),
        ),
        TrackerDataSourceCard(
          title: 'Health Connect',
          subtitle: 'Optional health data',
          iconEmoji: '❤️',
          status: 'Not connected',
          isConnected: false,
          onConnect: () => _showPlaceholder('Health Connect'),
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
    final activities = [
      {
        'title': 'Meditation completed',
        'subtitle': '${snapshot.meditationMinutes} min',
        'color': OptivusColors.purpleAccent,
      },
      {
        'title': 'Saved ${snapshot.todaySavedLabel}',
        'subtitle': 'Money System',
        'color': OptivusColors.mintAccent,
      },
      {'title': 'Water logged', 'subtitle': '+250ml', 'color': OptivusColors.blueAccent},
      {
        'title': 'Walk completed',
        'subtitle': '${snapshot.weeklyDistanceLabel} km',
        'color': OptivusColors.brandAccent,
      },
    ];

    return TrackerActivityTimeline(activities: activities);
  }

  Widget _buildTrackerSettingsTeaser() {
    return GestureDetector(
      onTap: () => _showPlaceholder('Tracker Settings'),
      child: TrackerGlassCard(
        padding: const EdgeInsets.all(20),
        radius: 20,
        opacity: 0.7,
        child: Row(
          children: [
            TrackerHeaderButton(
              icon: Icons.settings,
              onTap: () => _showPlaceholder('Tracker Settings'),
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
            const Icon(Icons.arrow_forward_ios, size: 16, color: OptivusColors.sub),
          ],
        ),
      ),
    );
  }
}

class _TrackerGraphCarouselCard extends StatefulWidget {
  final String activePeriod;
  final _TrackerUiSnapshot snapshot;

  const _TrackerGraphCarouselCard({
    required this.activePeriod,
    required this.snapshot,
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
                  color: isSelected ? OptivusColors.ink : OptivusColors.ink.withValues(alpha: 0.2),
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
          style: const TextStyle(fontSize: 11, color: OptivusColors.sub, height: 1.25),
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
    return [
      _TrackerGraphConfig(
        title: '${period.name} Performance',
        subtitle: 'Energy vs Habits Completed',
        badgeText: '+12%',
        accentColor: OptivusColors.trackerAccent,
        values: period.performanceValues,
        showLineOverlay: true,
      ),
      _TrackerGraphConfig(
        title: 'Life Balance',
        subtitle: 'Body 72% • Mind 80% • Focus 45%\nFinance 90% • Growth 60%',
        badgeText: 'Stable',
        accentColor: OptivusColors.blueAccent,
        values: period.lifeBalanceValues,
      ),
      _TrackerGraphConfig(
        title: 'Screen Time',
        subtitle:
            '${snapshot.screenTimeLabel} total • Risk: ${snapshot.screenRisk}\n${snapshot.screenInsight}',
        badgeText: '-45m',
        accentColor: OptivusColors.roseAccent,
        values: period.screenTimeValues,
      ),
      _TrackerGraphConfig(
        title: 'Money Progress',
        subtitle:
            '${snapshot.confirmedSavedLabel} confirmed • ${snapshot.potentialSavedLabel} potential\nNext level: ${snapshot.nextMoneyLevelLabel}',
        badgeText: snapshot.todaySavedLabel,
        accentColor: OptivusColors.mintAccent,
        values: period.moneyValues,
      ),
      _TrackerGraphConfig(
        title: 'Movement',
        subtitle:
            '${snapshot.weeklyDistanceLabel} km • Best pace ${snapshot.bestPaceLabel}\nLongest ${snapshot.longestDistanceLabel} km',
        badgeText: '+2k',
        accentColor: OptivusColors.brandAccent,
        values: period.movementValues,
      ),
      _TrackerGraphConfig(
        title: 'Consistency',
        subtitle:
            'Meditation ${snapshot.meditationStreakDays}d • Saving ${snapshot.savingStreakDays}d\nWater ${snapshot.waterStreakDays}d • Workout ${snapshot.workoutStreakDays}d',
        badgeText: 'On track',
        accentColor: OptivusColors.purpleAccent,
        values: period.consistencyValues,
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
  final int lifeScorePercent;
  final int activeSystemCount;
  final int waterStreakDays;
  final int workoutStreakDays;
  final int meditationStreakDays;

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
    required this.lifeScorePercent,
    required this.activeSystemCount,
    required this.waterStreakDays,
    required this.workoutStreakDays,
    required this.meditationStreakDays,
  });

  factory _TrackerUiSnapshot.fromState(MockTrackerState state) {
    final hydrationMl = state.hydrationLogs.isEmpty
        ? 1200
        : state.hydrationLogs.fold<int>(
            0,
            (total, log) => total + log.amountMl,
          );

    int meditationMinutes = 5;
    for (final session in state.trackerSessions) {
      final title = session.title.toLowerCase();
      final category = session.category.toLowerCase();
      if (title.contains('meditat') || category == 'mind') {
        meditationMinutes = session.value.clamp(0, 5).toInt();
        break;
      }
    }

    final screenMinutes = state.screenTimeApps.isEmpty
        ? 260
        : state.screenTimeApps.fold<int>(
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
    final insightAppName = topScreenApp?.name ?? 'Instagram';
    final insightMinutes = topScreenApp?.durationMinutes ?? 200;
    final insightRisk = (topScreenApp?.distractionRisk ?? 'High').toLowerCase();
    final screenInsight =
        '$insightAppName ${_formatMinutes(insightMinutes)} → $insightRisk distraction risk';

    final confirmedEntries = state.savingsEntries
        .where((entry) => entry.isConfirmed)
        .toList(growable: false);
    final todayConfirmedEntries = confirmedEntries
        .where((entry) => entry.timestamp.toLowerCase() == 'today')
        .toList(growable: false);
    final todaySaved = todayConfirmedEntries.isEmpty
        ? 10.0
        : todayConfirmedEntries.fold<double>(
            0,
            (total, entry) => total + entry.amount,
          );
    final confirmedSaved = state.moneyGoal.totalConfirmedSaved > 0
        ? state.moneyGoal.totalConfirmedSaved
        : (confirmedEntries.isEmpty
              ? 80.0
              : confirmedEntries.fold<double>(
                  0,
                  (total, entry) => total + entry.amount,
                ));
    final potentialSaved = state.moneyGoal.totalPotentialSaved > 0
        ? state.moneyGoal.totalPotentialSaved
        : 40.0;

    final activities = state.fitnessActivities;
    final weeklyDistanceKm = activities.isEmpty
        ? 2.4
        : activities.fold<double>(
            0,
            (total, activity) => total + activity.distanceKm,
          );
    final longestDistanceKm = activities.isEmpty
        ? 2.4
        : activities
              .map((activity) => activity.distanceKm)
              .reduce((a, b) => a > b ? a : b);
    final validPaces = activities
        .map((activity) => activity.paceMinutesPerKm)
        .where((pace) => pace > 0)
        .toList(growable: false);
    final bestPaceMinutesPerKm = validPaces.isEmpty
        ? 6.5
        : validPaces.reduce((a, b) => a < b ? a : b);

    return _TrackerUiSnapshot(
      hydrationMl: hydrationMl,
      meditationMinutes: meditationMinutes,
      totalScreenMinutes: screenMinutes,
      screenRisk: screenRisk,
      screenInsight: screenInsight,
      todaySaved: todaySaved,
      confirmedSaved: confirmedSaved,
      potentialSaved: potentialSaved,
      savingStreakDays: state.moneyGoal.streakDays > 0
          ? state.moneyGoal.streakDays
          : 3,
      weeklyDistanceKm: weeklyDistanceKm,
      longestDistanceKm: longestDistanceKm,
      bestPaceMinutesPerKm: bestPaceMinutesPerKm,
      lifeScorePercent: 42,
      activeSystemCount: 5,
      waterStreakDays: state.hydrationLogs.isEmpty
          ? 4
          : state.hydrationLogs.length,
      workoutStreakDays: activities.isEmpty ? 2 : activities.length,
      meditationStreakDays: meditationMinutes >= 5 ? 5 : 1,
    );
  }

  String get hydrationLabel => _formatLiters(hydrationMl);
  String get screenTimeLabel => _formatMinutes(totalScreenMinutes);
  String get todaySavedLabel => _formatRupees(todaySaved);
  String get confirmedSavedLabel => _formatRupees(confirmedSaved);
  String get potentialSavedLabel => _formatRupees(potentialSaved);
  String get weeklyDistanceLabel => _formatDistance(weeklyDistanceKm);
  String get longestDistanceLabel => _formatDistance(longestDistanceKm);
  String get bestPaceLabel => _formatPace(bestPaceMinutesPerKm);
  String get nextMoneyLevelLabel {
    final nextLevel = confirmedSaved < 100.0 ? 100.0 : confirmedSaved + 50.0;
    return _formatRupees(nextLevel);
  }
}

class _ActiveTrackerConfig {
  final String title;
  final String status;
  final String iconEmoji;
  final String buttonText;
  final Color accentColor;
  final String activationSource;

  const _ActiveTrackerConfig({
    required this.title,
    required this.status,
    required this.iconEmoji,
    required this.buttonText,
    required this.accentColor,
    required this.activationSource,
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

String _formatRupees(double amount) {
  final rounded = amount.roundToDouble();
  if (amount == rounded) return '₹${rounded.toInt()}';
  return '₹${amount.toStringAsFixed(1)}';
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
