import sys

file_path = '/Users/roy/optivus2/Optivus/lib/features/home/widgets/home_glass_widgets.dart'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace('Color(0xFFF36F78)', 'const Color(0xFFF36F78)')

with open(file_path, 'w') as f:
    f.write(content)

file_path2 = '/Users/roy/optivus2/Optivus/lib/features/home/widgets/now_next_action_card.dart'
with open(file_path2, 'r') as f:
    content2 = f.read()

content2 = content2.replace('    const btnColor = Color(0xFFE2B814);\n', '')
content2 = content2.replace('    const btnTextColor = Color(0xFF534304);\n', '')

with open(file_path2, 'w') as f:
    f.write(content2)
