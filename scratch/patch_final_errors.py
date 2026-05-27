import os

with open('lib/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart', 'a') as f:
    f.write("\nexport 'package:optivus/features/onboarding/steps/base_timeline_step.dart';\n")
    f.write("\nextension StateControllerEatingExt2 on StateController<RoutineState> { void setMealPlan(dynamic d, dynamic p) {} }\n")
    
with open('lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart', 'r') as f:
    content = f.read()
content = content.replace("List<Map<String, dynamic>>.from(routineProvider.routineTemplates['eating_menu'] ?? [])", "List<Map<String, dynamic>>.from([])")
content = content.replace("sensitiveContext: ref.context,", "")
with open('lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart', 'w') as f:
    f.write(content)

with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'r') as f:
    content = f.read()
content = content.replace("index: i,", "")
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'w') as f:
    f.write(content)

with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'r') as f:
    content = f.read()
content = content.replace("List<FixedScheduleTemplate> _templates = [];", "List<dynamic> _templates = [];")
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'w') as f:
    f.write(content)

