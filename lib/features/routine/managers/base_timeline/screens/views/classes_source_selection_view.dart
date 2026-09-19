import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_radii.dart';
import 'package:optivus/core/widgets/liquid_section_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_action_card.dart';

/// Source selection stage for Classes Base Timeline setup.
class ClassesSourceSelectionView extends StatelessWidget {
  final BaseTimelineSetup setup;
  final VoidCallback onCancel;
  final void Function(ImageSource source) onPickPhoto;
  final VoidCallback onManualSetup;
  final VoidCallback? onEditCurrent;
  final VoidCallback? onRemoveSetup;

  const ClassesSourceSelectionView({
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
    final snapshot = setup.snapshotFor(BaseTimelineSection.classes);

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
                        'Update Timetable',
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
                      title: 'Current Timetable Photo',
                      isCompactRow: true,
                      height: 68,
                    ),
                    const SizedBox(height: 16),
                  ],
                  LiquidSectionHeader(
                    title:
                        (snapshot.sourceR2Key != null ||
                            snapshot.sourceAssetId != null)
                        ? 'USE A NEW TIMETABLE PHOTO'
                        : 'USE A TIMETABLE PHOTO',
                  ),
                  BaseTimelineSourceActionCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Take a Photo',
                    subtitle: 'Capture a printed timetable or screen',
                    accent: OptivusColors.blueAccent,
                    onTap: () => onPickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  BaseTimelineSourceActionCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Choose from Gallery',
                    subtitle: 'Upload a photo or screenshot from your device',
                    accent: OptivusColors.aquaAccent,
                    onTap: () => onPickPhoto(ImageSource.gallery),
                  ),
                  const SizedBox(height: 16),
                  const LiquidSectionHeader(title: 'OR SET UP MANUALLY'),
                  if ((snapshot.sourceR2Key != null ||
                          snapshot.sourceAssetId != null) &&
                      onEditCurrent != null)
                    BaseTimelineSourceActionCard(
                      icon: Icons.edit_calendar_rounded,
                      title: 'Edit current timetable',
                      subtitle: 'Keep timetable photo and adjust classes',
                      accent: OptivusColors.routineAccent,
                      onTap: onEditCurrent!,
                    )
                  else
                    BaseTimelineSourceActionCard(
                      icon: Icons.edit_calendar_rounded,
                      title: 'Set up manually',
                      subtitle: 'Add or adjust classes day by day',
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
}
