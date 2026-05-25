import 'package:flutter/material.dart';
import 'package:optivus/features/home/models/home_dashboard_state.dart';
import 'package:optivus/app/app_navigation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_glass_widgets.dart';
import 'sheets/demo_sheet.dart';

class ComingUpCard extends ConsumerWidget {
  final List<ComingUpItem> items;

  const ComingUpCard({super.key, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    return HomeGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMING UP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF8B8178), // brownish gray
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(appNavigationProvider.notifier).goToRoutine(),
                child: Row(
                  children: [
                    const Text(
                      'Open Routine',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7D5B21), // brown/mustard
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF7D5B21)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...items.asMap().entries.map((entry) {
            final isFirst = entry.key == 0;
            final isLast = entry.key == items.length - 1;
            return _buildItemRow(context, entry.value, isFirst, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, ComingUpItem item, bool isFirst, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time
          SizedBox(
            width: 45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.time,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A5A5A),
                  ),
                ),
                Text(
                  item.amPm,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFA0A0A0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Dot & Line
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: isFirst ? 42 : 0,
                  bottom: isLast ? 42 : 0,
                  width: 1,
                  child: Container(color: const Color(0xFFEAE2D3)),
                ),
                Container(
                  width: item.isNext ? 18 : 8,
                  height: item.isNext ? 18 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isNext ? const Color(0xFFE6AE24) : const Color(0xFFD1CDC7),
                    border: item.isNext
                        ? Border.all(color: const Color(0xFFF8EBD8), width: 4)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: GestureDetector(
                onTap: () {
                  DemoSheet.show(context, title: item.title, message: 'Routine / Calendar event details here.');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: item.isNext ? Colors.white : const Color(0xFFFCF8F9),
                    borderRadius: BorderRadius.circular(16),
                    border: item.isNext
                        ? Border.all(color: const Color(0xFFF6E8CE), width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
                    if (item.isNext)
                      const Text(
                        'NEXT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF8B6C23),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
