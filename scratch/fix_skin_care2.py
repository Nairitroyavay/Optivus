filepath = 'lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace("final routineProvider = StateProvider<RoutineState>((ref) => RoutineState());", "final routineProvider = StateProvider<dynamic>((ref) => null);")
content = content.replace("onPressed: _generateTextSkinCareReview", "onPressed: () {}")
content = content.replace("onTap: _pickSkinCarePhoto", "onTap: () {}")
content = content.replace("text: _photoUploadLabel(_photoImportMetadata!)", "text: ''")
content = content.replace("onTap: _removeSkinCarePhoto", "onTap: () {}")
content = content.replace("onTap: _generatePhotoSkinCareReview", "onTap: () {}")

# Delete `_applySkinCarePlansFromTemplates` and `_markSuggestionsAccepted` as they use `setSkinCarePlan` and `setRoutineTemplates`
import re
content = re.sub(r"Future<void> _applySkinCarePlansFromTemplates\(.*?\}", "", content, flags=re.DOTALL)
content = re.sub(r"Future<void> _markSuggestionsAccepted\(.*?\}", "", content, flags=re.DOTALL)

with open(filepath, 'w') as f:
    f.write(content)
