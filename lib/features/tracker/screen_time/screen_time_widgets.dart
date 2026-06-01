import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
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
                const Icon(
                  Icons.check_circle,
                  color: OptivusColors.mintAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Usage Access connected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: OptivusColors.ink,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: OptivusColors.mintAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Local data',
                    style: TextStyle(
                      color: OptivusColors.mintAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Using local app usage seed data for this UI pass.\n\nOptivus reads app usage duration, not your messages, chats, reels, or content.',
              style: TextStyle(
                fontSize: 12,
                color: OptivusColors.sub,
                height: 1.4,
              ),
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
              Icon(
                Icons.lock_outline,
                color: OptivusColors.roseAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usage Access not connected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.ink,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect Android Usage Access later to track total screen time, top apps, usage by time range, and focus-loss windows.',
            style: TextStyle(
              fontSize: 12,
              color: OptivusColors.sub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                _showScreenTimeControlSheet(
                  context,
                  'Usage Access',
                  'Open Tracker Usage Access Setup from Phone Data Sources to connect Android app usage. This frontend card is ready for the native settings intent.',
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: OptivusColors.ink,
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
                  color: OptivusColors.sub,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: OptivusColors.roseAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Distraction risk: High',
                  style: TextStyle(
                    color: OptivusColors.roseAccent,
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
                    backgroundColor: OptivusColors.sub.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      OptivusColors.roseAccent,
                    ),
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
                              color: OptivusColors.ink,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '20m',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: OptivusColors.sub,
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
                          color: OptivusColors.sub,
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
                color: OptivusColors.roseAccent,
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
    Color riskColor = OptivusColors.sub;
    if (app.riskLevel == 'High') riskColor = OptivusColors.roseAccent;
    if (app.riskLevel == 'Medium') riskColor = OptivusColors.brandAccent;

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
                        color: OptivusColors.ink,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      app.formattedDuration,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: app.isLimitCrossed
                            ? OptivusColors.roseAccent
                            : OptivusColors.ink,
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
                        color: OptivusColors.sub,
                      ),
                    ),
                    if (app.isLimitCrossed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: OptivusColors.roseAccent.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Crossed limit',
                          style: TextStyle(
                            fontSize: 9,
                            color: OptivusColors.roseAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: app.limitMinutes != null
                        ? (app.minutes / (app.limitMinutes! * 1.5)).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.5,
                    backgroundColor: OptivusColors.sub.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      app.isLimitCrossed
                          ? OptivusColors.roseAccent
                          : OptivusColors.blueAccent,
                    ),
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
            () => _showScreenTimeControlSheet(
              context,
              'Set soft limit',
              'Create a soft daily warning for doom apps without blocking phone access. Native persistence will connect here later.',
            ),
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            context,
            'Customize categories',
            Icons.category_outlined,
            () => _showScreenTimeControlSheet(
              context,
              'Customize app category',
              'Review doom, productive, and neutral app groups before saving category changes.',
            ),
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            context,
            'View weekly',
            Icons.calendar_view_week_outlined,
            () => _showScreenTimeControlSheet(
              context,
              'Weekly Report',
              'Weekly report combines total time, risk windows, best focus blocks, and top categories.',
            ),
          ),
          const SizedBox(width: 12),
          _buildControlButton(
            context,
            'Permissions',
            Icons.settings_outlined,
            () => _showScreenTimeControlSheet(
              context,
              'Usage Access Settings',
              'Open the Tracker Usage Access setup screen from Phone Data Sources to recheck Android status.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
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
              color: OptivusColors.ink.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: OptivusColors.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: OptivusColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showScreenTimeControlSheet(
  BuildContext context,
  String title,
  String body,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final media = MediaQuery.of(context);
      return Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.fromLTRB(22, 18, 22, 22 + media.padding.bottom),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.borderSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: const TextStyle(
                  color: OptivusColors.sub,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OptivusColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    },
  );
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: OptivusColors.ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Risk window highlighted in red',
            style: TextStyle(fontSize: 12, color: OptivusColors.sub),
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
                        color: isRisk
                            ? OptivusColors.roseAccent.withValues(alpha: 0.8)
                            : OptivusColors.blueAccent.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hours[index],
                      style: const TextStyle(
                        fontSize: 10,
                        color: OptivusColors.sub,
                        fontWeight: FontWeight.bold,
                      ),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: OptivusColors.ink,
              fontSize: 14,
            ),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: OptivusColors.sub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              apps,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isRisk ? OptivusColors.roseAccent : OptivusColors.ink,
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: OptivusColors.ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          _buildWindowRow(
            '10:30 PM - 12:00 AM',
            'High',
            OptivusColors.roseAccent,
          ),
          _buildWindowRow(
            '4:00 PM - 4:40 PM',
            'Medium',
            OptivusColors.brandAccent,
          ),
          _buildWindowRow(
            '12:30 PM - 1:00 PM',
            'Low',
            OptivusColors.blueAccent,
          ),
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OptivusColors.ink,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              risk,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: OptivusColors.ink,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OptivusColors.mintAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '-18%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.mintAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Screen time reduced 18% compared to last week.',
            style: TextStyle(fontSize: 12, color: OptivusColors.sub),
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
                    style: const TextStyle(
                      fontSize: 9,
                      color: OptivusColors.sub,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: height,
                    decoration: BoxDecoration(
                      color: isHigh
                          ? OptivusColors.roseAccent.withValues(alpha: 0.8)
                          : OptivusColors.blueAccent.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.dayLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OptivusColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
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
