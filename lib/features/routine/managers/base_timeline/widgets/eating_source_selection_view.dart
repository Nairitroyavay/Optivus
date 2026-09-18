import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Clean source selection view presented when Eating schedule is unconfigured.
///
/// Provides three explicit setup paths:
/// 1. Build personalized plan (AI generation)
/// 2. Import meal plan photo (OCR / photo extraction)
/// 3. Create manually (manual plan starting with custom meals)
class EatingSourceSelectionView extends StatelessWidget {
  final VoidCallback onBuildPersonalized;
  final VoidCallback onImportPhoto;
  final VoidCallback onCreateManually;

  const EatingSourceSelectionView({
    super.key,
    required this.onBuildPersonalized,
    required this.onImportPhoto,
    required this.onCreateManually,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Option 1: Build Balanced Plan
          _buildOptionCard(
            context: context,
            title: 'Build Balanced Plan',
            subtitle:
                'Generate a balanced weekly plan matched to your body goals, preferences, and meal schedule.',
            icon: Icons.auto_awesome_rounded,
            badge: 'RECOMMENDED',
            accent: OptivusColors.roseAccent,
            onTap: onBuildPersonalized,
          ),
          const SizedBox(height: 14),

          // Option 2: Import from Photo
          _buildOptionCard(
            context: context,
            title: 'Scan Photo',
            subtitle:
                'Take or upload a photo of your existing diet chart, meal prep list, or menu.',
            icon: Icons.photo_camera_rounded,
            badge: 'SCAN PHOTO',
            accent: OptivusColors.blueAccent,
            onTap: onImportPhoto,
          ),
          const SizedBox(height: 14),

          // Option 3: Create Manually
          _buildOptionCard(
            context: context,
            title: 'Create Manually',
            subtitle:
                'Add and customize your own meals, dishes, and timings without AI generation.',
            icon: Icons.edit_calendar_rounded,
            badge: 'MANUAL',
            accent: OptivusColors.textSecondary,
            onTap: onCreateManually,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: OptivusColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: OptivusColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: OptivusColors.textSecondary.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
