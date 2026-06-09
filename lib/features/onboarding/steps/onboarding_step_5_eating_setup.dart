import 'dart:io';
import 'dart:math' as math;

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
const String onboardingEatingGeneratedSource = 'ai_generated_meal_setup';
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
  String? _createError;
  bool _creatingRoutine = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(mockOnboardingProvider).draft;
    final base = draft.baseTimeline;
    final path = base.eatingSetupPath;
    final eatingBlocks = base.confirmedBlocksForSection('eating');
    final isChoice = base.eatingSetupStep == 0;

    return Column(
      children: [
        Expanded(
          child: OnboardingScrollView(
            padding: EdgeInsets.fromLTRB(24, isChoice ? 10 : 2, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isChoice)
                  _EatingChoiceScreen(path: path)
                else ...[
                  _EatingStageBackButton(onTap: _returnToChoices),
                  const SizedBox(height: 10),
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
                      blocks: eatingBlocks
                          .where(
                            (block) =>
                                block.source == onboardingEatingGeneratedSource,
                          )
                          .toList(growable: false),
                      error: _createError,
                      isGenerating: _creatingRoutine,
                      onGenerate: _generateCreatedRoutine,
                      onDayChanged: (day) => setState(() => _selectedDay = day),
                    ),
                ],
              ],
            ),
          ),
        ),
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
        () => _generationError = onboarding5FriendlyAiMessage(
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
        () => _generationError = onboarding5FriendlyAiMessage(
          aiState.errorMessage,
          result.warnings,
        ),
      );
      return;
    }

    _replaceEatingBlocks(blocks);
    setState(() => _generationError = null);
  }

  Future<void> _generateCreatedRoutine() async {
    if (_creatingRoutine) return;
    setState(() {
      _creatingRoutine = true;
      _createError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    final base = ref.read(mockOnboardingProvider).draft.baseTimeline;
    final blocks = onboarding5GeneratedMealBlocks(base);
    if (blocks.isEmpty) {
      setState(() {
        _creatingRoutine = false;
        _createError = 'AI is busy right now. Try again in a moment.';
      });
      return;
    }

    _replaceEatingBlocks(blocks);
    setState(() => _creatingRoutine = false);
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
      updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
        final switchedPath = base.eatingSetupPath != value;
        return _clearEatingBlocks(
          base.copyWith(
            eatingSetupPath: value,
            eatingSetupStep: 1,
            eatingMode: value == onboardingEatingPathCreate
                ? (base.eatingMode ?? 'india')
                : base.eatingMode,
            foodType: value == onboardingEatingPathCreate
                ? (base.foodType ?? 'mixed')
                : base.foodType,
            mealsPerDay: value == onboardingEatingPathCreate
                ? (base.mealsPerDay ?? 4)
                : base.mealsPerDay,
            clearMealPlanning: value == onboardingEatingPathHasRoutine,
          ),
          clear: switchedPath,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EatingChoiceHeader(),
        const SizedBox(height: 18),
        _EatingPathCard(
          title: 'Yes, I have a routine/menu',
          subtitle: 'Upload a meal timetable or weekly menu.',
          icon: Icons.document_scanner_rounded,
          selected: path == onboardingEatingPathHasRoutine,
          accent: OptivusColors.success,
          onTap: () => select(onboardingEatingPathHasRoutine),
        ),
        const SizedBox(height: 12),
        _EatingPathCard(
          title: 'No, help me create one',
          subtitle: 'Generate a simple meal routine with dishes.',
          icon: Icons.auto_awesome_rounded,
          selected: path == onboardingEatingPathCreate,
          accent: OptivusColors.roseAccent,
          onTap: () => select(onboardingEatingPathCreate),
        ),
      ],
    );
  }
}

