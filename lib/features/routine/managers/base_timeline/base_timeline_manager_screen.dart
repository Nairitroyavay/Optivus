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
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';

class BaseTimelineManagerScreen extends ConsumerWidget {
  const BaseTimelineManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(routineNotifierProvider).items;

    final classes = BaseTimelineFilterUtils.getClasses(items);
    final work = BaseTimelineFilterUtils.getWorkItems(items);
    final eating = BaseTimelineFilterUtils.getEatingItems(items);
    final fixed = BaseTimelineFilterUtils.getFixedItems(items);
    final skinCare = BaseTimelineFilterUtils.getSkinCareItems(items);

    return Scaffold(
      backgroundColor: OptivusColors.routineBgBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: OptivusColors.textPrimary),
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
            colors: [OptivusColors.routineBgBottom, OptivusColors.routineBgBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
          children: [
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

            BaseTimelineOptionCard(
              title: 'Classes',
              subtitle: 'School, college, or course blocks',
              icon: Icons.school_rounded,
              itemCount: classes.length,
              previewText: classes.isNotEmpty ? _previewItem(classes.first) : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassesRoutineSetupScreen()),
              ),
            ),

            BaseTimelineOptionCard(
              title: 'Job / Work / Business',
              subtitle: 'Shifts, core hours, or flexible work',
              icon: Icons.work_rounded,
              itemCount: work.length,
              previewText: work.isNotEmpty ? _previewItem(work.first) : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkRoutineSetupScreen()),
              ),
            ),

            BaseTimelineOptionCard(
              title: 'Eating',
              subtitle: 'Breakfast, lunch, dinner windows',
              icon: Icons.restaurant_rounded,
              itemCount: eating.length,
              previewText: eating.isNotEmpty ? _previewItem(eating.first) : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EatingRoutineSetupScreen()),
              ),
            ),

            BaseTimelineOptionCard(
              title: 'Fixed',
              subtitle: 'Sleep, travel, bathing, or locked time',
              icon: Icons.schedule_rounded,
              itemCount: fixed.length,
              previewText: fixed.isNotEmpty ? _previewItem(fixed.first) : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FixedRoutineSetupScreen()),
              ),
            ),

            BaseTimelineOptionCard(
              title: 'Skin Care',
              subtitle: 'Morning & night skincare sets',
              icon: Icons.face_retouching_natural_rounded,
              itemCount: skinCare.length,
              previewText: skinCare.isNotEmpty ? _previewItem(skinCare.first) : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SkinCareRoutineSetupScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewItem(RoutineItem item) {
    return '${item.title} at ${TimelineUtils.formatTimeRange(item.startMinute, item.endMinute)}';
  }
}
