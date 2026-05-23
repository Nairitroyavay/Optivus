import re

# 1. Update BaseTimelineStep (Replace TabBar with OnboardingChip Row)
f3 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/steps/base_timeline_step.dart'
with open(f3, 'r') as f:
    c3 = f.read()

# Add listener
old_init = """  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }"""
new_init = """  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }"""
c3 = c3.replace(old_init, new_init)

# Replace TabBar
old_tabbar = """                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        OptivusColors.aquaAccent.withValues(alpha: 0.4),
                        const Color(0xFFFF88C9).withValues(alpha: 0.4)
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  labelColor: OptivusColors.textPrimary,
                  unselectedLabelColor: OptivusColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  tabs: _tabs.map((label) => Tab(text: label)).toList(),
                ),"""
new_tabbar = """                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _tabs.asMap().entries.map((e) {
                      final isSelected = _tabController.index == e.key;
                      return Padding(
                        padding: EdgeInsets.only(right: e.key == _tabs.length - 1 ? 0 : 8),
                        child: OnboardingChip(
                          label: e.value,
                          selected: isSelected,
                          onTap: () => _tabController.animateTo(e.key),
                          accent: e.key == 0 ? OptivusColors.aquaAccent : 
                                  e.key == 1 ? OptivusColors.brandAccent : 
                                  e.key == 2 ? OptivusColors.brandAccent :
                                  OptivusColors.aquaAccent,
                        ),
                      );
                    }).toList(),
                  ),
                ),"""
c3 = c3.replace(old_tabbar, new_tabbar)

# Also fix the OnboardingGlassCard padding around the tabbar so it fits the chips nicely
old_tab_card = """              OnboardingGlassCard(
                padding: const EdgeInsets.all(6),
                radius: 22,"""
new_tab_card = """              OnboardingGlassCard(
                padding: const EdgeInsets.all(12),
                radius: 22,"""
c3 = c3.replace(old_tab_card, new_tab_card)

with open(f3, 'w') as f:
    f.write(c3)


# 2. Update OnboardingSaveButton
f2 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_save_button.dart'
with open(f2, 'r') as f:
    c2 = f.read()

old_save = """            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  color: success
                      ? OptivusColors.success.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: success
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 2,
                      left: 6,
                      right: 6,
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _content(success),
                    ),
                  ],
                ),
              ),
            ),"""

new_save = """            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_height / 2),
                  color: success
                      ? OptivusColors.success.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                  gradient: success
                      ? RadialGradient(
                          center: const Alignment(-0.3, -0.8),
                          radius: 1.5,
                          colors: [
                            Colors.white.withValues(alpha: 0.8),
                            OptivusColors.success.withValues(alpha: 0.5),
                            OptivusColors.success.withValues(alpha: 0.1),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                  border: Border.all(
                    color: success
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.6),
                    width: success ? 2.0 : 1.5,
                  ),
                  boxShadow: success ? [
                    BoxShadow(
                      color: OptivusColors.success.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ] : [],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 1,
                      left: 4,
                      right: 4,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _content(success),
                      ),
                    ),
                  ],
                ),
              ),
            ),"""
c2 = c2.replace(old_save, new_save)
with open(f2, 'w') as f:
    f.write(c2)


# 3. Update OnboardingStepShell Indicator
f1 = '/Users/roy/optivus2/Optivus/lib/features/onboarding/widgets/onboarding_step_shell.dart'
with open(f1, 'r') as f:
    c1 = f.read()

old_pill_track = """                Positioned(
                  left: pillLeft,
                  top: pillTopLocal,
                  width: pillWidth,
                  height: _pillH,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_pillH / 2),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF89F4DD), Color(0xAA89F4DD), Color(0x4489F4DD)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.95),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_pillH / 2),
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
                ),"""

new_pill_track = """                Positioned(
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
c1 = c1.replace(old_pill_track, new_pill_track)
with open(f1, 'w') as f:
    f.write(c1)

print('Done applying super liquid modifications!')
