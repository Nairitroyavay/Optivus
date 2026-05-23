import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  final ScrollController _scrollController = ScrollController();
  static const double _hourHeight = 60.0;
  static const double _minuteHeight = _hourHeight / 60.0;

  @override
  void initState() {
    super.initState();
    // Scroll to current hour of the day on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final targetScroll = (now.hour * _hourHeight) - 100.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatMinute(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${displayHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  void _showAddBlockSheet() {
    final titleController = TextEditingController();
    int startHour = 8;
    int startMin = 0;
    int endHour = 9;
    int endMin = 0;
    RoutineBlockType type = RoutineBlockType.hardBlock;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEFFFEC), Color(0xFFC3FFB6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // ignore: deprecated_member_use
                  // colors: [Color(0xFFEFFFEC), Color(0xFFC3FFB6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ADD ROUTINE HARD BLOCK',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0, color: OptivusColors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Block Title (e.g. Gym, College, Commute)',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButton<int>(
                                      value: startHour,
                                      onChanged: (h) => setSheetState(() => startHour = h ?? 0),
                                      items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}:'))),
                                    ),
                                  ),
                                  Expanded(
                                    child: DropdownButton<int>(
                                      value: startMin,
                                      onChanged: (m) => setSheetState(() => startMin = m ?? 0),
                                      items: List.generate(12, (i) => DropdownMenuItem(value: i * 5, child: Text((i * 5).toString().padLeft(2, '0')))),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButton<int>(
                                      value: endHour,
                                      onChanged: (h) => setSheetState(() => endHour = h ?? 0),
                                      items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}:'))),
                                    ),
                                  ),
                                  Expanded(
                                    child: DropdownButton<int>(
                                      value: endMin,
                                      onChanged: (m) => setSheetState(() => endMin = m ?? 0),
                                      items: List.generate(12, (i) => DropdownMenuItem(value: i * 5, child: Text((i * 5).toString().padLeft(2, '0')))),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Block Type Strength:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Hard Block'),
                              selected: type == RoutineBlockType.hardBlock,
                              onSelected: (val) => setSheetState(() => type = RoutineBlockType.hardBlock),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Soft Buffer'),
                              selected: type == RoutineBlockType.softBlock,
                              onSelected: (val) => setSheetState(() => type = RoutineBlockType.softBlock),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OptivusColors.brandAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final sMin = startHour * 60 + startMin;
                        final eMin = endHour * 60 + endMin;

                        if (eMin <= sMin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('End time must be after start time.')),
                          );
                          return;
                        }

                        final newItem = RoutineItem(
                          id: 'r-${DateTime.now().millisecondsSinceEpoch}',
                          title: title,
                          startMinute: sMin,
                          endMinute: eMin,
                          blockType: type,
                        );

                        ref.read(mockRoutineProvider.notifier).addRoutineItem(newItem);
                        Navigator.pop(context);
                      },
                      child: const Text('Anchor to Time ruler', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAISuggestionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDCCBFF), Color(0xFFF9FCFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  Text(
                    'AI CORE OPTIMIZATIONS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.deepPurple,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Aura Coach detected 1 collision inside your Friday shift routines. I suggest these offline adjustments:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flash_on, color: Colors.orangeAccent, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Suggested Optimization:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OptivusColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Delay Gym Workout start from 17:30 to 18:00 to give your nervous system a 30m shift buffer.',
                      style: TextStyle(fontSize: 12, height: 1.3, color: OptivusColors.textBody),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Apply mock adjustment: Update workout routine block in mock app state
                        final gym = ref.read(mockRoutineProvider).firstWhere((r) => r.title.contains('Gym'));
                        ref.read(mockRoutineProvider.notifier).updateRoutineItem(
                              gym.copyWith(startMinute: 18 * 60, endMinute: 19 * 60 + 30),
                            );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI optimization applied: Gym delayed to 18:00.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Apply AI Adjustment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(mockRoutineProvider);
    final now = DateTime.now();
    final currentMinuteOfDay = now.hour * 60 + now.minute;

    // Scan for collisions/conflicts to display overlay alerts
    final conflictingItems = routines.where((item) => item.hasConflict).toList();

    return Column(
      children: [
        // Collision banner alert
        if (conflictingItems.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OptivusColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: OptivusColors.danger),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: OptivusColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Collision alert! ${conflictingItems.length} hard blocks overlap.',
                    style: const TextStyle(color: OptivusColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _showAISuggestionsSheet,
                  child: const Text('Resolve with AI', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
          ),

        // Controls bar (Add block, check AI options)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                    foregroundColor: OptivusColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: OptivusColors.borderSoft),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Block', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _showAddBlockSheet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCCBFF).withValues(alpha: 0.3),
                    foregroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFDCCBFF)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.psychology, size: 18, color: Colors.deepPurple),
                  label: const Text('AI Optimizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple)),
                  onPressed: _showAISuggestionsSheet,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 24 Hour scrollable grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  height: 24 * _hourHeight,
                  child: Stack(
                    children: [
                      // 1. Grid hours lines
                      for (int h = 0; h < 24; h++) ...[
                        Positioned(
                          top: h * _hourHeight,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        Positioned(
                          top: h * _hourHeight + 8,
                          left: 12,
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: OptivusColors.textSecondary,
                            ),
                          ),
                        ),
                      ],

                      // 2. Absolute positioned hard block overlay containers
                      for (final item in routines) ...[
                        Positioned(
                          top: item.startMinute * _minuteHeight,
                          height: (item.endMinute - item.startMinute) * _minuteHeight,
                          left: 70,
                          right: 16,
                          child: _buildRoutineBlockWidget(item),
                        ),
                      ],

                      // 3. Current Live time marker
                      Positioned(
                        top: currentMinuteOfDay * _minuteHeight,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1.5,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.redAccent, Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 120), // Spacer for floating tab bar
      ],
    );
  }

  Widget _buildRoutineBlockWidget(RoutineItem item) {
    Color baseColor;
    switch (item.blockType) {
      case RoutineBlockType.hardBlock:
        baseColor = const Color(0xFF3B82F6);
        break;
      case RoutineBlockType.softBlock:
        baseColor = const Color(0xFF10B981);
        break;
      case RoutineBlockType.flexibleTask:
        baseColor = const Color(0xFF8B5CF6);
        break;
      case RoutineBlockType.trackerTask:
        baseColor = const Color(0xFFF59E0B);
        break;
      case RoutineBlockType.checkIn:
        baseColor = const Color(0xFFEC4899);
        break;
      case RoutineBlockType.moneyTask:
        baseColor = const Color(0xFF14B8A6);
        break;
    }

    final isHard = item.blockType == RoutineBlockType.hardBlock;

    return GestureDetector(
      onTap: () {
        // Toggle item completion on tap
        ref.read(mockRoutineProvider.notifier).toggleRoutineCompleted(item.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isCompleted
              ? OptivusColors.success.withValues(alpha: 0.15)
              : item.hasConflict
                  ? OptivusColors.danger.withValues(alpha: 0.15)
                  : baseColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isCompleted
                ? OptivusColors.success
                : item.hasConflict
                    ? OptivusColors.danger
                    : baseColor,
            width: item.hasConflict ? 2.0 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.isCompleted
                  ? Icons.check_circle
                  : item.hasConflict
                      ? Icons.warning
                      : isHard
                          ? Icons.lock_outline
                          : Icons.access_time_filled,
              color: item.isCompleted
                  ? OptivusColors.success
                  : item.hasConflict
                      ? OptivusColors.danger
                      : baseColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: item.isCompleted
                          ? OptivusColors.success
                          : item.hasConflict
                              ? OptivusColors.danger
                              : OptivusColors.textPrimary,
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.conflictMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.conflictMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OptivusColors.danger),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_formatMinute(item.startMinute)} - ${_formatMinute(item.endMinute)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.isCompleted ? OptivusColors.success.withValues(alpha: 0.7) : OptivusColors.textSecondary,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: OptivusColors.textSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ref.read(mockRoutineProvider.notifier).deleteRoutineItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
