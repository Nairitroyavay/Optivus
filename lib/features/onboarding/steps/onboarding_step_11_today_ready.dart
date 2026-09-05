import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/presentation/step14_presentation_models.dart';
import 'package:optivus/features/onboarding/timeline/adapters/fixed_timeline_adapter.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_entry.dart';
import 'package:optivus/features/onboarding/timeline/models/timeline_style.dart';
import 'package:optivus/features/onboarding/timeline/widgets/full_screen_timeline_scaffold.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

/// Step 14 Final Review & Completion Screen.
class OnboardingStep14 extends ConsumerStatefulWidget {
  final ValueChanged<int>? onJumpToStep;
  final VoidCallback? onCompletionStarted;
  final ValueChanged<bool>? onFullTimelinePreviewChanged;

  const OnboardingStep14({
    super.key,
    this.onJumpToStep,
    this.onCompletionStarted,
    this.onFullTimelinePreviewChanged,
  });

  @override
  ConsumerState<OnboardingStep14> createState() => OnboardingStep14State();
}

class OnboardingStep14State extends ConsumerState<OnboardingStep14> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _attentionSectionKey = GlobalKey();

  Step14PresentationMode _presentationMode = Step14PresentationMode.review;
  String? _expandedGroupId;
  String? _savingGroupId;
  bool _showingAllReviewedChoices = false;
  bool _viewingFullTimeline = false;
  int _timelineSelectedDay = 1;
  RecoverableError? _recoverableError;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get isFullTimelinePreviewOpen => _viewingFullTimeline;

  void _setFullTimelinePreviewOpen(bool isOpen) {
    if (_viewingFullTimeline == isOpen) return;
    setState(() => _viewingFullTimeline = isOpen);
    widget.onFullTimelinePreviewChanged?.call(isOpen);
  }

  void closeFullTimelinePreview() {
    if (!mounted) return;
    _setFullTimelinePreviewOpen(false);
  }

  bool closeFullTimelinePreviewIfOpen() {
    if (!_viewingFullTimeline) return false;
    closeFullTimelinePreview();
    return true;
  }

  void focusFirstUnresolvedConflict({String? targetGroupId}) {
    if (!mounted) return;
    if (targetGroupId != null) {
      setState(() => _expandedGroupId = targetGroupId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _attentionSectionKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  void startFinishingPresentation() {
    if (!mounted) return;
    closeFullTimelinePreview();
    setState(() {
      _presentationMode = Step14PresentationMode.finishing;
      _recoverableError = null;
    });
  }

  void setFailureState(RecoverableError error) {
    if (!mounted) return;
    closeFullTimelinePreview();
    setState(() {
      _presentationMode = Step14PresentationMode.failure;
      _recoverableError = error;
    });
  }

  void setSuccessState() {
    if (!mounted) return;
    closeFullTimelinePreview();
    setState(() {
      _presentationMode = Step14PresentationMode.success;
      _recoverableError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(mockOnboardingProvider);
    final draft = onboarding.draft;
    final bundleResult = OnboardingCompletionService.projectBundleResult(draft);
    final bundle = switch (bundleResult) {
      Step14BundleBuildSuccess(:final bundle) => bundle,
      _ => null,
    };
    final invalidBundle = switch (bundleResult) {
      Step14BundleBuildInvalid invalid => invalid,
      _ => null,
    };
    final corruptBundle = switch (bundleResult) {
      Step14BundleBuildCorrupt corrupt => corrupt,
      _ => null,
    };

    final projectedReadiness = Step14ReadinessSummary.project(
      draft: draft,
      unresolvedConflictGroupCount: 0,
    );
    final readiness = corruptBundle == null
        ? projectedReadiness
        : Step14ReadinessSummary(
            profileComplete: projectedReadiness.profileComplete,
            routineGenerated: false,
            habitsConfigured: projectedReadiness.habitsConfigured,
            unresolvedConflictGroupCount: 0,
          );

    final previewData = bundle != null
        ? Step14FinalPreviewData.project(draft: draft, bundle: bundle)
        : null;

    // Watch active completion job if finishing
    final activeJobNotifier = ref.watch(activeOnboardingCompletionJobProvider);
    final activeJob = activeJobNotifier.value;

    // Handle full timeline preview mode
    if (_viewingFullTimeline && bundle != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) closeFullTimelinePreview();
        },
        child: _buildFullTimelineView(bundle),
      );
    }

    // Handle finishing / success / failure modes
    if (_presentationMode != Step14PresentationMode.review && bundle != null) {
      return _buildFinishingScaffold(
        activeJob: activeJob,
        draft: draft,
        bundle: bundle,
      );
    }

    // Standard Review Mode
    return PopScope(
      canPop: !_viewingFullTimeline,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _viewingFullTimeline) {
          setState(() => _viewingFullTimeline = false);
        }
      },
      child: OnboardingScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 18),

            // Section 1: Readiness Card
            _buildReadinessCard(
              readiness,
              invalidBundle: invalidBundle,
              bundleUnavailable: invalidBundle != null,
            ),
            const SizedBox(height: 16),

            if (corruptBundle != null) ...[
              _buildBundleRecoveryCard(corruptBundle.error),
              const SizedBox(height: 16),
            ],

            // Section 3: Final Preview
            if (previewData != null) ...[
              _buildFinalPreviewCard(previewData, draft),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      key: const ValueKey('step14-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                OptivusColors.aquaAccent.withValues(alpha: 0.28),
                OptivusColors.aquaAccent.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: OptivusColors.aquaAccent.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 20,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your Optivus is ready',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'One final review before we build your day.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Section 1: Readiness Card ───────────────────────────────────────────────
  Widget _buildReadinessCard(
    Step14ReadinessSummary readiness, {
    Step14BundleBuildInvalid? invalidBundle,
    required bool bundleUnavailable,
  }) {
    return OnboardingGlassCard(
      key: const ValueKey('step14-readiness'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Readiness',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              if (readiness.everythingReady)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: OptivusColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: OptivusColors.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Ready',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCheckRow('Profile complete', readiness.profileComplete),
          const SizedBox(height: 8),
          _buildCheckRow('Routine generated', readiness.routineGenerated),
          const SizedBox(height: 8),
          _buildCheckRow('Habits configured', readiness.habitsConfigured),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0x1A000000)),
          const SizedBox(height: 12),
          if (readiness.unresolvedConflictGroupCount > 0)
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: OptivusColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${readiness.unresolvedConflictGroupCount} schedule ${readiness.unresolvedConflictGroupCount == 1 ? 'choice needs' : 'choices need'} you',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.warning,
                    ),
                  ),
                ),
              ],
            )
          else if (!bundleUnavailable)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: OptivusColors.success,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Everything is ready',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.success,
                    ),
                  ),
                ),
              ],
            ),
          if (invalidBundle != null &&
              readiness.unresolvedConflictGroupCount == 0) ...[
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: OptivusColors.warning,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Needs your attention',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            if (invalidBundle.area == Step14InvalidArea.skinCare) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('step14-review-skin-care'),
                onPressed: () => widget.onJumpToStep?.call(7),
                icon: const Icon(Icons.face_rounded, size: 17),
                label: const Text('Review Skin Care'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBundleRecoveryCard(RecoverableError error) {
    return OnboardingGlassCard(
      key: const ValueKey('step14-bundle-recovery'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: OptivusColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.publicMessage,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, bool satisfied) {
    return Row(
      children: [
        Icon(
          satisfied
              ? Icons.check_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: satisfied
              ? OptivusColors.success
              : OptivusColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: satisfied
                  ? OptivusColors.textPrimary
                  : OptivusColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Section 2: Needs your attention ─────────────────────────────────────────
  // ignore: unused_element
  Widget _buildAttentionSection({
    required List<Step14ConflictGroup> unresolvedGroups,
    required List<Step14ConflictGroup> acceptedGroups,
    required List<TimelineConflictDraft> rawConflicts,
    required OnboardingDraft draft,
  }) {
    return Column(
      key: _attentionSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unresolvedGroups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Needs your attention',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OptivusColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${unresolvedGroups.length}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final group in unresolvedGroups) ...[
            _buildConflictGroupCard(
              group: group,
              isExpanded: group.stableGroupId == _expandedGroupId,
              rawConflicts: rawConflicts,
              draft: draft,
            ),
            const SizedBox(height: 10),
          ],
        ],

        // Accepted/Reviewed Choices Summary
        if (acceptedGroups.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildAcceptedChoicesSummary(
            acceptedGroups: acceptedGroups,
            rawConflicts: rawConflicts,
            draft: draft,
          ),
        ],
      ],
    );
  }

  Widget _buildConflictGroupCard({
    required Step14ConflictGroup group,
    required bool isExpanded,
    required List<TimelineConflictDraft> rawConflicts,
    required OnboardingDraft draft,
  }) {
    final isSaving = _savingGroupId == group.stableGroupId;

    return Semantics(
      container: true,
      label:
          '${group.leftLabel} and ${group.rightLabel} overlap on ${group.daySummary}. ${group.publicReason}',
      child: AnimatedContainer(
        key: ValueKey('step14-conflict-${group.stableGroupId}'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        child: OnboardingGlassCard(
          padding: const EdgeInsets.all(16),
          tint: OptivusColors.warning.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedGroupId = isExpanded ? null : group.stableGroupId;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.pairTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: OptivusColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Affected Day Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final day in group.affectedDays)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: group.acceptedDays.contains(day)
                            ? OptivusColors.success.withValues(alpha: 0.15)
                            : OptivusColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        Step14ConflictGroup.weekdayShortName(day),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: group.acceptedDays.contains(day)
                              ? OptivusColors.success
                              : OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),

              if (isExpanded) ...[
                const SizedBox(height: 10),
                // Time Range
                if (group.hasUniformTimeRange &&
                    group.sharedTimeRange.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: OptivusColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          group.sharedTimeRange,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (group.overlapRangesByDay.isNotEmpty) ...[
                  for (final entry in group.overlapRangesByDay.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${Step14ConflictGroup.weekdayShortName(entry.key)} · ${entry.value}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Text(
                  group.publicReason,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OptivusColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: isSaving
                          ? null
                          : () => _editBlock(draft, group.leftEntryIdentity),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text('Edit ${group.leftLabel}'),
                    ),
                    OutlinedButton(
                      onPressed: isSaving
                          ? null
                          : () => _editBlock(draft, group.rightEntryIdentity),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text('Edit ${group.rightLabel}'),
                    ),
                    if (group.canKeepBoth) ...[
                      FilledButton.tonal(
                        key: ValueKey(
                          'step14-keep-both-${group.stableGroupId}',
                        ),
                        onPressed: isSaving
                            ? null
                            : () => _handleKeepBothDays(
                                group: group,
                                daysToAccept: group.unresolvedDays,
                                rawConflicts: rawConflicts,
                              ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Keep both on these days'),
                      ),
                      OutlinedButton(
                        key: ValueKey(
                          'step14-review-days-${group.stableGroupId}',
                        ),
                        onPressed: isSaving
                            ? null
                            : () => _showReviewDaysSheet(
                                group: group,
                                rawConflicts: rawConflicts,
                              ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Review days'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedChoicesSummary({
    required List<Step14ConflictGroup> acceptedGroups,
    required List<TimelineConflictDraft> rawConflicts,
    required OnboardingDraft draft,
  }) {
    if (acceptedGroups.length <= 2 || _showingAllReviewedChoices) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in acceptedGroups) ...[
            OnboardingGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              tint: OptivusColors.success.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: OptivusColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.pairTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Kept together · ${group.daySummary}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showReviewDaysSheet(
                      group: group,
                      rawConflicts: rawConflicts,
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      );
    }

    // Aggregated view for > 2 accepted choices
    return OnboardingGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      tint: OptivusColors.success.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: OptivusColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${acceptedGroups.length} schedule choices reviewed',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showingAllReviewedChoices = true),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'View reviewed choices',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3: Final Preview Card ───────────────────────────────────────────
  Widget _buildFinalPreviewCard(
    Step14FinalPreviewData previewData,
    OnboardingDraft draft,
  ) {
    return OnboardingGlassCard(
      key: const ValueKey('step14-final-preview'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Final preview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              OnboardingActionPill(
                key: const ValueKey('step14-edit-setup'),
                label: 'Edit setup',
                icon: Icons.tune_rounded,
                accent: OptivusColors.brandAccent,
                compact: true,
                onTap: _showEditSetupSheet,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPreviewRow('Goal', previewData.primaryGoal ?? 'Not selected'),
          _buildPreviewRow(
            'Schedule',
            '${previewData.scheduledActivitiesCount} activities scheduled',
          ),
          _buildPreviewRow('Habit focus', previewData.habitFocus),
          _buildPreviewRow(
            'Coach',
            '${previewData.coachName} (${previewData.coachStyle})',
          ),
          _buildPreviewRow(
            'Notifications',
            previewData.notificationsCount > 0
                ? '${previewData.notificationsCount} selected'
                : 'None selected',
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0x1A000000)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('step14-view-timeline'),
              onPressed: () => _setFullTimelinePreviewOpen(true),
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
              label: const Text('See your timeline'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: OptivusColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full Timeline View (AH-F018) ────────────────────────────────────────────
  Widget _buildFullTimelineView(OnboardingCompletionBundle bundle) {
    final entries = <TimelineEntry>[];
    for (final block in bundle.baseTimelineBlocks) {
      if (block.section == 'fixed' &&
          (block.crossesMidnight || block.startMinute >= block.endMinute)) {
        entries.addAll(
          const FixedTimelineAdapter()
              .toEntries(block)
              .map((entry) => entry.copyWith(isEditable: false)),
        );
        continue;
      }
      final category = switch (block.section) {
        'classes' => TimelineCategory.classes,
        'job_work_business' => TimelineCategory.work,
        'eating' => TimelineCategory.meal,
        'fixed' => TimelineCategory.fixed,
        'skin_care' => TimelineCategory.skinCare,
        _ => TimelineCategory.other,
      };
      entries.add(
        TimelineEntry(
          id: block.id,
          sourceId: block.id,
          startMinute: block.startMinute,
          endMinute: block.endMinute,
          repeatDays: block.repeatDays,
          title: block.title,
          subtitle: block.location,
          category: category,
          isEditable: false,
        ),
      );
    }

    return FullScreenTimelineScaffold(
      key: const ValueKey('onboarding-step14-shared-preview'),
      entries: entries,
      selectedDay: _timelineSelectedDay,
      onDayChanged: (day) => setState(() => _timelineSelectedDay = day),
      title: 'Today timeline preview',
      subtitle: 'Review only — edit items from their setup step.',
      mode: TimelineMode.previewReadOnly,
      accent: OptivusColors.aquaAccent,
      styleBuilder: (entry) =>
          TimelineEntryStyle.defaultForCategory(entry.category),
    );
  }

  // ── Finishing / Success / Failure Presentation ──────────────────────────────
  Widget _buildFinishingScaffold({
    required OnboardingCompletionJob? activeJob,
    required OnboardingDraft draft,
    required OnboardingCompletionBundle bundle,
  }) {
    if (_presentationMode == Step14PresentationMode.success) {
      return _buildSuccessView();
    }

    if (_presentationMode == Step14PresentationMode.failure &&
        _recoverableError != null) {
      return _buildFailureView(activeJob);
    }

    // Finishing Progress View
    final currentStage =
        activeJob?.stage ?? OnboardingCompletionStage.validateInput;
    final jobStatus = activeJob?.status ?? OnboardingJobStatus.running;
    final stageProjections = CompletionStageProjection.projectAll(
      currentStage: currentStage,
      jobStatus: jobStatus,
    );

    return Scaffold(
      key: const ValueKey('step14-finishing'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Subtle Orb Visual
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          OptivusColors.aquaAccent.withValues(alpha: 0.35),
                          OptivusColors.aquaAccent.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.90),
                          boxShadow: [
                            BoxShadow(
                              color: OptivusColors.aquaAccent.withValues(
                                alpha: 0.40,
                              ),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sync_rounded,
                          size: 20,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Building your Optivus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "We're putting everything in place.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Stage rows
                  for (final stage in stageProjections) ...[
                    _buildStageRow(stage),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageRow(CompletionStageProjection stage) {
    return Row(
      key: ValueKey('step14-finishing-stage-${stage.stageId.id}'),
      children: [
        _buildStageIndicator(stage.status),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            stage.publicLabel,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: stage.status == CompletionStageStatus.active
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: stage.status == CompletionStageStatus.pending
                  ? OptivusColors.textSecondary.withValues(alpha: 0.5)
                  : OptivusColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageIndicator(CompletionStageStatus status) {
    return switch (status) {
      CompletionStageStatus.completed => const Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: OptivusColors.success,
      ),
      CompletionStageStatus.active => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: OptivusColors.brandAccent.withValues(alpha: 0.2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: OptivusColors.brandAccent,
            ),
          ),
        ),
      ),
      CompletionStageStatus.pending => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: OptivusColors.textSecondary.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      ),
      CompletionStageStatus.failed => const Icon(
        Icons.error_rounded,
        size: 18,
        color: OptivusColors.danger,
      ),
    };
  }

  Widget _buildSuccessView() {
    return Scaffold(
      key: const ValueKey('step14-success'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OptivusColors.success.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 40,
                  color: OptivusColors.success,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "You're ready",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: OptivusColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your Optivus is ready for today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailureView(OnboardingCompletionJob? activeJob) {
    final error = _recoverableError!;
    final snapshot = const OnboardingCurrentRunSnapshot.none();
    final canReturn = canReturnToStep14Review(
      job: activeJob,
      currentRunSnapshot: snapshot,
    );

    return Scaffold(
      key: const ValueKey('step14-failure'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: OptivusColors.warning.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 32,
                      color: OptivusColors.warning,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your setup is safe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.publicMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions based on RecoverableError
                  if (error.retrySafe)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _presentationMode =
                                Step14PresentationMode.finishing;
                            _recoverableError = null;
                          });
                          widget.onCompletionStarted?.call();
                        },
                        child: const Text('Try Again'),
                      ),
                    ),
                  if (error.retryAction ==
                      RecoverableRetryAction.reauthenticate) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            ref.read(authProvider.notifier).logout(),
                        child: const Text('Sign In Again'),
                      ),
                    ),
                  ],
                  if (error.retryAction ==
                      RecoverableRetryAction.restartRecovery) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go('/onboarding/needs-action'),
                        child: const Text('Recover Setup'),
                      ),
                    ),
                  ],
                  if (canReturn) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _presentationMode = Step14PresentationMode.review;
                          _recoverableError = null;
                        });
                      },
                      child: const Text('Back to Review'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Actions ──────────────────────────────────────────────────────────
  void _editBlock(OnboardingDraft draft, String blockId) {
    final block = draft.baseTimeline.blockById(blockId);
    if (block == null) return;
    final step = switch (block.section) {
      'classes' || 'job_work_business' => 4,
      'eating' => 5,
      'fixed' => 6,
      'skin_care' => 7,
      _ => 4,
    };
    widget.onJumpToStep?.call(step);
  }

  void _showEditSetupSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            side: BorderSide(
              color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
              width: 1.0,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: OptivusColors.borderNeutral.withValues(
                          alpha: 0.60,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Edit Setup',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _buildSetupOption(
                    icon: Icons.calendar_today_rounded,
                    title: 'Schedule & Classes',
                    step: 4,
                  ),
                  _buildSetupOption(
                    icon: Icons.restaurant_rounded,
                    title: 'Meals & Eating Mode',
                    step: 5,
                  ),
                  _buildSetupOption(
                    icon: Icons.bedtime_rounded,
                    title: 'Fixed Routine & Sleep',
                    step: 6,
                  ),
                  _buildSetupOption(
                    icon: Icons.face_rounded,
                    title: 'Skin Care',
                    step: 7,
                  ),
                  _buildSetupOption(
                    icon: Icons.track_changes_rounded,
                    title: 'Habits & Check-ins',
                    step: 8,
                  ),
                  _buildSetupOption(
                    icon: Icons.flag_rounded,
                    title: 'Identity Goals',
                    step: 10,
                  ),
                  _buildSetupOption(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    step: 13,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetupOption({
    required IconData icon,
    required String title,
    required int step,
  }) {
    return ListTile(
      leading: Icon(icon, color: OptivusColors.brandAccent),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () {
        Navigator.pop(context);
        widget.onJumpToStep?.call(step);
      },
    );
  }

  void _handleKeepBothDays({
    required Step14ConflictGroup group,
    required List<int> daysToAccept,
    List<TimelineConflictDraft>? rawConflicts,
  }) {
    if (_savingGroupId != null) return;
    setState(() => _savingGroupId = group.stableGroupId);
    final draft = ref.read(mockOnboardingProvider).draft;
    final timezoneId = draft.timezoneId.isNotEmpty
        ? draft.timezoneId
        : ref.read(regionSettingsProvider).timezone;

    final conflicts =
        rawConflicts ??
        draft.baseTimeline.detectConflicts(
          ownerUid: draft.uid.isEmpty ? 'local-onboarding-owner' : draft.uid,
          timezoneId: timezoneId,
          revision: draft.revision,
        );

    final rawForGroup = conflicts.where((c) {
      final id1 = c.firstBlockId;
      final id2 = c.secondBlockId;
      final leftId = id1.compareTo(id2) <= 0 ? id1 : id2;
      final rightId = id1.compareTo(id2) <= 0 ? id2 : id1;
      return '$leftId|$rightId|${c.conflictType}' == group.stableGroupId;
    }).firstOrNull;

    if (rawForGroup != null) {
      ref
          .read(mockOnboardingProvider.notifier)
          .updateDraft(
            (draft) => draft.acceptTimelineConflictGroup(
              conflict: rawForGroup,
              weekdays: daysToAccept,
              timezoneId: timezoneId,
            ),
          );
    }

    if (mounted) {
      setState(() => _savingGroupId = null);
    }
  }

  void _showReviewDaysSheet({
    required Step14ConflictGroup group,
    required List<TimelineConflictDraft> rawConflicts,
  }) {
    final selectedDays = group.acceptedDays.toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                side: BorderSide(
                  color: OptivusColors.borderNeutral.withValues(alpha: 0.50),
                  width: 1.0,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: OptivusColors.borderNeutral.withValues(
                              alpha: 0.60,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        group.pairTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Choose where this overlap is intentional',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final day in group.affectedDays)
                        CheckboxListTile(
                          value: selectedDays.contains(day),
                          title: Text(
                            Step14ConflictGroup.weekdayFullName(day),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onChanged: (checked) {
                            setModalState(() {
                              if (checked ?? false) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleKeepBothDays(
                            group: group,
                            daysToAccept: selectedDays.toList()..sort(),
                            rawConflicts: rawConflicts,
                          );
                        },
                        child: const Text('Save Choices'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
