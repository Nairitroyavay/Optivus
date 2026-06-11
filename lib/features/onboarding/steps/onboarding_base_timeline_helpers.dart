import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_step.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/routine_import_review_screen.dart';
import 'package:optivus/features/routine/providers/routine_navigation_provider.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/upload_state.dart';

const onboardingClassJobStepIndex = 4;
const onboardingEatingStepIndex = 5;
const onboardingFixedStepIndex = 6;
const onboardingSkinCareStepIndex = 7;

const onboardingSectionClasses = 'Classes';
const onboardingSectionWork = 'Job / Work / Business';
const onboardingSectionEating = 'Eating';
const onboardingSectionSkinCare = 'Skin Care';

String onboardingTimelineSectionKey(String sectionLabel) {
  return switch (sectionLabel) {
    onboardingSectionClasses => 'classes',
    onboardingSectionWork => 'job_work_business',
    onboardingSectionEating => 'eating',
    onboardingSectionSkinCare => 'skin_care',
    _ => 'fixed',
  };
}

RoutineImportSource onboardingImportSourceForSection(String sectionLabel) {
  return switch (sectionLabel) {
    onboardingSectionWork => RoutineImportSource.work,
    onboardingSectionEating => RoutineImportSource.eating,
    onboardingSectionSkinCare => RoutineImportSource.skinCare,
    _ => RoutineImportSource.classes,
  };
}

String onboardingImportId(String sectionLabel, String mode) {
  final section = sectionLabel
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+$'), '');
  final normalizedMode = mode
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+$'), '');
  return '${section}_$normalizedMode';
}

String onboardingTimeLabel(int minute) {
  return TimelineUtils.formatMinute(minute.clamp(0, 24 * 60).toInt());
}

int onboardingMinuteFromTime(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}

TimeOfDay onboardingTimeFromMinute(int minute) {
  final safe = minute.clamp(0, 24 * 60 - 1).toInt();
  return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
}

List<int> onboardingEveryDay() => const [1, 2, 3, 4, 5, 6, 7];

List<int> onboardingWeekdays() => const [1, 2, 3, 4, 5];

class OnboardingStageBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const OnboardingStageBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 18),
        ),
      ),
    );
  }
}

BaseTimelineDraft upsertGeneratedEatingImport(
  BaseTimelineDraft base,
  BodyBasicsDraft body,
) {
  final now = DateTime.now();
  final existing = base.latestImportForSection(onboardingSectionEating);
  final blocks = _generatedEatingBlocks(base, body, now);
  final entry = PendingFutureImportDraft(
    id: onboardingImportId(onboardingSectionEating, 'ai_generated'),
    section: onboardingSectionEating,
    mode: 'AI Generated',
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
    status: PendingFutureImportDraft.needsReviewStatus,
    parsedBlocks: blocks,
    confidence: 0.72,
  );
  return base.upsertPendingImport(entry);
}

BaseTimelineDraft upsertGeneratedSkinCareImport(BaseTimelineDraft base) {
  final now = DateTime.now();
  final existing = base.latestImportForSection(onboardingSectionSkinCare);
  final blocks = _generatedSkinCareBlocks(base, now);
  final entry = PendingFutureImportDraft(
    id: onboardingImportId(onboardingSectionSkinCare, 'ai_generated'),
    section: onboardingSectionSkinCare,
    mode: 'AI Generated',
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
    status: PendingFutureImportDraft.needsReviewStatus,
    parsedBlocks: blocks,
    confidence: 0.70,
  );
  return base.upsertPendingImport(entry);
}

