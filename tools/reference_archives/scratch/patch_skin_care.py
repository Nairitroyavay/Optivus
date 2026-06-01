filepath = 'lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Fix the missing RoutineState dummy
content = content.replace("final routineProvider = StateProvider<dynamic>((ref) => null);", "final routineProvider = StateProvider<RoutineState>((ref) => RoutineState());\nclass RoutineState { final routineTemplates = const {}; final fixedScheduleTemplates = const []; dynamic classesForDay(int day) => []; }")

# Re-add dummy variables/methods that we mistakenly deleted
dummy_ui_methods = """
  void _generateTextSkinCareReview() {}
  void _pickSkinCarePhoto() {}
  String _photoUploadLabel(dynamic metadata) => '';
  void _removeSkinCarePhoto() {}
  void _generatePhotoSkinCareReview() {}
  bool _isUploadingPhoto = false;
  bool _isGenerating = false;
  String? _generationError;
  Map<String, dynamic>? _photoImportMetadata;
"""
content = content.replace("class _SkinCareSetupScreenState extends ConsumerState<SkinCareSetupScreen> {", "class _SkinCareSetupScreenState extends ConsumerState<SkinCareSetupScreen> {\n" + dummy_ui_methods)

# Restore the deleted `_buildColoredBlock` and `_buildAddButton`
import os
os.system("cp reference_copied_old_frontend/onboarding_base_timeline/skin_care/skin_care_setup_screen.dart scratch/temp_skin.dart")
with open("scratch/temp_skin.dart", "r") as tmp:
    ref_content = tmp.read()

build_colored = ref_content[ref_content.find("Widget _buildColoredBlock("):ref_content.find("Widget _buildAddButton(")]
build_add = ref_content[ref_content.find("Widget _buildAddButton("):ref_content.find("static const _kPlaceholderTitles")]

content = content.replace("  // ── Placeholder title guard", build_colored + "\n" + build_add + "\n  // ── Placeholder title guard")

with open(filepath, 'w') as f:
    f.write(content)
