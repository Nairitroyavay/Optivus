import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:optivus/repositories/auth_repository.dart';
// import 'package:optivus/services/auth_service.dart';
import 'package:optivus/widgets/liquid_glass_tabbar.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';
import 'package:optivus/widgets/animated_bot_avatar.dart';
import 'package:optivus/widgets/app_button.dart';
import 'package:optivus/state/mock_auth_state.dart';

// Per-tab gradient definitions matching the visual palette of the design system
const List<List<Color>> _tabGradients = [
  [Color(0xFFFFB3B3), Color(0xFFFCFFFD)], // Home
  [Color(0xFFA3FF91), Color(0xFFEFFFEC)], // Routine
  [Color(0xFF78EFFF), Color(0xFFE8FCFF)], // Tracker
  [Color(0xFFDCCBFF), Color(0xFFFFFCFF)], // Coach
  [Color(0xFFFFB6DC), Color(0xFFFFFFFC)], // Goals
  [Color(0xFFFFC35C), Color(0xFFFFF4DD)], // Profile
];

class AppShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const AppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  // final AuthRepository _authRepository = AuthRepository(AuthService());

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _tabGradients.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _tabGradients[_currentIndex];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
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
              _buildHeader(),

              // Scrollable Tab View Contents
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Active Tab Content
                      _buildTabContent(),

                      // Important: bottom buffer to prevent contents from being hidden under the floating tabbar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LiquidGlassTabBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        activeColor: _tabGradients[_currentIndex][0],
      ),
    );
  }

  Widget _buildHeader() {
    String title = '';
    String subtitle = '';
    Widget trailing = const SizedBox.shrink();

    switch (_currentIndex) {
      case 0:
        title = 'Optivus';
        subtitle = 'PLAN. EXECUTE. BECOME.';
        trailing = const SizedBox(
          width: 44,
          height: 44,
          child: AnimatedBotAvatar(),
        );
        break;
      case 1:
        title = 'Routines';
        subtitle = 'Daily commitments & habits';
        break;
      case 2:
        title = 'Progress';
        subtitle = 'Visualizing your consistency';
        break;
      case 3:
        title = 'AI Coach';
        subtitle = 'Always supportive, never shaming';
        break;
      case 4:
        title = 'Goals';
        subtitle = 'Identity level targets';
        break;
      default:
        title = 'Profile';
        subtitle = 'Account details & preferences';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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

  Widget _buildTabContent() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildRoutineTab();
      case 2:
        return _buildTrackerTab();
      case 3:
        return _buildCoachTab();
      case 4:
        return _buildGoalsTab();
      default:
        return _buildProfileTab();
    }
  }

  // ── Tab 0: Home ────────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB830),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ONGOING STREAK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '12 Days Unbroken',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F111A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You are currently outperforming 94% of members. Keep up the high standard.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TODAY\'S PRIORITIES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        _GlassListItem(
          title: 'Morning Mindfulness',
          subtitle: '10 min of tranquil deep breathing',
          onTap: () {},
          trailing: const Icon(Icons.circle_outlined, color: Colors.blueGrey),
        ),
        const SizedBox(height: 12),
        _GlassListItem(
          title: 'Advanced AI Architecting',
          subtitle: 'Execute high level coding strategies',
          onTap: () {},
          trailing: const Icon(Icons.circle_outlined, color: Colors.blueGrey),
        ),
      ],
    );
  }

  // ── Tab 1: Routines ────────────────────────────────────────────────────────
  Widget _buildRoutineTab() {
    return Column(
      children: [
        _GlassListItem(
          title: 'Hydration Intake',
          subtitle: 'Target: 3.5 Liters of pure water',
          onTap: () {},
          trailing: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
        ),
        const SizedBox(height: 12),
        _GlassListItem(
          title: 'Read Academic Literature',
          subtitle: '30 minutes of strict absorption',
          onTap: () {},
          trailing: const Icon(Icons.circle_outlined, color: Colors.blueGrey),
        ),
        const SizedBox(height: 12),
        _GlassListItem(
          title: 'Aerobic Threshold Training',
          subtitle: '5km standard road running session',
          onTap: () {},
          trailing: const Icon(Icons.circle_outlined, color: Colors.blueGrey),
        ),
      ],
    );
  }

  // ── Tab 2: Tracker ─────────────────────────────────────────────────────────
  Widget _buildTrackerTab() {
    return Column(
      children: [
        LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F111A),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final completed = index < 5;
                  return Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: completed
                              ? const Color(0xFF78EFFF).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.3),
                          border: Border.all(
                            color: completed
                                ? const Color(0xFF78EFFF)
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            completed ? Icons.check : Icons.close,
                            size: 14,
                            color: completed
                                ? const Color(0xFF0F111A)
                                : Colors.blueGrey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        days[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _GlassListItem(
          title: 'Daily Performance Record',
          subtitle: '94% average completion rate',
          onTap: () {},
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        ),
      ],
    );
  }

  // ── Tab 3: AI Coach ────────────────────────────────────────────────────────
  Widget _buildCoachTab() {
    final mockUser = ref.watch(mockAuthProvider);
    final firstName = mockUser.mockUserName.isNotEmpty
        ? mockUser.mockUserName.split(' ')[0]
        : 'Nairit';

    return Column(
      children: [
        const SizedBox(height: 20),
        const Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: AnimatedBotAvatar(),
          ),
        ),
        const SizedBox(height: 24),
        LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aura Coach',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F111A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '"Greetings, $firstName. I detected you completed your early routine yesterday without friction. That shows immense dedication. How are you feeling about your tasks today?"',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey.shade800,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          text: 'Talk with Coach',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI Chat interface coming soon!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Tab 4: Goals ───────────────────────────────────────────────────────────
  Widget _buildGoalsTab() {
    return Column(
      children: [
        _GlassCategoryCard(
          title: 'Professional Mastery',
          subtitle: 'Architect top-tier software systems',
          icon: Icons.computer_rounded,
          color: const Color(0xFFFFB6DC),
          progress: 0.85,
        ),
        const SizedBox(height: 16),
        _GlassCategoryCard(
          title: 'Peak Physical Conditioning',
          subtitle: 'Develop stamina, flexibility & focus',
          icon: Icons.directions_run_rounded,
          color: const Color(0xFFA3FF91),
          progress: 0.62,
        ),
        const SizedBox(height: 16),
        _GlassCategoryCard(
          title: 'Financial Sovereignty',
          subtitle: 'Secure strategic asset control',
          icon: Icons.monetization_on_outlined,
          color: const Color(0xFFFFC35C),
          progress: 0.40,
        ),
      ],
    );
  }

  // ── Tab 5: Profile ─────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    final mockUser = ref.watch(mockAuthProvider);
    final userName = mockUser.mockUserName.isNotEmpty ? mockUser.mockUserName : 'Nairit Roy';

    return Column(
      children: [
        LiquidGlassPanel(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFC35C),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: Color(0xFF0F111A),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F111A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since May 2026',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _GlassListItem(
          title: 'Settings & Security',
          subtitle: 'Configure privacy and notifications',
          onTap: () {},
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        ),
        const SizedBox(height: 12),
        _GlassListItem(
          title: 'Support Center',
          subtitle: 'Get assistance and leave feedback',
          onTap: () {},
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        ),
        const SizedBox(height: 32),

        // Premium Sign Out Capsule Button
        AppButton(
          text: 'Sign Out',
          onPressed: _signOut,
        ),
      ],
    );
  }

  Future<void> _signOut() async {
    try {
      // TODO: Connect real Firebase Auth later:
      // await _authRepository.signOut();

      // Clear local session state
      ref.read(mockAuthProvider.notifier).logout();

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Private Reusable Glass Widgets for AppShell UI ───────────────────────────

class _GlassListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  const _GlassListItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F111A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _GlassCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;

  const _GlassCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF0F111A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F111A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F111A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
