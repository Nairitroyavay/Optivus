import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';

class OnboardingStep6 extends ConsumerWidget {
  const OnboardingStep6({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(mockOnboardingProvider).draft.baseTimeline;
    final fixedBlocks = base.confirmedBlocksForSection('fixed');
    final sleep = _sleepBlock(base);
    final bath = _bathBlock(base);
    final stage = base.fixedScheduleSetupStep;

    return OnboardingStepBody(
      title: 'Fixed Schedule',
      subtitle: 'Manual-only non-negotiable blocks.',
      accent: const Color(0xFFF2B84B),
      children: [
        if (stage <= 0)
          _FixedTimeStage(
            title: 'Sleep time',
            subtitle: 'Sleep can cross midnight and stays one overnight block.',
            minute: sleep.startMinute,
            icon: Icons.bedtime_rounded,
            onChanged: (value) => _updateSleep(ref, sleepStart: value),
          )
        else if (stage == 1)
          _FixedTimeStage(
            title: 'Wake time',
            subtitle: 'This is saved as the end of your overnight sleep block.',
            minute: sleep.endMinute,
            icon: Icons.wb_sunny_rounded,
            onChanged: (value) => _updateSleep(ref, wakeMinute: value),
          )
        else if (stage == 2)
          _FixedTimeStage(
            title: 'Bath time',
            subtitle: 'Set the normal bath or shower time.',
            minute: bath.startMinute,
            icon: Icons.shower_rounded,
            onChanged: (value) => _updateBath(ref, startMinute: value),
          )
        else if (stage == 3)
          const _OptionalFixedBlockStage()
        else if (stage == 4)
          _FixedPreview(blocks: fixedBlocks)
        else
          _FixedSummary(blocks: fixedBlocks),
      ],
    );
  }
}

class _FixedTimeStage extends StatelessWidget {
  final String title;
  final String subtitle;
  final int minute;
  final IconData icon;
  final ValueChanged<int> onChanged;

