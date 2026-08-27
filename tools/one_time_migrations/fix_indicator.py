"""Archived one-time frontend migration. Do not execute."""

raise SystemExit("Archived migration: do not run against the current repository.")

import re

file_path = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_step_shell.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Make dimensions bigger
old_dims = """  static const double _dotD = 6.0;
  static const double _gap = 9.0;
  static const double _pillH = 13.0;
  static const double _pillW = 22.0;
  static const double _padH = 10.0;
  static const double _padV = 7.0;"""
new_dims = """  static const double _dotD = 8.0;
  static const double _gap = 12.0;
  static const double _pillH = 18.0;
  static const double _pillW = 32.0;
  static const double _padH = 14.0;
  static const double _padV = 9.0;"""
content = content.replace(old_dims, new_dims)

# Update pill styling
old_pill_track = """                Positioned(
                  left: pillLeft,
                  top: pillTopLocal,
                  width: pillWidth,
                  height: _pillH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_pillH / 2),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_pillH / 2),
                          color: const Color(0xFF89F4DD).withValues(alpha: 0.3),
                          gradient: RadialGradient(
                            center: const Alignment(-0.5, -0.8),
                            radius: 1.8,
                            colors: [
                              Colors.white.withValues(alpha: 0.9),
                              const Color(0xFF89F4DD).withValues(alpha: 0.5),
                              const Color(0xFF89F4DD).withValues(alpha: 0.1),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 2,
                              right: 2,
                              height: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),"""

new_pill_track = """                Positioned(
                  left: pillLeft,
                  top: pillTopLocal,
                  width: pillWidth,
                  height: _pillH,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: OptivusColors.success.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(_pillH / 2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1.0,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.white.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Inner liquid color blob
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        OptivusColors.aquaAccent.withValues(alpha: 0.8),
                                        OptivusColors.success.withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // White top inner glow (3D curve)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.85),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.5],
                                    ),
                                  ),
                                ),
                              ),
                              // Top glossy highlight
                              Positioned(
                                top: 1,
                                left: 6,
                                right: 6,
                                height: 3.5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.95),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),"""

content = content.replace(old_pill_track, new_pill_track)

with open(file_path, 'w') as f:
    f.write(content)

print('Done applying real liquid glass to indicator!')
