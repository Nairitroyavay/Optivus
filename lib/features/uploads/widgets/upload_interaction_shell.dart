import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_bottom_sheet.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/uploads/models/upload_interaction_models.dart';
import 'package:optivus/state/upload_state.dart';

class UploadInteractionShell extends StatelessWidget {
  final UploadShellConfig config;
  final Map<String, UploadSlotRuntimeState> slotStates;
  final void Function(String slotKey, ImageSource source)? onPickSource;
  final void Function(String slotKey)? onRemove;
  final void Function(String slotKey)? onRetry;
  final void Function(String slotKey)? onDismissError;
  final Key? cardKey;

  const UploadInteractionShell({
    super.key,
    required this.config,
    required this.slotStates,
    this.onPickSource,
    this.onRemove,
    this.onRetry,
    this.onDismissError,
    this.cardKey,
  });

  bool get _isHydrating =>
      slotStates.values.any((s) => s.isHydrating);

  @override
  Widget build(BuildContext context) {
    final accent = config.accentColor;

    return Container(
      key: cardKey,
      child: OnboardingGlassCard(
        tint: accent.withValues(alpha: 0.07),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  config.isDualSlot
                      ? Icons.document_scanner_rounded
                      : Icons.add_photo_alternate_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    config.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ),
                if (config.requirementMode == UploadRequirementMode.required)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: OptivusColors.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Optional',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            if (config.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                config.subtitle!,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Slot Tiles / Hydration Skeleton
            if (_isHydrating)
              _buildHydrationSkeleton()
            else
              _buildSlotsRow(context),

            // Attempt Errors (per slot)
            for (final slot in config.slots) ...[
              if (slotStates[slot.key]?.attemptError != null) ...[
                const SizedBox(height: 8),
                _buildErrorBanner(context, slot),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHydrationSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < config.slots.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OptivusColors.brandAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotsRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 220;
        if (config.isDualSlot && isCompact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < config.slots.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _buildSlotItem(context, config.slots[i]),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < config.slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _buildSlotItem(context, config.slots[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSlotItem(BuildContext context, UploadSlotConfig slot) {
    final state = slotStates[slot.key] ??
        UploadSlotRuntimeState(
          slotKey: slot.key,
          purpose: slot.purpose,
        );

    return UploadSlotTile(
      config: slot,
      state: state,
      accentColor: config.accentColor,
      onTap: () => _handleSlotTap(context, slot.key),
      onRemove: onRemove != null ? () => onRemove!(slot.key) : null,
    );
  }

  Widget _buildErrorBanner(BuildContext context, UploadSlotConfig slot) {
    final error = slotStates[slot.key]?.attemptError;
    if (error == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: OptivusColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: OptivusColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: OptivusColors.warning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: OptivusColors.warning,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onRetry!(slot.key),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.brandAccent,
                  ),
                ),
              ),
            ),
          ],
          if (onDismissError != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onDismissError!(slot.key),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleSlotTap(BuildContext context, String slotKey) {
    final state = slotStates[slotKey];
    if (state == null || state.isBusy || state.isHydrating) return;
    final slotConfig = config.slotFor(slotKey);
    final allowCamera = slotConfig?.allowCamera ?? true;
    final allowGallery = slotConfig?.allowGallery ?? true;

    if (!allowCamera && !allowGallery) return;
    if (allowCamera && !allowGallery) {
      onPickSource?.call(slotKey, ImageSource.camera);
      return;
    }
    if (!allowCamera && allowGallery) {
      onPickSource?.call(slotKey, ImageSource.gallery);
      return;
    }

    showUploadActionSheet(
      context,
      title: state.hasDurableAsset ? 'Replace Photo' : 'Add Photo',
      allowCamera: allowCamera,
      allowGallery: allowGallery,
      onSelectCamera: () => onPickSource?.call(slotKey, ImageSource.camera),
      onSelectGallery: () => onPickSource?.call(slotKey, ImageSource.gallery),
    );
  }
}

class UploadSlotTile extends StatelessWidget {
  final UploadSlotConfig config;
  final UploadSlotRuntimeState state;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final double width;
  final double height;

  const UploadSlotTile({
    super.key,
    required this.config,
    required this.state,
    required this.accentColor,
    required this.onTap,
    this.onRemove,
    this.width = 64,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    final hasAsset = state.hasDurableAsset;
    final isBusy = state.isBusy;
    final previewPath = state.usablePreviewPath;
    final remotePreview = state.remotePreviewUri;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.label.isNotEmpty) ...[
          Text(
            config.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: OptivusColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main tile container
              GestureDetector(
                key: ValueKey('upload-slot-tile-${config.key}'),
                behavior: HitTestBehavior.opaque,
                onTap: isBusy ? null : onTap,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: hasAsset ? 0.35 : 0.18,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasAsset
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.6),
                      width: 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _buildTileContent(previewPath, remotePreview),
                  ),
                ),
              ),

              // Remove button ("X")
              if (hasAsset && !isBusy && onRemove != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: GestureDetector(
                    key: ValueKey('upload-slot-remove-${config.key}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onRemove,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTileContent(String? previewPath, Uri? remotePreview) {
    if (state.isBusy || state.phase == UploadInteractionPhase.processing) {
      return Container(
        color: Colors.white.withValues(alpha: 0.8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.phase == UploadInteractionPhase.preparing
                  ? 'Preparing'
                  : state.phase == UploadInteractionPhase.processing
                      ? 'Processing'
                      : 'Uploading',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ],
        ),
      );
    }

    if (state.hasDurableAsset) {
      if (previewPath != null) {
        return Image.file(
          File(previewPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackPreview(),
        );
      }
      if (remotePreview != null) {
        return Image.network(
          remotePreview.toString(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackPreview(),
        );
      }
      return _fallbackPreview();
    }

    // Empty state
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          config.icon,
          color: accentColor,
          size: 22,
        ),
        const SizedBox(height: 3),
        Text(
          config.placeholderPrompt ?? 'Add photo',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: OptivusColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _fallbackPreview() {
    return Container(
      color: accentColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: accentColor, size: 16),
          const SizedBox(height: 2),
          const Text(
            'Photo uploaded',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900),
          ),
          if (state.previewStatus == UploadedAssetPreviewStatus.loading)
            const Text(
              'Loading preview…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 6.5, color: OptivusColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

Future<void> showUploadActionSheet(
  BuildContext context, {
  String title = 'Choose Photo Source',
  bool allowCamera = true,
  bool allowGallery = true,
  required VoidCallback onSelectCamera,
  required VoidCallback onSelectGallery,
}) {
  return showLiquidBottomSheet(
    context,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (allowCamera)
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: OptivusColors.brandAccent,
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onSelectCamera();
                },
              ),
            if (allowGallery)
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: OptivusColors.brandAccent,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onSelectGallery();
                },
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Presentation-only hybrid composition combining an upload slot with a text field.
/// Invariant 11: Product names / text field state remains feature-owned.
class UploadImageAndNamesCard extends StatelessWidget {
  final UploadSlotConfig slotConfig;
  final UploadSlotRuntimeState slotState;
  final TextEditingController textController;
  final String title;
  final String? subtitle;
  final String? textFieldHint;
  final String? helperText;
  final int countBadgeNumber;
  final String countBadgeLabel;
  final bool textInputEnabled;
  final bool photoEnabled;
  final Color accentColor;
  final VoidCallback onTapPhoto;
  final VoidCallback? onRemovePhoto;
  final ValueChanged<String>? onTextChanged;

  const UploadImageAndNamesCard({
    super.key,
    required this.slotConfig,
    required this.slotState,
    required this.textController,
    required this.title,
    this.subtitle,
    this.textFieldHint,
    this.helperText,
    this.countBadgeNumber = 0,
    this.countBadgeLabel = 'products',
    this.textInputEnabled = true,
    this.photoEnabled = true,
    this.accentColor = OptivusColors.roseAccent,
    required this.onTapPhoto,
    this.onRemovePhoto,
    this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingGlassCard(
      tint: accentColor.withValues(alpha: 0.07),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with count badge
          Row(
            children: [
              Icon(Icons.face_retouching_natural_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                ),
              ),
              if (countBadgeNumber > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: accentColor),
                      const SizedBox(width: 3),
                      Text(
                        '$countBadgeNumber $countBadgeLabel',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Side-by-side or stacked layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo slot
              UploadSlotTile(
                config: slotConfig,
                state: slotState,
                accentColor: accentColor,
                onTap: photoEnabled ? onTapPhoto : () {},
                onRemove: photoEnabled ? onRemovePhoto : null,
                width: 68,
                height: 68,
              ),
              const SizedBox(width: 12),
              // Names text field (Feature-owned controller)
              Expanded(
                child: TextField(
                  key: const ValueKey('onboarding-step7-product-names-field'),
                  controller: textController,
                  enabled: textInputEnabled,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: onTextChanged,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: textFieldHint ?? 'Type product names here…',
                    hintStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OptivusColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(
                      alpha: textInputEnabled ? 0.35 : 0.15,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
