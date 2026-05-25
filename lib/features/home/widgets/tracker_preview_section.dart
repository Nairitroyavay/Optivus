import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'home_glass_widgets.dart';
import 'sheets/demo_sheet.dart';

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
              return _buildPreviewCard(context, ref, previews[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(BuildContext context, WidgetRef ref, TrackerPreview preview) {
    return SizedBox(
      width: 160,
      child: HomeGlassCard(
        padding: const EdgeInsets.all(16),
        radius: 20,
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
            child: HomeActionPill(
              label: preview.buttonText,
              compact: true,
              selected: true,
              accent: preview.id == 'money' ? OptivusColors.brandAccent : OptivusColors.homeAccent,
              onTap: () {
                if (preview.id == 'money') {
                  DemoSheet.show(context, title: "Saved", message: "₹50 added to your Money System.");
                } else if (preview.id == 'hydration') {
                  DemoSheet.show(context, title: "Hydration", message: "+1 glass of water logged.");
                } else if (preview.id == 'smoking') {
                  DemoSheet.show(context, title: "Smoking", message: "Cigarette logged in tracker.");
                } else if (preview.id == 'focus') {
                  DemoSheet.show(context, title: "Deep Focus", message: "Deep focus session started.");
                } else {
                  ref.read(appNavigationProvider.notifier).goToTracker();
                }
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}
