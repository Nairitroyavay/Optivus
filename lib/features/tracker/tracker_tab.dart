import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';

class TrackerTab extends ConsumerStatefulWidget {
  const TrackerTab({super.key});

  @override
  ConsumerState<TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends ConsumerState<TrackerTab> {
  String _activeMetricView = 'Daily';

  void _showMockSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: OptivusColors.brandAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomReserve = 76.0 + media.padding.bottom + media.viewInsets.bottom + 48.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OptivusColors.trackerTop,
            Color(0xFFD9FFFF),
          ],
          stops: [0.0, 0.80],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
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
                      const SizedBox(height: 24),
                      _buildProgressCarousel(),
                      const SizedBox(height: 32),
                      _buildTodayProgressHero(context),
                      const SizedBox(height: 40),
                      const TrackerSectionHeader(title: 'ACTIVE TRACKERS'),
                      _buildActiveTrackers(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'DISCOVER TRACKERS'),
                      _buildDiscoverTrackers(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'PHONE DATA SOURCES'),
                      _buildPhoneDataSources(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'RECENT ACTIVITY'),
                      _buildRecentActivity(),
                      const SizedBox(height: 48),
                      _buildTrackerSettingsTeaser(),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              'MEASURE DISCIPLINE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: kSub,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tracking Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: kInk,
              ) ?? const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: kInk,
              ),
            ),
          ],
        ),
        TrackerHeaderButton(
          icon: Icons.settings,
          onTap: () => _showMockSnackbar('Open Tracker Settings'),
        ),
      ],
    );
  }

  Widget _buildTodayProgressHero(BuildContext context) {
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Life Score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kInk,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'System is active',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kSub,
                    ),
                  ),
                ],
              ),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [OptivusColors.brandAccent, kRose],
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
                child: const Text(
                  '42%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              TrackerMetricChip(category: 'Mind', value: 'Meditation 5m'),
              TrackerMetricChip(category: 'Body', value: 'Water 1.2L / 2.5L'),
              TrackerMetricChip(category: 'Focus', value: 'Screen time risk High'),
              TrackerMetricChip(category: 'Finance', value: '₹10 saved'),
              TrackerMetricChip(category: 'Movement', value: 'Walk 2.4 km'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return TrackerSegmentedControl(
      segments: const ['Daily', 'Weekly', 'Monthly', 'Yearly'],
      selectedSegment: _activeMetricView,
      onSegmentSelected: (view) {
        setState(() => _activeMetricView = view);
      },
    );
  }

  Widget _buildProgressCarousel() {
    return _TrackerGraphCarouselCard(activePeriod: _activeMetricView);
  }

  Widget _buildActiveTrackers() {
    return Column(
      children: [
        TrackerActiveCard(
          title: 'Meditation',
          status: '5 / 5 min today',
          iconEmoji: '🧘',
          buttonText: 'View',
          accentColor: kPurple,
          onAction: () => _showMockSnackbar('Open Meditation Details'),
        ),
        TrackerActiveCard(
          title: 'Money System',
          status: '₹10 saved today',
          iconEmoji: '💰',
          buttonText: 'View',
          accentColor: kMint,
          onAction: () => _showMockSnackbar('Open Money System Details'),
        ),
        TrackerActiveCard(
          title: 'Screen Time',
          status: '4h 20m total\nRisk: High',
          iconEmoji: '📱',
          buttonText: 'View',
          accentColor: kRose,
          onAction: () => _showMockSnackbar('Open Screen Time Details'),
        ),
        TrackerActiveCard(
          title: 'Walk / Run',
          status: '2.4 km this week',
          iconEmoji: '🏃',
          buttonText: 'Start',
          accentColor: kAmber,
          onAction: () => _showMockSnackbar('Start Walk / Run'),
        ),
        TrackerActiveCard(
          title: 'Hydration',
          status: '1.2L / 2.5L',
          iconEmoji: '💧',
          buttonText: '+250ml',
          accentColor: kBlue,
          onAction: () => _showMockSnackbar('Logged 250ml water'),
        ),
      ],
    );
  }

  Widget _buildDiscoverTrackers() {
    return Column(
      children: [
        TrackerDiscoverCard(
          title: 'Smoking',
          description: 'Not set up\nTrack cravings, relapses, money saved.',
          iconEmoji: '🚭',
          onActivate: () => _showMockSnackbar('Activate Smoking Tracker'),
        ),
        TrackerDiscoverCard(
          title: 'Alcohol',
          description: 'Not set up\nTrack clean days and relapse recovery.',
          iconEmoji: '🍺',
          onActivate: () => _showMockSnackbar('Activate Alcohol Tracker'),
        ),
        TrackerDiscoverCard(
          title: 'Nutrition',
          description: 'Not set up\nTrack meals, protein, calories.',
          iconEmoji: '🍽',
          onActivate: () => _showMockSnackbar('Activate Nutrition Tracker'),
        ),
        TrackerDiscoverCard(
          title: 'Sleep',
          description: 'Not set up\nTrack sleep quality and energy.',
          iconEmoji: '😴',
          onActivate: () => _showMockSnackbar('Activate Sleep Tracker'),
        ),
        TrackerDiscoverCard(
          title: 'Workout',
          description: 'Not set up\nTrack workouts, sets, progress.',
          iconEmoji: '🏋️',
          onActivate: () => _showMockSnackbar('Activate Workout Tracker'),
        ),
        TrackerDiscoverCard(
          title: 'Reading',
          description: 'Not set up\nTrack pages and consistency.',
          iconEmoji: '📚',
          onActivate: () => _showMockSnackbar('Activate Reading Tracker'),
        ),
      ],
    );
  }

  Widget _buildPhoneDataSources() {
    return Column(
      children: [
        TrackerDataSourceCard(
          title: 'Screen Time',
          subtitle: 'Usage Access needed',
          iconEmoji: '📱',
          status: 'Connected',
          isConnected: false,
          onConnect: () => _showMockSnackbar('Request Screen Time Access'),
        ),
        TrackerDataSourceCard(
          title: 'Walk / Run GPS',
          subtitle: 'Location permission needed',
          iconEmoji: '📍',
          status: 'Connected',
          isConnected: false,
          onConnect: () => _showMockSnackbar('Request Location Access'),
        ),
        TrackerDataSourceCard(
          title: 'Health Connect',
          subtitle: 'Optional health data',
          iconEmoji: '❤️',
          status: 'Connected',
          isConnected: false,
          onConnect: () => _showMockSnackbar('Request Health Connect Access'),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      {'title': 'Meditation completed', 'subtitle': '5 min', 'color': kPurple},
      {'title': 'Saved ₹10', 'subtitle': 'Money System', 'color': kMint},
      {'title': 'Water logged', 'subtitle': '+250ml', 'color': kBlue},
      {'title': 'Walk completed', 'subtitle': '2.4 km', 'color': kAmber},
    ];

    return TrackerActivityTimeline(activities: activities);
  }

  Widget _buildTrackerSettingsTeaser() {
    return GestureDetector(
      onTap: () => _showMockSnackbar('Open Tracker Settings'),
      child: const TrackerGlassCard(
        padding: EdgeInsets.all(20),
        radius: 20,
        opacity: 0.7,
        child: Row(
          children: [
            TrackerHeaderButton(
              icon: Icons.settings,
              onTap: _doNothing, // Just for visual in teaser, actual tap handled by parent
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracker Settings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: kInk,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage active trackers, permissions, goals, reminders, and data sources.',
                    style: TextStyle(
                      fontSize: 12,
                      color: kSub,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: kSub),
          ],
        ),
      ),
    );
  }
}

void _doNothing() {}

class _TrackerGraphCarouselCard extends StatefulWidget {
  final String activePeriod;

  const _TrackerGraphCarouselCard({required this.activePeriod});

  @override
  State<_TrackerGraphCarouselCard> createState() => _TrackerGraphCarouselCardState();
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
    final graphs = [
      {'title': '${widget.activePeriod} Performance', 'subtitle': 'Energy vs Habits Completed', 'badge': '+12%', 'color': kPurple, 'values': [0.3, 0.6, 0.8, 0.4, 0.9, 0.7, 0.5]},
      {'title': 'Life Balance', 'subtitle': null, 'badge': 'Stable', 'color': kBlue, 'values': [0.5, 0.5, 0.6, 0.5, 0.7, 0.6, 0.5]},
      {'title': 'Screen Time', 'subtitle': null, 'badge': '-45m', 'color': kRose, 'values': [0.8, 0.7, 0.4, 0.9, 0.6, 0.5, 0.8]},
      {'title': 'Money', 'subtitle': null, 'badge': '₹30k', 'color': const Color(0xFF00C896), 'values': [0.3, 0.4, 0.3, 0.5, 0.4, 0.3, 0.6]},
      {'title': 'Sleep Quality', 'subtitle': 'Average 7.5 hrs', 'badge': '+5%', 'color': const Color(0xFF6A5ACD), 'values': [0.7, 0.8, 0.7, 0.9, 0.8, 0.9, 0.8]},
      {'title': 'Hydration', 'subtitle': null, 'badge': '+1.2L', 'color': const Color(0xFF00BFFF), 'values': [0.5, 0.6, 0.8, 0.7, 0.9, 0.8, 0.9]},
      {'title': 'Steps', 'subtitle': null, 'badge': '+2k', 'color': const Color(0xFFFF8C00), 'values': [0.4, 0.5, 0.7, 0.6, 0.8, 0.7, 0.9]},
    ];

    return TrackerGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: graphs.length,
              itemBuilder: (context, index) {
                final graph = graphs[index];
                return _buildInnerGraph(
                  title: graph['title'] as String,
                  subtitle: graph['subtitle'] as String?,
                  badgeText: graph['badge'] as String,
                  values: graph['values'] as List<double>,
                  accentColor: graph['color'] as Color,
                );
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
                  color: isSelected ? kInk : kInk.withValues(alpha: 0.2),
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
    required String title,
    String? subtitle,
    required String badgeText,
    required List<double> values,
    required Color accentColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: kInk,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: kSub,
            ),
          ),
        ],
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (index) {
            final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            double heightPercent = values.length > index ? values[index] : 0.5;
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 18,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: heightPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  days[index],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
