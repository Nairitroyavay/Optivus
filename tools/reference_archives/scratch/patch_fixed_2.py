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
    content = content.replace(
        "dynamic validateFixedScheduleTemplateDraft(dynamic t) => null;",
        "dynamic validateFixedScheduleTemplateDraft(dynamic t, {dynamic existingTemplates, dynamic currentTemplateId, dynamic allowOverlap, dynamic endTime}) => null;"
    )
    
    # Fix getters
    content = content.replace(
        "DateTime get updatedAt => DateTime.now();",
        "DateTime get updatedAt => DateTime.now();\n  bool get isActive => true;\n  int get reminderOffsetMinutes => 0;"
    )
    
    with open(filepath, 'w') as f:
        f.write(content)

