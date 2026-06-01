import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

class CoachBottomSheets {
  static Widget _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? OptivusColors.danger : OptivusColors.textPrimary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? OptivusColors.danger
              : OptivusColors.textPrimary,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
    );
  }

  static void showInputPlusMenuSheet(
    BuildContext context, {
    ValueChanged<String>? onPromptSelected,
    VoidCallback? onNewSession,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).padding.bottom;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            padding: EdgeInsets.only(top: 24, bottom: 24 + bottom),
            decoration: const BoxDecoration(
              color: OptivusColors.backgroundBottom,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                  _buildMenuItem(
                    context,
                    'Ask about today',
                    Icons.calendar_today_outlined,
                    onTap: () => onPromptSelected?.call(
                      'Audit today and give me the next best move.',
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    'Start new session',
                    Icons.add_circle_outline,
                    onTap: onNewSession,
                  ),
                  _buildMenuItem(
                    context,
                    'Add task by chat',
                    Icons.add_task_outlined,
                    onTap: () => onPromptSelected?.call(
                      'Help me add one clear task to my routine.',
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    'Upload image',
                    Icons.image_outlined,
                    onTap: () => onPromptSelected?.call(
                      'I want to discuss an image. Help me capture the important details in text for now.',
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    'Voice note',
                    Icons.mic_none_outlined,
                    onTap: () => onPromptSelected?.call(
                      'I want to capture a voice note. Help me turn it into a short written note.',
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    'Log mood',
                    Icons.mood_outlined,
                    onTap: () => onPromptSelected?.call(
                      'Help me log my current mood and choose one next action.',
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    'Log craving',
                    Icons.local_dining_outlined,
                    onTap: () => onPromptSelected?.call(
                      'Help me handle a craving right now and protect the streak.',
                    ),
                  ),
                  _buildMenuItem(
                    context,
                    'Ask for routine improvement',
                    Icons.auto_graph_outlined,
                    onTap: () => onPromptSelected?.call(
                      'Improve my routine for today without overloading it.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
