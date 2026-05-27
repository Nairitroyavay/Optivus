import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';

void showRoutineFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RoutineFilterSheetBody(parentRef: ref),
  );
}

class _RoutineFilterSheetBody extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _RoutineFilterSheetBody({required this.parentRef});

  @override
  ConsumerState<_RoutineFilterSheetBody> createState() => _RoutineFilterSheetBodyState();
}

class _RoutineFilterSheetBodyState extends ConsumerState<_RoutineFilterSheetBody> {
  late String _selectedView;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedView = widget.parentRef.read(routineFilterProvider);
    _selectedCategory = widget.parentRef.read(selectedCategoryFilterProvider);
  }

  void _apply() {
    widget.parentRef.read(routineFilterProvider.notifier).state = _selectedView;
    widget.parentRef.read(selectedCategoryFilterProvider.notifier).state = _selectedCategory;
    Navigator.of(context).pop();
  }

  void _clear() {
    setState(() {
      _selectedView = 'all';
      _selectedCategory = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0FFF0), Color(0xFFDCFFCC)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Header fixed at top
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _clear,
                          style: TextButton.styleFrom(
                            foregroundColor: OptivusColors.textSecondary,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Text(
                          'Filter Routine',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: _apply,
                          style: TextButton.styleFrom(
                            foregroundColor: OptivusColors.routineAccent,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    const _SectionLabel('View'),
                    _buildOptionsGrid(
                      options: primaryFilters,
                      selectedValue: _selectedView,
                      onSelect: (v) => setState(() => _selectedView = v),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel('Category'),
                    _buildOptionsGrid(
                      options: categoryFilters,
                      selectedValue: _selectedCategory,
                      onSelect: (v) => setState(() => _selectedCategory = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionsGrid({
    required List<RoutineFilterOption> options,
    required String selectedValue,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selectedValue == option.key;
        return GestureDetector(
          onTap: () => onSelect(option.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? OptivusColors.routineAccent : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? OptivusColors.routineAccent : Colors.white.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : OptivusColors.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textSecondary,
        ),
      ),
    );
  }
}
