import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// Shows the AI Routine Assistant bottom sheet.
void showAIAssistantSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AIAssistantSheetBody(),
  );
}

class _AIAssistantSheetBody extends StatefulWidget {
  const _AIAssistantSheetBody();

  @override
  State<_AIAssistantSheetBody> createState() => _AIAssistantSheetBodyState();
}

class _AIAssistantSheetBodyState extends State<_AIAssistantSheetBody> {
  int? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0FFF0), Color(0xFFDCFFCC)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 22,
                    color: Color(0xFFA56CF0),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI Routine Assistant',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: OptivusColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Smart suggestions powered by AI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: OptivusColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              ..._options.asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value;
                final isSelected = _selectedOption == idx;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedOption = isSelected ? null : idx;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? opt.color.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? opt.color.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(opt.icon, size: 20, color: opt.color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? opt.color
                                        : OptivusColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: OptivusColors.textMuted,
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 12),
                            // Mock suggestion card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.suggestion,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: OptivusColors.textBody,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _ActionPill(
                                        label: 'Accept',
                                        color: OptivusColors.success,
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'AI suggestion applied',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionPill(
                                        label: 'Edit',
                                        color: OptivusColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionPill(
                                        label: 'Reject',
                                        color: OptivusColors.danger,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionPill({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AIOption {
  final String title;
  final IconData icon;
  final Color color;
  final String suggestion;
  const _AIOption(this.title, this.icon, this.color, this.suggestion);
}

const _options = [
  _AIOption(
    'Improve today\'s plan',
    Icons.auto_fix_high,
    Color(0xFF8B5CF6),
    'Move your Meditation from 7:40 AM to 6:30 AM for better cortisol sync. Also, add a 10-min stretch after Gym at 7:15 PM.',
  ),
  _AIOption(
    'Fill free time',
    Icons.schedule,
    Color(0xFF3B82F6),
    'You have a 2h gap from 5:00–6:30 PM after class. I suggest: 30 min Reading, 15 min Hydration check, then Gym prep.',
  ),
  _AIOption(
    'Fix conflicts',
    Icons.warning_amber,
    Color(0xFFEF5B5B),
    'Lunch (1:00 PM) overlaps with Class (9:00 AM – 5:00 PM). Mark Lunch as allowOverlap since you eat during class break.',
  ),
  _AIOption(
    'Create tiny version for busy day',
    Icons.compress,
    Color(0xFFF59E0B),
    'Tiny day: 5 min meditation, 15 min reading, skip gym (rest day), keep meal blocks. Estimated: 3 hard blocks only.',
  ),
  _AIOption(
    'Suggest better task order',
    Icons.swap_vert,
    Color(0xFF10B981),
    'Move skin care before meditation for better habit stacking. Your current order breaks the "anchor chain" pattern.',
  ),
  _AIOption(
    'Rebuild this week',
    Icons.calendar_month,
    Color(0xFF14B8A6),
    'Based on your patterns: Mon/Wed/Fri → full gym days, Tue/Thu → light + focus sessions, Weekend → flexible recovery.',
  ),
];
