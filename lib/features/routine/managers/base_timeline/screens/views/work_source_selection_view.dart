import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_section_header.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/services/work_presentation_utils.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_action_card.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_source_selection_scaffold.dart';

/// Source selection stage for Work / Business Base Timeline setup.
class WorkSourceSelectionView extends StatelessWidget {
  final BaseTimelineSetup setup;
  final VoidCallback onCancel;
  final void Function(ImageSource source) onPickPhoto;
  final VoidCallback onManualSetup;
  final VoidCallback? onEditCurrent;
  final VoidCallback? onRemoveSetup;
  final String? lifeRole;
  final String? businessMode;

  const WorkSourceSelectionView({
    super.key,
    required this.setup,
    required this.onCancel,
    required this.onPickPhoto,
    required this.onManualSetup,
    this.onEditCurrent,
    this.onRemoveSetup,
    this.lifeRole,
    this.businessMode,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = setup.snapshotFor(BaseTimelineSection.work);
    final isConfigured = snapshot.isConfigured;
    final viewTitle = WorkPresentationUtils.sourceSelectionTitle(lifeRole);
    final viewSubtitle = WorkPresentationUtils.sourceSelectionSubtitle(
      lifeRole,
      isConfigured: isConfigured,
    );
    final hasPhoto =
        snapshot.sourceR2Key != null || snapshot.sourceAssetId != null;

    return BaseTimelineSourceSelectionScaffold(
      title: viewTitle,
      subtitle: viewSubtitle,
      onBack: onCancel,
      preservationNotice:
          isConfigured ? WorkPresentationUtils.sourceDraftNotice(lifeRole) : null,
      onRemoveSetup: isConfigured ? onRemoveSetup : null,
      removeLabel: WorkPresentationUtils.removeSetupLabel(lifeRole),
      currentSourcePreview: hasPhoto
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const LiquidSectionHeader(title: 'CURRENT PHOTO'),
                BaseTimelinePhotoPreviewCard(
                  r2Key: snapshot.sourceR2Key,
                  assetId: snapshot.sourceAssetId,
                  title: WorkPresentationUtils.photoCardTitle(lifeRole),
                  isCompactRow: true,
                  height: 68,
                ),
              ],
            )
          : null,
      children: [
        LiquidSectionHeader(
          title: hasPhoto ? 'USE A NEW PHOTO' : 'USE A SCHEDULE PHOTO',
        ),
        BaseTimelineSourceActionCard(
          icon: Icons.camera_alt_rounded,
          title: 'Take a Photo',
          subtitle: WorkPresentationUtils.sourceCameraSubtitle(lifeRole),
          accent: OptivusColors.warning,
          onTap: () => onPickPhoto(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        BaseTimelineSourceActionCard(
          icon: Icons.photo_library_rounded,
          title: 'Choose from Gallery',
          subtitle: 'Upload a photo or screenshot from your device',
          accent: OptivusColors.warning,
          onTap: () => onPickPhoto(ImageSource.gallery),
        ),
        const SizedBox(height: 16),
        const LiquidSectionHeader(title: 'OR SET UP MANUALLY'),
        if (isConfigured || setup.workBlocks.isNotEmpty)
          BaseTimelineSourceActionCard(
            icon: Icons.edit_calendar_rounded,
            title: WorkPresentationUtils.sourceEditCurrentTitle(lifeRole),
            subtitle: WorkPresentationUtils.sourceEditCurrentSubtitle(
              hasSourcePhoto: hasPhoto,
              lifeRole: lifeRole,
            ),
            accent: OptivusColors.warning,
            onTap: onEditCurrent ?? onManualSetup,
          )
        else
          BaseTimelineSourceActionCard(
            icon: Icons.edit_calendar_rounded,
            title: WorkPresentationUtils.sourceManualTitle(lifeRole),
            subtitle: WorkPresentationUtils.sourceManualSubtitle(
              lifeRole: lifeRole,
              businessMode: businessMode,
            ),
            accent: OptivusColors.warning,
            onTap: onManualSetup,
          ),
      ],
    );
  }
}
