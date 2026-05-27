import re
import os

filepath = 'lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

# 1. Fix Imports
content = re.sub(
    r"import 'package:optivus/providers/routine_provider.dart';",
    "import 'package:optivus/state/app_state.dart';\nimport 'package:optivus/models/onboarding_draft.dart';",
    content
)

content = re.sub(
    r"import 'package:image_picker/image_picker.dart';",
    "",
    content
)
content = re.sub(
    r"import 'package:optivus/core/constants/event_names.dart';",
    "",
    content
)
content = re.sub(
    r"import 'package:optivus/core/providers.dart';",
    "",
    content
)
content = re.sub(
    r"import 'package:optivus/services/image_upload_service.dart';",
    "",
    content
)
content = re.sub(
    r"import 'package:optivus/services/routine_acceptance_guard.dart';",
    "",
    content
)

# Remove ImageUploadService variable
content = re.sub(
    r"final ImageUploadService _imageUploadService = ImageUploadService\(\);",
    "",
    content
)

# 2. Fix initState to read from mockOnboardingProvider instead of routineProvider
init_state_replacement = """
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final baseTimeline = ref.read(mockOnboardingProvider).draft.baseTimeline;
      final savedClasses = baseTimeline.blocks.where((b) => b.section == 'classes').toList();
      if (!mounted) return;

      final next = <int, List<ClassRoutineBlock>>{
        for (int i = 0; i < 7; i++) i: <ClassRoutineBlock>[],
      };

      for (final item in savedClasses) {
        for (final day in item.repeatDays) {
          final dayIndex = (day - 1).clamp(0, 6);
          final start = item.startMinute / 60.0 - 6.0;
          final duration = (item.endMinute - item.startMinute) / 60.0;
          next[dayIndex]!.add(
            ClassRoutineBlock(
              id: 'class_${dayIndex}_${item.id}',
              subject: item.title,
              room: item.location ?? '',
              professor: '',
              start: start < 0 ? start + 24 : start,
              duration: duration <= 0 ? 1.0 : duration,
              icon: Icons.school_rounded,
              color: Color(0xFF378ADD),
              hasTopTape: true,
              hasBottomTape: true,
            ),
          );
        }
      }

      for (int i = 0; i < 7; i++) {
        next[i]!.sort((a, b) => a.start.compareTo(b.start));
        next[i]!.add(ClassRoutineBlock(
          id: 'add_saved_$i',
          subject: '',
          start: 7.0,
          isAdd: true,
        ));
      }

      setState(() => weeklyRoutines = next);
    });
"""

# Replace the specific block in initState
content = re.sub(
    r"WidgetsBinding\.instance\.addPostFrameCallback\(\(_\) \{.*?setState\(\(\) => weeklyRoutines = next\);\n    \}\);",
    init_state_replacement,
    content,
    flags=re.DOTALL
)

# 3. Fix _save to write to mockOnboardingProvider
save_replacement = """
  Future<bool> _save(WidgetRef ref) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);

    try {
      final List<TimelineBlockDraft> newBlocks = [];
      for (int day = 0; day < 7; day++) {
        for (final block in weeklyRoutines[day]!) {
          if (block.isAdd || block.subject.trim().isEmpty) continue;
          
          int startMin = ((block.start + 6.0) * 60).round();
          int endMin = ((block.start + block.duration + 6.0) * 60).round();
          
          newBlocks.add(TimelineBlockDraft(
            id: 'class_${day}_${DateTime.now().millisecondsSinceEpoch}_${block.subject}',
            section: 'classes',
            title: block.subject,
            startMinute: startMin,
            endMinute: endMin,
            crossesMidnight: endMin < startMin,
            blockType: TimelineBlockDraft.hardBlockKey,
            repeatDays: [day + 1],
            location: block.room.isNotEmpty ? block.room : null,
          ));
        }
      }

      ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
        final filteredBlocks = draft.baseTimeline.blocks.where((b) => b.section != 'classes').toList();
        return draft.copyWith(
          baseTimeline: draft.baseTimeline.copyWith(blocks: [...filteredBlocks, ...newBlocks]),
          clearFinalPreview: true,
        );
      });
      ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);

      return true;
    } catch (e) {
      debugPrint('[ClassSetup] accept_save_failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
"""

content = re.sub(
    r"Future<bool> _save\(WidgetRef ref\) async \{.*?finally \{\n      if \(mounted\) setState\(\(\) => _isSaving = false\);\n    \}\n  \}",
    save_replacement,
    content,
    flags=re.DOTALL
)

# 4. Remove all photo import and AI import backend logic
# Just replace _importPhoto and _parseText with simple placeholders or remove the backend calls
content = re.sub(
    r"Future<void> _importPhoto\(\) async \{.*?\n  \}",
    "Future<void> _importPhoto() async { setState(() { _isImportingPhoto = false; _photoImportError = 'Photo import is disabled in setup.'; }); }",
    content,
    flags=re.DOTALL
)

content = re.sub(
    r"Future<void> _parseText\(\) async \{.*?\n  \}",
    "Future<void> _parseText() async { setState(() { _isParsingText = false; _textImportError = 'Text import is disabled in setup.'; }); }",
    content,
    flags=re.DOTALL
)

with open(filepath, 'w') as f:
    f.write(content)

print("Class Editor Fixed!")
