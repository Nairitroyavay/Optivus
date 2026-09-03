import re

path = 'lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart'
with open(path, 'r') as f:
    content = f.read()

# durableSkinFaceAssetFromDraft
content = re.sub(
    r'final assetId = base\.skinCareFacePhotoAssetId\?\.trim\(\) \?\? '"''"';\n  final r2Key = base\.skinCareFacePhotoR2Key\?\.trim\(\) \?\? '"''"';\n  final status = base\.skinCareFacePhotoStatus;\n  final createdAt = base\.skinCareFacePhotoCreatedAt \?\? DateTime\.fromMillisecondsSinceEpoch\(0\);\n  final updatedAt = base\.skinCareFacePhotoUpdatedAt \?\? createdAt;',
    r'var assetId = base.skinCareFacePhotoAssetId?.trim() ?? "";\n  var r2Key = base.skinCareFacePhotoR2Key?.trim() ?? "";\n  var status = base.skinCareFacePhotoStatus;\n  var createdAt = base.skinCareFacePhotoCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);\n  var updatedAt = base.skinCareFacePhotoUpdatedAt ?? createdAt;\n\n  // Legacy migration for draft: if face photo is empty but product photo has data, use product photo\n  if (assetId.isEmpty && (base.skinCareProductPhotoAssetId?.trim() ?? "").isNotEmpty) {\n    assetId = base.skinCareProductPhotoAssetId!.trim();\n    r2Key = base.skinCareProductPhotoR2Key?.trim() ?? "";\n    status = base.skinCareProductPhotoStatus;\n    createdAt = base.skinCareProductPhotoCreatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);\n    updatedAt = base.skinCareProductPhotoUpdatedAt ?? createdAt;\n  }',
    content
)

with open(path, 'w') as f:
    f.write(content)
