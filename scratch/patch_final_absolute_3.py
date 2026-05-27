import re

with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'r') as f:
    c = f.read()
# Replace the dangling comma
c = re.sub(r"\}\s*,\s*,\s*\);", "}\n                              );", c)
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_schedule_editor.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'r') as f:
    c = f.read()
# Fix invalid assignment
c = c.replace("List<FixedScheduleTemplate> _templates = [];", "List<dynamic> _templates = [];")
c = c.replace("_templates = List<FixedScheduleTemplate>.from(t)", "_templates = t")
with open('lib/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart', 'r') as f:
    c = f.read()
c = "import 'package:optivus/state/app_state.dart';\n" + c
with open('lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart', 'w') as f:
    f.write(c)

with open('lib/features/onboarding/steps/base_timeline_step.dart', 'r') as f:
    c = f.read()
# Inject imports
imports = """
import 'package:optivus/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_editors/eating_timeline_editor.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_editors/fixed_timeline_editor.dart';
import 'package:optivus/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart';

"""
c = c.replace("import 'package:optivus/state/app_state.dart';", "import 'package:optivus/state/app_state.dart';\n" + imports)

# Add the launch button widget
btn_widget = """
  Widget _launchEditorButton({required bool enabled, required String title, required Widget Function(BuildContext) builder}) {
    if (!enabled) return Center(child: Text('Disabled for current role'));
    return Center(
      child: FilledButton.icon(
        icon: const Icon(Icons.fullscreen),
        label: Text('Open $title Editor'),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: builder));
        },
      )
    );
  }
"""
c = c.replace("Widget _section({", btn_widget + "\n  Widget _section({")

# Replace sections in TabBarView
tabs_view_regex = r"TabBarView\(\s*controller: _tabController,\s*physics: const NeverScrollableScrollPhysics\(\),\s*children: \["
new_children = """
              _launchEditorButton(
                 enabled: _classesEnabled(role),
                 title: 'Classes',
                 builder: (ctx) => ClassSetupScreen(onComplete: () => Navigator.pop(ctx)),
              ),
              _section(
                enabled: _jobEnabled(role),
                requiredLabel: _jobRequired(role)
                    ? 'Required for your role'
                    : 'Disabled by current role',
                title: 'Job / Work / Business',
                icon: Icons.work_rounded,
                accent: OptivusColors.brandAccent,
                description:
                    'Set fixed shifts, flexible work windows, business duration, and best time.',
                controller: _titleCtrl,
                controllerHint: 'Office shift, client work, store hours',
                addLabel: 'Add work block',
                blockType: RoutineBlockType.hardBlock,
                filter: (item) => item.notes == 'Job / Work / Business',
                chips: const [
                  'Normal job schedule',
                  'Hard block',
                  'Soft block',
                  'Fixed',
                  'Flexible',
                  'Mixed',
                  'Priority',
                ],
                extra: role == LifeRoleDraft.businessKey
                    ? _businessModeSelector()
                    : null,
              ),
              _launchEditorButton(
                 enabled: true,
                 title: 'Eating',
                 builder: (ctx) => EatingSetupScreen(onComplete: () => Navigator.pop(ctx)),
              ),
              _launchEditorButton(
                 enabled: true,
                 title: 'Fixed',
                 builder: (ctx) => FixedScheduleSetupScreen(onComplete: () => Navigator.pop(ctx)),
              ),
              _launchEditorButton(
                 enabled: true,
                 title: 'Skin Care',
                 builder: (ctx) => SkinCareSetupScreen(onComplete: () => Navigator.pop(ctx)),
              ),
"""
c = re.sub(r"(_section\(\s*enabled: _classesEnabled.*?_skinCareSection\(\),\s*)", new_children, c, flags=re.DOTALL)

with open('lib/features/onboarding/steps/base_timeline_step.dart', 'w') as f:
    f.write(c)