List<TimelineBlockDraft> _generatedEatingBlocks(
  BaseTimelineDraft base,
  BodyBasicsDraft body,
  DateTime now,
) {
  final dailyCalories = body.calorieEstimate ?? 0;
  final dailyProtein = body.proteinEstimate ?? 0;
  TimelineBlockDraft meal({
    required String id,
    required String title,
    required int start,
    required int duration,
    required String category,
    required double calorieRatio,
    required double proteinRatio,
  }) {
    return TimelineBlockDraft(
      id: 'eating-$id-${now.millisecondsSinceEpoch}',
      section: 'eating',
      title: title,
      startMinute: start,
      endMinute: (start + duration).clamp(1, 24 * 60).toInt(),
      repeatDays: onboardingEveryDay(),
      blockType: TimelineBlockDraft.softBlockKey,
      source: 'ai_generated',
      mealCategory: category,
      calories: dailyCalories <= 0
          ? null
          : double.parse((dailyCalories * calorieRatio).toStringAsFixed(0)),
      protein: dailyProtein <= 0
          ? null
          : double.parse((dailyProtein * proteinRatio).toStringAsFixed(0)),
    );
  }

  final blocks = <TimelineBlockDraft>[
    meal(
      id: 'breakfast',
      title: _mealTitle(base, 'Breakfast'),
      start: base.breakfastMinute ?? 8 * 60,
      duration: 30,
      category: 'Breakfast',
      calorieRatio: 0.25,
      proteinRatio: 0.25,
    ),
    meal(
      id: 'lunch',
      title: _mealTitle(base, 'Lunch'),
      start: base.lunchMinute ?? 13 * 60,
      duration: 35,
      category: 'Lunch',
      calorieRatio: 0.35,
      proteinRatio: 0.35,
    ),
    meal(
      id: 'dinner',
      title: _mealTitle(base, 'Dinner'),
      start: base.dinnerMinute ?? 20 * 60,
      duration: 35,
      category: 'Dinner',
      calorieRatio: 0.30,
      proteinRatio: 0.30,
    ),
  ];
  final snack = base.snackMinute;
  if (snack != null) {
    blocks.add(
      meal(
        id: 'snack',
        title: _mealTitle(base, 'Snack'),
        start: snack,
        duration: 20,
        category: 'Snack',
        calorieRatio: 0.10,
        proteinRatio: 0.10,
      ),
    );
  }
  return blocks;
}

String _mealTitle(BaseTimelineDraft base, String slot) {
  final goal = switch (base.mealPlanningGoal) {
    'gain_weight' => 'weight gain',
    'build_muscle' || 'muscle_gain' => 'muscle support',
    'lose_fat' || 'fat_loss' => 'fat loss',
    'eat_healthier' => 'healthy',
    _ => 'balanced',
  };
  return '$slot - $goal meal';
}

List<TimelineBlockDraft> _generatedSkinCareBlocks(
  BaseTimelineDraft base,
  DateTime now,
) {
  final products = _skinCareProductList(base);
  final hasMany = products.length >= 5;
  final morningProducts = products
      .where((item) => !_looksLikeNightActive(item))
      .take(4)
      .toList(growable: false);
  final nightProducts = products
      .where((item) => !_looksLikeSunscreen(item))
      .take(5)
      .toList(growable: false);
  final recoveryProducts = nightProducts
      .where((item) => !_looksLikeNightActive(item))
      .toList(growable: false);

  return [
    TimelineBlockDraft(
      id: 'skin-morning-${now.millisecondsSinceEpoch}',
      section: 'skin_care',
      title: 'Morning skin care',
      startMinute: 7 * 60 + 30,
      endMinute: 7 * 60 + 45,
      repeatDays: onboardingEveryDay(),
      blockType: TimelineBlockDraft.softBlockKey,
      source: 'ai_generated',
      skincareProducts: morningProducts.isEmpty
          ? const ['Cleanser', 'Moisturizer', 'Sunscreen']
          : morningProducts,
    ),
    TimelineBlockDraft(
      id: 'skin-night-${now.millisecondsSinceEpoch}',
      section: 'skin_care',
      title: hasMany ? 'Night active routine' : 'Night skin care',
      startMinute: 21 * 60 + 30,
      endMinute: 21 * 60 + 45,
      repeatDays: hasMany ? const [1, 3, 5] : onboardingEveryDay(),
      blockType: TimelineBlockDraft.softBlockKey,
      source: 'ai_generated',
      skincareProducts: nightProducts.isEmpty
          ? const ['Cleanser', 'Moisturizer']
          : nightProducts,
    ),
    if (hasMany)
      TimelineBlockDraft(
        id: 'skin-recovery-${now.millisecondsSinceEpoch}',
        section: 'skin_care',
        title: 'Skin recovery night',
        startMinute: 21 * 60 + 30,
        endMinute: 21 * 60 + 42,
        repeatDays: const [2, 4, 6, 7],
        blockType: TimelineBlockDraft.softBlockKey,
        source: 'ai_generated',
        skincareProducts: recoveryProducts.isEmpty
            ? const ['Cleanser', 'Moisturizer']
            : recoveryProducts,
      ),
  ];
}

