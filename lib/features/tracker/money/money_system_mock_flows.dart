import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/core/utils/currency_formatter.dart';
import 'package:optivus/core/widgets/liquid_bottom_sheet.dart';
import 'package:optivus/core/widgets/liquid_buttons.dart';
import 'package:optivus/models/money_models.dart';
import 'package:optivus/models/region_settings.dart';
import 'package:optivus/state/app_state.dart';
import 'package:optivus/state/region_settings_provider.dart';

enum MoneySettingKind {
  dailyTarget,
  tinySaveAmount,
  destinationLabel,
  defaultMethod,
  reminderTimeLabel,
  levelUpRule,
  manualConfirmationAllowed,
  exportSavingsData,
}

void showSaveViaUpiFlow(
  BuildContext context,
  WidgetRef ref, {
  String? convertEntryId,
  MoneyEntrySource source = MoneyEntrySource.upiMock,
  String? routineTaskId,
  VoidCallback? onSaved,
}) {
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) => _SaveViaUpiSheet(
      ref: ref,
      convertEntryId: convertEntryId,
      source: source,
      routineTaskId: routineTaskId,
      onSaved: onSaved,
    ),
  );
}

void showIAlreadySavedFlow(
  BuildContext context,
  WidgetRef ref, {
  MoneyEntrySource source = MoneyEntrySource.manual,
  String? routineTaskId,
  VoidCallback? onSaved,
}) {
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) => _AlreadySavedSheet(
      ref: ref,
      source: source,
      routineTaskId: routineTaskId,
      onSaved: onSaved,
    ),
  );
}

void showTinySaveFlow(
  BuildContext context,
  WidgetRef ref, {
  String? routineTaskId,
  VoidCallback? onSaved,
}) {
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) =>
        _TinySaveSheet(routineTaskId: routineTaskId, onSaved: onSaved),
  );
}

void showSkipTodayFlow(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onSkipped,
}) {
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) => _SkipTodaySheet(ref: ref, onSkipped: onSkipped),
  );
}

void showMoneyInfoSheet(BuildContext context, WidgetRef ref) {
  final region = ref.read(regionSettingsProvider);
  final isIndiaUpi = region.paymentRegion == PaymentRegion.indiaUpi;
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) => _SheetScaffold(
      title: 'How Money System works',
      subtitle: 'Discipline tracking only',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InfoRow(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Optivus never holds money',
            body:
                'Your cash, bank balance, and savings accounts stay outside Optivus.',
          ),
          const _InfoRow(
            icon: Icons.verified_user_outlined,
            title: 'Proof is local in this build',
            body:
                'This screen records saving discipline, streaks, and progress in local app state.',
          ),
          _InfoRow(
            icon: Icons.payments_outlined,
            title: isIndiaUpi
                ? 'UPI stays outside Optivus'
                : 'Local payment app flow is manual',
            body: isIndiaUpi
                ? 'No real UPI app opens and no transfer is made inside Optivus.'
                : 'Use your own bank, cash, or local payment app. Optivus only records the proof.',
          ),
          const _InfoRow(
            icon: Icons.auto_graph_rounded,
            title: 'Future-ready',
            body:
                'Backend and payment confirmation can be added later without changing the core habit model.',
          ),
        ],
      ),
    ),
  );
}

void showMoneySettingSheet(
  BuildContext context,
  WidgetRef ref,
  MoneySettingKind kind,
) {
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) => _MoneySettingSheet(ref: ref, kind: kind),
  );
}

