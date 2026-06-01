import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/utils/base_timeline_conflict_utils.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/routine_state.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/routine_item.dart';

class RoutineImportReviewScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final RoutineImportSource source;

  const RoutineImportReviewScreen({
    super.key,
    required this.onBack,
    required this.source,
  });

  @override
  ConsumerState<RoutineImportReviewScreen> createState() =>
      _RoutineImportReviewScreenState();
}

class _RoutineImportReviewScreenState
    extends ConsumerState<RoutineImportReviewScreen> {
  late List<RoutineItem> _blocks;
  final Set<String> _flexible = {};

  @override
  void initState() {
    super.initState();
    _blocks = _mockBlocks(widget.source);
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(routineNotifierProvider).items;
    final conflicts = <String, List<RoutineItem>>{
      for (final block in _blocks)
        block.id: BaseTimelineConflictUtils.findConflicts(block, existing),
    };
    final hasConflicts = conflicts.values.any((items) => items.isNotEmpty);

    return LiquidDetailScaffold(
      eyebrow: 'Routine import',
      title: '${_sourceLabel(widget.source)} Review',
      subtitle:
          'Review parsed blocks before saving to Base Timeline. AI/photo parsing is represented as a local preview in this frontend pass.',
      accentColor: OptivusColors.routineAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Import source summary',
          children: [
            Text(
              _sourceSummary(widget.source),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
                  .map(
                    (day) => LiquidPill(
                      label: day,
                      color: OptivusColors.routineAccent,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        if (hasConflicts)
          LiquidDetailSection(
            title: 'Conflict warnings',
            tint: OptivusColors.warning.withValues(alpha: 0.08),
            children: conflicts.entries
                .where((entry) => entry.value.isNotEmpty)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${_blockById(entry.key).title} overlaps ${entry.value.first.title}. Edit time or mark flexible when allowed.',
                      style: const TextStyle(
                        color: OptivusColors.warning,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        LiquidDetailSection(
          title: 'Missing info warnings',
          children: [
            Text(
              _blocks.any((b) => b.location == null || b.location!.isEmpty)
                  ? 'Some blocks are missing location/room details. You can save now and edit later.'
                  : 'No critical missing information.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: OptivusColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Parsed blocks preview',
          children: [
            ..._blocks.map(
              (block) => _ImportBlockTile(
                block: block,
                hasConflict: conflicts[block.id]?.isNotEmpty ?? false,
                isFlexible: _flexible.contains(block.id),
                onEdit: () => _shiftBlock(block),
                onDelete: () => setState(
                  () => _blocks = _blocks
                      .where((candidate) => candidate.id != block.id)
                      .toList(),
                ),
                onToggleFlexible: () => setState(() {
                  if (_flexible.contains(block.id)) {
                    _flexible.remove(block.id);
                  } else {
                    _flexible.add(block.id);
                  }
                  _blocks = [
                    for (final candidate in _blocks)
                      if (candidate.id == block.id)
                        candidate.copyWith(
                          blockType: _flexible.contains(block.id)
                              ? RoutineBlockType.flexibleTask
                              : block.blockType,
                          hardBlock:
                              !_flexible.contains(block.id) &&
                              block.isHardBlock,
                        )
                      else
                        candidate,
                  ];
                }),
              ),
            ),
            const SizedBox(height: 10),
            _TextButton(
              label: 'Add block',
              color: OptivusColors.routineAccent,
              onTap: _addBlock,
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _RoutineButton(
                label: 'Cancel',
                color: OptivusColors.textSecondary,
                onTap: widget.onBack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoutineButton(
                label: 'Save to Base Timeline',
                color: OptivusColors.routineAccent,
                onTap: _saveBlocks,
              ),
            ),
          ],
        ),
      ],
    );
  }

  RoutineItem _blockById(String id) {
    return _blocks.firstWhere((block) => block.id == id);
  }

  void _shiftBlock(RoutineItem block) {
    setState(() {
      _blocks = [
        for (final candidate in _blocks)
          if (candidate.id == block.id)
            candidate.copyWith(
              startMinute: (candidate.startMinute + 15).clamp(0, 1439),
              endMinute: (candidate.endMinute + 15).clamp(1, 1440),
              clearConflict: true,
            )
          else
            candidate,
      ];
    });
  }

  void _addBlock() {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _blocks = [
        ..._blocks,
        RoutineItem(
          id: 'import-added-$now',
          title: 'Added review block',
          startMinute: 15 * 60,
          endMinute: 15 * 60 + 45,
          blockType: RoutineBlockType.softBlock,
          category: _categoryFor(widget.source),
          source: RoutineSource.imported,
          hardBlock: false,
          repeatDays: const [1, 2, 3, 4, 5],
          notes: 'Added during import review.',
        ),
      ];
    });
  }

  void _saveBlocks() {
    final controller = ref.read(routineNotifierProvider.notifier);
    for (final block in _blocks) {
      controller.addItem(
        block.copyWith(
          id: '${block.id}-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
    }
    widget.onBack();
  }
}

class _ImportBlockTile extends StatelessWidget {
  final RoutineItem block;
  final bool hasConflict;
  final bool isFlexible;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFlexible;

  const _ImportBlockTile({
    required this.block,
    required this.hasConflict,
    required this.isFlexible,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFlexible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasConflict
              ? OptivusColors.warning.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.78),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  block.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              LiquidPill(
                label: isFlexible ? 'Flexible' : block.blockTypeLabel,
                color: isFlexible
                    ? OptivusColors.blockFlex
                    : block.isHardBlock
                    ? OptivusColors.blockHard
                    : OptivusColors.blockSoft,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            TimelineUtils.formatTimeRange(block.startMinute, block.endMinute),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TextButton(
                label: 'Edit +15m',
                color: OptivusColors.routineAccent,
                onTap: onEdit,
              ),
              _TextButton(
                label: isFlexible ? 'Hard/soft label' : 'Mark flexible',
                color: OptivusColors.blockFlex,
                onTap: onToggleFlexible,
              ),
              _TextButton(
                label: 'Delete',
                color: OptivusColors.danger,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RoutineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RoutineButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

List<RoutineItem> _mockBlocks(RoutineImportSource source) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return switch (source) {
    RoutineImportSource.classes => [
      RoutineItem(
        id: 'import-class-$now-1',
        title: 'Data Structures Lecture',
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
        source: RoutineSource.imported,
        hardBlock: true,
        repeatDays: const [1, 3, 5],
        location: 'Room 304',
        notes: 'Parsed from timetable image.',
      ),
      RoutineItem(
        id: 'import-class-$now-2',
        title: 'Lab Block',
        startMinute: 10 * 60,
        endMinute: 12 * 60,
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.classBlock,
        source: RoutineSource.imported,
        hardBlock: true,
        repeatDays: const [2, 4],
      ),
    ],
    RoutineImportSource.work => [
      RoutineItem(
        id: 'import-work-$now',
        title: 'Client work block',
        startMinute: 14 * 60,
        endMinute: 17 * 60,
        blockType: RoutineBlockType.hardBlock,
        category: RoutineCategory.job,
        source: RoutineSource.imported,
        hardBlock: true,
        repeatDays: const [1, 2, 3, 4, 5],
      ),
    ],
    RoutineImportSource.eating => [
      RoutineItem(
        id: 'import-eating-$now-1',
        title: 'Meal Plan Lunch',
        startMinute: 13 * 60,
        endMinute: 13 * 60 + 30,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
        source: RoutineSource.imported,
        mealCategory: 'Lunch',
        repeatDays: const [1, 2, 3, 4, 5, 6],
      ),
      RoutineItem(
        id: 'import-eating-$now-2',
        title: 'Meal Plan Dinner',
        startMinute: 21 * 60,
        endMinute: 21 * 60 + 30,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.eating,
        source: RoutineSource.imported,
        mealCategory: 'Dinner',
        repeatDays: const [1, 2, 3, 4, 5, 6],
      ),
    ],
    RoutineImportSource.skinCare => [
      RoutineItem(
        id: 'import-skin-$now-1',
        title: 'Morning Skin Care',
        startMinute: 7 * 60 + 35,
        endMinute: 7 * 60 + 45,
        blockType: RoutineBlockType.softBlock,
        category: RoutineCategory.skinCare,
        source: RoutineSource.imported,
        steps: const ['Cleanser', 'Vitamin C', 'Sunscreen'],
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
      ),
    ],
  };
}

RoutineCategory _categoryFor(RoutineImportSource source) {
  return switch (source) {
    RoutineImportSource.classes => RoutineCategory.classBlock,
    RoutineImportSource.work => RoutineCategory.job,
    RoutineImportSource.eating => RoutineCategory.eating,
    RoutineImportSource.skinCare => RoutineCategory.skinCare,
  };
}

String _sourceLabel(RoutineImportSource source) {
  return switch (source) {
    RoutineImportSource.classes => 'Classes',
    RoutineImportSource.work => 'Work',
    RoutineImportSource.eating => 'Eating',
    RoutineImportSource.skinCare => 'Skin Care',
  };
}

String _sourceSummary(RoutineImportSource source) {
  return switch (source) {
    RoutineImportSource.classes =>
      'Parsed preview from class timetable text/photo import. Review hard lecture/lab blocks before saving.',
    RoutineImportSource.work =>
      'Parsed preview from job/work/business schedule import. Review fixed and flexible blocks.',
    RoutineImportSource.eating =>
      'Parsed preview from meal-plan/eating sheet import. Review meal windows and missing dish info.',
    RoutineImportSource.skinCare =>
      'Parsed preview from skin care routine import. Review steps, product timing, and repeat days.',
  };
}
