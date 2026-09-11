import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/repositories/base_timeline_setup_repository.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

class BaseTimelineScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  final ValueChanged<RoutineDetailTarget>? onOpenDetail;

  const BaseTimelineScreen({super.key, this.onBack, this.onOpenDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupAsync = ref.watch(baseTimelineSetupNotifierProvider);

    final embedded = onBack != null;
    final bottomReserve = embedded ? liquidTabBarReserve(context) : 60.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomReserve),
          children: [
            // Top Nav Header
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: OptivusColors.textPrimary,
                    ),
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                if (onBack != null) const SizedBox(width: 10),
                const Text(
                  'Base Timeline',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Foundation schedule blocks and recurring weekly routines.',
                style: TextStyle(
                  fontSize: 13,
                  color: OptivusColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Single Parent Glass Container
            setupAsync.when(
              loading: () => Container(
                height: 360,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const CircularProgressIndicator(),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Failed to load timeline setup',
                      style: TextStyle(color: OptivusColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref
                          .read(baseTimelineSetupNotifierProvider.notifier)
                          .load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (setup) {
                final classSnap = setup.snapshotFor(
                  BaseTimelineSection.classes,
                );
                final workSnap = setup.snapshotFor(BaseTimelineSection.work);
                final eatingSnap = setup.snapshotFor(
                  BaseTimelineSection.eating,
                );
                final fixedSnap = setup.snapshotFor(BaseTimelineSection.fixed);
                final skinSnap = setup.snapshotFor(
                  BaseTimelineSection.skinCare,
                );

                return LiquidGlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      _buildRow(
                        context: context,
                        icon: Icons.school_rounded,
                        accentColor: OptivusColors.blueAccent,
                        title: 'Classes',
                        subtitle: classSnap.summary,
                        onTap: () => onOpenDetail?.call(
                          const RoutineDetailTarget(
                            view: RoutineDetailView.classesSetup,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildRow(
                        context: context,
                        icon: Icons.work_rounded,
                        accentColor: OptivusColors.warning,
                        title: 'Work / Business',
                        subtitle: workSnap.summary,
                        onTap: () => onOpenDetail?.call(
                          const RoutineDetailTarget(
                            view: RoutineDetailView.workSetup,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildRow(
                        context: context,
                        icon: Icons.restaurant_rounded,
                        accentColor: OptivusColors.roseAccent,
                        title: 'Eating',
                        subtitle: eatingSnap.summary,
                        onTap: () => onOpenDetail?.call(
                          const RoutineDetailTarget(
                            view: RoutineDetailView.eatingSetup,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildRow(
                        context: context,
                        icon: Icons.lock_clock_rounded,
                        accentColor: OptivusColors.purpleAccent,
                        title: 'Fixed',
                        subtitle: fixedSnap.summary,
                        onTap: () => onOpenDetail?.call(
                          const RoutineDetailTarget(
                            view: RoutineDetailView.fixedSetup,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      _buildRow(
                        context: context,
                        icon: Icons.spa_rounded,
                        accentColor: OptivusColors.mintAccent,
                        title: 'Skin Care',
                        subtitle: skinSnap.summary,
                        onTap: () => onOpenDetail?.call(
                          const RoutineDetailTarget(
                            view: RoutineDetailView.skinCareSetup,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OptivusColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 66, right: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
