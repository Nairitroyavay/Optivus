import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/theme/optivus_spacing.dart';

class OnboardingGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool selected;

  const OnboardingGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OptivusSpacing.base),
    this.radius = 24,
    this.tint,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor =
        tint ??
        (isDark
            ? OptivusColors.darkGlassFill
            : Colors.white.withValues(alpha: selected ? 0.15 : 0.05));
    final borderColor = isDark
        ? OptivusColors.darkGlassBorder
        : Colors.white.withValues(alpha: selected ? 0.95 : 0.65);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(
                    alpha: selected ? 0.25 : (isDark ? 0.08 : 0.15),
                  ),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: isDark ? 0.04 : 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 3,
                  left: 18,
                  right: 18,
                  height: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.4 : 0.8),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -15,
                    right: -15,
                    width: 70,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            OptivusColors.brandAccent.withValues(alpha: 0.22),
                            OptivusColors.brandAccent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool userScrollable;

  const OnboardingScrollView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 12, 24, 32),
    this.userScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLandscape =
        media.orientation == Orientation.landscape || media.size.height < 500;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: userScrollable
                ? const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  )
                : const NeverScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: isLandscape || !constraints.maxHeight.isFinite
                    ? 0
                    : constraints.maxHeight,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class OnboardingGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool hasPins;

  const OnboardingGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.radius = 38,
    this.hasPins = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 30,
                  right: 30,
                  height: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasPins) ...[
                  _panelPin(top: 16, left: 16),
                  _panelPin(top: 16, right: 16),
                  _panelPin(bottom: 16, left: 16),
                  _panelPin(bottom: 16, right: 16),
                ],
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _panelPin({double? top, double? left, double? right, double? bottom}) {
  return Positioned(
    top: top,
    left: left,
    right: right,
    bottom: bottom,
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 3,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 10,
            height: 1.5,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class OnboardingSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextAlign textAlign;

  const OnboardingSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: textAlign,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class OnboardingChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;
  final Widget? trailing;
  final Widget? expandedContent;

  const OnboardingChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    this.onTap,
    this.accent = OptivusColors.brandAccent,
    this.trailing,
    this.expandedContent,
  });

  @override
  Widget build(BuildContext context) {
    final clampedScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.38);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = selected
        ? accent
        : (isDark ? OptivusColors.textPrimaryDark : OptivusColors.textPrimary);
    final secondaryTextColor = isDark
        ? OptivusColors.textSecondaryDark
        : OptivusColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: OnboardingGlassCard(
        selected: selected,
        padding: const EdgeInsets.all(OptivusSpacing.base),
        tint: selected ? accent.withValues(alpha: 0.09) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? accent
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.62)),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : secondaryTextColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: clampedScaler,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: primaryTextColor),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          textScaler: clampedScaler,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected
                          ? accent
                          : (isDark
                                ? Colors.white38
                                : Colors.black.withValues(alpha: 0.35)),
                    ),
              ],
            ),
            if (expandedContent != null) ...[
              const SizedBox(height: 13),
              Divider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.58),
                height: 1,
              ),
              const SizedBox(height: 13),
              expandedContent!,
            ],
          ],
        ),
      ),
    );
  }
}

class OnboardingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color accent;

  const OnboardingChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.accent = OptivusColors.brandAccent,
  });

  @override
  Widget build(BuildContext context) {
    final clampedScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.38);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = selected
        ? accent
        : (isDark ? OptivusColors.textPrimaryDark : OptivusColors.textPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: isDark ? 0.25 : 0.35)
                    : Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: isDark ? 0.2 : 0.4),
                  width: selected ? 1.5 : 1.0,
                ),
                gradient: selected
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.15 : 0.25),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -6,
                    left: 10,
                    right: 10,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: isDark ? 0.4 : 0.8),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: accent),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: clampedScaler,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class OnboardingActionPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool selected;
  final bool compact;

  const OnboardingActionPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.accent = OptivusColors.brandAccent,
    this.selected = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final radius = compact ? 16.0 : 20.0;
    final clampedScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.38);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = selected
        ? accent
        : (isDark ? OptivusColors.textPrimaryDark : OptivusColors.textPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.52,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 14,
                  vertical: compact ? 8 : 11,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: isDark ? 0.25 : 0.4)
                      : Colors.white.withValues(alpha: isDark ? 0.08 : 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: isDark ? 0.2 : 0.4),
                    width: selected ? 1.5 : 1.0,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(
                        alpha: selected
                            ? (isDark ? 0.25 : 0.4)
                            : (isDark ? 0.12 : 0.2),
                      ),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: -6,
                      left: 10,
                      right: 10,
                      height: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(
                                alpha: isDark ? 0.4 : 0.85,
                              ),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: compact ? 15 : 17, color: accent),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: clampedScaler,
                              style: TextStyle(
                                color: textColor,
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingCardSkeleton extends StatelessWidget {
  final double height;
  final double radius;

  const OnboardingCardSkeleton({
    super.key,
    this.height = 140,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OnboardingGlassCard(
      radius: radius,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 16,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 12,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingIconPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final String? tooltip;

  const OnboardingIconPill({
    super.key,
    required this.icon,
    this.onTap,
    this.accent = OptivusColors.brandAccent,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 2,
                    left: 8,
                    right: 8,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.8),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(icon, color: accent, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class OnboardingDayDroplet extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const OnboardingDayDroplet({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 36.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.8 : 0.4),
                  width: 1.0,
                ),
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.5),
                  radius: 1.2,
                  colors: selected
                      ? [
                          Colors.white.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.6),
                          color.withValues(alpha: 0.2),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.6),
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 2,
                    left: 8,
                    right: 8,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.5),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? OptivusColors.textPrimary
                          : OptivusColors.textSecondary,
                      fontSize: selected ? 10 : 9,
                      fontWeight: FontWeight.w900,
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

class OnboardingLiquidToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  const OnboardingLiquidToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = OptivusColors.brandAccent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 54,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: value
                    ? accent.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.0,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: value ? 0.3 : 0.2),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 8,
                    right: 8,
                    height: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.8),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.35),
                          colors: [
                            Colors.white.withValues(alpha: 0.96),
                            (value ? accent : Colors.white).withValues(
                              alpha: 0.76,
                            ),
                            (value ? accent : OptivusColors.borderSoft)
                                .withValues(alpha: 0.36),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (value ? accent : Colors.black).withValues(
                              alpha: value ? 0.2 : 0.05,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
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

class OnboardingLiquidSlider extends StatefulWidget {
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;
  final Color accent;

  const OnboardingLiquidSlider({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.accent = OptivusColors.aquaAccent,
  });

  @override
  State<OnboardingLiquidSlider> createState() => _OnboardingLiquidSliderState();
}

class _OnboardingLiquidSliderState extends State<OnboardingLiquidSlider> {
  double _dragPercent = -1.0;

  @override
  Widget build(BuildContext context) {
    int selectedIndex = widget.options.indexOf(widget.selectedValue);

    final int steps = widget.options.length - 1;
    final double targetPercent = selectedIndex >= 0 && steps > 0
        ? selectedIndex / steps
        : 0.0;
    final double currentPercent = _dragPercent >= 0
        ? _dragPercent
        : targetPercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDragging = _dragPercent >= 0;
        final double thumbSize = isDragging ? 34.0 : 26.0;
        const double trackHorizontalPadding = 20.0;
        final double trackWidth = width - (trackHorizontalPadding * 2);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            RenderBox box = context.findRenderObject() as RenderBox;
            Offset localOffset = box.globalToLocal(details.globalPosition);
            double percent =
                (localOffset.dx - trackHorizontalPadding) / trackWidth;
            percent = percent.clamp(0.0, 1.0);
            setState(() {
              _dragPercent = percent;
            });
          },
          onHorizontalDragEnd: (details) {
            _snapTo(_dragPercent, steps);
          },
          onTapDown: (details) {
            RenderBox box = context.findRenderObject() as RenderBox;
            Offset localOffset = box.globalToLocal(details.globalPosition);
            double percent =
                (localOffset.dx - trackHorizontalPadding) / trackWidth;
            percent = percent.clamp(0.0, 1.0);
            _snapTo(percent, steps);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                SizedBox(
                  height: 34.0, // Fixed height to prevent layout shift
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: trackHorizontalPadding,
                        right: trackHorizontalPadding,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: trackHorizontalPadding,
                        width: trackWidth * currentPercent,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.accent.withValues(alpha: 0.4),
                                widget.accent.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Positioned(
                        left:
                            trackHorizontalPadding +
                            (trackWidth * currentPercent) -
                            (thumbSize / 2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.85),
                            border: Border.all(color: Colors.white, width: 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accent.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.accent.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 20,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(widget.options.length, (index) {
                      final percent = steps > 0 ? index / steps : 0.0;
                      final isSelected = index == selectedIndex;

                      const double labelWidth = 80.0;
                      final double leftOffset =
                          trackHorizontalPadding +
                          (trackWidth * percent) -
                          (labelWidth / 2);

                      return Positioned(
                        left: leftOffset,
                        width: labelWidth,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: isSelected
                                ? OptivusColors.textPrimary
                                : OptivusColors.textSecondary,
                            fontSize: isSelected ? 11 : 10,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          child: Text(widget.options[index]),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _snapTo(double percent, int steps) {
    if (steps <= 0) return;
    int index = (percent * steps).round();
    widget.onChanged(widget.options[index]);
    setState(() {
      _dragPercent = -1.0;
    });
  }
}

class OnboardingUnitToggle extends StatelessWidget {
  final String option1;
  final String option2;
  final bool isOption1;
  final ValueChanged<bool> onChanged;

  const OnboardingUnitToggle({
    super.key,
    required this.option1,
    required this.option2,
    required this.isOption1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const double toggleHeight = 28.0;
    const double pillWidth = 36.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!isOption1),
      child: Container(
        height: toggleHeight,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          boxShadow: [],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: isOption1
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: pillWidth,
                  height: toggleHeight - 6,
                  decoration: BoxDecoration(
                    color: OptivusColors.brandAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: OptivusColors.brandAccent.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: pillWidth,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        color: isOption1
                            ? Colors.white
                            : OptivusColors.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontFamily: 'Inter',
                      ),
                      child: Text(option1),
                    ),
                  ),
                ),
                SizedBox(
                  width: pillWidth,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        color: !isOption1
                            ? Colors.white
                            : OptivusColors.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontFamily: 'Inter',
                      ),
                      child: Text(option2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingLiquidContinuousSlider extends StatefulWidget {
  final double value;
  final String valueLabel;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Color accent;

  const OnboardingLiquidContinuousSlider({
    super.key,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.onChanged,
    this.accent = OptivusColors.brandAccent,
  });

  @override
  State<OnboardingLiquidContinuousSlider> createState() =>
      _OnboardingLiquidContinuousSliderState();
}

class _OnboardingLiquidContinuousSliderState
    extends State<OnboardingLiquidContinuousSlider> {
  double _dragValue = -1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDragging = _dragValue >= 0;
        final double thumbSize = isDragging ? 34.0 : 26.0;
        const double trackHorizontalPadding = 20.0;
        final double trackWidth = width - (trackHorizontalPadding * 2);

        final double range = widget.max - widget.min;
        double currentPercent = isDragging
            ? (_dragValue - widget.min) / range
            : (widget.value - widget.min) / range;

        currentPercent = currentPercent.clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            RenderBox box = context.findRenderObject() as RenderBox;
            Offset localOffset = box.globalToLocal(details.globalPosition);
            double percent =
                (localOffset.dx - trackHorizontalPadding) / trackWidth;
            percent = percent.clamp(0.0, 1.0);
            double newValue = widget.min + (percent * range);
            setState(() {
              _dragValue = newValue;
            });
            widget.onChanged(newValue);
          },
          onHorizontalDragEnd: (details) {
            setState(() {
              _dragValue = -1.0;
            });
          },
          onHorizontalDragCancel: () {
            setState(() {
              _dragValue = -1.0;
            });
          },
          onTapDown: (details) {
            RenderBox box = context.findRenderObject() as RenderBox;
            Offset localOffset = box.globalToLocal(details.globalPosition);
            double percent =
                (localOffset.dx - trackHorizontalPadding) / trackWidth;
            percent = percent.clamp(0.0, 1.0);
            double newValue = widget.min + (percent * range);
            widget.onChanged(newValue);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 32.0),
            child: SizedBox(
              height: 34.0,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: trackHorizontalPadding,
                    right: trackHorizontalPadding,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: trackHorizontalPadding,
                    width: trackWidth * currentPercent,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.accent.withValues(alpha: 0.4),
                            widget.accent.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left:
                        trackHorizontalPadding +
                        (trackWidth * currentPercent) -
                        (thumbSize / 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.85),
                        border: Border.all(color: Colors.white, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accent.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left:
                        trackHorizontalPadding +
                        (trackWidth * currentPercent) -
                        30,
                    top: 36,
                    child: SizedBox(
                      width: 60,
                      child: Text(
                        widget.valueLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: OptivusColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
