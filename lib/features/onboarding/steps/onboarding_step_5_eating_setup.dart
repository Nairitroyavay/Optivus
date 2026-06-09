import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/models/routine_import_review.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/state/routine_import_ai_state.dart';
import 'package:optivus/state/upload_state.dart';

const String onboardingEatingPathHasRoutine = 'has_routine';
const String onboardingEatingPathCreate = 'create';
const String onboardingEatingGeneratedSource = 'generated_meal_setup';
const String onboardingEatingAiImportSource = 'ai_import';

class OnboardingStep5 extends ConsumerStatefulWidget {
  const OnboardingStep5({super.key});

  @override
  ConsumerState<OnboardingStep5> createState() => _OnboardingStep5State();
}

class _OnboardingStep5State extends ConsumerState<OnboardingStep5> {
  int _selectedDay = 1;
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  String? _generationError;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final path = base.eatingSetupPath;
    final eatingBlocks = path == onboardingEatingPathCreate
        ? onboarding5GeneratedMealBlocks(base)
        : base.confirmedBlocksForSection('eating');

    return OnboardingStepBody(
      title: 'Eating Setup',
      subtitle: 'Build your weekly meal routine in a simple way.',
      accent: OptivusColors.success,
      children: [
        if (base.eatingSetupStep == 0)
          _EatingChoiceScreen(path: path)
        else ...[
          _EatingStageBackButton(onTap: _returnToChoices),
          const SizedBox(height: 12),
          if (path == onboardingEatingPathHasRoutine)
            _EatingUploadTimelineScreen(
              asset: _uploadedAsset,
              uploadError: _uploadError,
              generationError: _generationError,
              selectedDay: _selectedDay,
              blocks: eatingBlocks,
              onUpload: _startUpload,
              onRemove: _removeUploadedRoutine,
              onGenerate: _runAiExtraction,
              onDayChanged: (day) => setState(() => _selectedDay = day),
            )
          else
            _EatingCreateTimelineScreen(
              base: base,
              selectedDay: _selectedDay,
              blocks: eatingBlocks,
              onDayChanged: (day) => setState(() => _selectedDay = day),
            ),
        ],
      ],
    );
  }

  void _returnToChoices() {
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    updateBaseTimelineDraft(
      ref,
      onboardingEatingStepIndex,
      (base) => base.copyWith(eatingSetupStep: 0),
    );
  }

  Future<void> _startUpload() async {
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final asset = await ref
        .read(uploadControllerProvider.notifier)
        .startUpload(
          uid: uid,
          purpose: UploadedAssetPurpose.eatingMenu,
          sourceFeature: OnboardingDraft.sourceOnboarding,
        );
    if (!mounted) return;

    final uploadState = ref.read(uploadControllerProvider);
    setState(() {
      _uploadedAsset = asset ?? uploadState.asset;
      _uploadError = uploadState.status == UploadFlowStatus.failed
          ? _friendlyUploadMessage(uploadState.errorMessage)
          : null;
    });
  }

  void _removeUploadedRoutine() {
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    _replaceEatingBlocks(const []);
  }

  Future<void> _runAiExtraction() async {
    final asset = _uploadedAsset;
    setState(() => _generationError = null);
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    if (asset == null) {
      setState(
        () => _generationError = 'Upload your routine/menu photo first.',
      );
      return;
    }
    if (!_isSupportedImageContentType(asset.contentType)) {
      setState(
        () => _generationError =
            'This photo format is not supported. Please upload JPEG, PNG, or WEBP.',
      );
      return;
    }

    final now = DateTime.now();
    final uid =
        ref.read(authProvider).user?.uid ??
        ref.read(mockOnboardingProvider).draft.uid;
    final review = RoutineImportReviewDraft(
      id: onboardingImportId(onboardingSectionEating, 'photo_ai'),
      uid: uid,
      source: RoutineImportReviewSource.eating,
      status: RoutineImportReviewStatus.needsReview,
      sourceLabel: onboardingSectionEating,
      onboardingPendingImportId: onboardingImportId(
        onboardingSectionEating,
        'photo_ai',
      ),
      uploadedAssetId: asset.assetId,
      uploadedAssetR2Key: asset.r2Key,
      uploadedAssetStatus: asset.status.wireName,
      createdAt: now,
      updatedAt: now,
    );

    final result = await ref
        .read(routineImportAiControllerProvider.notifier)
        .runExtraction(review);
    if (!mounted) return;

    final aiState = ref.read(routineImportAiControllerProvider);
    if (result == null) {
      setState(
        () => _generationError = _friendlyAiMessage(
          aiState.errorMessage,
          const [],
        ),
      );
      return;
    }

    final blocks = onboarding5MealBlocksFromCandidates(
      result.candidates,
      now: DateTime.now(),
    );
    if (blocks.isEmpty) {
      setState(
        () => _generationError = _friendlyAiMessage(
          aiState.errorMessage,
          result.warnings,
        ),
      );
      return;
    }

    _replaceEatingBlocks(blocks);
    setState(() => _generationError = null);
  }

  void _replaceEatingBlocks(List<TimelineBlockDraft> eatingBlocks) {
    updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
      final nextBlocks =
          base.blocks
              .where((block) => block.section != 'eating')
              .toList(growable: true)
            ..addAll(eatingBlocks);
      final nextPending = base.pendingFutureImports
          .where((entry) => entry.section != onboardingSectionEating)
          .toList(growable: false);
      return base.copyWith(
        blocks: nextBlocks,
        pendingFutureImports: nextPending,
        eatingSetupStep: 1,
      );
    });
  }
}

