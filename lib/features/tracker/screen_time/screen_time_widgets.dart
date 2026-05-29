import 'package:flutter/material.dart';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';

import 'screen_time_models.dart';
import 'screen_time_mock_data.dart';

class ScreenTimeUsageStatusCard extends StatelessWidget {
  final bool isConnected;

  const ScreenTimeUsageStatusCard({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return TrackerGlassCard(
        padding: const EdgeInsets.all(16),
        radius: 20,
        opacity: 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: kMint, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Usage Access connected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kInk,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kMint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mock data',
                    style: TextStyle(
                      color: kMint,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Using mock app usage data for this UI pass.\n\nOptivus reads app usage duration, not your messages, chats, reels, or content.',
              style: TextStyle(fontSize: 12, color: kSub, height: 1.4),
            ),
          ],
        ),
      );
    }

    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_outline, color: kRose, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usage Access not connected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kInk,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect Android Usage Access later to track total screen time, top apps, usage by time range, and focus-loss windows.',
            style: TextStyle(fontSize: 12, color: kSub, height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mock: Usage Access Connection Sheet')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Connect Usage Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenTimeHeroCard extends StatelessWidget {
  const ScreenTimeHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      opacity: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kSub,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Distraction risk: High',
                  style: TextStyle(
                    color: kRose,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 160,
              width: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 0.75,
                    strokeWidth: 8,
                    backgroundColor: kSub.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(kRose),
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: const [
                          Text(
                            '4h',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: kInk,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '20m',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: kSub,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Total time',
                        style: TextStyle(
                          fontSize: 12,
                          color: kSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Instagram 3h 20m → high distraction risk',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kRose,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              TrackerMetricChip(category: 'Total', value: '4h 20m'),
              TrackerMetricChip(category: 'Risk', value: 'High'),
              TrackerMetricChip(category: 'Limit', value: '+1h 20m'),
              TrackerMetricChip(category: 'Score', value: '45%'),
              TrackerMetricChip(category: 'Best block', value: '9a - 11a'),
              TrackerMetricChip(category: 'Risk window', value: '10:30p - 12a'),
            ],
          ),
        ],
      ),
    );
  }
}

class ScreenTimeAppUsageRow extends StatelessWidget {
  final ScreenTimeAppUsageUiModel app;

  const ScreenTimeAppUsageRow({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    Color riskColor = kSub;
    if (app.riskLevel == 'High') riskColor = kRose;
    if (app.riskLevel == 'Medium') riskColor = kAmber;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              app.appName.substring(0, 1),
              style: TextStyle(
                color: riskColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      app.appName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kInk,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      app.formattedDuration,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: app.isLimitCrossed ? kRose : kInk,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      app.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: kSub,
                      ),
                    ),
                    if (app.isLimitCrossed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kRose.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Crossed limit',
                          style: TextStyle(fontSize: 9, color: kRose, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: app.limitMinutes != null ? (app.minutes / (app.limitMinutes! * 1.5)).clamp(0.0, 1.0) : 0.5,
                    backgroundColor: kSub.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(app.isLimitCrossed ? kRose : kBlue),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenTimeQuickControls extends StatelessWidget {
  const ScreenTimeQuickControls({super.key});

  void _showMockSheet(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kInk,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This is a placeholder for the mock bottom sheet requested in the plan.',
              style: TextStyle(color: kSub, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Close'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildControlButton(
            context,
            'Set soft limit',
            Icons.timer_outlined,
            () => _showMockSheet(context, 'Set soft limit'),
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            context,
            'Customize categories',
            Icons.category_outlined,
            () => _showMockSheet(context, 'Customize app category'),
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            context,
            'View weekly',
            Icons.calendar_view_week_outlined,
            () => _showMockSheet(context, 'Weekly Report'),
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            context,
            'Permissions',
            Icons.settings_outlined,
            () => _showMockSheet(context, 'Usage Access Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: kInk.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: kInk),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenTimeHourlyHeatmap extends StatelessWidget {
  const ScreenTimeHourlyHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    final hours = ['6AM', '9AM', '12PM', '3PM', '6PM', '9PM', '12AM'];
    final values = [0.2, 0.4, 0.6, 0.3, 0.8, 1.0, 0.1]; // Mock values

    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hourly Usage Heatmap',
            style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Risk window highlighted in red',
            style: TextStyle(fontSize: 12, color: kSub),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(hours.length, (index) {
                final isRisk = hours[index] == '9PM' || hours[index] == '12AM';
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: 40 * values[index] + 4,
                      decoration: BoxDecoration(
                        color: isRisk ? kRose.withValues(alpha: 0.8) : kBlue.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hours[index],
                      style: const TextStyle(fontSize: 10, color: kSub, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenTimeTopAppTimeline extends StatelessWidget {
  const ScreenTimeTopAppTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top App Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildTimelineRow('Morning', 'Chrome 20m, WhatsApp 10m'),
          _buildTimelineRow('Afternoon', 'YouTube 25m'),
          _buildTimelineRow('Evening', 'Instagram 1h 10m'),
          _buildTimelineRow('Night', 'Instagram 2h 10m', isRisk: true),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String time, String apps, {bool isRisk = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              time,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kSub),
            ),
          ),
          Expanded(
            child: Text(
              apps,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isRisk ? kRose : kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenTimeFocusLossWindows extends StatelessWidget {
  const ScreenTimeFocusLossWindows({super.key});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus Loss Windows',
            style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildWindowRow('10:30 PM - 12:00 AM', 'High', kRose),
          _buildWindowRow('4:00 PM - 4:40 PM', 'Medium', kAmber),
          _buildWindowRow('12:30 PM - 1:00 PM', 'Low', kBlue),
        ],
      ),
    );
  }

  Widget _buildWindowRow(String time, String risk, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            time,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              risk,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenTimeWeeklyComparison extends StatelessWidget {
  const ScreenTimeWeeklyComparison({super.key});

  @override
  Widget build(BuildContext context) {
    return TrackerGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      opacity: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Comparison',
                style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kMint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '-18%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kMint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Screen time reduced 18% compared to last week.',
            style: TextStyle(fontSize: 12, color: kSub),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: ScreenTimeMockData.weeklyData.map((data) {
              final isHigh = data.riskLevel == 'High';
              final height = (data.totalMinutes / 350) * 80;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    data.formattedDuration,
                    style: const TextStyle(fontSize: 9, color: kSub, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: height,
                    decoration: BoxDecoration(
                      color: isHigh ? kRose.withValues(alpha: 0.8) : kBlue.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.dayLabel,
                    style: const TextStyle(fontSize: 11, color: kInk, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
