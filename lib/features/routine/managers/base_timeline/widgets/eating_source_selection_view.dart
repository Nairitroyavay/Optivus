import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_action_card.dart';

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
  final VoidCallback onBuildPersonalized;
  final VoidCallback onImportPhoto;
  final VoidCallback onCreateManually;
  final String? errorMessage;
  final VoidCallback? onClearError;

  const EatingSourceSelectionView({
    super.key,
    required this.onBuildPersonalized,
    required this.onImportPhoto,
    required this.onCreateManually,
    this.errorMessage,
    this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null) ...[
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
          ],
          // Option 1: Build Balanced Plan
          BaseTimelineSourceActionCard(
            title: 'Build Balanced Plan',
            subtitle:
                'Generate a balanced weekly plan matched to your body goals, preferences, and meal schedule.',
            icon: Icons.auto_awesome_rounded,
            badgeText: 'RECOMMENDED',
            accent: OptivusColors.roseAccent,
            onTap: onBuildPersonalized,
          ),
          const SizedBox(height: 14),

          // Option 2: Import from Photo
          BaseTimelineSourceActionCard(
            title: 'Import from Photo',
            subtitle:
                'Take or upload a photo of your existing diet chart, meal prep list, or menu.',
            icon: Icons.photo_camera_rounded,
            badgeText: 'SCAN PHOTO',
            accent: OptivusColors.blueAccent,
            onTap: onImportPhoto,
          ),
          const SizedBox(height: 14),

          // Option 3: Create Manually
          BaseTimelineSourceActionCard(
            title: 'Create Manually',
            subtitle:
                'Add and customize your own meals, dishes, and timings without AI generation.',
            icon: Icons.edit_calendar_rounded,
            badgeText: 'MANUAL',
            accent: OptivusColors.textSecondary,
            onTap: onCreateManually,
          ),
        ],
      ),
    );
  }
}
