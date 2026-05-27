// REFERENCE COPY ONLY — not imported into app yet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/liquid_ui/liquid_ui.dart';
import 'package:optivus/features/routine/managers/base_timeline/legacy_stubs.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/fixed_schedule_editor.dart';

class FixedScheduleSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const FixedScheduleSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<FixedScheduleSetupScreen> createState() =>
      _FixedScheduleSetupScreenState();
}

class _FixedScheduleSetupScreenState
    extends ConsumerState<FixedScheduleSetupScreen> {
  List<FixedScheduleTemplate> _currentTemplates = const [];
  bool _isLoaded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _currentTemplates = ref.read(routineProvider).fixedScheduleTemplates;
        _isLoaded = true;
      });
    });
  }

  Future<bool> _save() async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    final normalizedTemplates =
        canonicalizeFixedScheduleTemplates(_currentTemplates);

    try {
      debugPrint('[FixedScheduleSetup] accept_start');
      debugPrint(
          '[FixedScheduleSetup] accept_templates_count=${normalizedTemplates.length}');
      ref.read(routineProvider.notifier).setFixedScheduleTemplates(
            normalizedTemplates,
          );
      await runRoutineAcceptWithTimeout(
        () => ref
            .read(routineRepositoryProvider)
            .saveFixedScheduleTemplates(normalizedTemplates),
      );
      debugPrint('[FixedScheduleSetup] accept_save_success');
      return true;
    } on RoutineAcceptTimeoutException {
      debugPrint('[FixedScheduleSetup] accept_timeout');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
      return false;
    } catch (e) {
      debugPrint('[FixedScheduleSetup] accept_save_failed: $e');
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LiquidIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 44,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Text(
                      'FIXED SCHEDULE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kSub,
                        letterSpacing: 1.5,
                      ),
                    ),
                    _isSaving
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : LiquidIconBtn(
                            icon: Icons.check_rounded,
                            size: 44,
                            onTap: () async {
                              final saved = await _save();
                              if (!context.mounted || !saved) return;
                              widget.onComplete();
                              Navigator.pop(context);
                            },
                          ),
                  ],
                ),
              ),

              // Shared editor
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16),
                  child: FixedScheduleEditor(
                    // Re-init once the routine state has been loaded.
                    key: ValueKey(_isLoaded),
                    initialTemplates: _currentTemplates,
                    onChanged: (templates) {
                      _currentTemplates = templates;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
