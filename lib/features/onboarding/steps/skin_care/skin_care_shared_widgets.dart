part of '../onboarding_step_7_skin_care_setup.dart';

/// Explicit horizontal inset container enforcing the canonical Step-7 24px inset contract.
///
/// Ensures full-bleed panes (such as rebuild editors when the root supplies 0px)
/// receive exactly 24px horizontal padding, while already-padded setup modes
/// do not double-pad.
class _SkinCareContainedPane extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const _SkinCareContainedPane({required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: child,
    );
  }
}

class _SkinCarePersonalizeSection extends StatelessWidget {
  final String skinType;
  final String concern;
  final String preference;
  final ValueChanged<String>? onSkinTypeChanged;
  final ValueChanged<String>? onConcernChanged;
  final ValueChanged<String>? onPreferenceChanged;

  const _SkinCarePersonalizeSection({
    required this.skinType,
    required this.concern,
    required this.preference,
    required this.onSkinTypeChanged,
    required this.onConcernChanged,
    required this.onPreferenceChanged,
  });

  String get _summary => [
    _skinCareOptionLabel(skinType),
    _skinCareOptionLabel(concern),
    _skinCareOptionLabel(preference),
  ].join(' · ');

  Future<void> _open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      enableDrag: false,
      elevation: 0,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (context) => _SkinCarePersonalizationSheet(
        skinType: skinType,
        concern: concern,
        preference: preference,
        onSkinTypeChanged: onSkinTypeChanged,
        onConcernChanged: onConcernChanged,
        onPreferenceChanged: onPreferenceChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        key: const ValueKey('onboarding-step7-personalize-tile'),
        behavior: HitTestBehavior.opaque,
        onTap: onSkinTypeChanged == null ? null : () => _open(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personalize routine',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.tune_rounded,
                color: OptivusColors.roseAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinCarePersonalizationSheet extends StatefulWidget {
  final String skinType;
  final String concern;
  final String preference;
  final ValueChanged<String>? onSkinTypeChanged;
  final ValueChanged<String>? onConcernChanged;
  final ValueChanged<String>? onPreferenceChanged;

  const _SkinCarePersonalizationSheet({
    required this.skinType,
    required this.concern,
    required this.preference,
    required this.onSkinTypeChanged,
    required this.onConcernChanged,
    required this.onPreferenceChanged,
  });

  @override
  State<_SkinCarePersonalizationSheet> createState() =>
      _SkinCarePersonalizationSheetState();
}

class _SkinCarePersonalizationSheetState
    extends State<_SkinCarePersonalizationSheet> {
  late String _skinType = widget.skinType;
  late String _concern = widget.concern;
  late String _preference = widget.preference;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('onboarding-step7-personalize-sheet'),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: OptivusColors.roseAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Personalize routine',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('onboarding-step7-personalize-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SkinCareChipGroup(
            label: 'Skin Type',
            children: [
              for (final option in _skinTypeOptions)
                _SkinCarePreferenceChip(
                  label: option.label,
                  selected: _skinType == option.key,
                  accent: OptivusColors.roseAccent,
                  onTap: widget.onSkinTypeChanged == null
                      ? null
                      : () {
                          setState(() => _skinType = option.key);
                          widget.onSkinTypeChanged!(option.key);
                        },
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SkinCareChipGroup(
            label: 'Main Concern',
            children: [
              for (final option in _skinConcernOptions)
                _SkinCarePreferenceChip(
                  label: option.label,
                  selected: _concern == option.key,
                  accent: OptivusColors.roseAccent,
                  onTap: widget.onConcernChanged == null
                      ? null
                      : () {
                          setState(() => _concern = option.key);
                          widget.onConcernChanged!(option.key);
                        },
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SkinCareChipGroup(
            label: 'Routine Style',
            children: [
              for (final option in _skinPreferenceOptions)
                _SkinCarePreferenceChip(
                  label: option.label,
                  selected: _preference == option.key,
                  accent: OptivusColors.roseAccent,
                  onTap: widget.onPreferenceChanged == null
                      ? null
                      : () {
                          setState(() => _preference = option.key);
                          widget.onPreferenceChanged!(option.key);
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const _skinTypeOptions = [
  _SkinOption('oily', 'Oily'),
  _SkinOption('dry', 'Dry'),
  _SkinOption('combination', 'Combination'),
  _SkinOption('not_sure', 'Not sure'),
];

const _skinConcernOptions = [
  _SkinOption('pimples', 'Acne'),
  _SkinOption('dark_spots', 'Spots'),
  _SkinOption('tan', 'Tan'),
  _SkinOption('dryness', 'Dryness'),
  _SkinOption('oiliness', 'Oiliness'),
  _SkinOption('none', 'None'),
];

const _skinPreferenceOptions = [
  _SkinOption('simple', 'Simple'),
  _SkinOption('balanced', 'Balanced'),
];

String _skinCareOptionLabel(String value) {
  return [
        ..._skinTypeOptions,
        ..._skinConcernOptions,
        ..._skinPreferenceOptions,
      ].where((option) => option.key == value).firstOrNull?.label ??
      value;
}

class _SkinCareProductNamesTarget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String? helperText;
  final int productCount;
  final ValueChanged<String> onChanged;

  const _SkinCareProductNamesTarget({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.helperText,
    required this.productCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final card = OnboardingGlassCard(
      key: const ValueKey('onboarding-step7-product-names-tile'),
      tint: OptivusColors.roseAccent.withValues(alpha: enabled ? 0.06 : 0.025),
      padding: const EdgeInsets.all(11),
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product names',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: enabled
                        ? OptivusColors.textPrimary
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
              if (productCount > 0)
                Semantics(
                  label: '$productCount products ready',
                  child: Row(
                    key: const ValueKey('onboarding-step7-product-count'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: OptivusColors.roseAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$productCount',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.roseAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: TextField(
              key: const ValueKey('onboarding-step7-product-names-field'),
              controller: controller,
              focusNode: focusNode,
              minLines: null,
              maxLines: null,
              expands: true,
              enabled: enabled,
              readOnly: false,
              autofocus: false,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.22,
                fontWeight: FontWeight.w700,
                color: enabled
                    ? OptivusColors.textPrimary
                    : OptivusColors.textSecondary,
              ),
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Minimalist SPF 50 - sunscreen\nVitamin C serum'
                    : helperText,
                hintStyle: const TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: OptivusColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white.withValues(
                  alpha: enabled ? 0.34 : 0.18,
                ),
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
          if (helperText != null) ...[
            const SizedBox(height: 5),
            Text(
              helperText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (enabled && focusNode != null && !focusNode!.hasFocus) {
          focusNode!.requestFocus();
        }
      },
      child: card,
    );
    return Opacity(opacity: enabled ? 1 : 0.55, child: child);
  }
}

class _SkinCareFrequencySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final Color accent;
  final bool compact;

  const _SkinCareFrequencySelector({
    required this.value,
    required this.onChanged,
    this.accent = OptivusColors.roseAccent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'How many times per day?',
      style: TextStyle(
        fontSize: compact ? 11 : 12,
        fontWeight: FontWeight.w900,
        color: OptivusColors.textPrimary,
      ),
    );
    final selector = Container(
      padding: EdgeInsets.all(compact ? 2 : 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in const [2, 3, 4])
            GestureDetector(
              key: ValueKey('onboarding-step7-frequency-$option'),
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : () => onChanged!(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: compact ? 32 : 34,
                height: compact ? 28 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == option ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$option',
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12,
                    fontWeight: FontWeight.w900,
                    color: value == option
                        ? Colors.white
                        : OptivusColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, const SizedBox(height: 8), selector],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 10),
            selector,
          ],
        );
      },
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        color: enabled
                            ? Colors.white
                            : OptivusColors.textSecondary,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : OptivusColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
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

class _SkinCarePhotoTarget extends ConsumerWidget {
  final UploadedAsset? asset;
  final String? localPreviewPath;
  final UploadedAssetPurpose purpose;
  final String title;
  final String uploadedTitle;
  final bool busy;
  final String? busyLabel;
  final bool enabled;
  final String? helperText;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _SkinCarePhotoTarget({
    required this.asset,
    this.localPreviewPath,
    this.purpose = UploadedAssetPurpose.skinProducts,
    this.title = 'Add photo',
    this.uploadedTitle = 'Photo uploaded',
    this.busy = false,
    this.busyLabel,
    this.enabled = true,
    this.helperText,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview =
        localPreviewPath ??
        (asset == null ? null : usableUploadedAssetLocalPreviewPath(asset!));
    final restoredUploads = ref.watch(restoredUploadsProvider);
    final restored =
        restoredUploads.forPurpose(purpose) ??
        (purpose == UploadedAssetPurpose.skinProducts ||
                purpose == UploadedAssetPurpose.skinFace
            ? restoredUploads.forPurpose(UploadedAssetPurpose.skinCare)
            : null);
    final remotePreview = restored?.asset.assetId == asset?.assetId
        ? restored?.previewUri
        : null;
    final previewStatus = restored?.asset.assetId == asset?.assetId
        ? restored?.previewStatus
        : UploadedAssetPreviewStatus.unavailable;
    final fileName = asset?.fileName.trim();

    return GestureDetector(
      key: const ValueKey('onboarding-step7-photo-tile'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.55,
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: preview != null
                      ? Image.file(
                          File(preview),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _fallback(previewStatus, fileName),
                        )
                      : remotePreview != null
                      ? Image.network(
                          remotePreview.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _fallback(
                            UploadedAssetPreviewStatus.unavailable,
                            fileName,
                          ),
                        )
                      : _fallback(previewStatus, fileName),
                ),
              ),
              if (busy)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.38),
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
                    key: const ValueKey('onboarding-step7-remove-photo-button'),
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
      ),
    );
  }

  Widget _fallback(
    UploadedAssetPreviewStatus? previewStatus,
    String? fileName,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          asset == null
              ? Icons.add_photo_alternate_rounded
              : Icons.check_circle_rounded,
          color: enabled
              ? OptivusColors.roseAccent
              : OptivusColors.textSecondary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          asset == null ? title : uploadedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: enabled
                ? OptivusColors.textPrimary
                : OptivusColors.textSecondary,
          ),
        ),
        if (asset != null) ...[
          if (fileName != null && fileName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              fileName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            previewStatus == UploadedAssetPreviewStatus.loading
                ? 'Loading preview…'
                : 'Preview unavailable',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: OptivusColors.textSecondary,
            ),
          ),
        ] else if (helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              helperText!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkinCareInlineMessage extends StatelessWidget {
  final String message;
  final bool compact;

  const _SkinCareInlineMessage({required this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 10,
      ),
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
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: compact ? 10 : 11.5,
                height: compact ? 1.2 : null,
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

IconData _skinCareSelectedProductIcon(String category) {
  return switch (category) {
    'cleanser' => Icons.face_retouching_natural_rounded,
    'moisturizer' => Icons.water_drop_rounded,
    'sunscreen' => Icons.wb_sunny_rounded,
    'vitamin_c_serum' => Icons.brightness_7_rounded,
    'treatment_serum' => Icons.science_rounded,
    _ => Icons.spa_rounded,
  };
}

void _showSkinCareSelectedProductsSheet(
  BuildContext context, {
  required List<String> products,
  required List<SkinCareProductRecommendationDraft> recommendations,
  required Color accent,
}) {
  final recommendationsByKey = {
    for (final product in recommendations) product.selectionKey: product,
  };
  final initialSize = math.min(0.78, 0.34 + (products.length * 0.075));

  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.24),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: 0.38,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: OptivusColors.textSecondary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected products',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: OptivusColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Products used to build your routine',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: OptivusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey(
                      'onboarding-step7-selected-products-close',
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: OptivusColors.textSecondary,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: OptivusColors.textSecondary.withValues(alpha: 0.1),
            ),
            Expanded(
              child: ListView.separated(
                key: const ValueKey('onboarding-step7-selected-products-list'),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final productName = products[index];
                  final recommendation =
                      recommendationsByKey[normalizeSkinCareSelectionKey(
                        productName,
                      )];
                  final category = recommendation == null
                      ? ''
                      : onboarding7RecommendationCategory(recommendation);
                  final details = [
                    if (category.isNotEmpty)
                      _onboarding7ProductCategoryLabel(category),
                    if (recommendation?.estimatedPrice.isNotEmpty ?? false)
                      formatSkinCarePriceDisplay(
                        recommendation!.currencyCode,
                        recommendation.estimatedPrice,
                      ),
                  ].where((part) => part.isNotEmpty).join(' • ');

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _skinCareSelectedProductIcon(category),
                            color: accent,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  details,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_rounded,
                          color: accent,
                          size: 19,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showSkinCareSpecialCareNotesSheet(
  BuildContext context,
  List<String> notes,
  Color accent,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Special-care notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final note in notes) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              note,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: OptivusColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SkinCareChipGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool compact;

  const _SkinCareChipGroup({
    required this.label,
    required this.children,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10.5 : 11,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textSecondary,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Wrap(
          spacing: compact ? 6 : 8,
          runSpacing: compact ? 5 : 8,
          children: children,
        ),
      ],
    );
  }
}

class _SkinCarePreferenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;
  final bool compact;

  const _SkinCarePreferenceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 8,
        ),
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
            fontSize: compact ? 11.5 : 12,
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
