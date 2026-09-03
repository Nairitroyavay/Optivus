import re

path = 'test/onboarding_persistence_phase2b_test.dart'
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    'skinCareSetupPath: \'has_products\',',
    'skinCareSetupPath: \'has_products\',\n      skinCareSkinType: \'oily\',\n      skinCareBudget: \'low\',\n      skinCareProblems: const [\'acne\'],\n      skinCareSelectedProductNames: const [\'cleanser\'],\n      skinCareDesiredApplicationsPerDay: 2,\n      blocks: const [\n        TimelineBlockDraft(\n          id: \'sk1\',\n          section: \'skin_care\',\n          title: \'Morning Routine\',\n          startMinute: 480,\n          endMinute: 495,\n          repeatDays: [1, 2, 3, 4, 5, 6, 7],\n          skincareSteps: [\'Cleanser\'],\n          blockType: TimelineBlockDraft.hardBlockKey,\n        ),\n        TimelineBlockDraft(\n          id: \'sk2\',\n          section: \'skin_care\',\n          title: \'Night Routine\',\n          startMinute: 1320,\n          endMinute: 1335,\n          repeatDays: [1, 2, 3, 4, 5, 6, 7],\n          skincareSteps: [\'Moisturizer\'],\n          blockType: TimelineBlockDraft.hardBlockKey,\n        ),\n      ],'
)

with open(path, 'w') as f:
    f.write(content)
