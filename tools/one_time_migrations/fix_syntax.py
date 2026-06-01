import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'
with open(file_path, 'r') as f:
    content = f.read()

bad_container = """          child: Container(
            width: 10,
            height: 1.5,
            color: Colors.black.withValues(alpha: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                offset: const Offset(0, 1),
              ),
            ],
          ),"""

good_container = """          child: Container(
            width: 10,
            height: 1.5,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),"""

content = content.replace(bad_container, good_container)

with open(file_path, 'w') as f:
    f.write(content)
print('Done syntax fix!')
