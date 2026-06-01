import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/models/home_mind_note.dart';
import 'package:optivus/features/home/providers/home_mind_note_provider.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'home_glass_widgets.dart';
import 'sheets/mini_action_plan_sheet.dart';

class MindSwitchSheet extends ConsumerStatefulWidget {
  const MindSwitchSheet({super.key});

  @override
  ConsumerState<MindSwitchSheet> createState() => _MindSwitchSheetState();
}

class _MindSwitchSheetState extends ConsumerState<MindSwitchSheet> {
  int _step = 0;
  MindNoteType? _selectedType;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _step++;
    });
  }

  void _prevStep() {
    setState(() {
      if (_step > 0) _step--;
    });
  }

  void _save(bool sendToCoach) {
    if (_selectedType == null || _controller.text.trim().isEmpty) return;

    ref
        .read(homeMindNoteProvider.notifier)
        .addNote(
          _controller.text.trim(),
          _selectedType!,
          MindNoteIntensity.medium, // Default intensity for quick switch
        );

    if (sendToCoach) {
      final notes = ref.read(homeMindNoteProvider);
      if (notes.isNotEmpty) {
        ref
            .read(homeMindNoteProvider.notifier)
            .toggleShareWithCoach(notes.first.id);
      }
      Navigator.pop(context);
      ref.read(appNavigationProvider.notifier).goToCoach();
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thought captured. Return to focus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: media.viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const Text(
          'I noticed I am overthinking.',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        HomeActionPill(
          label: 'Yes, capture it',
          selected: true,
          onTap: _nextStep,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const Text(
          'Step 2 of 4',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: OptivusColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'What kind of thought is this?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MindNoteType.values.map((type) {
            return ChoiceChip(
              label: Text(type.name),
              selected: _selectedType == type,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedType = type);
                  Future.delayed(const Duration(milliseconds: 200), _nextStep);
                }
              },
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              selectedColor: OptivusColors.homeAccent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _selectedType == type
                    ? OptivusColors.homeAccent
                    : OptivusColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
              side: BorderSide(
                color: _selectedType == type
                    ? OptivusColors.homeAccent
                    : Colors.transparent,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        HomeActionPill(label: 'Back', onTap: _prevStep),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      key: const ValueKey(3),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const Text(
          'Step 3 of 4',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: OptivusColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Write one line.',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          maxLines: 3,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: OptivusColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Just dump it here...',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: HomeActionPill(label: 'Back', onTap: _prevStep),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HomeActionPill(
                label: 'Next',
                selected: true,
                onTap: _nextStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      key: const ValueKey(4),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHandle(),
        const Text(
          'Step 4 of 4',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: OptivusColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Good. You noticed it.',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Now your brain knows: "I am overthinking."\nYou do not need to solve everything. Capture it, then return to your next task.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: OptivusColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: HomeActionPill(
                label: 'Save',
                selected: true,
                onTap: () => _save(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HomeActionPill(
                label: 'Send to Coach',
                onTap: () => _save(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeActionPill(
                label: 'Return to Focus',
                compact: true,
                onTap: () => _save(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HomeActionPill(
                label: 'Make Action Plan',
                compact: true,
                onTap: () {
                  _save(false);
                  MiniActionPlanSheet.show(context);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: OptivusColors.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
