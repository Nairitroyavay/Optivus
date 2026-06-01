import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/widgets/home_glass_widgets.dart';

double liquidTabBarReserve(BuildContext context) {
  final media = MediaQuery.of(context);
  return 76.0 + media.padding.bottom + media.viewInsets.bottom + 48.0;
}

class LiquidDetailScaffold extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool includeBottomReserve;

  const LiquidDetailScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.onBack,
    required this.children,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 0),
    this.includeBottomReserve = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = includeBottomReserve ? liquidTabBarReserve(context) : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverList.list(
                children: [
                  LiquidDetailHeader(
                    eyebrow: eyebrow,
                    title: title,
                    subtitle: subtitle,
                    accentColor: accentColor,
                    onBack: onBack,
                    trailing: trailing,
                  ),
                  const SizedBox(height: 20),
                  ...children,
                  SizedBox(height: bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiquidDetailHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onBack;
  final Widget? trailing;

  const LiquidDetailHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LiquidGlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          color: accentColor,
          onTap: onBack,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                  color: OptivusColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: OptivusColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2.2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(size / 2.2),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.14),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: OptivusColors.textPrimary, size: 18),
          ),
        ),
      ),
    );
  }
}

class LiquidDetailSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final Color? tint;

  const LiquidDetailSection({
    super.key,
    this.title,
    required this.children,
    this.padding = const EdgeInsets.all(18),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(
            title!.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: OptivusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
        ],
        ...children,
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HomeGlassCard(padding: padding, tint: tint, child: content),
    );
  }
}

class LiquidActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  const LiquidActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accentColor,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? OptivusColors.danger : accentColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: destructive
                          ? OptivusColors.danger
                          : OptivusColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: OptivusColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (trailing != null)
              Flexible(child: trailing!)
            else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: OptivusColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class LiquidPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const LiquidPill({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: filled ? 0 : 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}
