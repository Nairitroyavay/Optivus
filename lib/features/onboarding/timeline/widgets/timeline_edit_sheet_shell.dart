import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';

/// Modal bottom sheet shell for timeline editing.
///
/// Owns sheet frame, header, cancel/save buttons, safe area, keyboard padding,
/// error banner, and double-save protection.
class TimelineEditSheetShell extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Future<bool> Function()? onSave;
  final VoidCallback? onCancel;
  final String saveLabel;
  final Color accent;
  final String? initialError;

  const TimelineEditSheetShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.onSave,
    this.onCancel,
    this.saveLabel = 'Save',
    this.accent = OptivusColors.brandAccent,
    this.initialError,
  });

  /// Helper to display this edit sheet in a modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required WidgetBuilder builder,
    Future<bool> Function()? onSave,
    VoidCallback? onCancel,
    String saveLabel = 'Save',
    Color accent = OptivusColors.brandAccent,
    String? initialError,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimelineEditSheetShell(
        title: title,
        subtitle: subtitle,
        onSave: onSave,
        onCancel: onCancel,
        saveLabel: saveLabel,
        accent: accent,
        initialError: initialError,
        child: builder(ctx),
      ),
    );
  }

  @override
  State<TimelineEditSheetShell> createState() => _TimelineEditSheetShellState();
}

class _TimelineEditSheetShellState extends State<TimelineEditSheetShell> {
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
  }

  Future<void> _handleSave() async {
    if (_isSaving || widget.onSave == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onSave!();
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSaving = false;
          // Keep edit contents available on failure
        });
      }
    } catch (e) {
      if (!mounted) return;
      final raw =
          e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      final isCleanValidation = raw.isNotEmpty &&
          !raw.toLowerCase().contains('raw_') &&
          !raw.toLowerCase().contains('secret') &&
          !raw.toLowerCase().contains('token') &&
          !raw.contains('{') &&
          !raw.contains('}') &&
          !raw.contains('SocketException') &&
          !raw.contains('HttpException') &&
          !raw.contains('FirebaseException');
      setState(() {
        _isSaving = false;
        _errorMessage = isCleanValidation
            ? raw
            : 'Could not save schedule changes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Drag Handle ──
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: OptivusColors.textSecondary.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header Row ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        // Cancel button
                        TextButton(
                          key: const Key('timeline-edit-cancel-button'),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  widget.onCancel?.call();
                                  Navigator.of(context).pop(false);
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: OptivusColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(44, 36),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // Title
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: OptivusColors.textPrimary,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: OptivusColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Save button
                        ElevatedButton(
                          key: const Key('timeline-edit-save-button'),
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(60, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.saveLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0x1A000000)),

                  // ── Error Banner ──
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: OptivusColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: OptivusColors.danger.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: OptivusColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: OptivusColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Form Content ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
