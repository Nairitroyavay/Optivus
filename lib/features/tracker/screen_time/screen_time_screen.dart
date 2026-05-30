import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';

import 'screen_time_mock_data.dart';
import 'screen_time_widgets.dart';

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  String _activePeriod = 'Today';
  final bool _isUsageAccessConnected = true; // State B by default

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomReserve = media.padding.bottom + 48.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [OptivusColors.trackerTop, OptivusColors.trackerCardTint],
            stops: [0.0, 0.80],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScreenTimeUsageStatusCard(isConnected: _isUsageAccessConnected),
                      const SizedBox(height: 24),
                      _buildPeriodSelector(),
                      const SizedBox(height: 24),
                      const ScreenTimeHeroCard(),
                      const SizedBox(height: 24),
                      const TrackerSectionHeader(title: 'QUICK CONTROLS'),
                      const ScreenTimeQuickControls(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'TOP APPS'),
                      _buildTopAppsCard(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'DISTRACTION RISK'),
                      _buildDistractionRiskCard(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'ADVANCED INSIGHTS'),
                      _buildAdvancedInsights(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'COACH INSIGHT'),
                      _buildCoachInsightCard(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'APP CATEGORIES'),
                      _buildCategoryManagementPreview(),
                      const SizedBox(height: 32),
                      const TrackerSectionHeader(title: 'SETTINGS & LIMITS'),
                      _buildSettingsPreview(),
                      const SizedBox(height: 40),
                      _buildPrivacyNote(),
                      const SizedBox(height: 48),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TrackerHeaderButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Screen Time',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Focus patterns, app usage,\nand distraction risk.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.sub,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          TrackerHeaderButton(
            icon: Icons.info_outline,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Screen time tracking info')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return TrackerSegmentedControl(
      segments: const ['Today', 'Week', 'Month'],
      selectedSegment: _activePeriod,
      onSegmentSelected: (view) {
        setState(() => _activePeriod = view);
      },
    );
  }

  Widget _buildTopAppsCard() {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...ScreenTimeMockData.topAppsToday.map((app) => ScreenTimeAppUsageRow(app: app)),
        ],
      ),
    );
  }

  Widget _buildDistractionRiskCard() {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      opacity: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: OptivusColors.roseAccent),
              const SizedBox(width: 8),
              const Text(
                'High Distraction Risk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: OptivusColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your highest risk window is 10:30 PM - 12:00 AM.\nInstagram is your most-used high-risk app today.',
            style: TextStyle(
              fontSize: 13,
              color: OptivusColors.sub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OptivusColors.roseAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OptivusColors.roseAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 16, color: OptivusColors.roseAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Suggestion: Move night reading before phone use.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.roseAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              TrackerMetricChip(category: 'Worst time', value: 'Night'),
              TrackerMetricChip(category: 'Best block', value: '9a - 11a'),
              TrackerMetricChip(category: 'Risk window', value: '10:30p - 12a'),
              TrackerMetricChip(category: 'Streak', value: '3 doom days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedInsights() {
    return Column(
      children: [
        const ScreenTimeHourlyHeatmap(),
        const SizedBox(height: 16),
        const ScreenTimeTopAppTimeline(),
        const SizedBox(height: 16),
        const ScreenTimeFocusLossWindows(),
        const SizedBox(height: 16),
        _buildInsightRow(
          'Doom App Streak',
          'Instagram crossed limit 3 days in a row.',
          Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: 16),
        const ScreenTimeWeeklyComparison(),
      ],
    );
  }

  Widget _buildInsightRow(String title, String subtitle, IconData icon) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.6,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: OptivusColors.ink, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.ink,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OptivusColors.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryManagementPreview() {
    return Column(
      children: [
        _buildCategoryPreviewCard('Doom apps', ScreenTimeMockData.doomAppsCategories.join(', ')),
        const SizedBox(height: 12),
        _buildCategoryPreviewCard('Productive apps', ScreenTimeMockData.productiveAppsCategories.join(', ')),
        const SizedBox(height: 12),
        _buildCategoryPreviewCard('Neutral apps', ScreenTimeMockData.neutralAppsCategories.join(', ')),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock: Customize categories sheet')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.ink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Customize categories'),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPreviewCard(String title, String apps) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      opacity: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            apps,
            style: const TextStyle(fontSize: 12, color: OptivusColors.sub, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPreview() {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      opacity: 0.6,
      child: Column(
        children: [
          _buildSettingsRow('Soft limits'),
          _buildSettingsRow('App categories'),
          _buildSettingsRow('Risk windows'),
          _buildSettingsRow('Reminder style'),
          _buildSettingsRow('Privacy: show app names'),
          _buildSettingsRow('Usage Access'),
          _buildSettingsRow('Weekly report', isLast: true),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(String title, {bool isLast = false}) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mock: Open $title settings')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: OptivusColors.ink),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: OptivusColors.sub),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OptivusColors.sub.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.privacy_tip_outlined, size: 18, color: OptivusColors.sub),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Optivus can track app names and usage duration after permission.\nOptivus cannot read messages, chats, reels, posts, or what you watched.',
              style: TextStyle(fontSize: 11, color: OptivusColors.sub, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachInsightCard() {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      tint: OptivusColors.purpleAccent.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥋', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text(
                'Sensei',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: OptivusColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '“Your risk window starts after 10:30 PM. Put reading before phone use tonight. This may be a focus-loss window.”',
            style: TextStyle(
              fontSize: 14,
              color: OptivusColors.ink,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
