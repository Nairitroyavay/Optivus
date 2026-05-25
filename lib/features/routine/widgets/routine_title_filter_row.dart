import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart';

/// Title row + filter dropdown, matching old Optivus exactly.
///
/// Shows "Today's Flow" / "Tomorrow's Flow" / day name + GlassFilterDropdown.
class RoutineTitleFilterRow extends ConsumerWidget {
  const RoutineTitleFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(routineFilterProvider);
    final categoryFilter = ref.watch(selectedCategoryFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RoutineGlassFilter(
              selected: categoryFilter,
              options: categoryFilters,
              width: 168,
              onSelected: (f) {
                ref.read(selectedCategoryFilterProvider.notifier).state = f;
              },
            ),
            const SizedBox(width: 10),
            RoutineGlassFilter(
              selected: filter,
              width: 174,
              onSelected: (f) {
                ref.read(routineFilterProvider.notifier).state = f;
              },
            ),
          ],
        ),
      ),
    );
  }
}
