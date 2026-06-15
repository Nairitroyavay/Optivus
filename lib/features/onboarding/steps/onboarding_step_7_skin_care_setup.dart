import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/config/ai_workers_config.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/steps/onboarding_base_timeline_helpers.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_step_shell.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/models/onboarding_draft.dart';
import 'package:optivus/features/routine/utils/timeline_utils.dart';
import 'package:optivus/features/onboarding/steps/onboarding_step4_unified.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/auth_state.dart';
import 'package:optivus/models/uploaded_asset.dart';
import 'package:optivus/state/upload_state.dart';
import 'package:optivus/services/skin_care_ai_client.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

const String onboardingSkinCareGeneratedSource = 'ai_skin_care_setup';

@visibleForTesting
List<String> onboarding7SplitTypedProductNames(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return const [];
  return _dedupeSkinCareNames(
    text
        .split(RegExp(r'[\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}

@visibleForTesting
List<String> onboarding7ExtractPhotoProductNames(List<dynamic> products) {
  return _dedupeSkinCareNames(
    products.map(_skinCareNameFromProduct).where((name) => name.isNotEmpty),
  );
}

@visibleForTesting
List<String> onboarding7MergeProductNames(
  List<String> photoProducts,
  List<String> typedProducts,
) {
  return _dedupeSkinCareNames([...photoProducts, ...typedProducts]);
}

@visibleForTesting
List<TimelineBlockDraft> onboarding7TimelineBlocksFromWorkerBlocks(
  List<dynamic> rawBlocks, {
  DateTime? now,
}) {
  final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final blocks = <TimelineBlockDraft>[];

  for (var index = 0; index < rawBlocks.length; index += 1) {
    final raw = rawBlocks[index];
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final title = _stringValue(map['title'] ?? map['name']).trim();
    if (title.isEmpty) continue;

    final start = _minuteValue(
      map['startMinute'] ??
          map['start_minutes'] ??
          map['start'] ??
          map['startTimeMinute'],
    );
    final end = _minuteValue(
      map['endMinute'] ??
          map['end_minutes'] ??
          map['end'] ??
          map['endTimeMinute'],
    );
    if (start == null || end == null) continue;
    final safeStart = start.clamp(0, 24 * 60 - 1).toInt();
    final safeEnd = end.clamp(1, 24 * 60).toInt();
    if (safeEnd <= safeStart) continue;

    final repeatDays = _repeatDaysValue(map['repeatDays'] ?? map['days']);
    final products = _dedupeSkinCareNames([
      ..._skinCareNamesFromValue(map['skincareProducts']),
      ..._skinCareNamesFromValue(map['products']),
      ..._skinCareNamesFromValue(map['steps']),
    ]);

    final id = _stringValue(map['id']).trim();
    blocks.add(
      TimelineBlockDraft(
        id: id.isEmpty ? 'skin-care-$timestamp-$index' : id,
        section: 'skin_care',
        title: title,
        startMinute: safeStart,
        endMinute: safeEnd,
        repeatDays: repeatDays.isEmpty ? onboardingEveryDay() : repeatDays,
        blockType: TimelineBlockDraft.softBlockKey,
        source: onboardingSkinCareGeneratedSource,
        skincareProducts: products,
      ),
    );
  }

  return blocks;
}

@visibleForTesting
String onboarding7FriendlyAiMessage(String? error, List<String> warnings) {
  final messages = [
    if (error?.trim().isNotEmpty == true) error!.trim(),
    ...warnings
        .map((warning) => warning.trim())
        .where((warning) => warning.isNotEmpty),
  ];
  final text = messages.join(' ').toLowerCase();

  if (text.contains('missing_worker_url') ||
      text.contains('worker url') ||
      text.contains('worker is not configured') ||
      text.contains('not configured')) {
    if (kDebugMode) {
      return 'Real AI is not configured. Missing skin-care worker URL. Run Flutter with --dart-define=OPTIVUS_SKIN_CARE_WORKER_URL=<skin-care-worker-url>.';
    }
    return 'Skin care AI is unavailable right now. Please try again later.';
  }
  if (text.contains('no_products_detected')) {
    return 'AI could not read products from the photo. Try a clearer image or type product names.';
  }
  if (text.contains('unsupported_content_type') ||
      text.contains('content type') ||
      text.contains('format')) {
    return 'This photo format is not supported. Please upload JPEG, PNG, or WEBP.';
  }
  if (text.contains('r2_image_missing') || text.contains('not found')) {
    return 'Uploaded product photo could not be found. Please upload again.';
  }
  if (text.contains('payload_too_large') || text.contains('too large')) {
    return 'Product photo is too large. Upload a smaller, clearer photo.';
  }
  if (text.contains('provider_quota_exceeded') ||
      text.contains('provider_high_demand') ||
      text.contains('provider_request_failed') ||
      text.contains('rate_limit')) {
    return 'AI is busy right now. Try again in a moment.';
  }
  if (text.contains('provider_invalid_response') ||
      text.contains('provider_invalid_json')) {
    return 'AI response could not be read safely. Please try again.';
  }
  if (text.contains('unavailable') || text.contains('provider_timeout')) {
    return 'AI skin care service is unavailable. Try again later.';
  }
  if (messages.isNotEmpty && !messages.first.startsWith('provider_')) {
    return messages.first;
  }
  return 'AI failed to generate a routine. Try adding more details.';
}

String _skinCareNameFromProduct(dynamic item) {
  if (item is String) return item.trim();
  if (item is Map) {
    final map = Map<String, dynamic>.from(item);
    final name = _stringValue(map['name']).trim();
    if (name.isEmpty) return '';
    final brand = _stringValue(map['brand']).trim();
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) {
      return name;
    }
    return '$brand $name';
  }
  return '';
}

List<String> _skinCareNamesFromValue(dynamic value) {
  if (value == null) return const [];
  if (value is String) return onboarding7SplitTypedProductNames(value);
  if (value is List) return onboarding7ExtractPhotoProductNames(value);
  final name = _skinCareNameFromProduct(value);
  return name.isEmpty ? const [] : [name];
}

List<String> _dedupeSkinCareNames(Iterable<String> source) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in source) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.add(key)) result.add(value);
  }
  return result;
}

