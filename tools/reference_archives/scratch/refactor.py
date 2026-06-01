import sys
import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/home/widgets/home_glass_widgets.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Replace the tint fallback color
content = content.replace(
    'Colors.white.withValues(alpha: selected ? 0.15 : 0.05)',
    'const Color(0xFFFFF1F1).withValues(alpha: selected ? 0.35 : 0.15)'
)

# And in OnboardingActionPill/HomeActionPill
content = content.replace(
    'Colors.white.withValues(alpha: 0.1)',
    'const Color(0xFFFFF1F1).withValues(alpha: 0.15)'
)
content = content.replace(
    'Colors.white.withValues(alpha: 0.4)',
    'const Color(0xFFFFF1F1).withValues(alpha: 0.4)'
)

with open(file_path, 'w') as f:
    f.write(content)
