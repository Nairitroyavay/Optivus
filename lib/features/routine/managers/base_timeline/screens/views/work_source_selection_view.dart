import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/core/widgets/liquid_section_header.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';

/// Source selection stage for Work / Business Base Timeline setup.
class WorkSourceSelectionView extends StatelessWidget {
  final BaseTimelineSetup setup;
  final VoidCallback onCancel;
  final void Function(ImageSource source) onPickPhoto;
  final VoidCallback onManualSetup;
  final VoidCallback? onEditCurrent;
  final VoidCallback? onRemoveSetup;

  const WorkSourceSelectionView({
    super.key,
    required this.setup,
    required this.onCancel,
    required this.onPickPhoto,
    required this.onManualSetup,
    this.onEditCurrent,
    this.onRemoveSetup,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.work);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: OptivusColors.textPrimary,
                  ),
                  onPressed: onCancel,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OptivusRadii.md),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Work Schedule',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your current setup stays active until you save a new one.',
                        style: TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemoveSetup != null && snapshot.isConfigured)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: OptivusColors.textSecondary,
                    ),
                    color: OptivusColors.backgroundBottom,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: OptivusColors.borderStandard,
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'remove') {
                        onRemoveSetup!();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: OptivusColors.danger,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Remove setup',
                              style: TextStyle(
                                color: OptivusColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot.sourceR2Key != null ||
                      snapshot.sourceAssetId != null) ...[
                    const LiquidSectionHeader(title: 'CURRENT PHOTO'),
                    BaseTimelinePhotoPreviewCard(
                      r2Key: snapshot.sourceR2Key,
                      assetId: snapshot.sourceAssetId,
                      title: 'Current Work Schedule Photo',
                      isCompactRow: true,
                      height: 68,
                    ),
                    const SizedBox(height: 16),
                  ],
                  LiquidSectionHeader(
                    title:
                        (snapshot.sourceR2Key != null ||
                            snapshot.sourceAssetId != null)
                        ? 'USE A NEW PHOTO'
                        : 'USE A SCHEDULE PHOTO',
                  ),
                  _buildSourceActionCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Take a Photo',
                    subtitle: 'Capture a printed schedule, contract, or screen',
                    accent: OptivusColors.warning,
                    onTap: () => onPickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _buildSourceActionCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Choose from Gallery',
                    subtitle: 'Upload a photo or screenshot from your device',
                    accent: OptivusColors.aquaAccent,
                    onTap: () => onPickPhoto(ImageSource.gallery),
                  ),
                  const SizedBox(height: 16),
                  const LiquidSectionHeader(title: 'OR SET UP MANUALLY'),
                  if (snapshot.isConfigured || setup.workBlocks.isNotEmpty)
                    _buildSourceActionCard(
                      icon: Icons.edit_calendar_rounded,
                      title: 'Edit current work schedule',
                      subtitle:
                          (snapshot.sourceR2Key != null ||
                              snapshot.sourceAssetId != null)
                          ? 'Keep schedule photo and adjust blocks'
                          : 'Keep your current blocks and adjust them manually',
                      accent: OptivusColors.routineAccent,
                      onTap: onEditCurrent ?? onManualSetup,
                    )
                  else
                    _buildSourceActionCard(
                      icon: Icons.edit_calendar_rounded,
                      title: 'Set up manually',
                      subtitle: 'Add your work blocks day by day',
                      accent: OptivusColors.routineAccent,
                      onTap: onManualSetup,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return OnboardingGlassCard(
      radius: OptivusRadii.cardStandard,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OptivusRadii.cardStandard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      OptivusRadii.controlCompact,
                    ),
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: OptivusColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
