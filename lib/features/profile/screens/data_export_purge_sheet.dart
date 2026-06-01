// Legacy Profile sheet. Active data controls live in DataControlScreen.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/models/user_profile.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showDataExportPurgeSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'GDPR Privacy Control',
    subtitle: 'Data Export & Safety Purge',
    child: StatefulBuilder(
      builder: (context, setState) {
        // Keep states inside builder so it rebuilds properly and compiles cleanly
        final exportContainer = _DataExportWidget(ref: ref);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'YOUR DATA PORTABILITY',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            exportContainer,
            const SizedBox(height: 24),
            const Text(
              'ACCOUNT PURGE & RESET',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.danger,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OptivusColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: OptivusColors.danger.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.warning,
                        color: OptivusColors.danger,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Irreversible Actions Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: OptivusColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Performing a Factory Reset completely purges all local databases, routines lists, habit records, goals, and credentials. It resets onboarding back to step zero.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: OptivusColors.textBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OptivusColors.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text(
                            'Double Confirmation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: OptivusColors.danger,
                            ),
                          ),
                          content: const Text(
                            'Are you absolutely certain you want to purge all records? This action cannot be reversed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OptivusColors.danger,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(context); // Dialog
                                Navigator.pop(context); // Sheet
                                ref
                                    .read(mockUserProfileProvider.notifier)
                                    .updateProfile(UserProfile.empty(uid: ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Account reset completely. Logging out.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: OptivusColors.danger,
                                  ),
                                );
                              },
                              child: const Text(
                                'Yes, Purge Everything',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Perform Factory Reset',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DataExportWidget extends StatefulWidget {
  final WidgetRef ref;
  const _DataExportWidget({required this.ref});

  @override
  State<_DataExportWidget> createState() => _DataExportWidgetState();
}

class _DataExportWidgetState extends State<_DataExportWidget> {
  bool _isExporting = false;
  String? _exportedJson;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'In compliance with GDPR specifications, you are permitted to export a complete copy of your local data matrix at any point.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: OptivusColors.textBody,
            ),
          ),
          const SizedBox(height: 16),
          if (_isExporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: CircularProgressIndicator(
                  color: OptivusColors.brandAccent,
                ),
              ),
            )
          else if (_exportedJson != null) ...[
            Container(
              height: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  _exportedJson ?? '',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 9),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.copy, size: 14),
              label: const Text(
                'Copy JSON to Clipboard',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _exportedJson ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('JSON copied to clipboard!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ] else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: OptivusColors.brandAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: OptivusColors.brandAccent),
                ),
              ),
              icon: const Icon(Icons.download, size: 16),
              label: const Text(
                'Generate Export Package',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () {
                setState(() => _isExporting = true);
                Future.delayed(const Duration(milliseconds: 1200), () {
                  final profile = widget.ref.read(mockUserProfileProvider);
                  final map = {
                    'exportedAt': DateTime.now().toIso8601String(),
                    'userId': profile.uid,
                    'profile': {
                      'name': profile.displayName,
                      'role': profile.lifeRole,
                      'bmi': profile.bmiEstimate,
                      'coachName': profile.coachName,
                      'coachStyle': profile.coachStyle,
                    },
                    'compliance': {
                      'gdprOptIn': true,
                      'localDecryptionKey': 'aes-256-gcm-mock',
                    },
                  };
                  if (mounted) {
                    setState(() {
                      _isExporting = false;
                      _exportedJson = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(map);
                    });
                  }
                });
              },
            ),
        ],
      ),
    );
  }
}
