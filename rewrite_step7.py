import sys

content = """import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/features/onboarding/steps/ai_thinking_card.dart';

class OnboardingStep7 extends ConsumerWidget {
  const OnboardingStep7({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(mockOnboardingProvider).draft.baseTimeline;
    final hasActivePath =
        base.skinCareSetupPath == 'has_products' ||
        base.skinCareSetupPath == 'no_products' ||
        base.skinCareSetupPath == 'skip' ||
        base.skinCareSkipped;
    final isChoice = base.skinCareSetupStep <= 0 || !hasActivePath;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SkinCareHeader(),
          const SizedBox(height: 18),
          Expanded(
            child: isChoice
                ? _SkinCareChoiceScreen(base: base)
                : _SkinCareSelectedModeScreen(base: base),
          ),
        ],
      ),
    );
  }
}

class _SkinCareHeader extends StatelessWidget {
  const _SkinCareHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skin Care',
          style: TextStyle(
            fontSize: 26,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Face and skin routine setup.',
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

class _SkinCareChoiceScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareChoiceScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void select(String value) {
      ref.read(mockOnboardingProvider.notifier).clearValidation();
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final isSkip = value == 'skip';
        final switchedPath = base.skinCareSetupPath != value;
        final blocks = switchedPath && !isSkip
            ? base.blocks.where((b) => b.section != 'skin_care').toList()
            : base.blocks;
        return base.copyWith(
          blocks: blocks,
          skinCareSetupPath: value,
          skinCareSetupStep: isSkip ? 1 : 1, // Immediately set to 1
          skinCareSkipped: isSkip,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkinCarePathCard(
          title: 'I have products',
          subtitle: 'Type product names to build a routine.',
          icon: Icons.spa_rounded,
          accent: OptivusColors.roseAccent,
          selected:
              base.skinCareSetupPath == 'has_products' && !base.skinCareSkipped,
          onTap: () => select('has_products'),
        ),
        const SizedBox(height: 12),
        _SkinCarePathCard(
          title: 'Build routine for me',
          subtitle: 'Answer skin details to generate a routine.',
          icon: Icons.face_retouching_natural_rounded,
          accent: OptivusColors.purpleAccent,
          selected:
              base.skinCareSetupPath == 'no_products' && !base.skinCareSkipped,
          onTap: () => select('no_products'),
        ),
        const SizedBox(height: 12),
        _SkinCarePathCard(
          title: 'Skip',
          subtitle: 'Skin care will be skipped for now.',
          icon: Icons.skip_next_rounded,
          accent: OptivusColors.textSecondary,
          selected: base.skinCareSetupPath == 'skip' || base.skinCareSkipped,
          onTap: () => select('skip'),
        ),
      ],
    );
  }
}

class _SkinCarePathCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _SkinCarePathCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        tint: selected
            ? accent.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.48),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.62)
                      : Colors.white.withValues(alpha: 0.72),
                ),
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

class _SkinCareSelectedModeScreen extends ConsumerWidget {
  final BaseTimelineDraft base;

  const _SkinCareSelectedModeScreen({required this.base});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (base.skinCareSkipped || base.skinCareSetupPath == 'skip') {
      return const _SkipModeScreen();
    }

    final blocks = base.confirmedBlocksForSection('skin_care');

    if (base.skinCareSetupPath == 'has_products') {
      return _HasProductsModeScreen(base: base, blocks: blocks);
    }

    return _NoProductsModeScreen(base: base, blocks: blocks);
  }
}

class _SkipModeScreen extends StatelessWidget {
  const _SkipModeScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.textSecondary.withValues(alpha: 0.08),
          child: const Row(
            children: [
              Icon(Icons.skip_next_rounded, color: OptivusColors.textSecondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Skin care will be skipped for now.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HasProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _HasProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_HasProductsModeScreen> createState() =>
      _HasProductsModeScreenState();
}

class _HasProductsModeScreenState extends ConsumerState<_HasProductsModeScreen> {
  late final TextEditingController _controller;
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  bool _generating = false;
  String? _generationError;
  int _selectedDay = DateTime.now().weekday;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.base.skinCareProductNames);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    setState(() {
      _uploadError = null;
    });
    try {
      await ref
          .read(uploadControllerProvider.notifier)
          .startUpload(purpose: UploadedAssetPurpose.skinCareProducts);
    } catch (_) {}

    final uploadState = ref.read(uploadControllerProvider);
    final asset = uploadState.asset;
    setState(() {
      _uploadedAsset = asset ?? uploadState.asset;
      _uploadError = uploadState.status == UploadFlowStatus.failed
          ? 'Upload failed.'
          : null;
    });
  }

  void _removeUploadedAsset() {
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
    });
  }

  Future<void> _generate() async {
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    setState(() {
      _generating = true;
      _generationError = null;
    });

    try {
      final user = ref.read(firebaseUserProvider).value;
      final idToken = await user?.getIdToken() ?? '';
      final uid = user?.uid ?? 'test-uid';
      final client = ref.read(skinCareAiClientProvider);

      List<String> photoProducts = [];
      if (_uploadedAsset != null) {
        final analysis = await client.analyzeProducts(
          uid: uid,
          idToken: idToken,
          assetKey: _uploadedAsset!.r2Key!,
        );
        if (!analysis.hasError && analysis.detectedProducts != null) {
          photoProducts = analysis.detectedProducts!.cast<String>();
        }
      }

      final result = await client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          'productsFromPhoto': photoProducts,
          'typedProductNames': _controller.text,
          'skinType': 'unknown',
          'mainProblem': 'none',
          'budget': 'medium',
          'routinePreference': 'balanced',
        },
      );

      if (result.hasError || result.timelineBlocks.isEmpty) {
        setState(() {
          _generating = false;
          _generationError = result.errorMessage ?? 'AI failed to generate a routine. Try adding more details.';
        });
        return;
      }

      final newBlocks = result.timelineBlocks.map((b) => TimelineBlockDraft.fromJson(b)).toList();
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final nextBlocks = base.blocks.where((b) => b.section != 'skin_care').toList()..addAll(newBlocks);
        return base.copyWith(
          blocks: nextBlocks,
          skinCareProductNames: _controller.text,
          skinCareSkipped: false,
        );
      });

      setState(() {
        _generating = false;
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _generationError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OnboardingGlassCard(
          tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
          padding: const EdgeInsets.all(12),
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'I have products',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 80,
                    child: _SkinCarePhotoTarget(
                      asset: _uploadedAsset,
                      onRemove: _removeUploadedAsset,
                      onTap: _generating ? null : _startUpload,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 400 ? 200 : MediaQuery.of(context).size.width - 150,
                    child: OnboardingTextInputCard(
                      controller: _controller,
                      title: 'Product names',
                      hint: 'Cleanser, moisturizer...',
                      accent: OptivusColors.roseAccent,
                      minLines: 2,
                      onChanged: (value) => updateBaseTimelineDraft(
                        ref,
                        onboardingSkinCareStepIndex,
                        (base) => base.copyWith(skinCareProductNames: value),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OnboardingActionPill(
                      label: 'Build skin routine',
                      icon: Icons.auto_awesome_rounded,
                      accent: OptivusColors.roseAccent,
                      selected: true,
                      onTap: _generating ? () {} : _generate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_uploadError != null || _generationError != null) ...[
          const SizedBox(height: 10),
          _SkinCareInlineMessage(message: _uploadError ?? _generationError!),
        ],
        const SizedBox(height: 12),
        if (_generating)
          const AiThinkingCard(section: 'Skin Care', label: 'Building routine...')
        else if (generated)
          _SkinCareTimelineSection(
            selectedDay: _selectedDay,
            blocks: widget.blocks,
            onDayChanged: (d) => setState(() => _selectedDay = d),
            emptyLabel: 'No skin care scheduled for this day.',
            accent: OptivusColors.roseAccent,
          )
        else
          const Spacer(),
      ],
    );
  }
}

class _NoProductsModeScreen extends ConsumerStatefulWidget {
  final BaseTimelineDraft base;
  final List<TimelineBlockDraft> blocks;

  const _NoProductsModeScreen({required this.base, required this.blocks});

  @override
  ConsumerState<_NoProductsModeScreen> createState() =>
      _NoProductsModeScreenState();
}

class _NoProductsModeScreenState extends ConsumerState<_NoProductsModeScreen> {
  UploadedAsset? _uploadedAsset;
  String? _uploadError;
  bool _generating = false;
  String? _generationError;
  int _selectedDay = DateTime.now().weekday;
  List<String> _suggestedProducts = [];

  Future<void> _startUpload() async {
    setState(() => _uploadError = null);
    try {
      await ref
          .read(uploadControllerProvider.notifier)
          .startUpload(purpose: UploadedAssetPurpose.skinCareProducts);
    } catch (_) {}

    final uploadState = ref.read(uploadControllerProvider);
    final asset = uploadState.asset;
    setState(() {
      _uploadedAsset = asset ?? uploadState.asset;
      _uploadError = uploadState.status == UploadFlowStatus.failed ? 'Upload failed.' : null;
    });
  }

  void _removeUploadedAsset() {
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
    });
  }

  Future<void> _generate() async {
    ref.read(mockOnboardingProvider.notifier).clearValidation();
    setState(() {
      _generating = true;
      _generationError = null;
    });

    try {
      final user = ref.read(firebaseUserProvider).value;
      final idToken = await user?.getIdToken() ?? '';
      final uid = user?.uid ?? 'test-uid';
      final client = ref.read(skinCareAiClientProvider);

      final result = await client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          'skinType': widget.base.skinCareSkinType,
          'mainProblem': widget.base.skinCareProblems.isNotEmpty ? widget.base.skinCareProblems.first : 'none',
          'budget': widget.base.skinCareBudget,
          'routinePreference': widget.base.skinCarePreference,
          'facePhotoR2Key': _uploadedAsset?.r2Key,
        },
      );

      if (result.hasError || result.timelineBlocks.isEmpty) {
        setState(() {
          _generating = false;
          _generationError = result.errorMessage ?? 'AI failed to generate a routine. Try adding more details.';
        });
        return;
      }

      final newBlocks = result.timelineBlocks.map((b) => TimelineBlockDraft.fromJson(b)).toList();
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final nextBlocks = base.blocks.where((b) => b.section != 'skin_care').toList()..addAll(newBlocks);
        return base.copyWith(
          blocks: nextBlocks,
          skinCareSkipped: false,
        );
      });

      setState(() {
        _generating = false;
        _suggestedProducts = result.suggestedProducts;
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _generationError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!generated || _generating)
          Expanded(
            child: OnboardingGlassCard(
              tint: OptivusColors.purpleAccent.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(12),
              radius: 18,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Build routine for me',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 80,
                          child: _SkinCarePhotoTarget(
                            asset: _uploadedAsset,
                            onRemove: _removeUploadedAsset,
                            onTap: _generating ? null : _startUpload,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 400 ? 200 : MediaQuery.of(context).size.width - 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkinCareChipGroup(
                                label: 'Skin Type',
                                children: [
                                  for (final option in const [
                                    _SkinOption('oily', 'Oily'),
                                    _SkinOption('dry', 'Dry'),
                                    _SkinOption('combination', 'Combination'),
                                    _SkinOption('not_sure', 'Not sure'),
                                  ])
                                    _SkinCarePreferenceChip(
                                      label: option.label,
                                      selected: widget.base.skinCareSkinType == option.key,
                                      accent: OptivusColors.purpleAccent,
                                      onTap: () => updateBaseTimelineDraft(
                                        ref,
                                        onboardingSkinCareStepIndex,
                                        (base) => base.copyWith(
                                          skinCareSkinType: option.key,
                                          skinCareSkipped: false,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _SkinCareChipGroup(
                                label: 'Concerns',
                                children: [
                                  for (final option in const [
                                    _SkinOption('pimples', 'Acne'),
                                    _SkinOption('dark_spots', 'Spots'),
                                    _SkinOption('tan', 'Tan'),
                                    _SkinOption('dryness', 'Dryness'),
                                    _SkinOption('oiliness', 'Oiliness'),
                                    _SkinOption('none', 'None'),
                                  ])
                                    _SkinCarePreferenceChip(
                                      label: option.label,
                                      selected: widget.base.skinCareProblems.contains(option.key),
                                      accent: OptivusColors.purpleAccent,
                                      onTap: () {
                                        final next = {...widget.base.skinCareProblems};
                                        if (option.key == 'none') {
                                          next..clear()..add('none');
                                        } else {
                                          next.remove('none');
                                          next.contains(option.key) ? next.remove(option.key) : next.add(option.key);
                                        }
                                        updateBaseTimelineDraft(
                                          ref,
                                          onboardingSkinCareStepIndex,
                                          (base) => base.copyWith(
                                            skinCareProblems: next.toList(),
                                            skinCareSkipped: false,
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _SkinCareChipGroup(
                                label: 'Budget',
                                children: [
                                  for (final option in const [
                                    _SkinOption('low', 'Low'),
                                    _SkinOption('medium', 'Medium'),
                                    _SkinOption('high', 'High'),
                                  ])
                                    _SkinCarePreferenceChip(
                                      label: option.label,
                                      selected: widget.base.skinCareBudget == option.key,
                                      accent: OptivusColors.purpleAccent,
                                      onTap: () => updateBaseTimelineDraft(
                                        ref,
                                        onboardingSkinCareStepIndex,
                                        (base) => base.copyWith(
                                          skinCareBudget: option.key,
                                          skinCareSkipped: false,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OnboardingActionPill(
                            label: 'Build skin routine',
                            icon: Icons.auto_awesome_rounded,
                            accent: OptivusColors.purpleAccent,
                            selected: true,
                            onTap: _generating ? () {} : _generate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OnboardingGlassCard(
                  tint: OptivusColors.purpleAccent.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  radius: 20,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: OptivusColors.purpleAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Routine built',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                      ),
                      OnboardingActionPill(
                        label: 'Rebuild',
                        icon: Icons.refresh_rounded,
                        accent: OptivusColors.purpleAccent,
                        compact: true,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingSkinCareStepIndex,
                          (base) => base.copyWith(
                            blocks: base.blocks.where((b) => b.section != 'skin_care').toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (_uploadError != null || _generationError != null) ...[
          const SizedBox(height: 10),
          _SkinCareInlineMessage(message: _uploadError ?? _generationError!),
        ],
        const SizedBox(height: 12),
        if (_generating)
          const AiThinkingCard(section: 'Skin Care', label: 'Building routine...')
        else if (generated)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_suggestedProducts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Suggested: ${_suggestedProducts.join(", ")}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                _SkinCareTimelineSection(
                  selectedDay: _selectedDay,
                  blocks: widget.blocks,
                  onDayChanged: (d) => setState(() => _selectedDay = d),
                  emptyLabel: 'No skin care scheduled for this day.',
                  accent: OptivusColors.purpleAccent,
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}

class _SkinCarePhotoTarget extends StatelessWidget {
  final UploadedAsset? asset;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _SkinCarePhotoTarget({
    required this.asset,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = asset?.localPreviewPath;
    final showFile = preview != null && File(preview).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

class _SkinCareInlineMessage extends StatelessWidget {
  final String message;

  const _SkinCareInlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: OptivusColors.roseAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OptivusColors.roseAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: OptivusColors.roseAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: OptivusColors.roseAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCareTimelineSection extends StatelessWidget {
  final int selectedDay;
  final List<TimelineBlockDraft> blocks;
  final ValueChanged<int> onDayChanged;
  final String emptyLabel;
  final Color accent;

  const _SkinCareTimelineSection({
    required this.selectedDay,
    required this.blocks,
    required this.onDayChanged,
    required this.emptyLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dayBlocks = blocks
        .where((block) => block.repeatDays.contains(selectedDay))
        .toList(growable: false)
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Routine',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          _SkinCareDayChips(
            selectedDay: selectedDay,
            onChanged: onDayChanged,
            accent: accent,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dayBlocks.isEmpty
                ? _SkinCareTimelineEmptyCard(label: emptyLabel)
                : OnboardingBaseTimeline(blocks: dayBlocks),
          ),
        ],
      ),
    );
  }
}

class _SkinCareDayChips extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onChanged;
  final Color accent;

  const _SkinCareDayChips({
    required this.selectedDay,
    required this.onChanged,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 7; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selectedDay == i ? accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _dayName(i),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: selectedDay == i
                      ? Colors.white
                      : OptivusColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _dayName(int day) {
    switch (day) {
      case 1:
        return 'M';
      case 2:
        return 'T';
      case 3:
        return 'W';
      case 4:
        return 'T';
      case 5:
        return 'F';
      case 6:
        return 'S';
      case 7:
        return 'S';
      default:
        return '';
    }
  }
}

class _SkinCareTimelineEmptyCard extends StatelessWidget {
  final String label;

  const _SkinCareTimelineEmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 48, color: OptivusColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: OptivusColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCareChipGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SkinCareChipGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _SkinCarePreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SkinCarePreferenceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : OptivusColors.textSecondary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? Colors.white : OptivusColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SkinOption {
  final String key;
  final String label;

  const _SkinOption(this.key, this.label);
}
"""

with open("/Users/roy/optivus2/Optivus/lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart", "w") as f:
    f.write(content)
