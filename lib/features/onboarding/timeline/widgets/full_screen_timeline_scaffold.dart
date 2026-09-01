import 'package:flutter/material.dart';
import '../../../../core/theme/optivus_colors.dart';
import '../../widgets/onboarding_glass_widgets.dart';
import '../layout/timeline_overlap_engine.dart';
import '../models/timeline_entry.dart';
import '../models/timeline_geometry.dart';
import '../models/timeline_style.dart';
import 'timeline_day_chips.dart';
import 'timeline_viewport.dart';

/// Presentation mode for the timeline widget.
enum TimelineMode {
  /// Full-screen interactive and editable timeline experience.
  fullScreenEditable,

  /// Read-only summary preview (used in Step 14 review).
  previewReadOnly,
}

/// Presentation mode within an onboarding step.
enum OnboardingTimelinePresentationMode {
  /// Initial setup / input / upload mode.
  setup,

  /// Full-screen timeline presentation mode after generation success.
  timeline,
}

/// Full-screen timeline scaffold.
///
/// Provides top header/banner, day chips, timeline viewport, and empty-state presentation.
class FullScreenTimelineScaffold extends StatelessWidget {
  final List<TimelineEntry> entries;
  final int selectedDay;
  final ValueChanged<int> onDayChanged;
  final TimelineEntryStyle Function(TimelineEntry) styleBuilder;
  final ValueChanged<TimelineEntry>? onEntryTapped;
  final TimelineMode mode;
  final Widget? headerBanner;
  final String? title;
  final String? subtitle;
  final String emptyDayMessage;
  final Color accent;
  final TimelineGeometryConfig geometryConfig;
  final Widget? bottomAction;
  final ScrollController? scrollController;
  final Widget Function(BuildContext, PositionedTimelineEntry)? blockBuilder;

  const FullScreenTimelineScaffold({
    super.key,
    required this.entries,
    required this.selectedDay,
    required this.onDayChanged,
    required this.styleBuilder,
    this.onEntryTapped,
    this.mode = TimelineMode.fullScreenEditable,
    this.headerBanner,
    this.title,
    this.subtitle,
    this.emptyDayMessage = 'No schedule blocks on this day.',
    this.accent = OptivusColors.brandAccent,
    this.geometryConfig = const TimelineGeometryConfig(),
    this.bottomAction,
    this.scrollController,
    this.blockBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutResult = TimelineOverlapEngine.computeLayout(
          entries: entries,
          availableWidth: constraints.maxWidth,
          selectedDay: selectedDay,
          config: geometryConfig,
        );

        final dayEntries = layoutResult.entries;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header / Banner Area ──
            if (headerBanner != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: headerBanner!,
              )
            else if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: OptivusColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: OptivusColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 6),

            // ── Day Chips ──
            TimelineDayChips(
              selectedDay: selectedDay,
              onDayChanged: onDayChanged,
              accent: accent,
            ),

            const SizedBox(height: 4),

            // ── Timeline Viewport / Empty State ──
            Expanded(
              child: dayEntries.isEmpty
                  ? _EmptyDayPlaceholder(
                      message: emptyDayMessage,
                      accent: accent,
                    )
                  : TimelineViewport(
                      layoutResult: layoutResult,
                      styleBuilder: styleBuilder,
                      onEntryTapped: mode == TimelineMode.fullScreenEditable
                          ? onEntryTapped
                          : null,
                      accent: accent,
                      scrollController: scrollController,
                      blockBuilder: blockBuilder,
                    ),
            ),

            // ── Optional Bottom Action ──
            ?bottomAction,
          ],
        );
      },
    );
  }
}

class _EmptyDayPlaceholder extends StatelessWidget {
  final String message;
  final Color accent;

  const _EmptyDayPlaceholder({required this.message, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: OnboardingGlassCard(
          tint: Colors.white.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 36,
                color: accent.withValues(alpha: 0.70),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OptivusColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
