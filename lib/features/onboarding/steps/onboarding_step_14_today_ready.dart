import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/errors/completion_error_mapper.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/presentation/step14_presentation_models.dart';
import 'package:optivus/features/onboarding/onboarding_step_id.dart';
import 'package:optivus/features/onboarding/timeline/widgets/step14_final_timeline.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_completion_bundle.dart';
import 'package:optivus/models/onboarding_completion_job.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/services/onboarding_completion_job_service.dart';
import 'package:optivus/services/onboarding_completion_service.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';

int step14InitialTimelineDay([DateTime? now]) =>
    (now ?? DateTime.now()).weekday;

/// Step 14 Final Review & Completion Screen.
class OnboardingTodayReadyStep extends ConsumerStatefulWidget {
  final ValueChanged<int>? onJumpToStep;
  final VoidCallback? onCompletionStarted;
  final ValueChanged<bool>? onFullTimelinePreviewChanged;

  const OnboardingTodayReadyStep({
    super.key,
    this.onJumpToStep,
    this.onCompletionStarted,
    this.onFullTimelinePreviewChanged,
  });

  @override
  ConsumerState<OnboardingTodayReadyStep> createState() =>
      OnboardingTodayReadyStepState();
}

class OnboardingTodayReadyStepState
    extends ConsumerState<OnboardingTodayReadyStep> {
  final ScrollController _scrollController = ScrollController();

  Step14PresentationMode _presentationMode = Step14PresentationMode.review;
  bool _viewingFullTimeline = false;
  int _timelineSelectedDay = step14InitialTimelineDay();
  RecoverableError? _recoverableError;
  OnboardingCompletionJob? _failureJob;
  OnboardingCurrentRunSnapshot? _failureSnapshot;
  int _failureReadGeneration = 0;

  @override
  void dispose() {
    _failureReadGeneration++;
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

  void startFinishingPresentation() {
    if (!mounted) return;
    closeFullTimelinePreview();
    _failureReadGeneration++;
    _failureJob = null;
    _failureSnapshot = null;
    setState(() {
      _presentationMode = Step14PresentationMode.finishing;
      _recoverableError = null;
    });
  }

  void setFailureState(RecoverableError error, {OnboardingCompletionJob? job}) {
    if (!mounted) return;
    closeFullTimelinePreview();
    setState(() {
      _presentationMode = Step14PresentationMode.failure;
      _recoverableError = error;
      _failureJob = job;
      _failureSnapshot = null;
    });
    _loadFailureSnapshot(++_failureReadGeneration);
  }

  Future<void> _loadFailureSnapshot(int generation) async {
    final uid = ref.read(onboardingStateProvider).draft.uid;
    try {
      final snapshot = await ref
          .read(onboardingCompletionJobServiceProvider)
          .loadCurrentRunSnapshot(uid);
      if (!mounted ||
          generation != _failureReadGeneration ||
          ref.read(onboardingStateProvider).draft.uid != uid) {
        return;
      }
      setState(() {
        _failureSnapshot = snapshot;
        final persisted = snapshot.job;
        if (persisted != null &&
            persisted.lastFailureCode != null &&
            (_failureJob == null || _failureJob!.jobId == persisted.jobId)) {
          _failureJob = persisted;
          _recoverableError = CompletionErrorMapper.map(job: persisted);
        }
        if (snapshot.hasPointer &&
            (persisted == null ||
                snapshot.ownerUid != uid ||
                snapshot.runId != persisted.jobId ||
                snapshot.pointerSchemaVersion != 1 ||
                snapshot.sourceFingerprint != persisted.sourceFingerprint ||
                snapshot.draftRevision != persisted.draftRevision ||
                !['active', 'completed'].contains(snapshot.pointerStatus))) {
          _recoverableError = CompletionErrorMapper.map(isContradiction: true);
        }
      });
    } catch (_) {
      // Unknown server state is not evidence that editing is safe.
      // Keep retry available, but never fabricate an absent pointer.
    }
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
    final onboarding = ref.watch(onboardingStateProvider);
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
        child: _buildFullTimelineView(bundle, draft),
      );
    }

    // Handle finishing / success / failure modes
    if (_presentationMode != Step14PresentationMode.review) {
      return _buildFinishingScaffold(
        activeJob: activeJob?.uid == draft.uid ? activeJob : null,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _buildHeader(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: OnboardingScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  if (previewData != null) ...[
                    _buildFinalPreviewCard(previewData, draft),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
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
                onPressed: () =>
                    widget.onJumpToStep?.call(OnboardingStepId.skinCare.index),
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
  Widget _buildFullTimelineView(
    OnboardingCompletionBundle bundle,
    OnboardingDraft draft,
  ) {
    return Step14FinalTimeline(
      key: const ValueKey('onboarding-step14-shared-preview'),
      bundle: bundle,
      sourceBlocks: draft.baseTimeline.blocks,
      selectedDay: _timelineSelectedDay,
      onDayChanged: (day) => setState(() => _timelineSelectedDay = day),
    );
  }

  // ── Finishing / Success / Failure Presentation ──────────────────────────────
  Widget _buildFinishingScaffold({
    required OnboardingCompletionJob? activeJob,
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
    final snapshot = _failureSnapshot;
    final job = _failureJob ?? activeJob;
    final canReturn =
        snapshot != null &&
        canReturnToStep14Review(job: job, currentRunSnapshot: snapshot);
    final failureStage = CompletionErrorMapper.safeStage(
      job?.lastFailureStage ?? error.supportHint,
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

                  ExpansionTile(
                    key: const ValueKey('step14-technical-details'),
                    title: const Text('Technical details'),
                    children: [
                      Text(
                        'Stage: $failureStage',
                        key: const ValueKey('step14-failure-stage'),
                      ),
                      Text(
                        'Code: ${CompletionErrorMapper.safeCode(error.diagnosticCode)}',
                        key: const ValueKey('step14-failure-code'),
                      ),
                      Text(
                        'Retryable: ${error.retrySafe ? 'Yes' : 'No'}',
                        key: const ValueKey('step14-failure-retryable'),
                      ),
                    ],
                  ),
                  // Actions based on RecoverableError
                  if (error.retrySafe)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          startFinishingPresentation();
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
                    step: OnboardingStepId.classesJob.index,
                  ),
                  _buildSetupOption(
                    icon: Icons.restaurant_rounded,
                    title: 'Meals & Eating Mode',
                    step: OnboardingStepId.eating.index,
                  ),
                  _buildSetupOption(
                    icon: Icons.bedtime_rounded,
                    title: 'Fixed Routine & Sleep',
                    step: OnboardingStepId.fixedSchedule.index,
                  ),
                  _buildSetupOption(
                    icon: Icons.face_rounded,
                    title: 'Skin Care',
                    step: OnboardingStepId.skinCare.index,
                  ),
                  _buildSetupOption(
                    icon: Icons.track_changes_rounded,
                    title: 'Habits & Check-ins',
                    step: OnboardingStepId.badHabits.index,
                  ),
                  _buildSetupOption(
                    icon: Icons.flag_rounded,
                    title: 'Identity Goals',
                    step: OnboardingStepId.identityGoals.index,
                  ),
                  _buildSetupOption(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    step: OnboardingStepId.notifications.index,
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
}
