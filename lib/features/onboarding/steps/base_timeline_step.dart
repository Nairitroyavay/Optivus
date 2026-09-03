import 'package:optivus/models/uploaded_asset.dart';

UploadedAssetPurpose? onboardingUploadPurposeForBaseTimelineSection(
  String section,
) {
  return switch (section) {
    'Classes' => UploadedAssetPurpose.classTimetable,
    'Job / Work / Business' => UploadedAssetPurpose.workSchedule,
    'Eating' => UploadedAssetPurpose.eatingMenu,
    // 'Skin Care' is explicitly handled in step 7 and uses multiple purposes (skin_face/skin_products)
    'Skin Care' => null,
    _ => null,
  };
}
