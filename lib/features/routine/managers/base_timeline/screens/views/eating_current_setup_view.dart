import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/timeline/adapters/meal_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_geometry.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/eating_plan_freshness.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/eating_domain_engine.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_current_setup_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_domain_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_meal_detail_sheet.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/eating_plan_summary_card.dart';
import 'package:optivus/state/app_state.dart';

/// Read-only Current Setup view for Eating Base Timeline.
///
/// Features:
/// - Canonical responsive [BaseTimelineCurrentSetupHeader]
/// - Compact contextual [EatingPlanSummaryCard]
/// - Interactive Timeline hero with [FullScreenTimelineScaffold]
/// - Tapping a front card opens [EatingMealDetailSheet]
class EatingCurrentSetupView extends ConsumerStatefulWidget {
  final BaseTimelineSetup setup;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final VoidCallback onBack;
  final VoidCallback onEditSchedule;
  final VoidCallback onChangeSource;
  final VoidCallback onRemoveSetup;
  final VoidCallback onOpenSettings;
  final VoidCallback onRegenerate;
  final void Function(String r2Key, String? assetId)? onViewPhoto;
  final bool routineRefreshPending;
  final String? routineRefreshMessage;
  final VoidCallback? onRetryRefresh;
  final String? primaryButtonLabel;

  const EatingCurrentSetupView({
    super.key,
    required this.setup,
    required this.selectedDay,
    required this.onDayChanged,
    required this.onBack,
    required this.onEditSchedule,
    required this.onChangeSource,
    required this.onRemoveSetup,
    required this.onOpenSettings,
    required this.onRegenerate,
    this.onViewPhoto,
    this.routineRefreshPending = false,
    this.routineRefreshMessage,
    this.onRetryRefresh,
    this.primaryButtonLabel,
  });

  @override
  ConsumerState<EatingCurrentSetupView> createState() =>
      _EatingCurrentSetupViewState();
}

class _EatingCurrentSetupViewState
    extends ConsumerState<EatingCurrentSetupView> {
  String? _frontBlockId;

  EatingPlanFreshness _evaluatePlanFreshness(BaseTimelineSetup setup) {
    return EatingPlanFreshness.evaluate(
      setup: setup,
      profile: ref.read(userProfileProvider),
      engine: ref.read(eatingDomainEngineProvider),
    );
  }

  bool _isPlanStale(BaseTimelineSetup setup) {
    return _evaluatePlanFreshness(setup) == EatingPlanFreshness.stale;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.setup.snapshotFor(BaseTimelineSection.eating);
    final blockMap = {
      for (final block in widget.setup.eatingBlocks) block.id: block,
    };

    final isStale = _isPlanStale(widget.setup);
    final freshness = _evaluatePlanFreshness(widget.setup);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Unified Current Setup Header
          BaseTimelineCurrentSetupHeader(
            title: 'Eating',
            summary: snapshot.summary,
            accent: OptivusColors.roseAccent,
            onBack: widget.onBack,
            primaryButtonLabel: widget.primaryButtonLabel ?? 'Edit schedule',
            primaryButtonKey: const Key(
              'base-timeline-header-edit-schedule-button',
            ),
            onPrimaryAction: widget.onEditSchedule,
            changeSourceLabel: 'Change source',
            onChangeSource: widget.onChangeSource,
            removeLabel: 'Remove Eating Plan',
            onRemove: widget.onRemoveSetup,
          ),

          // 2. Refresh pending banner
          if (widget.routineRefreshPending && widget.onRetryRefresh != null)
            BaseTimelineRefreshPendingBanner(
              message: widget.routineRefreshMessage,
              onRetry: widget.onRetryRefresh!,
            ),

          // 3. Compact Plan Summary Card
          EatingPlanSummaryCard(
            setup: widget.setup,
            isStale: isStale,
            freshness: freshness,
            onOpenSettings: widget.onOpenSettings,
            onRegenerate: widget.onRegenerate,
            onViewPhoto: snapshot.sourceR2Key != null
                ? () => widget.onViewPhoto?.call(
                    snapshot.sourceR2Key!,
                    snapshot.sourceAssetId,
                  )
                : null,
          ),

          // 4. Interactive Timeline hero
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScaler = MediaQuery.maybeTextScalerOf(context);
                final textScale = textScaler?.scale(1.0) ?? 1.0;
                final availableWidth = constraints.maxWidth > 72
                    ? constraints.maxWidth - 72
                    : constraints.maxWidth;
                final adapter = MealTimelineAdapter(
                  accent: OptivusColors.roseAccent,
                  contentWidth: availableWidth,
                  textScale: textScale,
                );
                final entries = widget.setup.eatingBlocks
                    .expand((b) => adapter.toEntries(b))
                    .toList();

                return FullScreenTimelineScaffold(
                  entries: entries,
                  selectedDay: widget.selectedDay,
                  onDayChanged: widget.onDayChanged,
                  styleBuilder: (entry) => adapter.styleForEntry(entry),
                  overlapPresentation:
                      TimelineOverlapPresentation.frontAndExposed,
                  frontEntryId: _frontBlockId,
                  onFrontSelected: (id) => setState(() => _frontBlockId = id),
                  blockBuilder: (context, positioned) {
                    final block = blockMap[positioned.entry.sourceId];
                    if (block == null) return const SizedBox.shrink();
                    return BaseTimelineDomainCard(
                      positioned: positioned,
                      block: block,
                      domain: BaseTimelineCardDomain.eating,
                      accent: OptivusColors.roseAccent,
                      isEditable: false,
                      onTap: () {
                        if (positioned.hasOverlap && !positioned.isFront) {
                          HapticFeedback.lightImpact();
                          setState(() => _frontBlockId = positioned.entry.id);
                        } else {
                          EatingMealDetailSheet.show(
                            context,
                            block,
                            onEdit: widget.onEditSchedule,
                          );
                        }
                      },
                    );
                  },
                  accent: OptivusColors.roseAccent,
                  mode: TimelineMode.previewReadOnly,
                  visibleRangePolicy:
                      TimelineVisibleRangePolicy.contentAdaptive,
                  stretchPolicy: TimelineStretchPolicy.constraintBased,
                  emptyDayMessage: 'No meals scheduled.',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
