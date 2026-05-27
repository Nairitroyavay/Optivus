import re

filepath = 'lib/features/onboarding/steps/base_timeline_editors/skin_care_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Replace _save
save_replacement = """
  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    
    try {
      final List<TimelineBlockDraft> newBlocks = [];
      for (int d = 0; d < 7; d++) {
        final itemsForDay = weeklyRoutines[d] ?? [];
        for (final item in itemsForDay) {
          if (item.isAdd || item.title.trim().isEmpty) continue;
          
          int startMin = ((item.start + 6.0) * 60).round();
          int endMin = ((item.start + item.duration + 6.0) * 60).round();
          if (startMin < 0) startMin += 24 * 60;
          if (endMin < 0) endMin += 24 * 60;
          
          newBlocks.add(TimelineBlockDraft(
            id: 'skin_care_${d}_${DateTime.now().millisecondsSinceEpoch}_${item.title.replaceAll(" ", "")}',
            section: 'skin_care',
            title: item.title,
            startMinute: startMin,
            endMinute: endMin,
            crossesMidnight: endMin < startMin,
            blockType: TimelineBlockDraft.hardBlockKey,
            repeatDays: [d + 1],
          ));
        }
      }

      ref.read(mockOnboardingProvider.notifier).updateDraft((draft) {
        final filteredBlocks = draft.baseTimeline.blocks.where((b) => b.section != 'skin_care').toList();
        return draft.copyWith(
          baseTimeline: draft.baseTimeline.copyWith(blocks: [...filteredBlocks, ...newBlocks]),
          clearFinalPreview: true,
        );
      });
      ref.read(mockOnboardingProvider.notifier).setStepDirty(4, true);

      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
"""

content = re.sub(
    r"Future<void> _save\(WidgetRef ref\) async \{.*?finally \{\n      if \(mounted\) setState\(\(\) => _isSaving = false\);\n    \}\n  \}",
    save_replacement,
    content,
    flags=re.DOTALL
)

# Overwrite initState
init_replacement = """
  @override
  void initState() {
    super.initState();
    weeklyRoutines = {};
    for (int i = 0; i < 7; i++) {
      weeklyRoutines[i] = [
        SkinCareRoutineBlock(
          id: 'add1_$i',
          title: '',
          start: 1.0,
          isAdd: true,
        ),
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final baseTimeline = ref.read(mockOnboardingProvider).draft.baseTimeline;
      final savedItems = baseTimeline.blocks.where((b) => b.section == 'skin_care').toList();
      if (!mounted) return;

      final next = <int, List<SkinCareRoutineBlock>>{
        for (int i = 0; i < 7; i++) i: <SkinCareRoutineBlock>[],
      };

      for (final item in savedItems) {
        for (final day in item.repeatDays) {
          final dayIndex = (day - 1).clamp(0, 6);
          final start = item.startMinute / 60.0 - 6.0;
          final duration = (item.endMinute - item.startMinute) / 60.0;
          next[dayIndex]!.add(
            SkinCareRoutineBlock(
              id: 'skin_${dayIndex}_${item.id}',
              title: item.title,
              start: start < 0 ? start + 24 : start,
              duration: duration <= 0 ? 1.0 : duration,
              icon: Icons.water_drop_rounded,
              color: Color(0xFF0EA5E9),
              hasTopTape: true,
              hasBottomTape: true,
            ),
          );
        }
      }

      for (int i = 0; i < 7; i++) {
        next[i]!.sort((a, b) => a.start.compareTo(b.start));
        next[i]!.add(SkinCareRoutineBlock(
          id: 'add_saved_$i',
          title: '',
          start: 7.0,
          isAdd: true,
        ));
      }

      setState(() => weeklyRoutines = next);
    });
  }
"""

content = re.sub(
    r"@override\n  void initState\(\) \{.*?setState\(\(\) => weeklyRoutines = next\);\n    \}\);\n  \}",
    init_replacement,
    content,
    flags=re.DOTALL
)

# Nullify all the AI methods to fix compile errors
methods_to_nullify = [
    r"Future<List<Map<String, dynamic>>> _previewGeneratedSkinTemplates\(.*?\).*?^  \}",
    r"Future<void> _generateTextSkinCareReview\(\) async \{.*?\n  \}",
    r"Future<void> _generatePhotoSkinCareReview\(\) async \{.*?\n  \}",
    r"Future<void> _openGeneratedSkinReview\(.*?\).*?^  \}",
    r"Map<String, dynamic> _skinCarePhotoMetadata\(.*?\) \{.*?\n  \}",
    r"Future<void> _pickSkinCarePhoto\(\) async \{.*?\n  \}",
    r"void _showPhotoAiComingSoon\(\) \{.*?\n  \}",
    r"Future<void> _removeSkinCarePhoto\(\) async \{.*?\n  \}",
    r"Future<void> _clearPhotoAfterFailedImport\(.*?\) async \{.*?\n  \}",
    r"Future<void> _deletePhotoMetadataQuietly\(.*?\) async \{.*?\n  \}",
    r"String _photoUploadLabel\(.*?\) \{.*?\n  \}",
    r"Map<String, dynamic> _normalizeSkinTemplate\(.*?\) \{.*?\n  \}",
    r"Map<String, dynamic> _resolveTemplate\(.*?\) \{.*?\n  \}",
    r"List<RoutineAnchor> _anchorsFromRoutineState\(.*?\) \{.*?\n  \}",
    r"Map<String, dynamic> _skinTemplateForSave\(.*?\) \{.*?\n  \}",
    r"List<Map<String, dynamic>> _templateSteps\(.*?\) \{.*?\n  \}",
    r"String _timingRuleFor24h\(.*?\) \{.*?\n  \}",
    r"String _endTimeFrom24h\(.*?\) \{.*?\n  \}",
    r"double _templateConfidence\(.*?\) \{.*?\n  \}",
    r"List<String> _templateWarnings\(.*?\) \{.*?\n  \}",
    r"Future<void> _acceptGeneratedSkinTemplates\(.*?\) async \{.*?\n  \}"
]

for pattern in methods_to_nullify:
    content = re.sub(pattern, "", content, flags=re.DOTALL|re.MULTILINE)

# Overwrite the `_showRoutineReviewDialog` to use `_save()` without ref
content = re.sub(r"void _showRoutineReviewDialog\(\) \{\n    _save\(\)\.then\(\(success\)", r"void _showRoutineReviewDialog() {\n    _save().then((_)", content)

with open(filepath, 'w') as f:
    f.write(content)