List<String> _skinCareProductList(BaseTimelineDraft base) {
  final typed = base.skinCareProductNames
      ?.split(RegExp(r'[\n,]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (typed != null && typed.isNotEmpty) return typed;
  final problems = base.skinCareProblems;
  final simple =
      base.skinCarePreference == 'simple' ||
      base.skinCarePreference == 'minimal';
  return [
    'Gentle cleanser',
    'Light moisturizer',
    'Sunscreen SPF 30',
    if (!simple && problems.contains('pimples')) 'Acne spot treatment',
    if (!simple && problems.contains('dark_spots')) 'Dark spot serum',
  ];
}

bool _looksLikeSunscreen(String value) {
  final lower = value.toLowerCase();
  return lower.contains('sunscreen') || lower.contains('spf');
}

bool _looksLikeNightActive(String value) {
  final lower = value.toLowerCase();
  return lower.contains('retinol') ||
      lower.contains('acid') ||
      lower.contains('aha') ||
      lower.contains('bha') ||
      lower.contains('exfol');
}

void updateBaseTimelineDraft(
  WidgetRef ref,
  int stepIndex,
  BaseTimelineDraft Function(BaseTimelineDraft base) update,
) {
  ref
      .read(mockOnboardingProvider.notifier)
      .updateDraft(
        (draft) => draft.copyWith(
          baseTimeline: update(draft.baseTimeline),
          clearFinalPreview: true,
        ),
      );
  ref.read(mockOnboardingProvider.notifier).setStepDirty(stepIndex, true);
}

Future<void> openOnboardingImportReview(
  BuildContext context, {
  required RoutineImportSource source,
  bool autoRunAiOnLoad = false,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => RoutineImportReviewScreen(
        source: source,
        autoRunAiOnLoad: autoRunAiOnLoad,
        onBack: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

class OnboardingStepBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Color accent;

  const OnboardingStepBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.accent = OptivusColors.brandAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: OnboardingSectionTitle(title: title, subtitle: subtitle),
        ),
        Expanded(
          child: OnboardingScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InternalProgress(accent: accent),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingTimeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int minute;
  final ValueChanged<int> onChanged;
  final IconData icon;
  final Color accent;

  const OnboardingTimeTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.minute,
    required this.onChanged,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: accent.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OnboardingActionPill(
            label: onboardingTimeLabel(minute),
            icon: Icons.schedule_rounded,
            accent: accent,
            selected: true,
            compact: true,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: onboardingTimeFromMinute(minute),
              );
              if (picked == null) return;
              onChanged(onboardingMinuteFromTime(picked));
            },
          ),
        ],
      ),
    );
  }
}

class OnboardingUploadReviewCard extends ConsumerWidget {
  final String sectionLabel;
  final String title;
  final String subtitle;
  final int stepIndex;
  final Color accent;
  final bool autoRunAiOnLoad;