class _EatingChoiceScreen extends ConsumerWidget {
  final String? path;

  const _EatingChoiceScreen({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(String value) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      updateBaseTimelineDraft(
        ref,
        onboardingEatingStepIndex,
        (base) => base.copyWith(
          eatingSetupPath: value,
          eatingSetupStep: 1,
          clearMealPlanning: value == onboardingEatingPathHasRoutine,
        ),
      );
    }

    return Column(
      children: [
        OnboardingChoiceTile(
          title: 'Yes, I have a routine/menu',
          subtitle: 'Upload a meal timetable or weekly menu.',
          icon: Icons.document_scanner_rounded,
          selected: path == onboardingEatingPathHasRoutine,
          accent: OptivusColors.success,
          onTap: () => select(onboardingEatingPathHasRoutine),
        ),
        const SizedBox(height: 12),
        OnboardingChoiceTile(
          title: 'No, help me create one',
          subtitle: 'Start with simple daily meal times.',
          icon: Icons.auto_awesome_rounded,
          selected: path == onboardingEatingPathCreate,
          accent: OptivusColors.brandAccent,
          onTap: () => select(onboardingEatingPathCreate),
        ),
      ],
    );
  }
}

class _EatingStageBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EatingStageBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('onboarding-step5-back'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 17),
                SizedBox(width: 5),
                Text(
                  'Back',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EatingUploadTimelineScreen extends ConsumerWidget {
  final UploadedAsset? asset;
  final String? uploadError;
  final String? generationError;
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final VoidCallback onGenerate;
  final ValueChanged<int> onDayChanged;

  const _EatingUploadTimelineScreen({
    required this.asset,
    required this.uploadError,
    required this.generationError,
    required this.selectedDay,
    required this.blocks,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadControllerProvider);
    final aiState = ref.watch(routineImportAiControllerProvider);
    final uploadBusy =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.eatingMenu &&
        uploadState.isBusy;
    final generating = aiState.isExtracting;
    final status = uploadBusy
        ? _uploadStatus(uploadState.status)
        : generating
        ? 'AI is generating your timeline.'
        : asset == null
        ? 'No photo uploaded yet.'
        : 'Photo ready. Generate your timeline.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EatingUploadCard(
          asset: asset,
          status: status,
          busy: uploadBusy || generating,
          onUpload: onUpload,
          onRemove: onRemove,
          onGenerate: asset == null || uploadBusy || generating
              ? null
              : onGenerate,
        ),
        if (uploadError != null || generationError != null) ...[
          const SizedBox(height: 10),
          _EatingInlineMessage(message: uploadError ?? generationError!),
        ],
        if (generating) ...[
          const SizedBox(height: 10),
          const _EatingLoadingCard(),
        ],
        const SizedBox(height: 18),
        _EatingTimelineSection(
          selectedDay: selectedDay,
          blocks: blocks,
          onDayChanged: onDayChanged,
          emptyLabel: 'Generate your weekly meal routine first.',
        ),
      ],
    );
  }
}

class _EatingCreateTimelineScreen extends ConsumerWidget {
  final BaseTimelineDraft base;
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final ValueChanged<int> onDayChanged;

