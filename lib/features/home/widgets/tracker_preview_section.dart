import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';

class TrackerPreviewSection extends ConsumerWidget {
  final List<TrackerPreview> previews;

  const TrackerPreviewSection({super.key, required this.previews});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (previews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trackers Today',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: previews.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildPreviewCard(context, previews[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(BuildContext context, TrackerPreview preview) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            preview.subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OptivusColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent.withValues(
                  alpha: 0.1,
                ),
                foregroundColor: OptivusColors.brandAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${preview.buttonText} action...')),
                );
              },
              child: Text(
                preview.buttonText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
