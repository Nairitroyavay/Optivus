"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_glass_widgets.dart'

with open(file_path, 'r') as f:
    content = f.read()

# Replace OnboardingGlassCard
card_orig = """  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? OptivusColors.brandAccent.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.62);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color:
                tint ?? Colors.white.withValues(alpha: selected ? 0.38 : 0.30),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: selected ? 1.7 : 1.1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: selected ? 0.54 : 0.42),
                Colors.white.withValues(alpha: 0.18),
                (selected
                        ? OptivusColors.aquaAccent
                        : OptivusColors.brandAccent)
                    .withValues(alpha: selected ? 0.12 : 0.06),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.055),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.48),
                blurRadius: 10,
                offset: const Offset(-2, -3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }"""

card_new = """  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected ? [
          BoxShadow(
            color: OptivusColors.brandAccent.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(-10, 8),
          ),
          BoxShadow(
            color: OptivusColors.aquaAccent.withValues(alpha: 0.20),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(10, 8),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: tint ?? Colors.white.withValues(alpha: selected ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.6 : 0.45),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: selected ? 0.25 : 0.15),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.02),
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
                          Colors.white.withValues(alpha: 0.8),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -10,
                    right: -10,
                    width: 60,
                    height: 40,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: OptivusColors.brandAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }"""

content = content.replace(card_orig, card_new)

# Replace OnboardingGlassPanel
panel_orig = """  @override
  Widget build(BuildContext context) {
    final innerRadius = radius - 1.5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.70),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.40),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(innerRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.2, 0.45, 1.0],
                      colors: [
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.04),
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
    );
  }"""

panel_new = """  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
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
                color: Colors.white.withValues(alpha: 0.65),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.02),
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
  }"""

content = content.replace(panel_orig, panel_new)

# Replace OnboardingChip
chip_orig = """  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.72),
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : OptivusColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }"""

chip_new = """  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0.7 : 0.45),
                  width: 1.0,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: selected ? 0.4 : 0.25),
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
                            Colors.white.withValues(alpha: 0.8),
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
                        Icon(icon, size: 14, color: selected ? Colors.white : accent),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : OptivusColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
  }"""

content = content.replace(chip_orig, chip_new)

# Replace OnboardingActionPill
pill_orig = """  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 11 : 14,
                vertical: compact ? 8 : 11,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.84)
                    : Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(compact ? 16 : 20),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.58),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? accent.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.045),
                    blurRadius: selected ? 16 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: compact ? 15 : 17,
                      color: selected ? Colors.white : accent,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : OptivusColors.textPrimary,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w900,
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
  }"""

pill_new = """  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final radius = compact ? 16.0 : 20.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.52,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
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
                      ? accent.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: selected ? 0.75 : 0.45),
                    width: 1.0,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: selected ? 0.4 : 0.2),
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
                              Colors.white.withValues(alpha: 0.85),
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
                          Icon(
                            icon,
                            size: compact ? 15 : 17,
                            color: selected ? Colors.white : accent,
                          ),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : OptivusColors.textPrimary,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w900,
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
  }"""

content = content.replace(pill_orig, pill_new)

# Replace OnboardingIconPill
icon_pill_orig = """  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.60)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }"""

icon_pill_new = """  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
  }"""

content = content.replace(icon_pill_orig, icon_pill_new)

# Replace OnboardingDayDroplet
droplet_orig = """  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 36.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: selected
                ? [
                    Colors.white.withValues(alpha: 0.92),
                    color.withValues(alpha: 0.74),
                    color.withValues(alpha: 0.46),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.84),
                    Colors.white.withValues(alpha: 0.42),
                    color.withValues(alpha: 0.16),
                  ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.90 : 0.62),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? color.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? OptivusColors.textPrimary
                : OptivusColors.textSecondary,
            fontSize: selected ? 10 : 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }"""

droplet_new = """  @override
  Widget build(BuildContext context) {
    final size = selected ? 42.0 : 36.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
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
                          Colors.black.withValues(alpha: 0.02),
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
  }"""

content = content.replace(droplet_orig, droplet_new)

# Replace OnboardingLiquidToggle
toggle_orig = """  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 54,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: value
              ? accent.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.38),
          border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: value
                  ? accent.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  (value ? accent : Colors.white).withValues(alpha: 0.76),
                  (value ? accent : OptivusColors.borderSoft).withValues(
                    alpha: 0.36,
                  ),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            ),
          ),
        ),
      ),
    );
  }"""

toggle_new = """  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: value
                  ? accent.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
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
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.35),
                          colors: [
                            Colors.white.withValues(alpha: 0.96),
                            (value ? accent : Colors.white).withValues(alpha: 0.76),
                            (value ? accent : OptivusColors.borderSoft).withValues(alpha: 0.36),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
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
  }"""

content = content.replace(toggle_orig, toggle_new)

with open(file_path, 'w') as f:
    f.write(content)

print('Done rewriting widgets.')
