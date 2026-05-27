import re
import os

filepath = 'lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Remove anything related to ImageUploadService, runRoutineAcceptWithTimeout, firestoreServiceProvider
# Replace the whole _showRoutineReviewDialog with a simple save and pop

replacement_review = """
  void _showRoutineReviewDialog() {
    _save(ref).then((success) {
      if (success && mounted) {
        widget.onComplete();
      }
    });
  }
"""

content = re.sub(r"void _showRoutineReviewDialog\(\) \{.*?(?=  Widget _buildDroplet)", replacement_review, content, flags=re.DOTALL)

with open(filepath, 'w') as f:
    f.write(content)

print("Class Editor Fixed Part 2!")