  const OnboardingUploadReviewCard({
    super.key,
    required this.sectionLabel,
    required this.title,
    required this.subtitle,
    required this.stepIndex,
    required this.accent,
    this.autoRunAiOnLoad = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final pending = draft.baseTimeline.latestImportForSection(sectionLabel);
    final uploadState = ref.watch(uploadControllerProvider);
    final purpose = onboardingUploadPurposeForBaseTimelineSection(sectionLabel);
    final applies =
        purpose != null &&
        uploadState.purpose == purpose &&
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding;
    final busy = applies && uploadState.isBusy;
    final status = _statusText(uploadState, pending, applies);

    return OnboardingGlassCard(
      tint: accent.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _StatusLine(
            label: status,
            icon: pending?.status == PendingFutureImportDraft.appliedStatus
                ? Icons.check_circle_outline_rounded
                : pending?.hasUploadedAssetReference == true
                ? Icons.rate_review_rounded
                : Icons.image_outlined,
            color: pending?.status == PendingFutureImportDraft.appliedStatus
                ? OptivusColors.success
                : pending?.hasUploadedAssetReference == true
                ? OptivusColors.warning
                : accent,
          ),
          if (pending?.uploadedAssetR2Key != null) ...[
            const SizedBox(height: 7),
            Text(
              pending!.uploadedAssetR2Key!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OnboardingActionPill(
                label: busy ? 'Uploading...' : 'Upload photo',
                icon: busy ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                accent: accent,
                selected: true,
                compact: true,
                onTap: busy || purpose == null
                    ? null
                    : () => _startUpload(context, ref, purpose),
              ),
              if (pending?.hasUploadedAssetReference == true ||
                  pending?.parsedBlocks.isNotEmpty == true)
                OnboardingActionPill(
                  label:
                      pending?.status == PendingFutureImportDraft.appliedStatus
                      ? 'Review saved'
                      : 'Review AI draft',
                  icon: Icons.rate_review_rounded,
                  accent: OptivusColors.success,
                  compact: true,
                  selected:
                      pending?.status == PendingFutureImportDraft.appliedStatus,
                  onTap: () => openOnboardingImportReview(
                    context,
                    source: onboardingImportSourceForSection(sectionLabel),
                    autoRunAiOnLoad: false,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusText(
    UploadState uploadState,
    PendingFutureImportDraft? pending,
    bool applies,
  ) {
    if (pending?.status == PendingFutureImportDraft.appliedStatus) {
      return 'Review applied. Blocks are saved.';
    }
    if (applies && uploadState.isBusy) {
      return switch (uploadState.status) {
        UploadFlowStatus.picking => 'Choosing photo...',
        UploadFlowStatus.preparing => 'Preparing photo...',
        UploadFlowStatus.signing => 'Preparing secure upload...',
        UploadFlowStatus.uploading => 'Uploading photo...',
        UploadFlowStatus.savingMetadata => 'Saving upload reference...',
        _ => 'Uploading photo...',
      };
    }
    if (pending?.hasUploadedAssetReference == true) {
      return 'Photo uploaded. Review AI draft to continue.';
    }
    if (pending?.parsedBlocks.isNotEmpty == true) {
      return 'Draft generated. Review it to continue.';
    }
    return 'No upload yet.';
  }

  Future<void> _startUpload(
    BuildContext context,
    WidgetRef ref,
    UploadedAssetPurpose purpose,
  ) async {
    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final now = DateTime.now();
    final existing = ref
        .read(mockOnboardingProvider)
        .draft
        .baseTimeline
        .latestImportForSection(sectionLabel);
    final seed = PendingFutureImportDraft(
      id: onboardingImportId(sectionLabel, 'photo_upload'),
      section: sectionLabel,
      mode: 'Photo Upload',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      status: PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: existing?.uploadedAssetId,
      uploadedAssetR2Key: existing?.uploadedAssetR2Key,
      uploadedAssetStatus: existing?.uploadedAssetStatus,
      parsedBlocks: existing?.parsedBlocks ?? const [],
    );
    updateBaseTimelineDraft(
      ref,
      stepIndex,
      (base) => base.upsertPendingImport(seed),
    );

    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: purpose,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );
    if (!context.mounted) return;
    final state = ref.read(uploadControllerProvider);
    final next = seed.copyWith(
      updatedAt: DateTime.now(),
      status: asset == null && state.status == UploadFlowStatus.failed
          ? PendingFutureImportDraft.errorStatus
          : PendingFutureImportDraft.pendingStatus,
      uploadedAssetId: asset?.assetId ?? state.asset?.assetId,
      uploadedAssetR2Key: asset?.r2Key ?? state.asset?.r2Key,
      uploadedAssetStatus:
          asset?.status.wireName ??
          state.asset?.status.wireName ??
          (state.status == UploadFlowStatus.failed
              ? UploadedAssetStatus.failed.wireName
              : UploadedAssetStatus.uploaded.wireName),
      errorMessage: state.status == UploadFlowStatus.failed
          ? state.errorMessage
          : null,
      clearErrorMessage: state.status != UploadFlowStatus.failed,
    );
    updateBaseTimelineDraft(
      ref,
      stepIndex,
      (base) => base.upsertPendingImport(next),
    );
    if (asset == null) return;
    await openOnboardingImportReview(
      context,
      source: onboardingImportSourceForSection(sectionLabel),
      autoRunAiOnLoad: autoRunAiOnLoad,
    );
  }
}

class OnboardingMiniBlockList extends StatelessWidget {
  final String title;
  final List<TimelineBlockDraft> blocks;
  final Color accent;
  final String emptyLabel;

  const OnboardingMiniBlockList({
    super.key,
    required this.title,
    required this.blocks,
    required this.accent,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...blocks]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return OnboardingGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text(
              emptyLabel,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            )
          else
            ...sorted
                .take(8)
                .map(
                  (block) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BlockRow(block: block, accent: accent),
                  ),
                ),
        ],
      ),
    );
  }
}

class OnboardingTextInputCard extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  final Color accent;
  final int minLines;
  final ValueChanged<String>? onChanged;

  const OnboardingTextInputCard({
    super.key,
    required this.controller,
    required this.title,
    required this.hint,
    required this.accent,
    this.minLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: accent.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: minLines == 1 ? 1 : 5,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OptivusColors.textSecondary,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.34),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalProgress extends StatelessWidget {
  final Color accent;

  const _InternalProgress({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Colors.white.withValues(alpha: 0.28),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.42,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: accent.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusLine({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  final TimelineBlockDraft block;
  final Color accent;

  const _BlockRow({required this.block, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: accent, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
