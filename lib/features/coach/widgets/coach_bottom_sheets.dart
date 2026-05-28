import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class CoachBottomSheets {
  static void showNewSessionSheet(BuildContext context, {required ValueChanged<String> onSessionSelected}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 48),
          decoration: const BoxDecoration(
            color: OptivusColors.backgroundBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Start New Coach Session',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildSessionOption(context, 'Ask Anything', Icons.chat_bubble_outline, onSessionSelected),
                  _buildSessionOption(context, 'Today\'s Plan', Icons.wb_sunny_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Recovery', Icons.healing_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Study / Work', Icons.menu_book_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Calm', Icons.self_improvement_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Slip-up Comeback', Icons.undo_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Improve Routine', Icons.tune_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Weekly Review', Icons.calendar_month_outlined, onSessionSelected),
                  _buildSessionOption(context, 'Custom Session', Icons.add_circle_outline, onSessionSelected),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static void showCoachMenuSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 24, bottom: 48),
          decoration: const BoxDecoration(
            color: OptivusColors.backgroundBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Coach Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(context, 'Coach Settings', Icons.settings_outlined),
              _buildMenuItem(context, 'Session History', Icons.history_outlined),
              _buildMenuItem(context, 'Change Coach Name', Icons.edit_outlined),
              _buildMenuItem(context, 'Change Coach Style', Icons.style_outlined),
              _buildMenuItem(context, 'Change Slip-up Handling', Icons.published_with_changes_outlined),
              const Divider(color: OptivusColors.borderSoft),
              _buildMenuItem(context, 'Clear Current Session', Icons.clear_all_outlined),
              _buildMenuItem(context, 'Archive Session', Icons.archive_outlined),
              _buildMenuItem(context, 'Privacy', Icons.privacy_tip_outlined),
              _buildMenuItem(context, 'Export Chat', Icons.import_export_outlined),
              _buildMenuItem(context, 'Delete Chat', Icons.delete_outline, isDestructive: true),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildSessionOption(BuildContext context, String label, IconData icon, ValueChanged<String> onSelected) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onSelected(label);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        height: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: OptivusColors.coachTop.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OptivusColors.coachTop),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: OptivusColors.coachAccent, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMenuItem(BuildContext context, String label, IconData icon, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? OptivusColors.danger : OptivusColors.textPrimary),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? OptivusColors.danger : OptivusColors.textPrimary,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label tapped'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  static void showInputPlusMenuSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 24, bottom: 48),
          decoration: const BoxDecoration(
            color: OptivusColors.backgroundBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OptivusColors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuItem(context, 'Ask about today', Icons.calendar_today_outlined),
              _buildMenuItem(context, 'Start new session', Icons.add_circle_outline),
              _buildMenuItem(context, 'Add task by chat', Icons.add_task_outlined),
              _buildMenuItem(context, 'Upload image', Icons.image_outlined),
              _buildMenuItem(context, 'Voice note', Icons.mic_none_outlined),
              _buildMenuItem(context, 'Log mood', Icons.mood_outlined),
              _buildMenuItem(context, 'Log craving', Icons.local_dining_outlined),
              _buildMenuItem(context, 'Ask for routine improvement', Icons.auto_graph_outlined),
            ],
          ),
        );
      },
    );
  }
}
