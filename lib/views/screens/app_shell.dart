import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/widgets/liquid_glass_tabbar.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/home/home_tab.dart';
import 'package:optivus/features/routine/routine_tab.dart';
import 'package:optivus/features/tracker/tracker_tab.dart';
import 'package:optivus/features/coach/coach_tab.dart';
import 'package:optivus/features/goals/goals_tab.dart';
import 'package:optivus/features/profile/profile_tab.dart';
import 'package:optivus/app/app_navigation_controller.dart';

// Per-tab gradient definitions using the blueprint OptivusColors tokens exactly
const List<List<Color>> _tabGradients = [
  [OptivusColors.homeTop, Color(0xFFFFEDED)], // Home: #FFE0E0 to #FFEDED
  [
    OptivusColors.routineBgTop,
    OptivusColors.routineBgBottom,
  ], // Routine: RoutineTab also paints this
  [OptivusColors.trackerTop, OptivusColors.trackerBottom], // Tracker: #BFFFFE
  [OptivusColors.coachTop, OptivusColors.coachBottom], // Coach: #F7E0FF
  [OptivusColors.goalsTop, OptivusColors.goalsBottom], // Goals: #FFD9F2
  [OptivusColors.profileTop, OptivusColors.profileBottom], // Profile: #FAFFE3
];

// Per-tab accent colors for active indicator
const List<Color> _tabAccents = [
  OptivusColors.homeAccent, // #F36F78
  OptivusColors.routineAccent, // #72C95F
  OptivusColors.trackerAccent, // #36C6D4
  OptivusColors.coachAccent, // #A56CF0
  OptivusColors.goalsAccent, // #EC5FAE
  OptivusColors.profileAccent, // #C9B63C
];

class AppShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final List<Widget?> _tabCache;

  @override
  void initState() {
    super.initState();
    _tabCache = List<Widget?>.filled(_tabGradients.length, null);
    final initialIndex = widget.initialIndex.clamp(0, _tabGradients.length - 1);
    _ensureTabLoaded(initialIndex);
    ref.read(appNavigationProvider.notifier).setTab(initialIndex);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final nextIndex = widget.initialIndex.clamp(0, _tabGradients.length - 1);
      _ensureTabLoaded(nextIndex);
      ref.read(appNavigationProvider.notifier).setTab(nextIndex);
    }
  }

  void _ensureTabLoaded(int index) {
    _tabCache[index] ??= switch (index) {
      0 => const HomeTab(),
      1 => const RoutineTab(),
      2 => const TrackerTab(),
      3 => const CoachTab(),
      4 => const GoalsTab(),
      _ => const ProfileTab(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(appNavigationProvider);
    _ensureTabLoaded(currentIndex);
    final colors = _tabGradients[currentIndex];

    return Scaffold(
      extendBody: true,
      backgroundColor: OptivusColors.backgroundBottom,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: const [0.0, 0.80],
          ),
        ),
        // IndexedStack preserves state across tabs.
        // No global SafeArea here; each tab manages its own SafeArea.
        child: IndexedStack(
          index: currentIndex,
          children: List.generate(
            _tabGradients.length,
            (index) => _tabCache[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(appNavigationProvider.notifier).setTab(index);
        },
        activeColor: _tabAccents[currentIndex],
      ),
    );
  }
}
