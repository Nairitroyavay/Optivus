import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_blur_card.dart';
import 'package:optivus/core/widgets/liquid_buttons.dart';
import 'package:optivus/features/tracker/money/money_system_mock_flows.dart';

class MoneyHeroTargetCard extends StatelessWidget {
  final String status;
  final double confirmedSaved;
  final double potentialSaved;
  final int streakDays;
  final double currentLevel;
  final double nextLevel;

  const MoneyHeroTargetCard({
    super.key,
    required this.status,
    required this.confirmedSaved,
    required this.potentialSaved,
    required this.streakDays,
    required this.currentLevel,
    required this.nextLevel,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidBlurCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      child: Column(
        children: [
          const Text(
            'Today\'s target',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OptivusColors.sub,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '₹10',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'Saved' 
                  ? OptivusColors.mintAccent.withValues(alpha: 0.1) 
                  : OptivusColors.trackerAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status == 'Saved' 
                    ? OptivusColors.mintAccent.withValues(alpha: 0.3)
                    : OptivusColors.trackerAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Status: $status',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: status == 'Saved' ? OptivusColors.mintAccent : OptivusColors.trackerAccent,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn('Confirmed saved', '₹${confirmedSaved.toInt()}', OptivusColors.mintAccent),
              _buildStatColumn('Potential saved', '₹${potentialSaved.toInt()}', OptivusColors.purpleAccent),
              _buildStatColumn('Current streak', '$streakDays days', OptivusColors.roseAccent),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: OptivusColors.trackerAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, color: OptivusColors.trackerAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current level: ₹${currentLevel.toInt()}/day',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Next level: ₹${nextLevel.toInt()}/day after 3 more successful days',
                        style: const TextStyle(fontSize: 12, color: OptivusColors.sub, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color accent) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: OptivusColors.sub,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class MoneyQuickActionRow extends StatelessWidget {
  final VoidCallback onSaved;
  final VoidCallback onSkipped;

  const MoneyQuickActionRow({
    super.key,
    required this.onSaved,
    required this.onSkipped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidPrimaryButton(
          label: 'Save via UPI',
          onPressed: () => showSaveViaUpiFlow(context, onSaved),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LiquidOutlineButton(
                label: 'I already saved',
                onPressed: () => showIAlreadySavedFlow(context, onSaved),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LiquidOutlineButton(
                label: 'Skip today',
                onPressed: () => showSkipTodayFlow(context, onSkipped),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WeeklySavingStrip extends StatelessWidget {
  const WeeklySavingStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final days = [
      {'day': 'Mon', 'val': '₹10', 'state': 'saved'},
      {'day': 'Tue', 'val': '₹10', 'state': 'saved'},
      {'day': 'Wed', 'val': '₹10', 'state': 'today'},
      {'day': 'Thu', 'val': '-', 'state': 'empty'},
      {'day': 'Fri', 'val': '-', 'state': 'empty'},
      {'day': 'Sat', 'val': '-', 'state': 'empty'},
      {'day': 'Sun', 'val': '-', 'state': 'empty'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This Week',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: OptivusColors.sub,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((d) {
            final isSaved = d['state'] == 'saved';
            final isToday = d['state'] == 'today';
            return Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSaved 
                    ? OptivusColors.mintAccent.withValues(alpha: 0.1) 
                    : isToday 
                        ? Colors.white.withValues(alpha: 0.6) 
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSaved 
                      ? OptivusColors.mintAccent.withValues(alpha: 0.3)
                      : isToday 
                          ? OptivusColors.trackerAccent 
                          : OptivusColors.borderSoft,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    d['day']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday ? OptivusColors.ink : OptivusColors.sub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    d['val']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSaved ? OptivusColors.mintAccent : OptivusColors.ink,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class MoneySourcesSummary extends StatelessWidget {
  const MoneySourcesSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidBlurCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Money sources',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          _buildSourceRow('Manual saving', '₹150', OptivusColors.blueAccent),
          const SizedBox(height: 12),
          _buildSourceRow('UPI saving', '₹60', OptivusColors.trackerAccent),
          const SizedBox(height: 12),
          _buildSourceRow('Bad habit money converted', '₹30', OptivusColors.purpleAccent),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: OptivusColors.borderSoft),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Confirmed saved total', style: TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.sub)),
              Text('₹240', style: TextStyle(fontWeight: FontWeight.w900, color: OptivusColors.mintAccent, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Potential saved total', style: TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.sub)),
              Text('₹350', style: TextStyle(fontWeight: FontWeight.w900, color: OptivusColors.purpleAccent, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow(String label, String amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: OptivusColors.ink)),
        const Spacer(),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.ink)),
      ],
    );
  }
}

// ── TAB CONTENTS ─────────────────────────────────────────────────────────────

class TodayTabContent extends StatelessWidget {
  final String status;
  final VoidCallback onSaved;
  final VoidCallback onSkipped;

  const TodayTabContent({
    super.key,
    required this.status,
    required this.onSaved,
    required this.onSkipped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidBlurCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today finance proof:',
                style: TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.sub),
              ),
              const SizedBox(height: 8),
              const Text(
                '“Save ₹10 to protect your future self.”',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OptivusColors.ink, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              MoneyQuickActionRow(onSaved: onSaved, onSkipped: onSkipped),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidBlurCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Level progress',
                style: TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.sub),
              ),
              SizedBox(height: 8),
              Text(
                '2 more successful days to unlock ₹25/day suggestion',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: OptivusColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OptivusColors.coachTop.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OptivusColors.coachAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.notifications_active_outlined, color: OptivusColors.coachAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Evening reminder: Protect your future self.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.coachAccent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HistoryTabContent extends StatelessWidget {
  const HistoryTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', true),
              _buildFilterChip('UPI', false),
              _buildFilterChip('Manual', false),
              _buildFilterChip('Cash', false),
              _buildFilterChip('Bad habit money', false),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildHistoryItem('May 20', '₹10', 'UPI', 'Success', OptivusColors.mintAccent),
        _buildHistoryItem('May 19', '₹10', 'Manual', 'Confirmed', OptivusColors.mintAccent),
        _buildHistoryItem('May 18', '-', 'Skipped', 'Skipped', OptivusColors.sub),
        _buildHistoryItem('May 17', '₹10', 'UPI', 'Success', OptivusColors.mintAccent),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? OptivusColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? OptivusColors.ink : OptivusColors.borderSoft),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : OptivusColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String date, String amount, String method, String status, Color statusColor) {
    return LiquidBlurCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.ink)),
                const SizedBox(height: 4),
                Text(method, style: const TextStyle(fontSize: 12, color: OptivusColors.sub)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: OptivusColors.ink)),
              const SizedBox(height: 4),
              Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class BadHabitTabContent extends StatelessWidget {
  const BadHabitTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidBlurCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Potential money saved from avoided bad habits', style: TextStyle(color: OptivusColors.sub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              _buildBadHabitRow('Cigarettes avoided', '₹350 potential saved this week'),
              const SizedBox(height: 16),
              _buildBadHabitRow('Junk food avoided', '₹120 potential saved this week'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: OptivusColors.borderSoft),
              ),
              _buildBadHabitRow('Converted to real savings', '₹200'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: LiquidPrimaryButton(
                      label: 'Save avoided money',
                      onPressed: () => showSaveViaUpiFlow(context, () {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LiquidOutlineButton(
                      label: 'View bad habit tracker',
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: OptivusColors.purpleAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: OptivusColors.purpleAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You avoided cigarettes today.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OptivusColors.ink)),
              const SizedBox(height: 4),
              const Text('Potential saved: ₹50', style: TextStyle(color: OptivusColors.purpleAccent, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              LiquidPrimaryButton(
                label: 'Move ₹50 to savings',
                onPressed: () => showSaveViaUpiFlow(context, () {}),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Keep as avoided money', style: TextStyle(color: OptivusColors.sub, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadHabitRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.ink)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: OptivusColors.sub, fontSize: 13)),
      ],
    );
  }
}

class GoalsTabContent extends StatelessWidget {
  const GoalsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidBlurCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: Column(
            children: [
              const Text('Main Goal', style: TextStyle(color: OptivusColors.sub, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              const Text('Financially Free', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: OptivusColors.ink)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: const [
                      Text('Current level', style: TextStyle(color: OptivusColors.sub, fontSize: 12)),
                      SizedBox(height: 4),
                      Text('₹10/day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: OptivusColors.ink)),
                    ],
                  ),
                  Container(width: 1, height: 40, color: OptivusColors.borderSoft),
                  Column(
                    children: const [
                      Text('Next level', style: TextStyle(color: OptivusColors.sub, fontSize: 12)),
                      SizedBox(height: 4),
                      Text('₹25/day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: OptivusColors.ink)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [OptivusColors.brandAccent, Color(0xFFFDE68A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You saved successfully for 5 days.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OptivusColors.ink)),
              const SizedBox(height: 4),
              const Text('Level up to ₹25/day?', style: TextStyle(color: OptivusColors.ink)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OptivusColors.ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {},
                      child: const Text('Level up to ₹25/day', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Stay ₹10/day', style: TextStyle(color: OptivusColors.ink, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Custom Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OptivusColors.ink)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildGoalChip('Emergency fund'),
            _buildGoalChip('New phone'),
            _buildGoalChip('Course fee'),
            _buildGoalChip('Gym fee'),
            _buildGoalChip('Travel'),
            _buildGoalChip('Business fund'),
            _buildGoalChip('+ Custom'),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: OptivusColors.borderSoft),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: OptivusColors.ink)),
    );
  }
}

class InsightsTabContent extends StatelessWidget {
  const InsightsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _buildInsightCard('This week you saved', '₹70', OptivusColors.mintAccent)),
            const SizedBox(width: 16),
            Expanded(child: _buildInsightCard('You skipped', '1 day', OptivusColors.roseAccent)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildInsightCard('Your best streak is', '7 days', OptivusColors.brandAccent)),
            const SizedBox(width: 16),
            Expanded(child: _buildInsightCard('Converted bad-habit money', '₹100', OptivusColors.purpleAccent)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: OptivusColors.coachTop.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: OptivusColors.coachAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Sensei: ', style: TextStyle(fontWeight: FontWeight.bold, color: OptivusColors.coachAccent, fontSize: 16)),
              Expanded(
                child: Text(
                  '“Your money discipline is working. Keep ₹10/day until it feels automatic.”',
                  style: TextStyle(fontSize: 16, color: OptivusColors.ink, fontStyle: FontStyle.italic, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(String title, String value, Color color) {
    return LiquidBlurCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: OptivusColors.sub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class SettingsTabContent extends StatelessWidget {
  const SettingsTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidBlurCard(
      padding: const EdgeInsets.all(8),
      borderRadius: 24,
      child: Column(
        children: [
          _buildSettingsRow(context, 'Daily target amount', '₹10'),
          _buildSettingsRow(context, 'Saving destination', 'My Second Bank'),
          _buildSettingsRow(context, 'Default UPI app', 'Google Pay'),
          _buildSettingsRow(context, 'Reminder time', '8:00 PM'),
          _buildSettingsRow(context, 'Level-up rule', 'After 5 days'),
          _buildSettingsRow(context, 'Manual confirmation allowed', 'Yes'),
          _buildSettingsRow(context, 'Export savings data', ''),
          _buildSettingsRow(context, 'Reset money system', '', isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(BuildContext context, String title, String value, {bool isDestructive = false}) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? OptivusColors.roseAccent : OptivusColors.ink,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) Text(value, style: const TextStyle(color: OptivusColors.sub)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: isDestructive ? OptivusColors.roseAccent : OptivusColors.sub),
        ],
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open $title settings')),
        );
      },
    );
  }
}
