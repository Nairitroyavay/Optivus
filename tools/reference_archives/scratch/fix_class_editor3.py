import re

filepath = 'lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Replace the photo import UI logic to just be empty blocks or remove the import completely
# Wait, let's just delete the `_showPhotoImportBottomSheet` method and everything related
content = re.sub(r"void _showPhotoImportBottomSheet\(\).*?(?=  Widget build\(BuildContext context\))", "", content, flags=re.DOTALL)

# Delete `_acceptPendingImport` 
content = re.sub(r"Future<void> _acceptPendingImport\(.*?\) async \{.*?\}", "", content, flags=re.DOTALL)

# Let's delete the `_importPhoto` and `_parseText` methods entirely, we replaced them with placeholders earlier, but maybe there's still some photo picker stuff?
# Look for `_buildActionChips` and remove the AI/Photo buttons
action_chips_replacement = """
  Widget _buildActionChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('Manual add', Icons.edit_calendar_rounded, _setupMode == 'Manual', () {
            setState(() => _setupMode = 'Manual');
          }),
        ],
      ),
    );
  }
"""
content = re.sub(r"Widget _buildActionChips\(\) \{.*?(?=  Widget _buildReviewButton)", action_chips_replacement, content, flags=re.DOTALL)

# Replace the build method's usage of _pendingImportMetadata and other things
content = re.sub(r"if \(_setupMode == 'Photo Upload'\).*?(?=  Expanded\()", "", content, flags=re.DOTALL)
content = re.sub(r"if \(_setupMode == 'AI Text'\).*?(?=  Expanded\()", "", content, flags=re.DOTALL)

# There might be some other backend stuff in `_buildReviewButton`. Let's replace `_buildReviewButton`
review_btn_replacement = """
  Widget _buildReviewButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: LiquidButton(
            text: 'Save & Return',
            onTap: () {
              _save(ref).then((success) {
                if (success && mounted) {
                  widget.onComplete();
                }
              });
            },
          ),
        ),
      ),
    );
  }
"""
content = re.sub(r"Widget _buildReviewButton\(\) \{.*?(?=  @override\n  Widget build)", review_btn_replacement, content, flags=re.DOTALL)


with open(filepath, 'w') as f:
    f.write(content)
