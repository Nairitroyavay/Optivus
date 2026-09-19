import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_section_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_action_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_selection_scaffold.dart';

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
    final isConfigured = snapshot.isConfigured;

    final hasPhoto =
        snapshot.sourceR2Key != null || snapshot.sourceAssetId != null;

    final title = isConfigured ? 'Change Classes source' : 'Set up Classes';
    final subtitle = isConfigured
        ? 'Your current setup stays active until you save a new one.'
        : 'Choose how to add your academic schedule';

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
                  title: 'Current Timetable Photo',
                  isCompactRow: true,
                  height: 68,
                ),
              ],
            )
          : null,
      children: [
        LiquidSectionHeader(
          title: hasPhoto
              ? 'USE A NEW TIMETABLE PHOTO'
              : 'USE A TIMETABLE PHOTO',
        ),
        BaseTimelineSourceActionCard(
          icon: Icons.camera_alt_rounded,
          title: 'Take a photo',
          subtitle: 'Capture a printed timetable or screen',
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
        if (hasPhoto && onEditCurrent != null)
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
    );
  }
}
