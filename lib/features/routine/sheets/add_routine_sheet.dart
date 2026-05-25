import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/models/routine_item.dart';
import 'package:optivus/state/app_state.dart';

/// Shows the "Add to Routine" bottom sheet.
void showAddRoutineSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddRoutineSheetBody(parentRef: ref),
  );
}

class _AddRoutineSheetBody extends StatefulWidget {
  final WidgetRef parentRef;
  const _AddRoutineSheetBody({required this.parentRef});

  @override
  State<_AddRoutineSheetBody> createState() => _AddRoutineSheetBodyState();
}

class _AddRoutineSheetBodyState extends State<_AddRoutineSheetBody> {
  String? _selectedCategory;
  final _titleController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Drag handle
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
              // Title
              Row(
                children: [
                  Icon(Icons.add_circle, size: 22, color: OptivusColors.routineAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Add to Routine',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_selectedCategory == null) ...[
                // Category selection grid
                const Text(
                  'Choose a type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCategoryGrid(),
              ] else ...[
                // Form for selected category
                _buildForm(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      _Cat('Flexible Task', Icons.task_alt, const Color(0xFF8B5CF6), 'flexibleTask'),
      _Cat('Fixed Block', Icons.lock_outline, const Color(0xFF3B82F6), 'hardBlock'),
      _Cat('Habit', Icons.repeat, const Color(0xFF10B981), 'softBlock'),
      _Cat('Tracker Task', Icons.timer, const Color(0xFFF59E0B), 'trackerTask'),
      _Cat('Check-in', Icons.check_circle_outline, const Color(0xFFEC4899), 'checkIn'),
      _Cat('Money Task', Icons.savings, const Color(0xFF14B8A6), 'moneyTask'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((cat) {
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat.key),
          child: Container(
            width: (MediaQuery.of(context).size.width - 52) / 2,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cat.color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(cat.icon, size: 28, color: cat.color),
                const SizedBox(height: 8),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cat.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        GestureDetector(
          onTap: () => setState(() => _selectedCategory = null),
          child: const Row(
            children: [
              Icon(Icons.arrow_back, size: 18, color: OptivusColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'Back',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Title field
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'e.g., Morning Study',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Time pickers
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (t != null) setState(() => _startTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Start: ${_startTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (t != null) setState(() => _endTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'End: ${_endTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Save button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (_titleController.text.trim().isEmpty) return;
              final item = RoutineItem(
                id: 'routine-${DateTime.now().millisecondsSinceEpoch}',
                title: _titleController.text.trim(),
                startMinute: _startTime.hour * 60 + _startTime.minute,
                endMinute: _endTime.hour * 60 + _endTime.minute,
                blockType: _parseBlockType(_selectedCategory!),
                source: RoutineSource.manual,
              );
              widget.parentRef
                  .read(mockRoutineProvider.notifier)
                  .addRoutineItem(item);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.routineAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  RoutineBlockType _parseBlockType(String key) {
    return switch (key) {
      'hardBlock' => RoutineBlockType.hardBlock,
      'softBlock' => RoutineBlockType.softBlock,
      'flexibleTask' => RoutineBlockType.flexibleTask,
      'trackerTask' => RoutineBlockType.trackerTask,
      'checkIn' => RoutineBlockType.checkIn,
      'moneyTask' => RoutineBlockType.moneyTask,
      _ => RoutineBlockType.flexibleTask,
    };
  }
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  final String key;
  const _Cat(this.label, this.icon, this.color, this.key);
}
