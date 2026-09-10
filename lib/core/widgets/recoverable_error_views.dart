import 'package:flutter/material.dart';
import 'package:optivus/core/errors/recoverable_error.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/onboarding_glass_widgets.dart';

/// Presentation banner for a [RecoverableError].
class RecoverableErrorBanner extends StatelessWidget {
  final RecoverableError error;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final EdgeInsetsGeometry margin;

  const RecoverableErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel,
    this.margin = const EdgeInsets.fromLTRB(24, 0, 24, 10),
  });

  @override
  Widget build(BuildContext context) {
    final (tint, borderColor, textColor, icon) = _styleFor(error);
    final buttonText = retryLabel ?? _labelForAction(error.retryAction);

    return Container(
      key: ValueKey(error.diagnosticCode),
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              error.publicMessage,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onRetry != null &&
              error.retryAction != RecoverableRetryAction.none) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('onboarding-sync-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static (Color, Color, Color, IconData) _styleFor(RecoverableError error) {
    return switch (error.severity) {
      RecoverableErrorSeverity.critical => (
        OptivusColors.danger.withValues(alpha: 0.15),
        OptivusColors.danger.withValues(alpha: 0.80),
        OptivusColors.danger,
        Icons.error_outline_rounded,
      ),
      RecoverableErrorSeverity.error => (
        OptivusColors.danger.withValues(alpha: 0.10),
        OptivusColors.danger.withValues(alpha: 0.65),
        OptivusColors.danger,
        Icons.warning_amber_rounded,
      ),
      RecoverableErrorSeverity.warning => (
        OptivusColors.warning.withValues(alpha: 0.12),
        OptivusColors.warning.withValues(alpha: 0.70),
        OptivusColors.warning,
        Icons.warning_amber_rounded,
      ),
      RecoverableErrorSeverity.info => (
        OptivusColors.info.withValues(alpha: 0.10),
        OptivusColors.info.withValues(alpha: 0.60),
        OptivusColors.info,
        Icons.info_outline_rounded,
      ),
    };
  }

  static String _labelForAction(RecoverableRetryAction action) {
    return switch (action) {
      RecoverableRetryAction.retry => 'Retry',
      RecoverableRetryAction.retryUpload => 'Retry Upload',
      RecoverableRetryAction.retryGeneration => 'Retry',
      RecoverableRetryAction.retrySave => 'Retry Save',
      RecoverableRetryAction.reauthenticate => 'Sign In',
      RecoverableRetryAction.openSettings => 'Settings',
      RecoverableRetryAction.chooseAnother => 'Choose Another',
      RecoverableRetryAction.returnToStep => 'Fix Step',
      RecoverableRetryAction.resumeCompletion => 'Resume',
      RecoverableRetryAction.restartRecovery => 'Recover',
      RecoverableRetryAction.none => 'Dismiss',
    };
  }
}

/// Glass card representation of a [RecoverableError].
class RecoverableErrorCard extends StatelessWidget {
  final RecoverableError error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const RecoverableErrorCard({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (_, _, textColor, icon) = RecoverableErrorBanner._styleFor(error);
    final buttonText =
        retryLabel ?? RecoverableErrorBanner._labelForAction(error.retryAction);

    return OnboardingGlassCard(
      tint: textColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error.title ??
                        (error.isBlocking ? 'Action Required' : 'Notice'),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.publicMessage,
              style: const TextStyle(
                fontSize: 12,
                color: OptivusColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (onRetry != null &&
                error.retryAction != RecoverableRetryAction.none) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: textColor),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline error text for form fields.
class RecoverableErrorInline extends StatelessWidget {
  final RecoverableError? error;

  const RecoverableErrorInline({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        error!.publicMessage,
        style: const TextStyle(
          color: OptivusColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
