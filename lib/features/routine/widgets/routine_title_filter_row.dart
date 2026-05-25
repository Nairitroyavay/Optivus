import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/widgets/routine_glass_filter.dart';

/// Title row + filter dropdown, matching old Optivus exactly.
///
/// Shows "Today's Flow" / "Tomorrow's Flow" / day name + GlassFilterDropdown.
class RoutineTitleFilterRow extends ConsumerWidget {
  const RoutineTitleFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final filter = ref.watch(routineFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RoutineGlassFilter(
            selected: filter,
            onSelected: (f) {
              ref.read(routineFilterProvider.notifier).state = f;
            },
          ),
        ],
      ),
    );
  }

}
