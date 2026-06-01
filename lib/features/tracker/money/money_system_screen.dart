import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_screen_scaffold.dart';
import 'package:optivus/features/tracker/money/money_system_mock_flows.dart';
import 'package:optivus/features/tracker/money/money_system_widgets.dart';
import 'package:optivus/features/tracker/widgets/tracker_components.dart';

class MoneySystemScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const MoneySystemScreen({super.key, this.onBack});

  @override
  ConsumerState<MoneySystemScreen> createState() => _MoneySystemScreenState();
}

class _MoneySystemScreenState extends ConsumerState<MoneySystemScreen> {
  int _selectedTabIndex = 0;

  static const List<String> _tabs = [
    'Today',
    'History',
    'Bad Habit Savings',
    'Goals',
    'Insights',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final embedded = widget.onBack != null;
    final body = _MoneySystemContent(
      selectedTabIndex: _selectedTabIndex,
      tabs: _tabs,
      embedded: embedded,
      onBack: widget.onBack ?? () => Navigator.of(context).pop(),
      onInfo: () => showMoneyInfoSheet(context, ref),
      onTabSelected: (index) => setState(() => _selectedTabIndex = index),
      tabContent: _buildTabContent(),
    );

    if (embedded) return body;

    return LiquidScreenScaffold(
      topColor: OptivusColors.trackerTop,
      bottomColor: OptivusColors.trackerBottom,
      child: SafeArea(bottom: false, child: body),
    );
  }

  Widget _buildTabContent() {
    return switch (_selectedTabIndex) {
      0 => const TodayTabContent(),
      1 => const HistoryTabContent(),
      2 => const BadHabitTabContent(),
      3 => const GoalsTabContent(),
      4 => const InsightsTabContent(),
      5 => const SettingsTabContent(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _MoneySystemContent extends StatelessWidget {
  final int selectedTabIndex;
  final List<String> tabs;
  final bool embedded;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final ValueChanged<int> onTabSelected;
  final Widget tabContent;

  const _MoneySystemContent({
    required this.selectedTabIndex,
    required this.tabs,
    required this.embedded,
    required this.onBack,
    required this.onInfo,
    required this.onTabSelected,
    required this.tabContent,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        embedded ? 16 : 20,
        20,
        bottomInset + (embedded ? 132 : 40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneyHeader(onBack: onBack, onInfo: onInfo),
          const SizedBox(height: 22),
          const MoneyHeroTargetCard(),
          const SizedBox(height: 24),
          const TodayFinanceProofCard(),
          const SizedBox(height: 24),
          const WeeklySavingStrip(),
          const SizedBox(height: 24),
          const MoneySourcesSummary(),
          const SizedBox(height: 30),
          _MoneyTabSelector(
            tabs: tabs,
            selectedIndex: selectedTabIndex,
            onSelected: onTabSelected,
          ),
          const SizedBox(height: 22),
          tabContent,
        ],
      ),
    );
  }
}

class _MoneyHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onInfo;

  const _MoneyHeader({required this.onBack, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TrackerHeaderButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Money System',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: OptivusColors.ink,
                  letterSpacing: 0,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Real saving discipline. Optivus never holds your money.',
                style: TextStyle(
                  fontSize: 12,
                  color: OptivusColors.sub,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TrackerHeaderButton(icon: Icons.info_outline_rounded, onTap: onInfo),
      ],
    );
  }
}

class _MoneyTabSelector extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _MoneyTabSelector({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? OptivusColors.trackerAccent.withValues(alpha: 0.16)
                    : OptivusColors.trackerCardTint.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? OptivusColors.trackerAccent
                      : OptivusColors.borderSoft,
                ),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected
                      ? OptivusColors.trackerAccent
                      : OptivusColors.ink,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