  const _EatingCreateTimelineScreen({
    required this.base,
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsPerDay = _normalizedMealsPerDay(base.mealsPerDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.success.withValues(alpha: 0.07),
          padding: const EdgeInsets.all(16),
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create simple meal routine',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose your usual meals. You can change details later.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const _EatingFieldLabel('Meals per day'),
                  for (final count in const [3, 4, 5])
                    OnboardingChip(
                      label: '$count',
                      selected: mealsPerDay == count,
                      accent: OptivusColors.success,
                      onTap: () => updateBaseTimelineDraft(
                        ref,
                        onboardingEatingStepIndex,
                        (base) => base.copyWith(mealsPerDay: count),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in const [
                    _EatingModeOption('home', 'Home'),
                    _EatingModeOption('hostel_mess', 'Hostel/Mess'),
                    _EatingModeOption('mixed', 'Mixed'),
                  ])
                    OnboardingChip(
                      label: mode.label,
                      selected: (base.eatingMode ?? 'home') == mode.key,
                      accent: OptivusColors.success,
                      onTap: () => updateBaseTimelineDraft(
                        ref,
                        onboardingEatingStepIndex,
                        (base) => base.copyWith(eatingMode: mode.key),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MealTimeRows(base: base, mealsPerDay: mealsPerDay),
        const SizedBox(height: 18),
        _EatingTimelineSection(
          selectedDay: selectedDay,
          blocks: blocks,
          onDayChanged: onDayChanged,
          emptyLabel: 'Choose meal times to preview your week.',
        ),
      ],
    );
  }
}

class _EatingUploadCard extends StatelessWidget {
  final UploadedAsset? asset;
  final String status;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback onRemove;
  final VoidCallback? onGenerate;

  const _EatingUploadCard({
    required this.asset,
    required this.status,
    required this.busy,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.success.withValues(alpha: 0.07),
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload your routine/menu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your meal timetable or weekly menu photo.',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: busy ? null : onUpload,
                  child: _EatingPhotoTarget(asset: asset, onRemove: onRemove),
                ),
              ),
              const SizedBox(width: 12),
              _EatingGenerateButton(onTap: onGenerate, busy: busy),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingPhotoTarget extends StatelessWidget {
  final UploadedAsset? asset;
  final VoidCallback onRemove;

  const _EatingPhotoTarget({required this.asset, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final preview = asset?.localPreviewPath;
    final showFile = preview != null && File(preview).existsSync();

    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: showFile
                  ? Image.file(File(preview), fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          asset == null
                              ? Icons.add_photo_alternate_rounded
                              : Icons.image_rounded,
                          color: OptivusColors.success,
                          size: 27,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asset == null ? 'Add photo' : 'Photo uploaded',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (asset != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EatingGenerateButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;

  const _EatingGenerateButton({required this.onTap, required this.busy});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.45,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? OptivusColors.success : Colors.white,
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: OptivusColors.success.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.arrow_forward_rounded,
                  color: enabled ? Colors.white : OptivusColors.textSecondary,
                  size: 25,
                ),
        ),
      ),
    );
  }
}

class _MealTimeRows extends ConsumerWidget {
  final BaseTimelineDraft base;
  final int mealsPerDay;

  const _MealTimeRows({required this.base, required this.mealsPerDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[
      OnboardingTimeTile(
        title: 'Breakfast',
        subtitle: 'First meal of the day.',
        minute: base.breakfastMinute ?? 8 * 60,
        icon: Icons.free_breakfast_rounded,
        accent: OptivusColors.success,
        onChanged: (value) => updateBaseTimelineDraft(
          ref,
          onboardingEatingStepIndex,
          (base) => base.copyWith(breakfastMinute: value),
        ),
      ),
      OnboardingTimeTile(
        title: 'Lunch',
        subtitle: 'Main midday meal.',
        minute: base.lunchMinute ?? 13 * 60,
        icon: Icons.restaurant_rounded,
        accent: OptivusColors.success,
        onChanged: (value) => updateBaseTimelineDraft(
          ref,
          onboardingEatingStepIndex,
          (base) => base.copyWith(lunchMinute: value),
        ),
      ),
    ];

    if (mealsPerDay >= 4) {
      rows.add(
        OnboardingTimeTile(
          title: 'Snack',
          subtitle: 'A simple evening snack.',
          minute: base.snackMinute ?? 17 * 60,
          icon: Icons.local_cafe_rounded,
          accent: OptivusColors.success,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingEatingStepIndex,
            (base) => base.copyWith(snackMinute: value),
          ),
        ),
      );
    }

    rows.add(
      OnboardingTimeTile(
        title: 'Dinner',
        subtitle: 'Usual night meal.',
        minute: base.dinnerMinute ?? 20 * 60 + 30,
        icon: Icons.dinner_dining_rounded,
        accent: OptivusColors.success,
        onChanged: (value) => updateBaseTimelineDraft(
          ref,
          onboardingEatingStepIndex,
          (base) => base.copyWith(dinnerMinute: value),
        ),
      ),
    );

    if (mealsPerDay == 5) {
      rows.add(
        OnboardingTimeTile(
          title: 'Extra snack',
          subtitle: 'Small second snack.',
          minute: base.extraSnackMinute ?? 11 * 60,
          icon: Icons.bakery_dining_rounded,
          accent: OptivusColors.success,
          onChanged: (value) => updateBaseTimelineDraft(
            ref,
            onboardingEatingStepIndex,
            (base) => base.copyWith(extraSnackMinute: value),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          rows[i],
        ],
      ],
    );
  }
}

class _EatingTimelineSection extends StatelessWidget {
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final ValueChanged<int> onDayChanged;
  final String emptyLabel;

  const _EatingTimelineSection({
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final dayBlocks =
        blocks
            .where((block) => block.repeatDays.contains(selectedDay))
            .toList(growable: false)
          ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Your Weekly Meal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _EatingDayChips(selectedDay: selectedDay, onChanged: onDayChanged),
        const SizedBox(height: 12),
        OnboardingGlassCard(
          tint: OptivusColors.success.withValues(alpha: 0.06),
          padding: const EdgeInsets.all(14),
          radius: 22,
          child: dayBlocks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      emptyLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < dayBlocks.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _EatingMealBlock(block: dayBlocks[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _EatingDayChips extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onChanged;

  const _EatingDayChips({required this.selectedDay, required this.onChanged});

  static const _labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            OnboardingChip(
              label: _labels[index],
              selected: selectedDay == index + 1,
              accent: OptivusColors.success,
              onTap: () => onChanged(index + 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _EatingMealBlock extends StatelessWidget {
  final TimelineBlockDraft block;

  const _EatingMealBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: OptivusColors.success,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (block.mealCategory?.trim().isNotEmpty == true)
            Text(
              block.mealCategory!.trim(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: OptivusColors.success.withValues(alpha: 0.88),
              ),
            ),
        ],
      ),
    );
  }
}

class _EatingInlineMessage extends StatelessWidget {
  final String message;

  const _EatingInlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.warning.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: OptivusColors.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingLoadingCard extends StatelessWidget {
  const _EatingLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const OnboardingGlassCard(
      padding: EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI is reading your meal routine...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'AI is generating your timeline.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingFieldLabel extends StatelessWidget {
  final String label;

  const _EatingFieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EatingModeOption {
  final String key;
  final String label;

  const _EatingModeOption(this.key, this.label);
}

List<TimelineBlockDraft> onboarding5GeneratedMealBlocks(
  BaseTimelineDraft base, {
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final mealsPerDay = _normalizedMealsPerDay(base.mealsPerDay);
  final specs = <_MealSpec>[
    _MealSpec('breakfast', 'Breakfast', base.breakfastMinute ?? 8 * 60, 30),
    _MealSpec('lunch', 'Lunch', base.lunchMinute ?? 13 * 60, 45),
    if (mealsPerDay >= 4)
      _MealSpec('snack', 'Snack', base.snackMinute ?? 17 * 60, 20),
    _MealSpec('dinner', 'Dinner', base.dinnerMinute ?? 20 * 60 + 30, 45),
    if (mealsPerDay == 5)
      _MealSpec(
        'extra-snack',
        'Extra snack',
        base.extraSnackMinute ?? 11 * 60,
        20,
      ),
  ];

  return specs
      .where((spec) => spec.startMinute >= 0 && spec.startMinute < 24 * 60)
      .map(
        (spec) => TimelineBlockDraft(
          id: 'eating-${spec.id}-${timestamp.millisecondsSinceEpoch}',
          section: 'eating',
          title: spec.title,
          startMinute: spec.startMinute,
          endMinute: (spec.startMinute + spec.durationMinutes).clamp(
            1,
            24 * 60,
          ),
          repeatDays: onboardingEveryDay(),
          blockType: TimelineBlockDraft.hardBlockKey,
          source: onboardingEatingGeneratedSource,
          mealCategory: spec.title.toLowerCase().replaceAll(' ', '_'),
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
}

List<TimelineBlockDraft> onboarding5MealBlocksFromCandidates(
  List<RoutineImportCandidateBlock> candidates, {
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final blocks = <TimelineBlockDraft>[];
  for (final candidate in candidates) {
    final title = candidate.title.trim();
    final repeatDays =
        candidate.repeatDays
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList()
          ..sort();
    if (title.isEmpty) continue;
    if (!candidate.hasFixedTime ||
        candidate.startMinute >= candidate.endMinute) {
      continue;
    }
    blocks.add(
      TimelineBlockDraft(
        id: 'eating-ai-${candidate.id}-${timestamp.millisecondsSinceEpoch}',
        section: 'eating',
        title: title,
        startMinute: candidate.startMinute,
        endMinute: candidate.endMinute,
        repeatDays: repeatDays.isEmpty ? onboardingEveryDay() : repeatDays,
        location: candidate.location,
        blockType: TimelineBlockDraft.hardBlockKey,
        source: onboardingEatingAiImportSource,
        mealCategory:
            candidate.mealCategory ?? _inferMealCategory(candidate.title),
        dishes: candidate.steps,
      ),
    );
  }
  return blocks..sort((a, b) => a.startMinute.compareTo(b.startMinute));
}

int _normalizedMealsPerDay(int? value) {
  final count = value ?? 4;
  if (count <= 3) return 3;
  if (count >= 5) return 5;
  return 4;
}

bool _isSupportedImageContentType(String contentType) {
  final normalized = contentType.trim().toLowerCase();
  return normalized == 'image/jpeg' ||
      normalized == 'image/jpg' ||
      normalized == 'image/png' ||
      normalized == 'image/webp';
}

String _friendlyUploadMessage(String? message) {
  final value = message?.trim();
  if (value == null || value.isEmpty) return 'Photo upload failed. Try again.';
  final lower = value.toLowerCase();
  if (lower.contains('heic') ||
      lower.contains('heif') ||
      lower.contains('format') ||
      lower.contains('content type')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  return value;
}

String _friendlyAiMessage(String? error, List<String> warnings) {
  final messages = [
    if (error?.trim().isNotEmpty == true) error!.trim(),
    ...warnings
        .map((warning) => warning.trim())
        .where((warning) => warning.isNotEmpty),
  ];
  final text = messages.join(' ').toLowerCase();
  if (text.contains('unsupported_content_type') ||
      text.contains('content type') ||
      text.contains('format')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  if (text.contains('too large') || text.contains('image too large')) {
    return 'Meal photo is too large. Upload a smaller, clearer photo.';
  }
  if (text.contains('not found') || text.contains('r2_image_missing')) {
    return 'Uploaded meal photo could not be found. Please upload again.';
  }
  if (text.contains('unauthorized') || text.contains('invalid key')) {
    return 'AI key is invalid or unauthorized.';
  }
  if (text.contains('quota') || text.contains('rate limit')) {
    return 'AI quota or rate limit reached. Try again later.';
  }
  if (text.contains('invalid structured') ||
      text.contains('could not be read safely')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (messages.isNotEmpty) return messages.first;
  return 'AI could not read blocks from the meal photo. Try a clearer image.';
}

String _uploadStatus(UploadFlowStatus status) {
  return switch (status) {
    UploadFlowStatus.picking => 'Choosing photo...',
    UploadFlowStatus.preparing => 'Preparing photo...',
    UploadFlowStatus.signing => 'Preparing secure upload...',
    UploadFlowStatus.uploading => 'Uploading photo...',
    UploadFlowStatus.savingMetadata => 'Saving upload reference...',
    _ => 'Uploading photo...',
  };
}

String _inferMealCategory(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('breakfast')) return 'breakfast';
  if (lower.contains('lunch')) return 'lunch';
  if (lower.contains('dinner')) return 'dinner';
  if (lower.contains('snack')) return 'snack';
  return 'meal';
}

class _MealSpec {
  final String id;
  final String title;
  final int startMinute;
  final int durationMinutes;

  const _MealSpec(this.id, this.title, this.startMinute, this.durationMinutes);
}
