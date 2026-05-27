import re

# 1. eating_timeline_editor.dart
with open('lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart', 'r') as f:
    c = f.read()
c = c.replace("_blocksFromEatingTemplates(savedEatingTemplates);", "_blocksFromEatingTemplates(List<Map<String, dynamic>>.from(savedEatingTemplates));")
c = c.replace("sensitiveContext: eatFlag,", "")
with open('lib/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart', 'w') as f:
    f.write(c)

# 2. fixed_schedule_editor.dart
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'r') as f:
    c = f.read()
c = c.replace("index: i,\n                                touchUpdatedAt: true,", "")
c = c.replace("index: i,", "")
c = c.replace("touchUpdatedAt: true,", "")
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'w') as f:
    f.write(c)

# 3. fixed_timeline_editor.dart
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'r') as f:
    c = f.read()
c = c.replace("List<FixedScheduleTemplate> _templates = ref.read(routineProvider).fixedScheduleTemplates.toList();", "List<FixedScheduleTemplate> _templates = List<FixedScheduleTemplate>.from(ref.read(routineProvider).fixedScheduleTemplates.toList());")
c = c.replace("_templates = t", "_templates = List<FixedScheduleTemplate>.from(t)")
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'w') as f:
    f.write(c)

