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
  [OptivusColors.routineBgTop, OptivusColors.routineBgBottom], // Routine: RoutineTab also paints this
  [OptivusColors.trackerTop, Colors.white], // Tracker: #BFFFFE
  [OptivusColors.coachTop, Colors.white], // Coach: #F7E0FF
  [OptivusColors.goalsTop, Colors.white], // Goals: #FFD9F2
  [OptivusColors.profileTop, Colors.white], // Profile: #FCFFD6
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
    _ensureTabLoaded(widget.initialIndex.clamp(0, _tabGradients.length - 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appNavigationProvider.notifier).setTab(
        widget.initialIndex.clamp(0, _tabGradients.length - 1),
      );
    });
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
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Dynamic Premium Header
              _buildHeader(currentIndex),

              // Active Tab Content inside a state-preserving stack
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: List.generate(
                    _tabGradients.length,
                    (index) => _tabCache[index] ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
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

  Widget _buildHeader(int currentIndex) {
    // Home (0), Routine (1), Tracker (2), and Goals (4) tabs render their own custom headers
    if (currentIndex == 0 || currentIndex == 1 || currentIndex == 2 || currentIndex == 4) {
      return const SizedBox.shrink();
    }

    String title = '';
    String subtitle = '';
    Widget trailing = const SizedBox.shrink();

    switch (currentIndex) {
      case 3:
        title = 'AI Coach';
        subtitle = 'Always supportive, never shaming';
        break;
      default:
        title = 'Profile';
        subtitle = 'Account details & preferences';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F111A),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey.shade700,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
