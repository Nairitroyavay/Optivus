import 'package:flutter/material.dart';
import 'package:optivus/core/theme/optivus_colors.dart';

/// A filter chip with selected state animation matching Optivus liquid style.
class LiquidChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final IconData? icon;
  final String? emoji;

  const LiquidChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.selectedColor,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? OptivusColors.brandAccent;
    final maxWidth = MediaQuery.of(context).size.width - 48;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(120.0, 480.0).toDouble(),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? accent : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : OptivusColors.borderSoft,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : OptivusColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : OptivusColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrap of filter chips for multi-select or single-select scenarios.
class LiquidChipGroup extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final Color? selectedColor;
  final bool singleSelect;

  const LiquidChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.selectedColor,
    this.singleSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        return LiquidChip(
          label: opt,
          isSelected: selected.contains(opt),
          selectedColor: selectedColor,
          onTap: () => onToggle(opt),
        );
      }).toList(),
    );
  }
}
