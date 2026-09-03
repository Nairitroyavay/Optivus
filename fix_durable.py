import re

path = 'lib/features/onboarding/steps/onboarding_step_7_skin_care_setup.dart'
with open(path, 'r') as f:
    content = f.read()

# durableSkinProductsAssetFromDraft
content = re.sub(
    r'(UploadedAsset\? durableSkinProductsAssetFromDraft\(OnboardingDraft draft\) {\n  final base = draft\.baseTimeline;\n)',
    r'\1  if (base.skinCareSetupPath != "has_products") return null;\n',
    content
)

# durableSkinFaceAssetFromDraft
content = re.sub(
    r'(UploadedAsset\? durableSkinFaceAssetFromDraft\(OnboardingDraft draft\) {\n  final base = draft\.baseTimeline;\n)',
    r'\1  if (base.skinCareSetupPath != "no_products") return null;\n',
    content
)

with open(path, 'w') as f:
    f.write(content)