class _EatingChoiceHeader extends StatelessWidget {
  const _EatingChoiceHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eating Setup',
          style: TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Build your weekly meal routine in a simple way.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: OptivusColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EatingPathCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _EatingPathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        selected: selected,
        padding: const EdgeInsets.all(14),
        radius: 22,
        tint: selected ? accent.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.48),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
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
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 16),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
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
        ? 'Generating timeline...'
        : asset == null
        ? 'No photo yet'
        : 'Ready to generate';

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
          const SizedBox(height: 8),
          _EatingInlineMessage(message: uploadError ?? generationError!),
        ],
        const SizedBox(height: 14),
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
  final String? error;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final ValueChanged<int> onDayChanged;

  const _EatingCreateTimelineScreen({
    required this.base,
    required this.selectedDay,
    required this.blocks,
    required this.error,
    required this.isGenerating,
    required this.onGenerate,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsPerDay = _normalizedMealsPerDay(base.mealsPerDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
          padding: const EdgeInsets.all(13),
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create simple meal routine',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tell AI your food style. It will build your weekly meal timeline.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 11),
              _EatingChipGroup(
                label: 'Meals',
                children: [
                  for (final count in const [3, 4, 5])
                    OnboardingChip(
                      label: '$count',
                      selected: mealsPerDay == count,
                      accent: OptivusColors.roseAccent,
                      onTap: () => _updateCreateDraft(
                        ref,
                        (base) => base.copyWith(mealsPerDay: count),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              _EatingChipGroup(
                label: 'Style',
                children: [
                  for (final option in const [
                    _EatingModeOption('india', 'India'),
                    _EatingModeOption('us', 'US'),
                    _EatingModeOption('germany', 'Germany'),
                    _EatingModeOption('mixed', 'Mixed'),
                    _EatingModeOption('custom', 'Custom'),
                  ])
                    OnboardingChip(
                      label: option.label,
                      selected: (base.eatingMode ?? 'india') == option.key,
                      accent: OptivusColors.roseAccent,
                      onTap: () => _updateCreateDraft(
                        ref,
                        (base) => base.copyWith(eatingMode: option.key),
                      ),
                    ),
                ],
              ),
              if ((base.eatingMode ?? 'india') == 'custom') ...[
                const SizedBox(height: 9),
                _EatingCustomStyleField(base: base),
              ],
              const SizedBox(height: 9),
              _EatingChipGroup(
                label: 'Type',
                children: [
                  for (final option in const [
                    _EatingModeOption('veg', 'Veg'),
                    _EatingModeOption('non_veg', 'Non-veg'),
                    _EatingModeOption('mixed', 'Mixed'),
                  ])
                    OnboardingChip(
                      label: option.label,
                      selected: (base.foodType ?? 'mixed') == option.key,
                      accent: OptivusColors.roseAccent,
                      onTap: () => _updateCreateDraft(
                        ref,
                        (base) => base.copyWith(foodType: option.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _CompactMealTimeRows(base: base, mealsPerDay: mealsPerDay),
              const SizedBox(height: 11),
              _EatingGenerateRoutineButton(
                isGenerating: isGenerating,
                onTap: onGenerate,
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          _EatingInlineMessage(message: error!),
        ],
        const SizedBox(height: 12),
        if (blocks.isEmpty)
          const _EatingCompactEmptyState()
        else
          _EatingTimelineSection(
            selectedDay: selectedDay,
            blocks: blocks,
            onDayChanged: onDayChanged,
            emptyLabel: 'Generate your meal routine to preview the week.',
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
      tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(12),
      radius: 21,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload your routine/menu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          const Text(
            'Add your weekly meal timetable photo.',
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: busy ? null : onUpload,
                  child: _EatingPhotoTarget(asset: asset, onRemove: onRemove),
                ),
              ),
              const SizedBox(width: 10),
              _EatingGenerateButton(onTap: onGenerate, busy: busy),
            ],
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
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
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: showFile
                  ? Image.file(File(preview), fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          asset == null
                              ? Icons.add_photo_alternate_rounded
                              : Icons.image_rounded,
                          color: OptivusColors.roseAccent,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          asset == null ? 'Add photo' : 'Photo uploaded',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (asset != null)
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 15,
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? OptivusColors.roseAccent : Colors.white,
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: OptivusColors.roseAccent.withValues(alpha: 0.24),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.arrow_forward_rounded,
                  color: enabled ? Colors.white : OptivusColors.textSecondary,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

class _EatingChipGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _EatingChipGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 43,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _EatingCustomStyleField extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _EatingCustomStyleField({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      initialValue: base.foodStyleCustomText ?? '',
      minLines: 1,
      maxLines: 1,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Example: Bengali hostel food, high protein',
        hintStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.24),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OptivusColors.roseAccent),
        ),
      ),
      onChanged: (value) => _updateCreateDraft(
        ref,
        (base) => base.copyWith(foodStyleCustomText: value),
      ),
    );
  }
}

class _CompactMealTimeRows extends ConsumerWidget {
  final BaseTimelineDraft base;
  final int mealsPerDay;

  const _CompactMealTimeRows({required this.base, required this.mealsPerDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs = <_MealTimeControl>[
      _MealTimeControl('Breakfast', base.breakfastMinute ?? 8 * 60, (value) {
        _updateCreateDraft(
          ref,
          (base) => base.copyWith(breakfastMinute: value),
        );
      }),
      if (mealsPerDay == 5)
        _MealTimeControl('Extra snack', base.extraSnackMinute ?? 11 * 60, (
          value,
        ) {
          _updateCreateDraft(
            ref,
            (base) => base.copyWith(extraSnackMinute: value),
          );
        }),
      _MealTimeControl('Lunch', base.lunchMinute ?? 13 * 60, (value) {
        _updateCreateDraft(ref, (base) => base.copyWith(lunchMinute: value));
      }),
      if (mealsPerDay >= 4)
        _MealTimeControl('Snack', base.snackMinute ?? 17 * 60, (value) {
          _updateCreateDraft(ref, (base) => base.copyWith(snackMinute: value));
        }),
      _MealTimeControl('Dinner', base.dinnerMinute ?? 20 * 60 + 30, (value) {
        _updateCreateDraft(ref, (base) => base.copyWith(dinnerMinute: value));
      }),
    ];

    return Column(
      children: [
        for (var i = 0; i < specs.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _CompactMealTimeRow(spec: specs[i]),
        ],
      ],
    );
  }
}

class _CompactMealTimeRow extends StatelessWidget {
  final _MealTimeControl spec;

  const _CompactMealTimeRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: onboardingTimeFromMinute(spec.minute),
        );
        if (picked == null) return;
        spec.onChanged(onboardingMinuteFromTime(picked));
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                spec.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
              ),
              child: Text(
                onboardingTimeLabel(spec.minute),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.roseAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EatingGenerateRoutineButton extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onTap;

  const _EatingGenerateRoutineButton({
    required this.isGenerating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isGenerating ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: OptivusColors.roseAccent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.roseAccent.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGenerating)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.auto_awesome_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'Generate meal routine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
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
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 9),
        _EatingDayChips(selectedDay: selectedDay, onChanged: onDayChanged),
        const SizedBox(height: 10),
        if (dayBlocks.isEmpty)
          _EatingTimelineEmptyCard(label: emptyLabel)
        else
          _EatingVerticalTimeline(blocks: dayBlocks),
      ],
    );
  }
}

class _EatingVerticalTimeline extends StatelessWidget {
  final List<TimelineBlockDraft> blocks;

  const _EatingVerticalTimeline({required this.blocks});

  @override
  Widget build(BuildContext context) {
    final minStart = blocks.map((block) => block.startMinute).reduce(math.min);
    final maxEnd = blocks.map((block) => block.endMinute).reduce(math.max);
    final startMinute = math.max(5 * 60, ((minStart - 45) ~/ 60) * 60);
    final endMinute = math.min(24 * 60, (((maxEnd + 75) / 60).ceil()) * 60);
    final rangeMinutes = math.max(180, endMinute - startMinute);
    final height = (rangeMinutes * 0.56).clamp(220.0, 430.0);
    final pxPerMinute = height / rangeMinutes;

    return OnboardingGlassCard(
      tint: OptivusColors.roseAccent.withValues(alpha: 0.045),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      radius: 22,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 49,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: OptivusColors.roseAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            for (var minute = startMinute; minute <= endMinute; minute += 60)
              _EatingTimelineTick(
                minute: minute,
                top: (minute - startMinute) * pxPerMinute,
              ),
            for (final block in blocks)
              _EatingTimelineBlock(
                block: block,
                top: (block.startMinute - startMinute) * pxPerMinute,
                height: math
                    .max(
                      72,
                      (block.endMinute - block.startMinute) * pxPerMinute,
                    )
                    .toDouble(),
              ),
          ],
        ),
      ),
    );
  }
}

class _EatingTimelineTick extends StatelessWidget {
  final int minute;
  final double top;

  const _EatingTimelineTick({required this.minute, required this.top});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top - 6,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              _shortTimeLabel(minute),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.82),
              border: Border.all(
                color: OptivusColors.roseAccent.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.32),
            ),
          ),
        ],
      ),
    );
  }
}

