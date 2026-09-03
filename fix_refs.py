import re

path = 'lib/services/onboarding_completion_service.dart'
with open(path, 'r') as f:
    content = f.read()

# Replace product photo condition
content = content.replace(
    'if (base.skinCareProductPhotoAssetId?.trim().isNotEmpty == true ||\n        base.skinCareProductPhotoR2Key?.trim().isNotEmpty == true ||\n        base.skinCareProductPhotoStatus?.trim().isNotEmpty == true) {',
    'if (base.skinCareSetupPath == "has_products" && (base.skinCareProductPhotoAssetId?.trim().isNotEmpty == true || base.skinCareProductPhotoR2Key?.trim().isNotEmpty == true || base.skinCareProductPhotoStatus?.trim().isNotEmpty == true)) {'
)

# Replace face photo condition
content = content.replace(
    'if (base.skinCareFacePhotoAssetId?.trim().isNotEmpty == true ||\n        base.skinCareFacePhotoR2Key?.trim().isNotEmpty == true ||\n        base.skinCareFacePhotoStatus?.trim().isNotEmpty == true) {',
    'if (base.skinCareSetupPath == "no_products" && (base.skinCareFacePhotoAssetId?.trim().isNotEmpty == true || base.skinCareFacePhotoR2Key?.trim().isNotEmpty == true || base.skinCareFacePhotoStatus?.trim().isNotEmpty == true)) {'
)

with open(path, 'w') as f:
    f.write(content)
