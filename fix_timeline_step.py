import re

path = 'lib/features/onboarding/steps/base_timeline_step.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    "    'Skin Care' => UploadedAssetPurpose.skinCare,",
    "    // 'Skin Care' is explicitly handled in step 7 and uses multiple purposes (skin_face/skin_products)\n    'Skin Care' => null,"
)

with open(path, 'w') as f:
    f.write(content)