class _EatingTimelineBlock extends StatelessWidget {
  final TimelineBlockDraft block;
  final double top;
  final double height;

  const _EatingTimelineBlock({
    required this.block,
    required this.top,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final dishes = block.dishes
        .map((dish) => dish.trim())
        .where((dish) => dish.isNotEmpty)
        .take(3)
        .join(', ');

    return Positioned(
      top: top,
      left: 66,
      right: 0,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: OptivusColors.roseAccent.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: double.infinity,
              decoration: BoxDecoration(
                color: OptivusColors.roseAccent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${onboardingTimeLabel(block.startMinute)} - ${onboardingTimeLabel(block.endMinute)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                  if (dishes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dishes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
              accent: OptivusColors.roseAccent,
              onTap: () => onChanged(index + 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _EatingTimelineEmptyCard extends StatelessWidget {
  final String label;

  const _EatingTimelineEmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: OptivusColors.roseAccent.withValues(alpha: 0.045),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      radius: 22,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EatingCompactEmptyState extends StatelessWidget {
  const _EatingCompactEmptyState();

  @override
  Widget build(BuildContext context) {
    return const OnboardingGlassCard(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      radius: 20,
      child: Text(
        'Generate your meal routine to preview the week.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w800,
          color: OptivusColors.textSecondary,
        ),
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
      padding: const EdgeInsets.all(11),
      radius: 17,
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: OptivusColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.32,
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

class _EatingModeOption {
  final String key;
  final String label;

  const _EatingModeOption(this.key, this.label);
}

class _MealTimeControl {
  final String title;
  final int minute;
  final ValueChanged<int> onChanged;

  const _MealTimeControl(this.title, this.minute, this.onChanged);
}

List<TimelineBlockDraft> onboarding5GeneratedMealBlocks(
  BaseTimelineDraft base, {
  DateTime? now,
}) {
  final timestamp = now ?? DateTime.now();
  final mealsPerDay = _normalizedMealsPerDay(base.mealsPerDay);
  final style = _normalizedFoodStyle(base.eatingMode, base.foodStyleCustomText);
  final eatingType = _normalizedEatingType(base.foodType);
  final specs = <_MealSpec>[
    _MealSpec('breakfast', 'Breakfast', base.breakfastMinute ?? 8 * 60, 30),
    if (mealsPerDay == 5)
      _MealSpec(
        'extra-snack',
        'Extra snack',
        base.extraSnackMinute ?? 11 * 60,
        20,
      ),
    _MealSpec('lunch', 'Lunch', base.lunchMinute ?? 13 * 60, 45),
    if (mealsPerDay >= 4)
      _MealSpec('snack', 'Snack', base.snackMinute ?? 17 * 60, 20),
    _MealSpec('dinner', 'Dinner', base.dinnerMinute ?? 20 * 60 + 30, 45),
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
          mealCategory: spec.id,
          dishes: _mealDishes(
            style: style,
            eatingType: eatingType,
            mealId: spec.id,
          ),
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

String onboarding5FriendlyAiMessage(String? error, List<String> warnings) {
  final messages = [
    if (error?.trim().isNotEmpty == true) error!.trim(),
    ...warnings
        .map((warning) => warning.trim())
        .where((warning) => warning.isNotEmpty),
  ];
  final text = messages.join(' ').toLowerCase();
  if (text.contains('provider_request_failed')) {
    return 'AI is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_high_demand')) {
    return 'AI model is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_quota_exceeded') ||
      text.contains('quota') ||
      text.contains('rate limit')) {
    return 'AI quota/rate limit reached. Try again later.';
  }
  if (text.contains('unsupported_content_type') ||
      text.contains('content type') ||
      text.contains('format')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  if (text.contains('provider_empty_candidates')) {
    return 'AI could not read meals clearly. Try a clearer photo.';
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
  if (text.contains('invalid structured') ||
      text.contains('could not be read safely')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (messages.isNotEmpty && !messages.first.startsWith('provider_')) {
    return messages.first;
  }
  return 'AI could not read meals clearly. Try a clearer photo.';
}

BaseTimelineDraft _clearEatingBlocks(
  BaseTimelineDraft base, {
  bool clear = true,
}) {
  if (!clear) return base;
  return base.copyWith(
    blocks: base.blocks
        .where((block) => block.section != 'eating')
        .toList(growable: false),
    pendingFutureImports: base.pendingFutureImports
        .where((entry) => entry.section != onboardingSectionEating)
        .toList(growable: false),
  );
}

void _updateCreateDraft(
  WidgetRef ref,
  BaseTimelineDraft Function(BaseTimelineDraft base) update,
) {
  ref.read(mockOnboardingProvider.notifier).clearValidation();
  updateBaseTimelineDraft(ref, onboardingEatingStepIndex, (base) {
    final updated = update(base);
    return updated.copyWith(
      blocks: updated.blocks
          .where(
            (block) =>
                block.section != 'eating' ||
                block.source != onboardingEatingGeneratedSource,
          )
          .toList(growable: false),
    );
  });
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

String _uploadStatus(UploadFlowStatus status) {
  return switch (status) {
    UploadFlowStatus.picking => 'Choosing...',
    UploadFlowStatus.preparing => 'Preparing...',
    UploadFlowStatus.signing => 'Securing upload...',
    UploadFlowStatus.uploading => 'Uploading...',
    UploadFlowStatus.savingMetadata => 'Saving...',
    _ => 'Uploading...',
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

String _shortTimeLabel(int minute) {
  final hour = (minute ~/ 60) % 24;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$display $suffix';
}

String _normalizedFoodStyle(String? value, String? customText) {
  final style = value?.trim().toLowerCase();
  if (style == 'custom' && customText?.trim().isNotEmpty == true) {
    return 'custom';
  }
  return switch (style) {
    'us' => 'us',
    'germany' => 'germany',
    'mixed' => 'mixed',
    'custom' => 'mixed',
    _ => 'india',
  };
}

String _normalizedEatingType(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'veg' => 'veg',
    'non_veg' => 'non_veg',
    _ => 'mixed',
  };
}

List<String> _mealDishes({
  required String style,
  required String eatingType,
  required String mealId,
}) {
  final isVeg = eatingType == 'veg';
  return switch (style) {
    'us' => _usMealDishes(mealId, isVeg: isVeg),
    'germany' => _germanyMealDishes(mealId, isVeg: isVeg),
    'mixed' => _mixedMealDishes(mealId, isVeg: isVeg),
    'custom' => _customMealDishes(mealId, isVeg: isVeg),
    _ => _indiaMealDishes(mealId, isVeg: isVeg),
  };
}

List<String> _indiaMealDishes(String mealId, {required bool isVeg}) {
  return switch (mealId) {
    'breakfast' => ['Idli', 'Sambar', 'Fruit'],
    'extra-snack' => ['Poha cup', 'Tea'],
    'lunch' =>
      isVeg
          ? ['Dal rice', 'Paneer sabzi', 'Curd']
          : ['Chicken curry', 'Rice', 'Salad'],
    'snack' => ['Chana chaat', 'Tea'],
    'dinner' =>
      isVeg
          ? ['Roti', 'Mixed veg', 'Dal']
          : ['Roti', 'Egg curry', 'Vegetables'],
    _ => ['Simple meal'],
  };
}

List<String> _usMealDishes(String mealId, {required bool isVeg}) {
  return switch (mealId) {
    'breakfast' => ['Oatmeal', 'Greek yogurt', 'Berries'],
    'extra-snack' => ['Apple', 'Peanut butter'],
    'lunch' =>
      isVeg
          ? ['Veggie wrap', 'Soup', 'Fruit']
          : ['Chicken bowl', 'Rice', 'Salad'],
    'snack' => ['Trail mix', 'Yogurt'],
    'dinner' =>
      isVeg
          ? ['Pasta', 'Roasted vegetables']
          : ['Grilled chicken', 'Potatoes', 'Greens'],
    _ => ['Simple meal'],
  };
}

List<String> _germanyMealDishes(String mealId, {required bool isVeg}) {
  return switch (mealId) {
    'breakfast' => ['Muesli', 'Yogurt', 'Fruit'],
    'extra-snack' => ['Pretzel', 'Cheese'],
    'lunch' =>
      isVeg
          ? ['Kartoffelsalat', 'Lentil soup']
          : ['Chicken schnitzel', 'Potatoes', 'Salad'],
    'snack' => ['Quark', 'Fruit'],
    'dinner' =>
      isVeg
          ? ['Bread', 'Cheese', 'Vegetable soup']
          : ['Rye bread', 'Turkey slices', 'Soup'],
    _ => ['Simple meal'],
  };
}

List<String> _mixedMealDishes(String mealId, {required bool isVeg}) {
  return switch (mealId) {
    'breakfast' => ['Oats', 'Fruit', 'Yogurt'],
    'extra-snack' => ['Nuts', 'Fruit'],
    'lunch' =>
      isVeg
          ? ['Rice bowl', 'Beans', 'Vegetables']
          : ['Rice bowl', 'Chicken', 'Vegetables'],
    'snack' => ['Sandwich', 'Tea'],
    'dinner' =>
      isVeg
          ? ['Roti or bread', 'Vegetable curry']
          : ['Lean protein', 'Rice', 'Salad'],
    _ => ['Simple meal'],
  };
}

List<String> _customMealDishes(String mealId, {required bool isVeg}) {
  return switch (mealId) {
    'breakfast' => ['Simple local breakfast', 'Fruit'],
    'extra-snack' => ['Light snack'],
    'lunch' =>
      isVeg
          ? ['Local veg meal', 'Rice or bread']
          : ['Local protein meal', 'Rice or bread'],
    'snack' => ['Tea snack'],
    'dinner' => isVeg ? ['Simple veg dinner'] : ['Simple dinner with protein'],
    _ => ['Simple meal'],
  };
}

class _MealSpec {
  final String id;
  final String title;
  final int startMinute;
  final int durationMinutes;

  const _MealSpec(this.id, this.title, this.startMinute, this.durationMinutes);
}