void showResetMoneyConfirmationSheet(BuildContext context, WidgetRef ref) {
  showLiquidBottomSheet(
    context,
    backgroundColor: OptivusColors.trackerBottom,
    builder: (ctx) => _SheetScaffold(
      title: 'Reset money system?',
      subtitle: 'This clears local savings history.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SoftNotice(
            text:
                'This only resets local frontend data in Optivus. It does not affect any bank, cash, local payment app, or external account.',
            accent: OptivusColors.roseAccent,
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Reset money system',
            backgroundColor: OptivusColors.roseAccent,
            foregroundColor: OptivusColors.ink,
            icon: Icons.restart_alt_rounded,
            onPressed: () {
              ref.read(mockTrackerProvider.notifier).resetMoneySystem();
              Navigator.of(ctx).pop();
            },
          ),
          const SizedBox(height: 10),
          LiquidOutlineButton(
            label: 'Keep my local history',
            borderColor: OptivusColors.trackerAccent,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

class _SaveViaUpiSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final String? convertEntryId;
  final MoneyEntrySource source;
  final String? routineTaskId;
  final VoidCallback? onSaved;

  const _SaveViaUpiSheet({
    required this.ref,
    required this.source,
    this.convertEntryId,
    this.routineTaskId,
    this.onSaved,
  });

  @override
  ConsumerState<_SaveViaUpiSheet> createState() => _SaveViaUpiSheetState();
}

class _SaveViaUpiSheetState extends ConsumerState<_SaveViaUpiSheet> {
  late double _selectedAmount;
  late String _selectedDestination;
  String _selectedApp = 'Google Pay';
  final TextEditingController _customController = TextEditingController();
  bool _useCustomAmount = false;

  @override
  void initState() {
    super.initState();
    final trackerState = widget.ref.read(mockTrackerProvider);
    final region = widget.ref.read(regionSettingsProvider);
    final goal = trackerState.moneyGoal;
    final convertEntry = _convertEntry(trackerState);
    _selectedAmount = convertEntry?.amount ?? goal.currentLevelAmount;
    _selectedDestination = goal.destinationLabel;
    _selectedApp = region.paymentRegion == PaymentRegion.indiaUpi
        ? 'Google Pay'
        : 'Manual confirmation';
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  SavingEntry? _convertEntry(MockTrackerState state) {
    final entryId = widget.convertEntryId;
    if (entryId == null) return null;
    for (final entry in state.savingsEntries) {
      if (entry.id == entryId && entry.isPotential) return entry;
    }
    return null;
  }

  double? get _amount {
    if (!_useCustomAmount) return _selectedAmount;
    final region = ref.read(regionSettingsProvider);
    final normalized = _customController.text.trim().replaceAll(
      region.currencySymbol,
      '',
    );
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockTrackerProvider);
    final region = ref.watch(regionSettingsProvider);
    final goal = state.moneyGoal;
    final convertEntry = _convertEntry(state);
    final isIndiaUpi = region.paymentRegion == PaymentRegion.indiaUpi;
    final tinyDefault = defaultTinySaveAmount(region);
    final amountOptions = <double>{
      if (convertEntry != null) convertEntry.amount,
      goal.tinySaveAmount,
      goal.currentLevelAmount,
      goal.nextLevelAmount,
      tinyDefault,
      tinyDefault * 2,
    }.where((amount) => amount > 0).toList();
    final destinationOptions = {
      goal.destinationLabel,
      'Second account',
      'Family account',
      if (isIndiaUpi) 'Custom UPI ID' else 'Savings app',
    }.toList();

    return _SheetScaffold(
      title: convertEntry == null
          ? isIndiaUpi
                ? 'Save via UPI'
                : 'Save with local method'
          : 'Convert potential saving',
      subtitle:
          'Local frontend record only. No payment is made inside Optivus.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Amount'),
          _AmountChoices(
            amounts: amountOptions,
            selectedAmount: _selectedAmount,
            useCustom: _useCustomAmount,
            onSelected: (amount) {
              setState(() {
                _useCustomAmount = false;
                _selectedAmount = amount;
              });
            },
            onCustomSelected: () => setState(() => _useCustomAmount = true),
          ),
          if (_useCustomAmount) ...[
            const SizedBox(height: 10),
            _MoneyTextField(
              controller: _customController,
              hint: 'Enter custom amount',
              keyboardType: TextInputType.number,
              prefixText: '${region.currencySymbol} ',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),
          const _SectionLabel('Destination'),
          ...destinationOptions.map(
            (label) => _OptionTile(
              label: label,
              selected: _selectedDestination == label,
              icon: Icons.account_balance_outlined,
              onTap: () => setState(() => _selectedDestination = label),
            ),
          ),
          if (isIndiaUpi) ...[
            const SizedBox(height: 18),
            const _SectionLabel('UPI app choice'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['Google Pay', 'PhonePe', 'Paytm', 'BHIM']
                  .map(
                    (app) => _LiquidChoiceChip(
                      label: app,
                      selected: _selectedApp == app,
                      onTap: () => setState(() => _selectedApp = app),
                    ),
                  )
                  .toList(growable: false),
            ),
          ] else ...[
            const SizedBox(height: 18),
            const _SectionLabel('Saving method'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['Manual confirmation', 'Cash', 'Bank transfer']
                  .map(
                    (app) => _LiquidChoiceChip(
                      label: app,
                      selected: _selectedApp == app,
                      onTap: () => setState(() => _selectedApp = app),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 18),
          const _SoftNotice(
            text:
                'Optivus does not hold money. You save using your own bank, cash, or local payment app.',
            accent: OptivusColors.trackerAccent,
          ),
          const SizedBox(height: 22),
          LiquidPrimaryButton(
            label: isIndiaUpi ? 'Mark UPI transfer done' : 'Mark saving done',
            icon: Icons.check_circle_outline_rounded,
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: _amount == null
                ? null
                : () {
                    final navigator = Navigator.of(context);
                    final notifier = ref.read(mockTrackerProvider.notifier);
                    final method = isIndiaUpi
                        ? MoneySaveMethod.upiMock
                        : _methodFromLabel(_selectedApp);
                    if (convertEntry != null) {
                      notifier.convertPotentialToConfirmed(
                        convertEntry.id,
                        method: method,
                      );
                    } else {
                      notifier.saveMoneyToday(
                        amount: _amount!,
                        method: method,
                        currencyCode: region.currencyCode,
                        source: isIndiaUpi
                            ? widget.source
                            : MoneyEntrySource.manual,
                        routineTaskId: widget.routineTaskId,
                        description:
                            widget.source == MoneyEntrySource.routineTask
                            ? 'Routine Money System task'
                            : isIndiaUpi
                            ? 'Payment app transfer marked done'
                            : 'Manual saving confirmed',
                      );
                    }
                    widget.onSaved?.call();
                    navigator.pop();
                  },
          ),
        ],
      ),
    );
  }
}

class _AlreadySavedSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final MoneyEntrySource source;
  final String? routineTaskId;
  final VoidCallback? onSaved;

  const _AlreadySavedSheet({
    required this.ref,
    required this.source,
    this.routineTaskId,
    this.onSaved,
  });

  @override
  ConsumerState<_AlreadySavedSheet> createState() => _AlreadySavedSheetState();
}

class _AlreadySavedSheetState extends ConsumerState<_AlreadySavedSheet> {
  late double _selectedAmount;
  late MoneySaveMethod _selectedMethod;
  bool _useCustomAmount = false;
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final goal = widget.ref.read(mockTrackerProvider).moneyGoal;
    final region = widget.ref.read(regionSettingsProvider);
    _selectedAmount = goal.currentLevelAmount;
    _selectedMethod =
        goal.defaultMethod == MoneySaveMethod.upiMock &&
            region.paymentRegion != PaymentRegion.indiaUpi
        ? MoneySaveMethod.cash
        : goal.defaultMethod;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double? get _amount {
    if (!_useCustomAmount) return _selectedAmount;
    final region = ref.read(regionSettingsProvider);
    final parsed = double.tryParse(
      _customController.text.trim().replaceAll(region.currencySymbol, ''),
    );
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(mockTrackerProvider).moneyGoal;
    final region = ref.watch(regionSettingsProvider);
    final tinyDefault = defaultTinySaveAmount(region);
    final amountOptions = <double>{
      goal.tinySaveAmount,
      goal.currentLevelAmount,
      goal.nextLevelAmount,
      tinyDefault,
      tinyDefault * 2,
    }.where((amount) => amount > 0).toList();
    final canConfirm = goal.manualConfirmationAllowed;

    return _SheetScaffold(
      title: 'I already saved',
      subtitle: canConfirm
          ? 'Log money you saved outside Optivus.'
          : 'Manual confirmation is currently disabled in settings.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Amount'),
          _AmountChoices(
            amounts: amountOptions,
            selectedAmount: _selectedAmount,
            useCustom: _useCustomAmount,
            onSelected: (amount) {
              setState(() {
                _useCustomAmount = false;
                _selectedAmount = amount;
              });
            },
            onCustomSelected: () => setState(() => _useCustomAmount = true),
          ),
          if (_useCustomAmount) ...[
            const SizedBox(height: 10),
            _MoneyTextField(
              controller: _customController,
              hint: 'Enter saved amount',
              keyboardType: TextInputType.number,
              prefixText: '${region.currencySymbol} ',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),
          const _SectionLabel('Method'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: MoneySaveMethod.values
                .where(
                  (method) =>
                      method != MoneySaveMethod.none &&
                      (region.paymentRegion == PaymentRegion.indiaUpi ||
                          method != MoneySaveMethod.upiMock),
                )
                .map(
                  (method) => _LiquidChoiceChip(
                    label: moneySaveMethodLabel(method, region),
                    selected: _selectedMethod == method,
                    onTap: () => setState(() => _selectedMethod = method),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 22),
          LiquidPrimaryButton(
            label: 'Mark saved',
            icon: Icons.savings_outlined,
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: !canConfirm || _amount == null
                ? null
                : () {
                    ref
                        .read(mockTrackerProvider.notifier)
                        .saveMoneyToday(
                          amount: _amount!,
                          method: _selectedMethod,
                          currencyCode: region.currencyCode,
                          source: widget.source,
                          routineTaskId: widget.routineTaskId,
                          description:
                              widget.source == MoneyEntrySource.routineTask
                              ? 'Routine Money System task'
                              : 'Manual saving confirmed',
                        );
                    widget.onSaved?.call();
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }
}

class _TinySaveSheet extends ConsumerWidget {
  final String? routineTaskId;
  final VoidCallback? onSaved;

  const _TinySaveSheet({this.routineTaskId, this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(mockTrackerProvider).moneyGoal;
    final region = ref.watch(regionSettingsProvider);
    return _SheetScaffold(
      title: 'Tiny save',
      subtitle: 'Keep the finance identity alive with the smallest real proof.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoftNotice(
            text:
                'Save ${formatMoney(goal.tinySaveAmount, region)} outside Optivus, then mark the proof here.',
            accent: OptivusColors.mintAccent,
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Mark tiny save done',
            icon: Icons.check_rounded,
            backgroundColor: OptivusColors.mintAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: () {
              ref
                  .read(mockTrackerProvider.notifier)
                  .saveMoneyToday(
                    amount: goal.tinySaveAmount,
                    method: goal.defaultMethod,
                    currencyCode: region.currencyCode,
                    source: MoneyEntrySource.dailyTarget,
                    routineTaskId: routineTaskId,
                    description: 'Tiny save',
                  );
              onSaved?.call();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _SkipTodaySheet extends StatefulWidget {
  final WidgetRef ref;
  final VoidCallback? onSkipped;

  const _SkipTodaySheet({required this.ref, this.onSkipped});

  @override
  State<_SkipTodaySheet> createState() => _SkipTodaySheetState();
}

class _SkipTodaySheetState extends State<_SkipTodaySheet> {
  String _reason = 'No money today';

  @override
  Widget build(BuildContext context) {
    final reasons = [
      'No money today',
      'Forgot',
      'Emergency spend',
      'Need tiny version',
      'Do not want to say',
    ];

    return _SheetScaffold(
      title: 'Skip today',
      subtitle:
          'Skipping breaks the streak, but you can restart with tiny proof.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Reason'),
          ...reasons.map(
            (reason) => _OptionTile(
              label: reason,
              selected: _reason == reason,
              icon: Icons.radio_button_checked_rounded,
              onTap: () => setState(() => _reason = reason),
            ),
          ),
          const SizedBox(height: 14),
          const _SoftNotice(
            text: 'A tiny save can still protect the identity streak today.',
            accent: OptivusColors.roseAccent,
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Save tiny amount instead',
            icon: Icons.savings_outlined,
            backgroundColor: OptivusColors.mintAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: () {
              Navigator.of(context).pop();
              showTinySaveFlow(context, widget.ref);
            },
          ),
          const SizedBox(height: 10),
          LiquidOutlineButton(
            label: 'Skip money proof today',
            borderColor: OptivusColors.roseAccent,
            onPressed: () {
              widget.ref
                  .read(mockTrackerProvider.notifier)
                  .skipMoneyToday(reason: _reason);
              widget.onSkipped?.call();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _MoneySettingSheet extends StatefulWidget {
  final WidgetRef ref;
  final MoneySettingKind kind;

  const _MoneySettingSheet({required this.ref, required this.kind});

  @override
  State<_MoneySettingSheet> createState() => _MoneySettingSheetState();
}

class _MoneySettingSheetState extends State<_MoneySettingSheet> {
  late TextEditingController _controller;
  late MoneySaveMethod _method;
  late bool _manualAllowed;

  @override
  void initState() {
    super.initState();
    final goal = widget.ref.read(mockTrackerProvider).moneyGoal;
    final initialText = switch (widget.kind) {
      MoneySettingKind.dailyTarget =>
        goal.currentLevelAmount.toInt().toString(),
      MoneySettingKind.tinySaveAmount => goal.tinySaveAmount.toInt().toString(),
      MoneySettingKind.destinationLabel => goal.destinationLabel,
      MoneySettingKind.reminderTimeLabel => goal.reminderTimeLabel,
      MoneySettingKind.levelUpRule => goal.levelUpAfterDays.toString(),
      _ => '',
    };
    _controller = TextEditingController(text: initialText);
    _method = goal.defaultMethod;
    _manualAllowed = goal.manualConfirmationAllowed;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = widget.ref.read(regionSettingsProvider);
    return switch (widget.kind) {
      MoneySettingKind.dailyTarget => _numberSetting(
        context,
        title: 'Daily target amount',
        subtitle: 'Set the regular daily finance proof.',
        prefixText: '${region.currencySymbol} ',
        onSave: (value) => widget.ref
            .read(mockTrackerProvider.notifier)
            .updateMoneySettings(dailyTarget: value),
      ),
      MoneySettingKind.tinySaveAmount => _numberSetting(
        context,
        title: 'Tiny save amount',
        subtitle: 'Smallest fallback amount that still counts as proof.',
        prefixText: '${region.currencySymbol} ',
        onSave: (value) => widget.ref
            .read(mockTrackerProvider.notifier)
            .updateMoneySettings(tinySaveAmount: value),
      ),
      MoneySettingKind.destinationLabel => _textSetting(
        context,
        title: 'Saving destination',
        subtitle: 'Label where you actually keep the money.',
        hint: 'Second account, cash box, family account',
        onSave: (value) => widget.ref
            .read(mockTrackerProvider.notifier)
            .updateMoneySettings(destinationLabel: value),
      ),
      MoneySettingKind.reminderTimeLabel => _textSetting(
        context,
        title: 'Reminder time',
        subtitle:
            'Frontend label only. No notification permission is requested.',
        hint: '8:00 PM',
        onSave: (value) => widget.ref
            .read(mockTrackerProvider.notifier)
            .updateMoneySettings(reminderTimeLabel: value),
      ),
      MoneySettingKind.levelUpRule => _levelRuleSetting(context),
      MoneySettingKind.defaultMethod => _methodSetting(context),
      MoneySettingKind.manualConfirmationAllowed => _manualSetting(context),
      MoneySettingKind.exportSavingsData => _exportSheet(context),
    };
  }

  Widget _numberSetting(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String prefixText,
    required ValueChanged<double> onSave,
  }) {
    return _SheetScaffold(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneyTextField(
            controller: _controller,
            hint: 'Amount',
            keyboardType: TextInputType.number,
            prefixText: prefixText,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Save setting',
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: double.tryParse(_controller.text.trim()) == null
                ? null
                : () {
                    onSave(double.parse(_controller.text.trim()));
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }

  Widget _textSetting(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String hint,
    required ValueChanged<String> onSave,
  }) {
    return _SheetScaffold(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneyTextField(
            controller: _controller,
            hint: hint,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Save setting',
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () {
                    onSave(_controller.text.trim());
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }

  Widget _methodSetting(BuildContext context) {
    final region = widget.ref.read(regionSettingsProvider);
    return _SheetScaffold(
      title: 'Default method',
      subtitle: 'Used by tiny saves and routine money proof.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: MoneySaveMethod.values
                .where(
                  (method) =>
                      method != MoneySaveMethod.none &&
                      (region.paymentRegion == PaymentRegion.indiaUpi ||
                          method != MoneySaveMethod.upiMock),
                )
                .map(
                  (method) => _LiquidChoiceChip(
                    label: moneySaveMethodLabel(method, region),
                    selected: _method == method,
                    onTap: () => setState(() => _method = method),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Save method',
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: () {
              widget.ref
                  .read(mockTrackerProvider.notifier)
                  .updateMoneySettings(defaultMethod: _method);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _levelRuleSetting(BuildContext context) {
    final parsed = int.tryParse(_controller.text.trim());
    return _SheetScaffold(
      title: 'Level-up rule',
      subtitle:
          'Successful days needed before Optivus suggests a higher target.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoneyTextField(
            controller: _controller,
            hint: 'Days',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Save rule',
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: parsed == null || parsed <= 0
                ? null
                : () {
                    widget.ref
                        .read(mockTrackerProvider.notifier)
                        .updateMoneySettings(levelUpAfterDays: parsed);
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }

  Widget _manualSetting(BuildContext context) {
    return _SheetScaffold(
      title: 'Manual confirmation',
      subtitle: 'Controls whether “I already saved” can create local proof.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _LargeToggleCard(
                  label: 'Allowed',
                  selected: _manualAllowed,
                  onTap: () => setState(() => _manualAllowed = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LargeToggleCard(
                  label: 'Disabled',
                  selected: !_manualAllowed,
                  onTap: () => setState(() => _manualAllowed = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LiquidPrimaryButton(
            label: 'Save setting',
            backgroundColor: OptivusColors.trackerAccent,
            foregroundColor: OptivusColors.ink,
            onPressed: () {
              widget.ref
                  .read(mockTrackerProvider.notifier)
                  .updateMoneySettings(
                    manualConfirmationAllowed: _manualAllowed,
                  );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _exportSheet(BuildContext context) {
    final state = widget.ref.read(mockTrackerProvider);
    return _SheetScaffold(
      title: 'Export savings data',
      subtitle: 'Local export preview.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoftNotice(
            text:
                '${state.savingsEntries.length} local entries ready. Backend file export is intentionally not connected in this frontend phase.',
            accent: OptivusColors.trackerAccent,
          ),
          const SizedBox(height: 18),
          LiquidOutlineButton(
            label: 'Close',
            borderColor: OptivusColors.trackerAccent,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: OptivusColors.ink,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OptivusColors.sub,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: OptivusColors.sub,
          letterSpacing: 0.8,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OptivusColors.trackerCardTint.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: OptivusColors.trackerAccent.withValues(alpha: 0.22),
        ),
      ),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: OptivusColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OptivusColors.sub,
                    height: 1.35,
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

class _SoftNotice extends StatelessWidget {
  final String text;
  final Color accent;

  const _SoftNotice({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
          height: 1.35,
        ),
      ),
    );
  }
}

class _AmountChoices extends ConsumerWidget {
  final List<double> amounts;
  final double selectedAmount;
  final bool useCustom;
  final ValueChanged<double> onSelected;
  final VoidCallback onCustomSelected;

  const _AmountChoices({
    required this.amounts,
    required this.selectedAmount,
    required this.useCustom,
    required this.onSelected,
    required this.onCustomSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(regionSettingsProvider);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...amounts.map(
          (amount) => _LiquidChoiceChip(
            label: formatMoney(amount, region),
            selected: !useCustom && selectedAmount == amount,
            onTap: () => onSelected(amount),
          ),
        ),
        _LiquidChoiceChip(
          label: 'Custom',
          selected: useCustom,
          onTap: onCustomSelected,
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? OptivusColors.trackerAccent.withValues(alpha: 0.14)
              : OptivusColors.trackerCardTint.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? OptivusColors.trackerAccent
                : OptivusColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? OptivusColors.trackerAccent : OptivusColors.sub,
              size: 19,
            ),
            const SizedBox(width: 10),
            Icon(icon, color: OptivusColors.trackerAccent, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: OptivusColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LiquidChoiceChip({
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
              : OptivusColors.trackerCardTint.withValues(alpha: 0.72),
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

class _LargeToggleCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LargeToggleCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? OptivusColors.trackerAccent.withValues(alpha: 0.16)
              : OptivusColors.trackerCardTint.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? OptivusColors.trackerAccent
                : OptivusColors.borderSoft,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: selected ? OptivusColors.trackerAccent : OptivusColors.sub,
          ),
        ),
      ),
    );
  }
}

class _MoneyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  const _MoneyTextField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.prefixText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: OptivusColors.trackerAccent,
      onChanged: onChanged,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: OptivusColors.ink,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        hintStyle: const TextStyle(
          color: OptivusColors.sub,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: OptivusColors.trackerCardTint.withValues(alpha: 0.78),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: OptivusColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: OptivusColors.trackerAccent),
        ),
      ),
    );
  }
}

MoneySaveMethod _methodFromLabel(String label) {
  return switch (label) {
    'Cash' => MoneySaveMethod.cash,
    'Bank transfer' => MoneySaveMethod.bankTransfer,
    'Second account' => MoneySaveMethod.secondAccount,
    'Family account' => MoneySaveMethod.familyAccount,
    'UPI' ||
    'Google Pay' ||
    'PhonePe' ||
    'Paytm' ||
    'BHIM' => MoneySaveMethod.upiMock,
    _ => MoneySaveMethod.custom,
  };
}

String moneySaveMethodLabel(MoneySaveMethod method, [RegionSettings? region]) {
  return switch (method) {
    MoneySaveMethod.upiMock =>
      region?.paymentRegion == PaymentRegion.indiaUpi ? 'UPI' : 'Payment app',
    MoneySaveMethod.cash => 'Cash',
    MoneySaveMethod.bankTransfer => 'Bank transfer',
    MoneySaveMethod.secondAccount => 'Second account',
    MoneySaveMethod.familyAccount => 'Family account',
    MoneySaveMethod.custom => 'Custom',
    MoneySaveMethod.none => 'None',
  };
}

String moneyEntrySourceLabel(
  MoneyEntrySource source, [
  RegionSettings? region,
]) {
  return switch (source) {
    MoneyEntrySource.dailyTarget => 'Daily target',
    MoneyEntrySource.manual => 'Manual',
    MoneyEntrySource.upiMock =>
      region?.paymentRegion == PaymentRegion.indiaUpi ? 'UPI' : 'Payment app',
    MoneyEntrySource.badHabitAvoided => 'Bad habit avoided',
    MoneyEntrySource.badHabitConverted => 'Bad habit converted',
    MoneyEntrySource.routineTask => 'Routine task',
    MoneyEntrySource.adjustment => 'Adjustment',
  };
}

String moneyEntryStatusLabel(MoneyEntryStatus status) {
  return switch (status) {
    MoneyEntryStatus.confirmed => 'Confirmed',
    MoneyEntryStatus.potential => 'Potential',
    MoneyEntryStatus.skipped => 'Skipped',
  };
}
