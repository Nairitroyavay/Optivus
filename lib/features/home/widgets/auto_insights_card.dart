import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'home_glass_widgets.dart';
import 'sheets/focus_control_sheet.dart';

class AutoInsightsCard extends StatelessWidget {
  final List<AutoInsight> insights;

  const AutoInsightsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return HomeGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Auto Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => _buildInsightRow(context, insight)),
        ],
      ),
    );
  }

  Widget _buildInsightRow(BuildContext context, AutoInsight insight) {
    final Color riskColor;
    switch (insight.risk) {
      case InsightRisk.low:
        riskColor = OptivusColors.success;
        break;
      case InsightRisk.medium:
        riskColor = const Color(0xFFF59E0B);
        break;
      case InsightRisk.high:
        riskColor = OptivusColors.danger;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.insights, color: riskColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Screen Time',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textSecondary.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              FocusControlSheet.show(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: OptivusColors.brandAccent,
            ),
            child: const Text(
              'Control',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
