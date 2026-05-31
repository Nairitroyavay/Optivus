import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

void showLogoutDialog(BuildContext context, VoidCallback onLogout) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: OptivusColors.backgroundBottom,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Log out?',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        content: const Text(
          'Your data will stay safe in your account.',
          style: TextStyle(color: OptivusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: OptivusColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OptivusColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log out'),
          ),
        ],
      );
    },
  );
}
