import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/services/routine_entry_filter.dart';

/// Shows the Routine Filter bottom sheet.
void showRoutineFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RoutineFilterSheet(parentRef: ref),
  );
}

class RoutineFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const RoutineFilterSheet({super.key, required this.parentRef});

  @override
  ConsumerState<RoutineFilterSheet> createState() => _RoutineFilterSheetState();
}

class _RoutineFilterSheetState extends ConsumerState<RoutineFilterSheet> {
  late String _stagedView;
  late String _stagedStatus;
  late String _stagedCategory;
  bool _showAllCategories = false;

  @override
  void initState() {
    super.initState();
    final current = widget.parentRef.read(routineNotifierProvider);
    _stagedView = current.selectedPrimaryFilter;
    _stagedStatus = current.selectedStatusFilter;
    _stagedCategory = current.selectedCategoryFilter;
  }

  void _apply() {
    final notifier = widget.parentRef.read(routineNotifierProvider.notifier);
    notifier.setPrimaryFilter(_stagedView);
    notifier.setStatusFilter(_stagedStatus);
    notifier.setCategoryFilter(_stagedCategory);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _stagedView = 'all';
      _stagedStatus = 'any';
      _stagedCategory = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch occurrence-aware entries for the currently selected day
    final dayEntries = ref.watch(selectedDayRoutineEntriesProvider);

    // Derive available dynamic categories for this specific day
    final dynamicCategories = RoutineEntryFilter.dynamicCategoryOptions(
      dayEntries,
    );

    // If previously staged category is no longer valid, gracefully fall back to 'all'
    if (_stagedCategory != 'all' &&
        !dynamicCategories.any((c) => c.key == _stagedCategory)) {
      _stagedCategory = 'all';
    }

    // Calculate real-time filtered results count for staged preview
    final matchingEntries = RoutineEntryFilter.apply(
      dayEntries,
      view: _stagedView,
      status: _stagedStatus,
      category: _stagedCategory,
    );
    final count = matchingEntries.length;

    // Build category options list: 'all' followed by dynamic categories
    final allCategoryOption = const RoutineFilterOption(
      'all',
      'All Categories',
      'All',
    );
    final visibleCategoryOptions = <RoutineFilterOption>[
      allCategoryOption,
      if (_showAllCategories || dynamicCategories.length <= 6)
        ...dynamicCategories
      else
        ...dynamicCategories.take(5),
    ];
    final hasCategoryOverflow = dynamicCategories.length > 6;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                OptivusColors.routineSheetTop,
                OptivusColors.routineSheetBottom,
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
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
                          onPressed: _reset,
                          style: TextButton.styleFrom(
                            foregroundColor: OptivusColors.textSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
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
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: OptivusColors.textSecondary,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter sections list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    // Axis 1: VIEW
                    const _SectionLabel('VIEW'),
                    _buildOptionsGrid(
                      options: primaryFilters,
                      selectedValue: _stagedView,
                      onSelect: (v) => setState(() => _stagedView = v),
                    ),
                    const SizedBox(height: 24),

                    // Axis 2: STATUS
                    const _SectionLabel('STATUS'),
                    _buildOptionsGrid(
                      options: statusFilters,
                      selectedValue: _stagedStatus,
                      onSelect: (v) => setState(() => _stagedStatus = v),
                    ),
                    const SizedBox(height: 24),

                    // Axis 3: DYNAMIC CATEGORY
                    const _SectionLabel('CATEGORY'),
                    if (dynamicCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No categorized routines on this day.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: OptivusColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      _buildOptionsGrid(
                        options: visibleCategoryOptions,
                        selectedValue: _stagedCategory,
                        onSelect: (v) => setState(() => _stagedCategory = v),
                      ),
                      if (hasCategoryOverflow)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllCategories = !_showAllCategories;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: OptivusColors.routineAccent,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _showAllCategories
                                    ? 'Show fewer categories'
                                    : '+${dynamicCategories.length - 5} more categories',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              // Sticky apply button with live result count preview
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OptivusColors.routineAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        count == 1 ? 'Show 1 routine' : 'Show $count routines',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
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
              color: isSelected
                  ? OptivusColors.routineAccent
                  : Colors.white.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? OptivusColors.routineAccent
                    : Colors.white.withValues(alpha: 0.75),
                width: 1,
              ),
            ),
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: OptivusColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
