import 'package:optivus/models/region_settings.dart';

String formatMoney(double amount, RegionSettings regionSettings) {
  final decimals = regionSettings.currencyCode == 'JPY' ? 0 : 2;
  final rounded = amount.roundToDouble();
  final text = amount == rounded
      ? rounded.toInt().toString()
      : amount.toStringAsFixed(decimals);
  return '${regionSettings.currencySymbol}$text';
}

String formatCompactMoney(double amount, RegionSettings regionSettings) {
  final abs = amount.abs();
  if (abs >= 1000000) {
    return '${regionSettings.currencySymbol}${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    return '${regionSettings.currencySymbol}${(amount / 1000).toStringAsFixed(1)}K';
  }
  return formatMoney(amount, regionSettings);
}

double defaultTinySaveAmount(RegionSettings regionSettings) {
  return switch (regionSettings.currencyCode) {
    'INR' => 10,
    'JPY' => 100,
    'EUR' => 1,
    'GBP' => 1,
    _ => 1,
  };
}
