import 'dart:async';

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_blob_button.dart';

enum OnboardingActionKind {
  back,
  next,
  skip,
  notNow,
  generate,
  retry,
  regenerate,
  enterOptivus,
}

enum OnboardingActionEmphasis { primary, secondary, tertiary }

enum OnboardingActionOperationState { idle, active }

enum OnboardingKeyboardFooterBehavior {
  stayVisibleAboveKeyboard,
  hideWhileKeyboardVisible,
}

typedef OnboardingActionCallback = FutureOr<void> Function();

@immutable
class OnboardingAction {
  final Key? key;
  final OnboardingActionKind kind;
  final String label;
  final bool enabled;
  final bool visible;
  final OnboardingActionEmphasis emphasis;
  final OnboardingActionOperationState operationState;
  final String semanticLabel;
  final OnboardingActionCallback? onPressed;

  const OnboardingAction({
    this.key,
    required this.kind,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.visible = true,
    this.emphasis = OnboardingActionEmphasis.primary,
    this.operationState = OnboardingActionOperationState.idle,
    String? semanticLabel,
  }) : semanticLabel = semanticLabel ?? label;

  bool get isLoading => operationState == OnboardingActionOperationState.active;
}

@immutable
class OnboardingFooterMetrics {
  static const double primaryActionHeight = 104;
  static const double compactActionHeight = 52;
  static const double horizontalMargin = 24;
  static const double actionGap = 12;
  static const double topSpacing = 8;
  static const double bottomSpacing = 14;
  static const double contentToFooterGap = 0;

  final double safeAreaBottom;
  final double actionAreaHeight;
  final double accessoryHeight;

  const OnboardingFooterMetrics({
    required this.safeAreaBottom,
    this.actionAreaHeight = primaryActionHeight,
    this.accessoryHeight = 0,
  });

  factory OnboardingFooterMetrics.resolve(
    BuildContext context, {
    double actionAreaHeight = primaryActionHeight,
    double accessoryHeight = 0,
  }) {
    return OnboardingFooterMetrics(
      safeAreaBottom: MediaQuery.paddingOf(context).bottom,
      actionAreaHeight: actionAreaHeight,
      accessoryHeight: accessoryHeight,
    );
  }

  double get obstructionHeight =>
      topSpacing +
      actionAreaHeight +
      accessoryHeight +
      bottomSpacing +
      safeAreaBottom;

  /// Required reserve when this footer is used as an overlay. Ordinary
  /// onboarding uses structural layout, so the same extent is reserved by the
  /// footer's layout box rather than duplicated inside every scroll view.
  double get requiredContentInset => obstructionHeight + contentToFooterGap;
}

class OnboardingActionBar extends StatefulWidget {
  final List<OnboardingAction> actions;
  final OnboardingKeyboardFooterBehavior keyboardBehavior;
  final Widget? accessory;
  final bool reserveHiddenSpace;

  const OnboardingActionBar({
    super.key,
    required this.actions,
    this.keyboardBehavior =
        OnboardingKeyboardFooterBehavior.hideWhileKeyboardVisible,
    this.accessory,
    this.reserveHiddenSpace = false,
  });

  @override
  State<OnboardingActionBar> createState() => _OnboardingActionBarState();
}

class _OnboardingActionBarState extends State<OnboardingActionBar> {
  final Set<OnboardingActionKind> _ownedActions = <OnboardingActionKind>{};

  Future<void> _invoke(OnboardingAction action) async {
    if (!action.enabled || action.isLoading || action.onPressed == null) return;
    if (!_ownedActions.add(action.kind)) return;
    if (mounted) setState(() {});
    FutureOr<void> result;
    try {
      result = action.onPressed!();
    } catch (_) {
      _release(action.kind);
      rethrow;
    }
    if (result is Future<void>) {
      try {
        await result;
      } catch (_) {
        // Ensure async errors in callbacks unlock the fence via finally without zone crashes
      } finally {
        _release(action.kind);
      }
      return;
    }
    // A synchronous callback remains fenced for the current frame, preventing
    // multiple taps before its feature owner has a chance to publish state.
    WidgetsBinding.instance.addPostFrameCallback((_) => _release(action.kind));
  }

