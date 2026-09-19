import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_section_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_action_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_selection_scaffold.dart';

/// Clean source selection view presented when Eating schedule is unconfigured or changing source.
///
/// Uses canonical [BaseTimelineSourceActionCard] for visual consistency across
/// Classes, Work, and Eating.
///
/// Provides three explicit setup paths:
/// 1. Build Balanced Plan (AI generation)
/// 2. Scan Photo (OCR / photo extraction)
/// 3. Create Manually (manual plan starting with custom meals)
class EatingSourceSelectionView extends StatelessWidget {
  final BaseTimelineSetup setup;
  final VoidCallback onCancel;
  final VoidCallback onBuildPersonalized;
  final void Function(ImageSource source) onPickPhoto;
  final VoidCallback onCreateManually;
  final VoidCallback? onEditCurrent;
  final VoidCallback? onRemoveSetup;
  final String? errorMessage;
  final VoidCallback? onClearError;

  const EatingSourceSelectionView({
    super.key,
    required this.setup,
    required this.onCancel,
    required this.onBuildPersonalized,
    required this.onPickPhoto,
    required this.onCreateManually,
    this.onEditCurrent,
    this.onRemoveSetup,
    this.errorMessage,
    this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.eating);
    final isConfigured = snapshot.isConfigured;
    final hasPhoto =
        snapshot.sourceR2Key != null || snapshot.sourceAssetId != null;

    final title = isConfigured ? 'Change Eating source' : 'Set up Eating';
    final subtitle = isConfigured
        ? 'Your current setup stays active until you save a new one.'
        : 'Choose how to create your meal plan.';

    return BaseTimelineSourceSelectionScaffold(
      title: title,
      subtitle: subtitle,
      onBack: onCancel,
      preservationNotice: isConfigured
          ? 'Your current setup stays active until you save a new one.'
          : null,
      onRemoveSetup: isConfigured ? onRemoveSetup : null,
      removeLabel: 'Remove setup',
      currentSourcePreview: hasPhoto
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const LiquidSectionHeader(title: 'CURRENT PHOTO'),
                BaseTimelinePhotoPreviewCard(
                  r2Key: snapshot.sourceR2Key,
                  assetId: snapshot.sourceAssetId,
                  title: 'Current Meal Plan Photo',
                  isCompactRow: true,
                  height: 68,
                ),
              ],
            )
          : null,
      children: [
        if (errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: OptivusColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: OptivusColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: OptivusColors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: OptivusColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (onClearError != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: OptivusColors.textSecondary,
                    ),
                    onPressed: onClearError,
                  ),
              ],
            ),
          ),

        const LiquidSectionHeader(title: 'RECOMMENDED'),
        // Option 1: Build Balanced Plan
        BaseTimelineSourceActionCard(
          title: 'Build personalized plan',
          subtitle:
              'Generate a balanced weekly plan matched to your body goals, preferences, and meal schedule.',
          icon: Icons.auto_awesome_rounded,
          badgeText: 'RECOMMENDED',
          accent: OptivusColors.roseAccent,
          onTap: onBuildPersonalized,
        ),
        const SizedBox(height: 16),

        const LiquidSectionHeader(title: 'OR USE EXISTING'),
        BaseTimelineSourceActionCard(
          icon: Icons.camera_alt_rounded,
          title: 'Take a photo',
          subtitle: 'Capture a printed diet chart or menu',
          accent: OptivusColors.blueAccent,
          onTap: () => onPickPhoto(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        BaseTimelineSourceActionCard(
          icon: Icons.photo_library_rounded,
          title: 'Choose from gallery',
          subtitle: 'Upload a photo or screenshot from your device',
          accent: OptivusColors.aquaAccent,
          onTap: () => onPickPhoto(ImageSource.gallery),
        ),
        const SizedBox(height: 16),

        const LiquidSectionHeader(title: 'OR SET UP MANUALLY'),
        // Option 3: Create Manually
        if (hasPhoto && onEditCurrent != null)
          BaseTimelineSourceActionCard(
            title: 'Edit current meal plan',
            subtitle: 'Keep photo and adjust meals',
            icon: Icons.edit_calendar_rounded,
            badgeText: 'MANUAL',
            accent: OptivusColors.routineAccent,
            onTap: onEditCurrent!,
          )
        else
          BaseTimelineSourceActionCard(
            title: 'Create manually',
            subtitle:
                'Add and customize your own meals, dishes, and timings without AI generation.',
            icon: Icons.edit_calendar_rounded,
            badgeText: 'MANUAL',
            accent: OptivusColors.routineAccent,
            onTap: onCreateManually,
          ),
      ],
    );
  }
}
