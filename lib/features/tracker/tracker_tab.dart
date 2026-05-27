import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildTodayProgressHero(context),
          const SizedBox(height: 24),
          _buildPeriodSelector(),
          const SizedBox(height: 24),
          _buildProgressCarousel(),
          const SizedBox(height: 32),
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
              'Tracking Center',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: kInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Measure your discipline today',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kSub.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        LiquidIconBtn(
          icon: Icons.settings,
          onTap: () => _showMockSnackbar('Open Tracker Settings'),
        ),
      ],
    );
  }

  Widget _buildTodayProgressHero(BuildContext context) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Life Score',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'System is active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kSub.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Container(
                width: 64,
                height: 64,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
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
    if (_activeMetricView == 'Weekly' || _activeMetricView == 'Monthly') {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: LiquidCard.solid(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, color: kSub, size: 32),
              const SizedBox(height: 12),
              Text(
                '$_activeMetricView Progress',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _activeMetricView == 'Weekly'
                    ? 'Complete 7 days to unlock your first weekly review.'
                    : 'Complete 30 days to unlock deeper insights.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: kSub),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        children: const [
          TrackerGraphCard(
            title: 'Weekly Performance',
            subtitle: 'Energy vs Habits Completed',
            badgeText: '+12%',
            values: [0.3, 0.6, 0.8, 0.4, 0.9, 0.7, 0.5],
            accentColor: kPurple,
          ),
          TrackerGraphCard(
            title: 'Life Balance',
            badgeText: 'Stable',
            values: [0.5, 0.5, 0.6, 0.5, 0.7, 0.6, 0.5],
            accentColor: kBlue,
          ),
          TrackerGraphCard(
            title: 'Screen Time',
            badgeText: '-45m',
            values: [0.8, 0.7, 0.4, 0.9, 0.6, 0.5, 0.8],
            accentColor: kRose,
          ),
          TrackerGraphCard(
            title: 'Money',
            badgeText: '₹140',
            values: [0.2, 0.4, 0.6, 0.8, 0.5, 1.0, 0.3],
            accentColor: kMint,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrackers() {
    return Column(
      children: [
        TrackerCard(
          title: 'Meditation',
          status: '5 / 5 min today',
          iconEmoji: '🧘',
          buttonText: 'View',
          accentColor: kPurple,
          onAction: () => _showMockSnackbar('Open Meditation Details'),
        ),
        TrackerCard(
          title: 'Money System',
          status: '₹10 saved today',
          iconEmoji: '💰',
          buttonText: 'View',
          accentColor: kMint,
          onAction: () => _showMockSnackbar('Open Money System Details'),
        ),
        TrackerCard(
          title: 'Screen Time',
          status: '4h 20m total\nRisk: High',
          iconEmoji: '📱',
          buttonText: 'View',
          accentColor: kRose,
          onAction: () => _showMockSnackbar('Open Screen Time Details'),
        ),
        TrackerCard(
          title: 'Walk / Run',
          status: '2.4 km this week',
          iconEmoji: '🏃',
          buttonText: 'Start',
          accentColor: kAmber,
          onAction: () => _showMockSnackbar('Start Walk / Run'),
        ),
        TrackerCard(
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
        DiscoverTrackerCard(
          title: 'Smoking',
          description: 'Not set up\nTrack cravings, relapses, money saved.',
          iconEmoji: '🚭',
          onActivate: () => _showMockSnackbar('Activate Smoking Tracker'),
        ),
        DiscoverTrackerCard(
          title: 'Alcohol',
          description: 'Not set up\nTrack clean days and relapse recovery.',
          iconEmoji: '🍺',
          onActivate: () => _showMockSnackbar('Activate Alcohol Tracker'),
        ),
        DiscoverTrackerCard(
          title: 'Nutrition',
          description: 'Not set up\nTrack meals, protein, calories.',
          iconEmoji: '🍽',
          onActivate: () => _showMockSnackbar('Activate Nutrition Tracker'),
        ),
        DiscoverTrackerCard(
          title: 'Sleep',
          description: 'Not set up\nTrack sleep quality and energy.',
          iconEmoji: '😴',
          onActivate: () => _showMockSnackbar('Activate Sleep Tracker'),
        ),
        DiscoverTrackerCard(
          title: 'Workout',
          description: 'Not set up\nTrack workouts, sets, progress.',
          iconEmoji: '🏋️',
          onActivate: () => _showMockSnackbar('Activate Workout Tracker'),
        ),
        DiscoverTrackerCard(
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
        PhoneDataSourceCard(
          title: 'Screen Time',
          subtitle: 'Usage Access needed',
          iconEmoji: '📱',
          status: 'Connected',
          isConnected: false,
          onConnect: () => _showMockSnackbar('Request Screen Time Access'),
        ),
        PhoneDataSourceCard(
          title: 'Walk / Run GPS',
          subtitle: 'Location permission needed',
          iconEmoji: '📍',
          status: 'Connected',
          isConnected: false,
          onConnect: () => _showMockSnackbar('Request Location Access'),
        ),
        PhoneDataSourceCard(
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

    return LiquidCard.solid(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        children: activities.asMap().entries.map((entry) {
          final isLast = entry.key == activities.length - 1;
          final item = entry.value;
          final color = item['color'] as Color;
          
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: kInk,
                          ),
                        ),
                        Text(
                          item['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: kSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrackerSettingsTeaser() {
    return GestureDetector(
      onTap: () => _showMockSnackbar('Open Tracker Settings'),
      child: LiquidCard.solid(
        padding: const EdgeInsets.all(20),
        tint: Colors.white.withValues(alpha: 0.4),
        radius: 20,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, color: kSub, size: 20),
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
                      fontSize: 14,
                      color: kInk,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage active trackers, permissions, goals, reminders, and data sources.',
                    style: TextStyle(
                      fontSize: 11,
                      color: kSub,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: kSub),
          ],
        ),
      ),
    );
  }
}
