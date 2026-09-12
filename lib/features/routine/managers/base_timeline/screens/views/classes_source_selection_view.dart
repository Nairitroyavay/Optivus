import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_section.dart';
import 'package:optivus/features/routine/managers/base_timeline/models/base_timeline_setup.dart';
import 'package:optivus/features/routine/managers/base_timeline/widgets/base_timeline_photo_preview_card.dart';

/// Source selection stage for Classes Base Timeline setup.
class ClassesSourceSelectionView extends StatelessWidget {
  final BaseTimelineSetup setup;
  final VoidCallback onCancel;
  final void Function(ImageSource source) onPickPhoto;
  final VoidCallback onManualSetup;

  const ClassesSourceSelectionView({
    super.key,
    required this.setup,
    required this.onCancel,
    required this.onPickPhoto,
    required this.onManualSetup,
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
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
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
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (snapshot.sourceR2Key != null) ...[
                  const Text(
                    'CURRENT PHOTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OptivusColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  BaseTimelinePhotoPreviewCard(
                    r2Key: snapshot.sourceR2Key,
                    assetId: snapshot.sourceAssetId,
                    title: 'Current Timetable Photo',
                    height: 120,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  snapshot.sourceR2Key != null
                      ? 'USE A NEW TIMETABLE PHOTO'
                      : 'USE A TIMETABLE PHOTO',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSourceActionCard(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take a Photo',
                  subtitle: 'Capture a printed timetable or screen',
                  accent: OptivusColors.blueAccent,
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
                const Text(
                  'OR SET UP MANUALLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSourceActionCard(
                  icon: Icons.edit_calendar_rounded,
                  title: 'Set up manually',
                  subtitle: 'Add or adjust classes day by day',
                  accent: OptivusColors.routineAccent,
                  onTap: onManualSetup,
                ),
              ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: accent.withValues(alpha: 0.15),
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
    );
  }
}
