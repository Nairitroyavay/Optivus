import os
import glob

directory = '/Users/roy/optivus2/Optivus/lib/features/home/widgets/'
pattern = os.path.join(directory, '*.dart')

for filepath in glob.glob(pattern):
    with open(filepath, 'r') as file:
        content = file.read()
    
    new_content = content.replace(
        'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart',
        'home_glass_widgets.dart'
    )
    new_content = new_content.replace('OnboardingGlassCard', 'HomeGlassCard')
    new_content = new_content.replace('OnboardingActionPill', 'HomeActionPill')
    new_content = new_content.replace('OnboardingIconPill', 'HomeIconPill')
    
    if new_content != content:
        with open(filepath, 'w') as file:
            file.write(new_content)
