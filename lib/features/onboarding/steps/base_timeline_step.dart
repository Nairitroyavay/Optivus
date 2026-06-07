import 'package:optivus/models/uploaded_asset.dart';

UploadedAssetPurpose? onboardingUploadPurposeForBaseTimelineSection(
  String section,
) {
  return switch (section) {
    'Classes' => UploadedAssetPurpose.classTimetable,
    'Job / Work / Business' => UploadedAssetPurpose.workSchedule,
    'Eating' => UploadedAssetPurpose.eatingMenu,
    'Skin Care' => UploadedAssetPurpose.skinCare,
    _ => null,
  };
}
