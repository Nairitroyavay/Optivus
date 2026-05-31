import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_filter_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_option_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/classes_routine_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/work_routine_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/eating_routine_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/fixed_routine_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/skin_care_routine_setup_screen.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

class BaseTimelineManagerScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  final ValueChanged<RoutineDetailTarget>? onOpenDetail;

  const BaseTimelineManagerScreen({super.key, this.onBack, this.onOpenDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(routineNotifierProvider).items;

    final classes = BaseTimelineFilterUtils.getClasses(items);
    final work = BaseTimelineFilterUtils.getWorkItems(items);
    final eating = BaseTimelineFilterUtils.getEatingItems(items);
    final fixed = BaseTimelineFilterUtils.getFixedItems(items);
    final skinCare = BaseTimelineFilterUtils.getSkinCareItems(items);

    final embedded = onBack != null;

    return Scaffold(
      backgroundColor: embedded
          ? Colors.transparent
          : OptivusColors.routineBgBottom,
      appBar: embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: OptivusColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Base Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.textPrimary,
                ),
              ),
              centerTitle: true,
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              embedded ? 16 : 16,
              20,
              embedded ? 76 + MediaQuery.of(context).padding.bottom + 48 : 60,
            ),
            children: [
              if (embedded) ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: OptivusColors.textPrimary,
                      ),
                      onPressed: onBack,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Base Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              const Text(
                'Base Timeline Manager',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set the foundation blocks that shape your daily routine.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: OptivusColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Import Review',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _ImportReviewGrid(onOpenDetail: onOpenDetail),
              const SizedBox(height: 28),

              BaseTimelineOptionCard(
                title: 'Classes',
                subtitle: 'School, college, or course blocks',
                icon: Icons.school_rounded,
                itemCount: classes.length,
                previewText: classes.isNotEmpty
                    ? _previewItem(classes.first)
                    : null,
                onTap: () => _openSection(
                  context,
                  const RoutineDetailTarget(
                    view: RoutineDetailView.classesSetup,
                  ),
                  const ClassesRoutineSetupScreen(),
                ),
              ),

              BaseTimelineOptionCard(
                title: 'Job / Work / Business',
                subtitle: 'Shifts, core hours, or flexible work',
                icon: Icons.work_rounded,
                itemCount: work.length,
                previewText: work.isNotEmpty ? _previewItem(work.first) : null,
                onTap: () => _openSection(
                  context,
                  const RoutineDetailTarget(view: RoutineDetailView.workSetup),
                  const WorkRoutineSetupScreen(),
                ),
              ),

              BaseTimelineOptionCard(
                title: 'Eating',
                subtitle: 'Breakfast, lunch, dinner windows',
                icon: Icons.restaurant_rounded,
                itemCount: eating.length,
                previewText: eating.isNotEmpty
                    ? _previewItem(eating.first)
                    : null,
                onTap: () => _openSection(
                  context,
                  const RoutineDetailTarget(
                    view: RoutineDetailView.eatingSetup,
                  ),
                  const EatingRoutineSetupScreen(),
                ),
              ),

              BaseTimelineOptionCard(
                title: 'Fixed',
                subtitle: 'Sleep, travel, bathing, or locked time',
                icon: Icons.schedule_rounded,
                itemCount: fixed.length,
                previewText: fixed.isNotEmpty
                    ? _previewItem(fixed.first)
                    : null,
                onTap: () => _openSection(
                  context,
                  const RoutineDetailTarget(view: RoutineDetailView.fixedSetup),
                  const FixedRoutineSetupScreen(),
                ),
              ),

              BaseTimelineOptionCard(
                title: 'Skin Care',
                subtitle: 'Morning & night skincare sets',
                icon: Icons.face_retouching_natural_rounded,
                itemCount: skinCare.length,
                previewText: skinCare.isNotEmpty
                    ? _previewItem(skinCare.first)
                    : null,
                onTap: () => _openSection(
                  context,
                  const RoutineDetailTarget(
                    view: RoutineDetailView.skinCareSetup,
                  ),
                  const SkinCareRoutineSetupScreen(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSection(
    BuildContext context,
    RoutineDetailTarget target,
    Widget fallback,
  ) {
    if (onOpenDetail != null) {
      onOpenDetail!(target);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => fallback));
  }

  String _previewItem(RoutineItem item) {
    return '${item.title} at ${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)}';
  }
}

class _ImportReviewGrid extends StatelessWidget {
  final ValueChanged<RoutineDetailTarget>? onOpenDetail;

  const _ImportReviewGrid({required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (RoutineImportSource.classes, 'Classes AI text/photo/manual import'),
      (RoutineImportSource.work, 'Job / Work / Business schedule import'),
      (RoutineImportSource.eating, 'Eating / mess sheet import'),
      (RoutineImportSource.skinCare, 'Skin care product/routine import'),
    ];
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BaseTimelineOptionCard(
            title: _label(item.$1),
            subtitle: item.$2,
            icon: _icon(item.$1),
            itemCount: 0,
            previewText: 'Review parsed mock blocks before saving',
            onTap: () {
              onOpenDetail?.call(
                RoutineDetailTarget(
                  view: RoutineDetailView.importReview,
                  importSource: item.$1,
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  String _label(RoutineImportSource source) {
    return switch (source) {
      RoutineImportSource.classes => 'Classes Import Review',
      RoutineImportSource.work => 'Work Import Review',
      RoutineImportSource.eating => 'Eating Import Review',
      RoutineImportSource.skinCare => 'Skin Care Import Review',
    };
  }

  IconData _icon(RoutineImportSource source) {
    return switch (source) {
      RoutineImportSource.classes => Icons.school_rounded,
      RoutineImportSource.work => Icons.work_rounded,
      RoutineImportSource.eating => Icons.restaurant_rounded,
      RoutineImportSource.skinCare => Icons.face_retouching_natural_rounded,
    };
  }
}
