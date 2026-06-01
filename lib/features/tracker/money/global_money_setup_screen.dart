import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/utils/currency_formatter.dart';
import 'package:optivus/core/widgets/liquid_buttons.dart';
import 'package:optivus/core/widgets/liquid_detail_scaffold.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

class GlobalMoneySetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const GlobalMoneySetupScreen({super.key, required this.onBack});

  @override
  ConsumerState<GlobalMoneySetupScreen> createState() =>
      _GlobalMoneySetupScreenState();
}

class _GlobalMoneySetupScreenState
    extends ConsumerState<GlobalMoneySetupScreen> {
  late double _dailyTinyTarget;
  late MoneySaveMethod _savingMethod;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final goal = ref.read(mockTrackerProvider).moneyGoal;
    final region = ref.read(regionSettingsProvider);
    _dailyTinyTarget = goal.tinySaveAmount > 0
        ? goal.tinySaveAmount
        : defaultTinySaveAmount(region);
    _savingMethod =
        goal.defaultMethod == MoneySaveMethod.upiMock &&
            region.paymentRegion != PaymentRegion.indiaUpi
        ? MoneySaveMethod.cash
        : goal.defaultMethod;
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(regionSettingsProvider);
    final goal = ref.watch(mockTrackerProvider).moneyGoal;
    final paymentLabels = _paymentOptions(region);
    final targetOptions = <double>{
      defaultTinySaveAmount(region),
      goal.tinySaveAmount,
      goal.currentLevelAmount,
      region.currencyCode == 'JPY' ? 500 : 5,
      region.currencyCode == 'INR' ? 50 : 10,
    }.where((amount) => amount > 0).toList(growable: false)..sort();

    return LiquidDetailScaffold(
      eyebrow: 'Tracker',
      title: 'Global Money Setup',
      subtitle:
          'Currency, tiny saving target, local payment options, and proof rules.',
      accentColor: OptivusColors.trackerAccent,
      onBack: widget.onBack,
      children: [
        LiquidDetailSection(
          title: 'Currency',
          children: [
            _InfoRow(
              icon: Icons.public_rounded,
              title: '${region.countryName} currency',
              body:
                  '${region.currencyCode} ${region.currencySymbol} is used across Money System UI.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _CountryShortcut(label: 'India'),
                _CountryShortcut(label: 'United States'),
                _CountryShortcut(label: 'Japan'),
                _CountryShortcut(label: 'Europe'),
              ],
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Daily Tiny Saving Target',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: targetOptions
                  .map(
                    (amount) => _ChoiceChip(
                      label: formatMoney(amount, region),
                      selected: _dailyTinyTarget == amount,
                      onTap: () => setState(() {
                        _dailyTinyTarget = amount;
                        _saved = false;
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              'Current tiny save: ${formatMoney(_dailyTinyTarget, region)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: OptivusColors.ink,
              ),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Saving Method',
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _savingMethods(region)
                  .map(
                    (method) => _ChoiceChip(
                      label: _methodLabel(method, region),
                      selected: _savingMethod == method,
                      onTap: () => setState(() {
                        _savingMethod = method;
                        _saved = false;
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Payment Options by Country',
          children: [
            _InfoRow(
              icon: Icons.account_balance_wallet_outlined,
              title: region.paymentRegionLabel,
              body:
                  'Manual saving works everywhere. Region-specific payment apps are labels only until native integrations are added.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: paymentLabels
                  .map(
                    (label) => _ChoiceChip(
                      label: label,
                      selected: label == _methodLabel(_savingMethod, region),
                      onTap: () => setState(() {
                        _savingMethod = _methodFromLabel(label);
                        _saved = false;
                      }),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            const _Notice(
              text:
                  'Optivus does not hold money. You save using your own bank, cash, or local payment app.',
            ),
          ],
        ),
        LiquidDetailSection(
          title: 'Rules',
          children: [
            _InfoRow(
              icon: Icons.check_circle_outline_rounded,
              title: 'Manual saving',
              body: goal.manualConfirmationAllowed
                  ? 'Allowed everywhere.'
                  : 'Disabled in Money System settings.',
            ),
            _InfoRow(
              icon: Icons.swap_horiz_rounded,
              title: 'Bad habit money conversion',
              body:
                  'Avoided spend starts as potential money. Convert it only when you actually save outside Optivus.',
            ),
            _InfoRow(
              icon: Icons.arrow_upward_rounded,
              title: 'Level-up rule',
              body:
                  'After ${goal.levelUpAfterDays} successful days, Optivus can suggest a higher daily target.',
            ),
          ],
        ),
        LiquidPrimaryButton(
          label: _saved ? 'Saved' : 'Save money setup',
          icon: _saved
              ? Icons.check_circle_outline_rounded
              : Icons.save_outlined,
          backgroundColor: OptivusColors.trackerAccent,
          foregroundColor: OptivusColors.ink,
          onPressed: () {
            final effectiveMethod =
                _savingMethod == MoneySaveMethod.upiMock &&
                    region.paymentRegion != PaymentRegion.indiaUpi
                ? MoneySaveMethod.custom
                : _savingMethod;
            ref
                .read(mockTrackerProvider.notifier)
                .updateMoneySettings(
                  currencyCode: region.currencyCode,
                  tinySaveAmount: _dailyTinyTarget,
                  defaultMethod: effectiveMethod,
                  dailyTarget: goal.currentLevelAmount <= 0
                      ? _dailyTinyTarget
                      : goal.currentLevelAmount,
                );
            if (effectiveMethod != _savingMethod) {
              _savingMethod = effectiveMethod;
            }
            setState(() => _saved = true);
          },
        ),
      ],
    );
  }

  List<MoneySaveMethod> _savingMethods(RegionSettings region) {
    return [
      MoneySaveMethod.cash,
      MoneySaveMethod.bankTransfer,
      MoneySaveMethod.custom,
      if (region.paymentRegion == PaymentRegion.indiaUpi)
        MoneySaveMethod.upiMock,
      MoneySaveMethod.secondAccount,
    ];
  }

  List<String> _paymentOptions(RegionSettings region) {
    if (region.paymentRegion == PaymentRegion.indiaUpi) {
      return const [
        'Manual confirmation',
        'Cash',
        'Bank transfer',
        'UPI',
        'GPay',
        'PhonePe',
        'Paytm',
        'BHIM',
      ];
    }
    if (region.countryCode == 'JP') {
      return const ['Manual', 'Bank', 'Cash', 'Local wallet later'];
    }
    if (region.countryCode == 'US') {
      return const ['Manual', 'Bank', 'Cash', 'Savings app later'];
    }
    return const [
      'Manual confirmation',
      'Cash',
      'Bank transfer',
      'Other savings app',
    ];
  }

  String _methodLabel(MoneySaveMethod method, RegionSettings region) {
    return switch (method) {
      MoneySaveMethod.upiMock =>
        region.paymentRegion == PaymentRegion.indiaUpi ? 'UPI' : 'Payment app',
      MoneySaveMethod.cash => 'Cash',
      MoneySaveMethod.bankTransfer => 'Bank transfer',
      MoneySaveMethod.secondAccount => 'Other savings app',
      MoneySaveMethod.familyAccount => 'Family account',
      MoneySaveMethod.custom => 'Manual confirmation',
      MoneySaveMethod.none => 'None',
    };
  }

  MoneySaveMethod _methodFromLabel(String label) {
    return switch (label) {
      'UPI' ||
      'GPay' ||
      'PhonePe' ||
      'Paytm' ||
      'BHIM' => MoneySaveMethod.upiMock,
      'Cash' => MoneySaveMethod.cash,
      'Bank' || 'Bank transfer' => MoneySaveMethod.bankTransfer,
      'Other savings app' ||
      'Savings app later' ||
      'Local wallet later' => MoneySaveMethod.secondAccount,
      _ => MoneySaveMethod.custom,
    };
  }
}

class _CountryShortcut extends ConsumerWidget {
  final String label;

  const _CountryShortcut({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(regionSettingsProvider);
    final selected = settings.countryName == label;
    return _ChoiceChip(
      label: label,
      selected: selected,
      onTap: () =>
          ref.read(regionSettingsProvider.notifier).applyCountryPreset(label),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
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
              ? OptivusColors.trackerAccent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? OptivusColors.trackerAccent
                : OptivusColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? OptivusColors.trackerAccent : OptivusColors.ink,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: OptivusColors.trackerAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: OptivusColors.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OptivusColors.trackerAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OptivusColors.trackerAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1.4,
          color: OptivusColors.ink,
        ),
      ),
    );
  }
}
