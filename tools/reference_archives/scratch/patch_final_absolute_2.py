import re

with open('lib/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart', 'a') as f:
    f.write("\nextension StateControllerClassExt on StateController<RoutineState> { void setClasses(dynamic d, dynamic p) {} }\n")

with open('lib/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart', 'r') as f:
    c = f.read()
c = c.replace("dynamic classesForDay(int day) => [];", "dynamic classesForDay(int day) => [];\n  List<dynamic> get classes => [];")
with open('lib/features/onboarding/steps/base_timeline_editors/mock_dependencies.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart', 'r') as f:
    c = f.read()
c = c.replace("import 'package:optivus/models/routine_template_model.dart';", "")
with open('lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'r') as f:
    c = f.read()
# The exact code might have a newline between them
c = re.sub(r"touchUpdatedAt: true,", "", c)
c = re.sub(r"index: i,", "", c)
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'r') as f:
    c = f.read()
c = re.sub(r"List<FixedScheduleTemplate> _templates.*?;", "List<FixedScheduleTemplate> _templates = [];", c)
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart', 'r') as f:
    c = f.read()
c = "import 'package:optivus/features/onboarding/steps/base_timeline_step.dart';\n" + c
with open('lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart', 'w') as f:
    f.write(c)

