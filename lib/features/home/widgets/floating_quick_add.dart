import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:optivus/features/home/providers/home_dashboard_provider.dart';
import 'mind_note_editor_sheet.dart';
import 'mind_switch_sheet.dart';
import 'dart:ui';

class FloatingQuickAdd extends ConsumerWidget {
  const FloatingQuickAdd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: OptivusColors.brandAccent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          _showQuickAddSheet(context, ref);
        },
        backgroundColor: OptivusColors.brandAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: OptivusColors.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Quick Add',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildActionChip(
                          context,
                          'Add mind note',
                          Icons.psychology,
                          () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const MindNoteEditorSheet(),
                            );
                          },
                        ),
                        _buildActionChip(
                          context,
                          'Mind Switch',
                          Icons.switch_access_shortcut,
                          () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const MindSwitchSheet(),
                            );
                          },
                        ),
                        _buildActionChip(
                          context,
                          'Add task',
                          Icons.check_box_outlined,
                          () {
                            Navigator.pop(context);
                            ref
                                .read(appNavigationProvider.notifier)
                                .goToRoutine();
                          },
                        ),
                        _buildActionChip(
                          context,
                          'Add fixed block',
                          Icons.calendar_month,
                          () {
                            Navigator.pop(context);
                            ref
                                .read(appNavigationProvider.notifier)
                                .goToRoutine();
                          },
                        ),
                        _buildActionChip(
                          context,
                          'Ask coach',
                          Icons.chat_bubble_outline,
                          () {
                            Navigator.pop(context);
                            ref
                                .read(appNavigationProvider.notifier)
                                .goToCoach();
                          },
                        ),
                        _buildActionChip(
                          context,
                          'Log water',
                          Icons.water_drop,
                          () {
                            Navigator.pop(context);
                            ref
                                .read(homeDashboardProvider.notifier)
                                .completeCheckIn('water', '+250ml');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Water logged.')),
                            );
                          },
                        ),
                        _buildActionChip(
                          context,
                          'Log saved money',
                          Icons.savings,
                          () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Money saved logged.'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: OptivusColors.brandAccent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
