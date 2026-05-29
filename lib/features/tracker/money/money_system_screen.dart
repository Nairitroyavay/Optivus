import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_screen_scaffold.dart';
import 'package:optivus/features/tracker/money/money_system_widgets.dart';

class MoneySystemScreen extends StatefulWidget {
  const MoneySystemScreen({super.key});

  @override
  State<MoneySystemScreen> createState() => _MoneySystemScreenState();
}

class _MoneySystemScreenState extends State<MoneySystemScreen> {
  // Mock state
  String _todayStatus = 'Not saved yet';
  double _confirmedSaved = 240.0;
  final double _potentialSaved = 350.0;
  int _streakDays = 7;
  final double _currentLevel = 10.0;
  final double _nextLevel = 25.0;

  int _selectedTabIndex = 0;
  final List<String> _tabs = [
    'Today',
    'History',
    'Bad Habit Savings',
    'Goals',
    'Insights',
    'Settings'
  ];

  void _markSaved() {
    setState(() {
      _todayStatus = 'Saved';
      _confirmedSaved += 10.0;
      _streakDays += 1;
    });
  }

  void _markSkipped() {
    setState(() {
      _todayStatus = 'Skipped';
      _streakDays = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LiquidScreenScaffold(
      topColor: OptivusColors.trackerTop,
      appBar: _buildAppBar(context),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoneyHeroTargetCard(
                status: _todayStatus,
                confirmedSaved: _confirmedSaved,
                potentialSaved: _potentialSaved,
                streakDays: _streakDays,
                currentLevel: _currentLevel,
                nextLevel: _nextLevel,
              ),
              const SizedBox(height: 24),
              const WeeklySavingStrip(),
              const SizedBox(height: 24),
              const MoneySourcesSummary(),
              const SizedBox(height: 32),
              _buildTabSelector(),
              const SizedBox(height: 24),
              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: OptivusColors.ink, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Optivus Money System',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Real saving discipline. Optivus never holds your money.',
            style: TextStyle(
              fontSize: 10,
              color: OptivusColors.sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: OptivusColors.sub),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Optivus tracks discipline, not money.')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    // A horizontal scrolling list of tabs as it's 6 tabs.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? OptivusColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? OptivusColors.ink : OptivusColors.borderSoft,
                ),
              ),
              child: Text(
                _tabs[index],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : OptivusColors.ink,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return TodayTabContent(
          status: _todayStatus,
          onSaved: _markSaved,
          onSkipped: _markSkipped,
        );
      case 1:
        return const HistoryTabContent();
      case 2:
        return const BadHabitTabContent();
      case 3:
        return const GoalsTabContent();
      case 4:
        return const InsightsTabContent();
      case 5:
        return const SettingsTabContent();
      default:
        return const SizedBox.shrink();
    }
  }
}
