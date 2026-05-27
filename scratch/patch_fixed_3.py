import re
import os

files = [
    'lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart',
    'lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart'
]

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Fix validateFixedScheduleTemplateDraft
    content = re.sub(r"dynamic validateFixedScheduleTemplateDraft.*?=> null;", "dynamic validateFixedScheduleTemplateDraft(dynamic t, {dynamic title, dynamic startTime, dynamic endTime, dynamic existingTemplates, dynamic currentTemplateId, dynamic allowOverlap}) => null;", content)
    
    # Fix getters
    content = content.replace(
        "int get reminderOffsetMinutes => 0;",
        "int get reminderOffsetMinutes => 0;\n  String get category => '';\n  String get notes => '';\n  bool get reminderEnabled => false;"
    )
    
    with open(filepath, 'w') as f:
        f.write(content)

