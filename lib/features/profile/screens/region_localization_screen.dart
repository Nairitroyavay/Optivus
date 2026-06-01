import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/state/region_settings_provider.dart';

class RegionLocalizationScreen extends ConsumerWidget {
  final VoidCallback onBack;

  const RegionLocalizationScreen({super.key, required this.onBack});

  static const _countryPresets = [
    'India',
    'United States',
    'Japan',
    'United Kingdom',
    'Europe',
    'Other / Custom',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(regionSettingsProvider);
    final notifier = ref.read(regionSettingsProvider.notifier);

    return LiquidDetailScaffold(
      eyebrow: 'Profile',
      title: 'Region & Localization',
      subtitle:
          'Country, currency, units, week start, date format, and food vocabulary.',
      accentColor: OptivusColors.profileAccent,
      onBack: onBack,
      children: [
        LiquidDetailSection(
          title: 'Country / Region',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _countryPresets
                  .map(
                    (preset) => _PresetChip(
                      label: preset,
                      selected:
                          settings.countryName == preset ||
                          (preset == 'Other / Custom' &&
                              settings.countryCode == 'ZZ'),
                      onTap: () => notifier.applyCountryPreset(preset),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Locale',
          children: [
            _SummaryRow(
              icon: Icons.public_rounded,
              title: 'Country',
              value: '${settings.countryName} (${settings.countryCode})',
            ),
            _SummaryRow(
              icon: Icons.schedule_rounded,
              title: 'Timezone',
              value: settings.timezone,
            ),
            _SummaryRow(
              icon: Icons.translate_rounded,
              title: 'Language',
              value: settings.languageCode.toUpperCase(),
            ),
            _SummaryRow(
              icon: Icons.payments_outlined,
              title: 'Currency',
              value: '${settings.currencyCode} ${settings.currencySymbol}',
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Measurement Units',
          children: [
            _SegmentRow<MeasurementSystem>(
              label: 'Measurement system',
              values: MeasurementSystem.values,
              selected: settings.measurementSystem,
              labelFor: (value) => value.name,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(measurementSystem: value)),
            ),
            const SizedBox(height: 14),
            _SegmentRow<HeightUnit>(
              label: 'Height',
              values: HeightUnit.values,
              selected: settings.heightUnit,
              labelFor: (value) => value.label,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(heightUnit: value)),
            ),
            const SizedBox(height: 14),
            _SegmentRow<WeightUnit>(
              label: 'Weight',
              values: WeightUnit.values,
              selected: settings.weightUnit,
              labelFor: (value) => value.label,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(weightUnit: value)),
            ),
            const SizedBox(height: 14),
            _SegmentRow<DistanceUnit>(
              label: 'Distance',
              values: DistanceUnit.values,
              selected: settings.distanceUnit,
              labelFor: (value) => value.label,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(distanceUnit: value)),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Calendar & Food',
          children: [
            _SegmentRow<WeekStartDay>(
              label: 'Week start day',
              values: WeekStartDay.values,
              selected: settings.weekStartDay,
              labelFor: (value) => value.label,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(weekStartDay: value)),
            ),
            const SizedBox(height: 14),
            _SegmentRow<TimeFormatPreference>(
              label: 'Time format',
              values: TimeFormatPreference.values,
              selected: settings.timeFormat,
              labelFor: (value) => value.label,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(timeFormat: value)),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              icon: Icons.calendar_month_outlined,
              title: 'Date format',
              value: settings.dateFormat,
            ),
            _SegmentRow<FoodVocabularyMode>(
              label: 'Food vocabulary',
              values: FoodVocabularyMode.values,
              selected: settings.foodVocabularyMode,
              labelFor: (value) => value.label,
              onSelected: (value) =>
                  notifier.save(settings.copyWith(foodVocabularyMode: value)),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Payment Region',
          children: [
            _SummaryRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment options',
              value: settings.paymentRegionLabel,
            ),
            const SizedBox(height: 10),
            const Text(
              'Optivus does not hold money. You save using your own bank, cash, or local payment app.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: OptivusColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? OptivusColors.profileAccent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? OptivusColors.profileAccent
                : OptivusColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected
                ? OptivusColors.profileAccent
                : OptivusColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: OptivusColors.profileAccent, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: OptivusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentRow<T> extends StatelessWidget {
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  const _SegmentRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map(
                (value) => _PresetChip(
                  label: labelFor(value),
                  selected: selected == value,
                  onTap: () => onSelected(value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