  const _FixedTimeStage({
    required this.title,
    required this.subtitle,
    required this.minute,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingGlassCard(
          tint: const Color(0xFFFFF1B8).withValues(alpha: 0.42),
          child: Row(
            children: [
              const Icon(Icons.lock_clock_rounded, color: Color(0xFFB77800)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OnboardingTimeTile(
          title: title,
          subtitle: subtitle,
          minute: minute,
          onChanged: onChanged,
          icon: icon,
          accent: const Color(0xFFF2B84B),
        ),
        const SizedBox(height: 12),
        _SleepPreview(
          sleepStart: title == 'Wake time' ? null : minute,
          wake: title == 'Wake time' ? minute : null,
        ),
      ],
    );
  }
}

class _OptionalFixedBlockStage extends ConsumerStatefulWidget {
  const _OptionalFixedBlockStage();

  @override
  ConsumerState<_OptionalFixedBlockStage> createState() =>
      _OptionalFixedBlockStageState();
}

class _OptionalFixedBlockStageState
    extends ConsumerState<_OptionalFixedBlockStage> {
  String _title = 'Travel';
  int _startMinute = 8 * 60;
  int _duration = 30;

  @override
  Widget build(BuildContext context) {
    const presets = [
      'Travel',
      'Prayer',
      'Medication',
      'Tuition',
      'Family responsibility',
      'Other',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: const Color(0xFFFFF1B8).withValues(alpha: 0.40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional fixed blocks',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add only non-negotiable anchors. You can leave this empty.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets
                    .map(
                      (preset) => OnboardingChip(
                        label: preset,
                        selected: _title == preset,
                        accent: const Color(0xFFF2B84B),
                        onTap: () => setState(() => _title = preset),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OnboardingTimeTile(
          title: 'Start time',
          subtitle: 'Choose when this fixed anchor usually starts.',
          minute: _startMinute,
          icon: Icons.schedule_rounded,
          accent: const Color(0xFFF2B84B),
          onChanged: (value) => setState(() => _startMinute = value),
        ),
        const SizedBox(height: 12),
        _DurationCard(
          duration: _duration,
          onChanged: (value) => setState(() => _duration = value),
        ),
        const SizedBox(height: 12),
        OnboardingGlassCard(
          child: Center(
            child: OnboardingActionPill(
              label: 'Add fixed block',
              icon: Icons.add_rounded,
              accent: const Color(0xFFF2B84B),
              selected: true,
              onTap: _addBlock,
            ),
          ),
        ),
      ],
    );
  }

  void _addBlock() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final block = TimelineBlockDraft(
      id: 'fixed-${_title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}-$now',
      section: 'fixed',
      title: _title,
      startMinute: _startMinute,
      endMinute: (_startMinute + _duration).clamp(1, 24 * 60).toInt(),
      repeatDays: onboardingEveryDay(),
      blockType: TimelineBlockDraft.hardBlockKey,
      source: OnboardingDraft.sourceOnboarding,
    );
    updateBaseTimelineDraft(
      ref,
      onboardingFixedStepIndex,
      (base) => base.upsertBlock(block),
    );
  }
}

class _DurationCard extends StatelessWidget {
  final int duration;
  final ValueChanged<int> onChanged;

  const _DurationCard({required this.duration, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [10, 15, 30, 45, 60, 90];
    return OnboardingGlassCard(
      tint: const Color(0xFFFFF1B8).withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Duration',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => OnboardingChip(
                    label: '${option}m',
                    selected: duration == option,
                    accent: const Color(0xFFF2B84B),
                    onTap: () => onChanged(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FixedPreview extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _FixedPreview({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassTimelinePreview(blocks: blocks),
        const SizedBox(height: 12),
        OnboardingMiniBlockList(
          title: 'Review fixed blocks',
          blocks: blocks,
          accent: const Color(0xFFF2B84B),
          emptyLabel: 'Sleep and bath will appear here.',
        ),
      ],
    );
  }
}

class _FixedSummary extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _FixedSummary({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return OnboardingMiniBlockList(
      title: 'Fixed schedule summary',
      blocks: blocks,
      accent: const Color(0xFFF2B84B),
      emptyLabel: 'No fixed blocks saved yet.',
    );
  }
}

class _GlassTimelinePreview extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _GlassTimelinePreview({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final sleep = blocks.where(
      (block) => block.id == BaseTimelineDraft.fixedSleepId,
    );
    final sleepBlock = sleep.isEmpty ? null : sleep.first;
    return OnboardingGlassCard(
      tint: const Color(0xFFFFF1B8).withValues(alpha: 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Glass preview',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bedtime_rounded, color: Color(0xFFB77800)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sleepBlock == null
                        ? 'Sleep block not set'
                        : '${onboardingTimeLabel(sleepBlock.startMinute)} - ${onboardingTimeLabel(sleepBlock.endMinute)} overnight',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepPreview extends ConsumerWidget {
  final int? sleepStart;
  final int? wake;

  const _SleepPreview({this.sleepStart, this.wake});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleep = _sleepBlock(
      ref.watch(mockOnboardingProvider).draft.baseTimeline,
    );
    return OnboardingGlassCard(
      tint: const Color(0xFFFFF1B8).withValues(alpha: 0.30),
      child: Row(
        children: [
          const Icon(Icons.bed_rounded, color: Color(0xFFB77800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${onboardingTimeLabel(sleepStart ?? sleep.startMinute)} - ${onboardingTimeLabel(wake ?? sleep.endMinute)} as one sleep block',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TimelineBlockDraft _sleepBlock(BaseTimelineDraft base) {
  return base.blocks.firstWhere(
    (block) => block.id == BaseTimelineDraft.fixedSleepId,
    orElse: BaseTimelineDraft.defaultSleepBlock,
  );
}

TimelineBlockDraft _bathBlock(BaseTimelineDraft base) {
  return base.blocks.firstWhere(
    (block) => block.id == BaseTimelineDraft.fixedBathId,
    orElse: BaseTimelineDraft.defaultBathBlock,
  );
}

void _updateSleep(WidgetRef ref, {int? sleepStart, int? wakeMinute}) {
  updateBaseTimelineDraft(ref, onboardingFixedStepIndex, (base) {
    final current = _sleepBlock(base);
    final start = sleepStart ?? current.startMinute;
    final end = wakeMinute ?? current.endMinute;
    return base.upsertBlock(
      current.copyWith(
        startMinute: start,
        endMinute: end,
        crossesMidnight: end <= start,
        repeatDays: onboardingEveryDay(),
        blockType: TimelineBlockDraft.hardBlockKey,
        source: OnboardingDraft.sourceOnboarding,
      ),
    );
  });
}

void _updateBath(WidgetRef ref, {required int startMinute}) {
  updateBaseTimelineDraft(ref, onboardingFixedStepIndex, (base) {
    final current = _bathBlock(base);
    return base.upsertBlock(
      current.copyWith(
        startMinute: startMinute,
        endMinute: (startMinute + 30).clamp(1, 24 * 60).toInt(),
        crossesMidnight: false,
        repeatDays: onboardingEveryDay(),
        blockType: TimelineBlockDraft.hardBlockKey,
        source: OnboardingDraft.sourceOnboarding,
      ),
    );
  });
}