String _stringValue(dynamic value) => value == null ? '' : value.toString();

int? _minuteValue(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<int> _repeatDaysValue(dynamic value) {
  final raw = value is List ? value : const [];
  final days =
      raw
          .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
          .whereType<int>()
          .where((day) => day >= 1 && day <= 7)
          .toSet()
          .toList()
        ..sort();
  return days;
}

String _friendlySkinCareUploadMessage(String? message) {
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

String _skinCareUploadStatusLabel(UploadFlowStatus status) {
  return switch (status) {
    UploadFlowStatus.picking => 'Picking...',
    UploadFlowStatus.preparing => 'Preparing...',
    UploadFlowStatus.signing => 'Preparing...',
    UploadFlowStatus.uploading => 'Uploading...',
    UploadFlowStatus.savingMetadata => 'Saving...',
    _ => 'Uploading...',
  };
}

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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: OnboardingStepShell.bottomCtaHeight + 40),
      child: Column(
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
      ),
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

class _HasProductsModeScreenState
    extends ConsumerState<_HasProductsModeScreen> {
  static const double _setupTileHeight = 142;

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
    final uploadState = ref.read(uploadControllerProvider);
    if (uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare &&
        uploadState.isBusy) {
      return;
    }
    setState(() {
      _uploadError = null;
      _generationError = null;
    });
    ref.read(mockOnboardingProvider.notifier).clearValidation();

    UploadedAsset? asset;
    try {
      final uid =
          ref.read(authProvider).user?.uid ??
          ref.read(mockOnboardingProvider).draft.uid;
      asset = await ref
          .read(uploadControllerProvider.notifier)
          .startUpload(
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            purpose: UploadedAssetPurpose.skinCare,
          );
    } catch (_) {}
    if (!mounted) return;

    final latestUploadState = ref.read(uploadControllerProvider);
    final latestAsset = asset ?? latestUploadState.asset;
    setState(() {
      if (latestAsset != null) {
        _uploadedAsset = latestAsset;
      }
      _uploadError = latestUploadState.status == UploadFlowStatus.failed
          ? _friendlySkinCareUploadMessage(latestUploadState.errorMessage)
          : null;
    });
  }

  void _removeUploadedAsset() {
    final uploadState = ref.read(uploadControllerProvider);
    final uploadBusy =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare &&
        uploadState.isBusy;
    if (uploadBusy) return;
    setState(() {
      _uploadedAsset = null;
      _uploadError = null;
      _generationError = null;
    });
  }

  Future<void> _generate() async {
    if (_generating) return;
    final uploadState = ref.read(uploadControllerProvider);
    final uploadBusy =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare &&
        uploadState.isBusy;
    if (uploadBusy) return;

    ref.read(mockOnboardingProvider.notifier).clearValidation();
    final asset = _uploadedAsset;
    final typedProductNames = onboarding7SplitTypedProductNames(
      _controller.text,
    );
    if (asset == null && typedProductNames.isEmpty) {
      setState(() {
        _generationError =
            'Upload your product photo or type product names first.';
        _uploadError = null;
      });
      return;
    }
    if (asset != null && asset.r2Key.trim().isEmpty) {
      setState(() {
        _generationError = 'Upload incomplete. Please upload again.';
        _uploadError = null;
      });
      return;
    }

    setState(() {
      _generating = true;
      _generationError = null;
      _uploadError = null;
    });

    try {
      if (kDebugMode &&
          OptivusAiWorkersConfig.useWorker &&
          OptivusAiWorkersConfig.skinCareWorkerUrl.trim().isEmpty) {
        debugPrint(
          '[Onboarding7] Missing OPTIVUS_SKIN_CARE_WORKER_URL for Skin Care AI.',
        );
      }
      final user = ref.read(authProvider).user;
      final idToken =
          await ref.read(authRepositoryProvider).currentIdToken() ?? '';
      final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
      final client = ref.read(skinCareAiClientProvider);

      List<String> photoProducts = [];
      if (asset != null) {
        final analysis = await client.analyzeProducts(
          uid: uid,
          idToken: idToken,
          productPhotos: [asset.r2Key.trim()],
        );
        if (analysis.hasError) {
          if (typedProductNames.isEmpty) {
            if (!mounted) return;
            setState(() {
              _generating = false;
              _generationError = onboarding7FriendlyAiMessage(
                analysis.errorMessage,
                analysis.warnings,
              );
            });
            return;
          }
        } else {
          photoProducts = onboarding7ExtractPhotoProductNames(
            analysis.products,
          );
        }
      }

      final allProductNames = onboarding7MergeProductNames(
        photoProducts,
        typedProductNames,
      );
      final result = await client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          'productsFromPhoto': photoProducts,
          'typedProductNames': typedProductNames,
          'skinType': 'unknown',
          'mainProblem': 'none',
          'budget': 'medium',
          'routinePreference': 'balanced',
        },
      );

      if (result.hasError || result.timelineBlocks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _generating = false;
          _generationError = onboarding7FriendlyAiMessage(
            result.errorMessage,
            result.warnings,
          );
        });
        return;
      }

      final mappedBlocks = onboarding7TimelineBlocksFromWorkerBlocks(
        result.timelineBlocks,
      );
      if (mappedBlocks.isEmpty) {
        if (!mounted) return;
        setState(() {
          _generating = false;
          _generationError = 'AI returned an empty routine. Please try again.';
        });
        return;
      }

      final newBlocks = [
        for (final block in mappedBlocks)
          block.skincareProducts.isEmpty && allProductNames.isNotEmpty
              ? block.copyWith(skincareProducts: allProductNames)
              : block,
      ];

      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final List<TimelineBlockDraft> nextBlocks =
            base.blocks.where((b) => b.section != 'skin_care').toList()
              ..addAll(newBlocks);
        return base.copyWith(
          blocks: nextBlocks,
          skinCareProductNames: _controller.text,
          skinCareSkipped: false,
        );
      });

      if (!mounted) return;
      setState(() {
        _generating = false;
      });
    } catch (e, st) {
      debugPrint('Error generating routine (Products): $e\n$st');
      setState(() {
        _generating = false;
        _generationError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final generated = widget.blocks.isNotEmpty;
    final uploadState = ref.watch(uploadControllerProvider);
    final uploadApplies =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare;
    final uploadBusy = uploadApplies && uploadState.isBusy;
    final uploadError =
        _uploadError ??
        (uploadApplies && uploadState.status == UploadFlowStatus.failed
            ? _friendlySkinCareUploadMessage(uploadState.errorMessage)
            : null);
    final busy = uploadBusy || _generating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!generated || _generating)
          _HasProductsSetupCard(
            controller: _controller,
            asset: _uploadedAsset,
            tileHeight: _setupTileHeight,
            uploadBusy: uploadBusy,
            uploadStatusLabel: uploadBusy
                ? _skinCareUploadStatusLabel(uploadState.status)
                : null,
            busy: busy,
            onUpload: busy ? null : _startUpload,
            onRemove: busy ? null : _removeUploadedAsset,
            onGenerate: busy ? null : _generate,
            onChanged: (value) => updateBaseTimelineDraft(
              ref,
              onboardingSkinCareStepIndex,
              (base) => base.copyWith(
                skinCareProductNames: value,
                skinCareSkipped: false,
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OnboardingGlassCard(
                  tint: OptivusColors.roseAccent.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                          color: OptivusColors.roseAccent,
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
                        accent: OptivusColors.roseAccent,
                        compact: true,
                        onTap: () => updateBaseTimelineDraft(
                          ref,
                          onboardingSkinCareStepIndex,
                          (base) => base.copyWith(
                            blocks: base.blocks
                                .where((b) => b.section != 'skin_care')
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (uploadError != null || _generationError != null) ...[
          const SizedBox(height: 10),
          _SkinCareInlineMessage(message: uploadError ?? _generationError!),
        ],
        const SizedBox(height: 12),
        if (_generating)
          AiThinkingCard(
            title: 'Skin Care AI',
            detail: 'Building your routine from product names and labels',
            accent: OptivusColors.roseAccent,
            isActive: true,
          )
        else
          _SkinCareTimelineSection(
            selectedDay: _selectedDay,
            blocks: widget.blocks,
            onDayChanged: (d) => setState(() => _selectedDay = d),
            emptyLabel: 'Build your skin-care routine first.',
            accent: OptivusColors.roseAccent,
          ),
      ],
    );
  }
}

class _HasProductsSetupCard extends StatelessWidget {
  final TextEditingController controller;
  final UploadedAsset? asset;
  final double tileHeight;
  final bool uploadBusy;
  final String? uploadStatusLabel;
  final bool busy;
  final VoidCallback? onUpload;
  final VoidCallback? onRemove;
  final VoidCallback? onGenerate;
  final ValueChanged<String> onChanged;

  const _HasProductsSetupCard({
    required this.controller,
    required this.asset,
    required this.tileHeight,
    required this.uploadBusy,
    required this.uploadStatusLabel,
    required this.busy,
    required this.onUpload,
    required this.onRemove,
    required this.onGenerate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
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
          const SizedBox(height: 3),
          const Text(
            'Upload one clear photo with all your skin-care products together. Keep front labels visible.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 280;
              final photo = SizedBox(
                height: tileHeight,
                child: _SkinCarePhotoTarget(
                  asset: asset,
                  busy: uploadBusy,
                  busyLabel: uploadStatusLabel,
                  onRemove: onRemove,
                  onTap: onUpload,
                ),
              );
              final input = SizedBox(
                height: tileHeight,
                child: _SkinCareProductNamesTarget(
                  controller: controller,
                  onChanged: onChanged,
                ),
              );

              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [photo, const SizedBox(height: 10), input],
                );
              }

              return SizedBox(
                height: tileHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: photo),
                    const SizedBox(width: 10),
                    Expanded(child: input),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SkinCareGenerateRoutineButton(
            label: 'Build skin routine',
            busy: busy,
            onTap: onGenerate,
            accent: OptivusColors.roseAccent,
          ),
        ],
      ),
    );
  }
}

class _SkinCareProductNamesTarget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SkinCareProductNamesTarget({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      key: const ValueKey('onboarding-step7-product-names-tile'),
      tint: OptivusColors.roseAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(11),
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product names',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: TextField(
              key: const ValueKey('onboarding-step7-product-names-field'),
              controller: controller,
              minLines: null,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.22,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cleanser, moisturizer...\nAdd corrections here',
                hintStyle: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.34),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
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
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: OptivusColors.roseAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCareGenerateRoutineButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  final Color accent;

  const _SkinCareGenerateRoutineButton({
    required this.label,
    required this.busy,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.45,
        child: Container(
          key: const ValueKey('onboarding-step7-generate-button'),
          height: 44,
          decoration: BoxDecoration(
            color: enabled ? accent : Colors.white.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.auto_awesome_rounded,
                  color: enabled ? Colors.white : OptivusColors.textSecondary,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : OptivusColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
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
      final uid =
          ref.read(authProvider).user?.uid ??
          ref.read(mockOnboardingProvider).draft.uid;
      await ref
          .read(uploadControllerProvider.notifier)
          .startUpload(
            uid: uid,
            sourceFeature: OnboardingDraft.sourceOnboarding,
            purpose: UploadedAssetPurpose.skinCare,
          );
    } catch (_) {}

    final uploadState = ref.read(uploadControllerProvider);
    final asset = uploadState.asset;
    setState(() {
      _uploadedAsset = asset ?? uploadState.asset;
      _uploadError = uploadState.status == UploadFlowStatus.failed
          ? _friendlySkinCareUploadMessage(uploadState.errorMessage)
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
      final user = ref.read(authProvider).user;
      final idToken =
          await ref.read(authRepositoryProvider).currentIdToken() ?? '';
      final uid = user?.uid ?? ref.read(mockOnboardingProvider).draft.uid;
      final client = ref.read(skinCareAiClientProvider);

      final result = await client.generateRoutine(
        uid: uid,
        idToken: idToken,
        params: {
          'skinType': widget.base.skinCareSkinType,
          'mainProblem': widget.base.skinCareProblems.isNotEmpty
              ? widget.base.skinCareProblems.first
              : 'none',
          'budget': widget.base.skinCareBudget,
          'routinePreference': widget.base.skinCarePreference,
          'facePhotoR2Key': _uploadedAsset?.r2Key,
        },
      );

      if (result.hasError || result.timelineBlocks.isEmpty) {
        setState(() {
          _generating = false;
          _generationError = onboarding7FriendlyAiMessage(
            result.errorMessage,
            result.warnings,
          );
        });
        return;
      }

      final newBlocks = onboarding7TimelineBlocksFromWorkerBlocks(
        result.timelineBlocks,
      );
      if (newBlocks.isEmpty) {
        setState(() {
          _generating = false;
          _generationError = 'AI returned an empty routine. Please try again.';
        });
        return;
      }
      updateBaseTimelineDraft(ref, onboardingSkinCareStepIndex, (base) {
        final List<TimelineBlockDraft> nextBlocks =
            base.blocks.where((b) => b.section != 'skin_care').toList()
              ..addAll(newBlocks);
        return base.copyWith(blocks: nextBlocks, skinCareSkipped: false);
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
    final uploadState = ref.watch(uploadControllerProvider);
    final uploadApplies =
        uploadState.sourceFeature == OnboardingDraft.sourceOnboarding &&
        uploadState.purpose == UploadedAssetPurpose.skinCare;
    final uploadBusy = uploadApplies && uploadState.isBusy;
    final busy = uploadBusy || _generating;

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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final photo = SizedBox(
                          height: 112,
                          child: _SkinCarePhotoTarget(
                            asset: _uploadedAsset,
                            busy: uploadBusy,
                            busyLabel: uploadBusy
                                ? _skinCareUploadStatusLabel(uploadState.status)
                                : null,
                            onRemove: busy ? null : _removeUploadedAsset,
                            onTap: busy ? null : _startUpload,
                          ),
                        );
                        final controls = Column(
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
                                    selected:
                                        widget.base.skinCareSkinType ==
                                        option.key,
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
                                    selected: widget.base.skinCareProblems
                                        .contains(option.key),
                                    accent: OptivusColors.purpleAccent,
                                    onTap: () {
                                      final next = {
                                        ...widget.base.skinCareProblems,
                                      };
                                      if (option.key == 'none') {
                                        next
                                          ..clear()
                                          ..add('none');
                                      } else {
                                        next.remove('none');
                                        next.contains(option.key)
                                            ? next.remove(option.key)
                                            : next.add(option.key);
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
                                    selected:
                                        widget.base.skinCareBudget ==
                                        option.key,
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
                        );

                        if (constraints.maxWidth < 300) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              photo,
                              const SizedBox(height: 10),
                              controls,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: math.max(96, constraints.maxWidth * 0.30),
                              child: photo,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: controls),
                          ],
                        );
                      },
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
                            onTap: busy ? null : _generate,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                            blocks: base.blocks
                                .where((b) => b.section != 'skin_care')
                                .toList(),
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
          AiThinkingCard(
            title: 'Skin Care',
            detail: 'Building routine...',
            accent: OptivusColors.purpleAccent,
            isActive: true,
          )
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
  final bool busy;
  final String? busyLabel;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _SkinCarePhotoTarget({
    required this.asset,
    this.busy = false,
    this.busyLabel,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = asset?.localPreviewPath;
    final showFile = preview != null && File(preview).existsSync();

    return GestureDetector(
      key: const ValueKey('onboarding-step7-photo-tile'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
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
                          const SizedBox(height: 4),
                          Text(
                            asset == null ? 'Add photo' : 'Photo uploaded',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (busy)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.78),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: OptivusColors.roseAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          busyLabel ?? 'Uploading...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.roseAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (asset != null && !busy && onRemove != null)
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
        border: Border.all(
          color: OptivusColors.roseAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: OptivusColors.roseAccent,
            size: 16,
          ),
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
    final dayBlocks =
        blocks
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
                : _SkinCareVerticalTimeline(blocks: dayBlocks, accent: accent),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final dayName = [
              'MON',
              'TUE',
              'WED',
              'THU',
              'FRI',
              'SAT',
              'SUN',
            ][index];
            final dayIndex = index + 1; // 1-indexed for repeatDays
            final isSelected = selectedDay == dayIndex;
            return SizedBox(
              width: 52,
              height: 46,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(dayIndex),
                child: _SkinCareDayChip(
                  label: dayName,
                  selected: isSelected,
                  accent: accent,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SkinCareDayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;

  const _SkinCareDayChip({
    required this.label,
    required this.selected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 36.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (selected ? accent : Colors.black).withValues(
                  alpha: selected ? 0.07 : 0.035,
                ),
                blurRadius: selected ? 5 : 7,
                spreadRadius: 0,
                offset: Offset(0, selected ? 2 : 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: selected ? 0.60 : 0.70),
                blurRadius: selected ? 6 : 10,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? accent.withValues(alpha: 0.68)
                      : Colors.white.withValues(alpha: 0.38),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: 0.42)
                        : Colors.white.withValues(alpha: 0.72),
                    width: selected ? 1.8 : 1.2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 4,
                      left: 9,
                      right: 9,
                      height: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withValues(alpha: 0.46),
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: selected ? 12 : 10,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Colors.white
                            : OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinCareTimelineEmptyCard extends StatelessWidget {
  final String label;

  const _SkinCareTimelineEmptyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 110),
          child: OnboardingGlassCard(
            tint: Colors.white.withValues(alpha: 0.30),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            radius: 20,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _TimelineRange {
  final int startHour;
  final int endHour;

  const _TimelineRange({required this.startHour, required this.endHour});

  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
  int get hourCount => (endHour - startHour).clamp(1, 24);
}

class _VisualSkinCareBlock {
  final TimelineBlockDraft block;
  final int lane;
  final int order;
  final bool hasOverlap;

  const _VisualSkinCareBlock({
    required this.block,
    required this.lane,
    required this.order,
    required this.hasOverlap,
  });
}

class _SkinCareVerticalTimeline extends StatefulWidget {
  final List<TimelineBlockDraft> blocks;
  final Color accent;

  const _SkinCareVerticalTimeline({
    super.key,
    required this.blocks,
    required this.accent,
  });

  @override
  State<_SkinCareVerticalTimeline> createState() => _SkinCareVerticalTimelineState();
}

class _SkinCareVerticalTimelineState extends State<_SkinCareVerticalTimeline> {
  static const double _kMinTimelineAreaHeight = 300.0;
  static const double _kPixelsPerMinute = 1.35;
  static const int _kMaxOverlapLane = 3;
  static const double _kLeftOffset = 64.0;
  static const double _kTimelineBottomPadding = OnboardingStepShell.bottomCtaHeight + 40;

  String? _frontBlockId;

  int _compareBlocksByTime(TimelineBlockDraft a, TimelineBlockDraft b) {
    final startCompare = a.startMinute.compareTo(b.startMinute);
    if (startCompare != 0) return startCompare;
    final endCompare = a.endMinute.compareTo(b.endMinute);
    if (endCompare != 0) return endCompare;
    return a.title.compareTo(b.title);
  }

  bool _blocksOverlap(TimelineBlockDraft a, TimelineBlockDraft b) {
    return a.startMinute < b.endMinute && a.endMinute > b.startMinute;
  }

  double _timelineY({
    required int minuteOfDay,
    required int visibleStartMinute,
    required double topPadding,
  }) {
    return topPadding + (minuteOfDay - visibleStartMinute) * _kPixelsPerMinute;
  }

  double _blockDurationHeight(TimelineBlockDraft item) {
    final durationMinutes = (item.endMinute - item.startMinute).clamp(1, 24 * 60).toInt();
    return durationMinutes * _kPixelsPerMinute;
  }

  double _blockVisualHeight(TimelineBlockDraft item) {
    return _blockDurationHeight(item);
  }

  List<_VisualSkinCareBlock> _visualBlocksFor(List<TimelineBlockDraft> dayItems) {
    final sorted = [...dayItems]..sort(_compareBlocksByTime);
    final active = <_VisualSkinCareBlock>[];
    final visualBlocks = <_VisualSkinCareBlock>[];

    for (final block in sorted) {
      active.removeWhere((entry) => !_blocksOverlap(block, entry.block));

      final usedLanes = active.map((entry) => entry.lane).toSet();
      var lane = 0;
      while (usedLanes.contains(lane) && lane < _kMaxOverlapLane) {
        lane++;
      }
      if (usedLanes.contains(lane)) {
        lane = _kMaxOverlapLane;
      }

      final visual = _VisualSkinCareBlock(
        block: block,
        lane: lane,
        order: visualBlocks.length,
        hasOverlap: dayItems.any(
          (other) => other.id != block.id && _blocksOverlap(block, other),
        ),
      );
      active.add(visual);
      visualBlocks.add(visual);
    }

    return visualBlocks;
  }

  _TimelineRange _rangeFor(List<TimelineBlockDraft> items) {
    if (items.isEmpty) {
      return const _TimelineRange(startHour: 7, endHour: 22);
    }
    final minStart = items.map((e) => e.startMinute).reduce(math.min);
    final maxEnd = items.map((e) => e.endMinute).reduce(math.max);
    
    final startHour = math.max(0, (minStart ~/ 60) - 1);
    final endHour = math.min(24, ((maxEnd + 59) ~/ 60) + 1);
    
    return _TimelineRange(startHour: startHour, endHour: endHour);
  }

  bool _isFrontVisual(_VisualSkinCareBlock visual, List<_VisualSkinCareBlock> visualBlocks) {
    if (!visual.hasOverlap) return true;
    if (_frontBlockId != null) return visual.block.id == _frontBlockId;
    final overlapping = visualBlocks.where((v) => _visualsOverlap(visual, v)).toList();
    if (overlapping.isEmpty) return true;
    final first = overlapping.reduce((a, b) => a.order < b.order ? a : b);
    return visual == first;
  }

  bool _visualsOverlap(_VisualSkinCareBlock a, _VisualSkinCareBlock b) {
    return _blocksOverlap(a.block, b.block);
  }

  double _overlapExposedLabelWidth(double availableWidth) {
    final timelineWidth = availableWidth - _kLeftOffset - 16;
    if (timelineWidth < 180) return 36.0;
    if (timelineWidth < 240) return 42.0;
    return 48.0;
  }

  double _leftForVisual(
    _VisualSkinCareBlock visual,
    List<_VisualSkinCareBlock> visualBlocks,
    double exposedLabelWidth,
  ) {
    final baseLeft = _kLeftOffset;
    if (!visual.hasOverlap) return baseLeft;

    final isFront = _isFrontVisual(visual, visualBlocks);
    if (isFront) {
      final hasOverlappingBacks = visualBlocks.any(
        (v) => _visualsOverlap(visual, v) && v != visual && !_isFrontVisual(v, visualBlocks),
      );
      return baseLeft + (hasOverlappingBacks ? exposedLabelWidth : 0.0);
    }

    final overlapping = visualBlocks.where((v) => _visualsOverlap(visual, v)).toList();
    final orderedBacks = overlapping.where((v) => !_isFrontVisual(v, visualBlocks)).toList()..sort((a, b) => a.order.compareTo(b.order));
    final backIndex = orderedBacks.indexOf(visual);
    if (backIndex == -1) return baseLeft;

    final totalBacks = orderedBacks.length;
    final maxLabelWidth = 48.0;
    final actualLabelWidth = (exposedLabelWidth / math.max(1, totalBacks - 1)).clamp(12.0, maxLabelWidth);

    return baseLeft + (backIndex * actualLabelWidth);
  }

  double _rightForVisual(_VisualSkinCareBlock visual, List<_VisualSkinCareBlock> visualBlocks) {
    if (!visual.hasOverlap) return 16.0;
    final isFront = _isFrontVisual(visual, visualBlocks);
    if (isFront) return 16.0;

    final frontBlock = visualBlocks.firstWhere(
      (v) => _visualsOverlap(visual, v) && _isFrontVisual(v, visualBlocks),
      orElse: () => visual,
    );

    if (frontBlock == visual) return 16.0;
    
    final overlapping = visualBlocks.where((v) => _visualsOverlap(visual, v)).toList();
    final orderedBacks = overlapping.where((v) => !_isFrontVisual(v, visualBlocks)).toList()..sort((a, b) => a.order.compareTo(b.order));
    final backIndex = orderedBacks.indexOf(visual);
    final totalBacks = orderedBacks.length;
    final insetPerBack = 12.0;
    
    final stackInset = (totalBacks - 1 - backIndex) * insetPerBack;
    return 16.0 + 8.0 + stackInset;
  }

  List<_VisualSkinCareBlock> _paintOrderedBlocks(List<_VisualSkinCareBlock> visualBlocks) {
    final painted = [...visualBlocks];
    painted.sort((a, b) {
      final aFront = _isFrontVisual(a, visualBlocks);
      final bFront = _isFrontVisual(b, visualBlocks);
      if (aFront && !bFront) return 1;
      if (!aFront && bFront) return -1;
      return a.order.compareTo(b.order);
    });
    return painted;
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = [...widget.blocks]..sort(_compareBlocksByTime);
    final visualBlocks = _visualBlocksFor(dayItems);
    final paintedBlocks = _paintOrderedBlocks(visualBlocks);

    final range = _rangeFor(widget.blocks);
    const topPadding = 18.0;
    const bottomPadding = _kTimelineBottomPadding;

    final maxCardBottom = dayItems.fold<double>(0, (maxBottom, item) {
      final top = _timelineY(
        minuteOfDay: item.startMinute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      final bottom = top + _blockVisualHeight(item);
      return bottom > maxBottom ? bottom : maxBottom;
    });

    final timelineHeight = [
      _timelineY(
            minuteOfDay: range.endMinute,
            visibleStartMinute: range.startMinute,
            topPadding: topPadding,
          ) +
          bottomPadding,
      maxCardBottom + bottomPadding,
    ].reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : _kMinTimelineAreaHeight;
            
        return SizedBox(
          height: height,
          child: Container(
            key: const ValueKey('onboarding-step7-full-timeline'),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
            ),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: _kTimelineBottomPadding),
                child: LayoutBuilder(
                  builder: (context, scrollConstraints) {
                    final exposedLabelWidth = _overlapExposedLabelWidth(
                      scrollConstraints.maxWidth,
                    );

                    return SizedBox(
                      height: timelineHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 48,
                            width: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: widget.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: widget.accent.withValues(alpha: 0.40),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.accent.withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          ..._buildMinuteIndicators(
                            range: range,
                            dayItems: dayItems,
                            topPadding: topPadding,
                          ),

                          ...List.generate(range.hourCount + 1, (i) {
                            final hour = (range.startHour + i) % 24;
                            final minute = range.startMinute + i * 60;
                            final ampm = hour < 12 ? 'AM' : 'PM';
                            final displayHour = hour == 0
                                ? 12
                                : (hour > 12 ? hour - 12 : hour);
                            final label = '$displayHour $ampm';
                            return Positioned(
                              top: _timelineY(
                                    minuteOfDay: minute,
                                    visibleStartMinute: range.startMinute,
                                    topPadding: topPadding,
                                  ) - 10,
                              left: 0,
                              width: 56,
                              height: 20,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    width: 42,
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: OptivusColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 48,
                                    top: 9,
                                    width: 4,
                                    height: 1.5,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: widget.accent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          ...paintedBlocks.map(
                            (visual) => _buildColoredBlock(
                              visual,
                              visualBlocks: visualBlocks,
                              visibleStartMinute: range.startMinute,
                              topPadding: topPadding,
                              exposedLabelWidth: exposedLabelWidth,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMinuteIndicators({
    required _TimelineRange range,
    required List<TimelineBlockDraft> dayItems,
    required double topPadding,
  }) {
    final widgets = <Widget>[];
    final boundaryMinutes = (<int>{
      for (final item in dayItems) ...[item.startMinute, item.endMinute],
    }.where((minute) {
      return minute % 60 != 0 &&
          minute > range.startMinute &&
          minute < range.endMinute;
    }).toList())
      ..sort();

    var lastLabelY = double.negativeInfinity;
    for (final minute in boundaryMinutes) {
      final y = _timelineY(
        minuteOfDay: minute,
        visibleStartMinute: range.startMinute,
        topPadding: topPadding,
      );
      final showLabel = y - lastLabelY >= 18;
      if (showLabel) lastLabelY = y;
      widgets.addAll([
        if (showLabel)
          Positioned(
            top: y - 8,
            left: 0,
            width: 38,
            height: 16,
            child: Text(
              TimelineUtils.formatMinuteShort(minute),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: widget.accent.withValues(alpha: 0.68),
              ),
            ),
          ),
        Positioned(
          top: y,
          left: _kLeftOffset,
          right: 16,
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Positioned(
          top: y,
          left: 44,
          width: 18,
          height: 1.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ]);
    }
    return widgets;
  }

  Widget _buildColoredBlock(
    _VisualSkinCareBlock visual, {
    required List<_VisualSkinCareBlock> visualBlocks,
    required int visibleStartMinute,
    required double topPadding,
    required double exposedLabelWidth,
  }) {
    final item = visual.block;
    final isFront = _isFrontVisual(visual, visualBlocks);
    final isBackOverlap = visual.hasOverlap && !isFront;
    final top = _timelineY(
      minuteOfDay: item.startMinute,
      visibleStartMinute: visibleStartMinute,
      topPadding: topPadding,
    );
    final exactHeight = _blockDurationHeight(item);
    final height = exactHeight;
    final compact = height < 92;
    final tiny = height < 42;
    final baseColor = widget.accent;

    return Positioned(
      top: top,
      left: _leftForVisual(visual, visualBlocks, exposedLabelWidth),
      right: _rightForVisual(visual, visualBlocks),
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _frontBlockId = item.id);
        },
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(
                alpha: visual.hasOverlap ? (isFront ? 0.72 : 0.58) : 0.42,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: isFront ? 0.26 : 0.18),
                  baseColor.withValues(alpha: isFront ? 0.08 : 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isFront ? 0.96 : 0.82),
                width: isFront ? 1.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: isFront ? 0.18 : 0.09),
                  blurRadius: isFront ? 14 : 10,
                  offset: Offset(0, isFront ? 5 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: LayoutBuilder(
                  builder: (context, cardConstraints) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isBackOverlap ? 0 : tiny ? 8 : compact ? 12 : 14,
                        vertical: isBackOverlap ? 5 : tiny ? 1 : compact ? 7 : 10,
                      ),
                      child: isBackOverlap
                        ? Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: baseColor.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.face_retouching_natural_rounded, color: baseColor, size: tiny ? 10 : 15),
                                  SizedBox(width: tiny ? 4 : 8),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: tiny ? 10 : 13,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F111A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!tiny && item.skincareProducts != null && item.skincareProducts!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Text(
                                      item.skincareProducts!.join('\\n'),
                                      style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        fontWeight: FontWeight.w600,
                                        color: OptivusColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
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