  void _release(OnboardingActionKind kind) {
    if (mounted) {
      setState(() => _ownedActions.remove(kind));
    } else {
      _ownedActions.remove(kind);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen &&
        widget.keyboardBehavior ==
            OnboardingKeyboardFooterBehavior.hideWhileKeyboardVisible) {
      return const SizedBox.shrink(
        key: ValueKey('onboarding-cta-hidden-for-keyboard'),
      );
    }

    final visibleActions = widget.actions
        .where((action) => action.visible)
        .toList();
    if (visibleActions.isEmpty && !widget.reserveHiddenSpace) {
      return const SizedBox.shrink();
    }
    final actions = visibleActions.isEmpty ? widget.actions : visibleActions;
    final contentVisible = visibleActions.isNotEmpty;

    return IgnorePointer(
      ignoring: !contentVisible,
      child: ExcludeSemantics(
        excluding: !contentVisible,
        child: AnimatedOpacity(
          opacity: contentVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: const ValueKey('onboarding-cta-visible'),
            color: Colors.transparent,
            padding: EdgeInsets.fromLTRB(
              OnboardingFooterMetrics.horizontalMargin,
              OnboardingFooterMetrics.topSpacing,
              OnboardingFooterMetrics.horizontalMargin,
              OnboardingFooterMetrics.bottomSpacing +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionLayout(actions: actions, invoke: _invoke),
                if (widget.accessory != null) widget.accessory!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionLayout extends StatelessWidget {
  final List<OnboardingAction> actions;
  final ValueChanged<OnboardingAction> invoke;

  const _ActionLayout({required this.actions, required this.invoke});

  @override
  Widget build(BuildContext context) {
    final primary = actions
        .where((a) => a.emphasis == OnboardingActionEmphasis.primary)
        .toList();
    final lower = actions
        .where((a) => a.emphasis != OnboardingActionEmphasis.primary)
        .toList();

    final primaryWidgets = [
      for (final action in primary)
        _PrimaryAction(action: action, invoke: invoke),
    ];
    final lowerWidgets = [
      for (final action in lower)
        Expanded(
          child: _LowerAction(action: action, invoke: invoke),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lowerWidgets.isNotEmpty) ...[
          Row(children: lowerWidgets),
          const SizedBox(height: OnboardingFooterMetrics.actionGap),
        ],
        for (var i = 0; i < primaryWidgets.length; i++) ...[
          primaryWidgets[i],
          if (i != primaryWidgets.length - 1)
            const SizedBox(height: OnboardingFooterMetrics.actionGap),
        ],
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final OnboardingAction action;
  final ValueChanged<OnboardingAction> invoke;

  const _PrimaryAction({required this.action, required this.invoke});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: action.enabled && !action.isLoading,
      label: action.semanticLabel,
      value: action.isLoading ? 'In progress' : null,
      child: LiquidBlobButton(
        key: action.key ?? ValueKey('onboarding-action-${action.kind.name}'),
        label: action.label,
        onPressed: () => invoke(action),
        isLoading: action.isLoading,
        enabled: action.enabled,
        height: OnboardingFooterMetrics.primaryActionHeight,
        fullWidth: true,
      ),
    );
  }
}

class _LowerAction extends StatelessWidget {
  final OnboardingAction action;
  final ValueChanged<OnboardingAction> invoke;

  const _LowerAction({required this.action, required this.invoke});

  @override
  Widget build(BuildContext context) {
    final onPressed = action.enabled && !action.isLoading
        ? () => invoke(action)
        : null;
    final child = Text(action.label, maxLines: 2, textAlign: TextAlign.center);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: action.semanticLabel,
      value: action.isLoading ? 'In progress' : null,
      child: SizedBox(
        height: OnboardingFooterMetrics.compactActionHeight,
        child: action.emphasis == OnboardingActionEmphasis.tertiary
            ? TextButton(onPressed: onPressed, child: child)
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: OptivusColors.textPrimary,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: child,
              ),
      ),
    );
  }
}
