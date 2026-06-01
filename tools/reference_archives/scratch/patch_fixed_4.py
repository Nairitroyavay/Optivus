import re
import os

files = [
    'lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart',
    'lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart'
]

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Remove all DUMMY_DEFS sections
    content = re.sub(r"// --- DUMMY DEFS FOR PORTING ---.*?// ------------------------------", "", content, flags=re.DOTALL)
    
    # Prepend import
    content = "import 'package:optivus/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart';\n" + content
    
    with open(filepath, 'w') as f:
        f.write(content)

