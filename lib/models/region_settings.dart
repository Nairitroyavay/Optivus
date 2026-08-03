import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

enum MeasurementSystem { metric, imperial, mixed }

enum HeightUnit { cm, ftIn }

enum WeightUnit { kg, lb }

enum DistanceUnit { km, mile }

enum TemperatureUnit { celsius, fahrenheit }

enum TimeFormatPreference { system, twelveHour, twentyFourHour }

enum WeekStartDay { monday, sunday, saturday }

enum FoodVocabularyMode { global, india, japan, custom }

enum PaymentRegion { global, indiaUpi, manualOnly }

class _CurrencyProfile {
  final String code;
  final String symbol;

  const _CurrencyProfile(this.code, this.symbol);
}

const Map<String, _CurrencyProfile> _countryCurrencies = {
  'AE': _CurrencyProfile('AED', 'د.إ'),
  'AU': _CurrencyProfile('AUD', r'A$'),
  'BD': _CurrencyProfile('BDT', '৳'),
  'BR': _CurrencyProfile('BRL', r'R$'),
  'CA': _CurrencyProfile('CAD', r'C$'),
  'CH': _CurrencyProfile('CHF', 'CHF'),
  'CN': _CurrencyProfile('CNY', '¥'),
  'CZ': _CurrencyProfile('CZK', 'Kč'),
  'DK': _CurrencyProfile('DKK', 'kr'),
  'EG': _CurrencyProfile('EGP', 'E£'),
  'GB': _CurrencyProfile('GBP', '£'),
  'HK': _CurrencyProfile('HKD', r'HK$'),
  'ID': _CurrencyProfile('IDR', 'Rp'),
  'IN': _CurrencyProfile('INR', '₹'),
  'JP': _CurrencyProfile('JPY', '¥'),
  'KR': _CurrencyProfile('KRW', '₩'),
  'LK': _CurrencyProfile('LKR', 'Rs'),
  'MY': _CurrencyProfile('MYR', 'RM'),
  'MX': _CurrencyProfile('MXN', r'MX$'),
  'NG': _CurrencyProfile('NGN', '₦'),
  'NO': _CurrencyProfile('NOK', 'kr'),
  'NP': _CurrencyProfile('NPR', 'रू'),
  'NZ': _CurrencyProfile('NZD', r'NZ$'),
  'PH': _CurrencyProfile('PHP', '₱'),
  'PK': _CurrencyProfile('PKR', '₨'),
  'PL': _CurrencyProfile('PLN', 'zł'),
  'SA': _CurrencyProfile('SAR', 'SAR'),
  'SE': _CurrencyProfile('SEK', 'kr'),
  'SG': _CurrencyProfile('SGD', r'S$'),
  'TH': _CurrencyProfile('THB', '฿'),
  'TR': _CurrencyProfile('TRY', '₺'),
  'TW': _CurrencyProfile('TWD', r'NT$'),
  'US': _CurrencyProfile('USD', r'$'),
  'VN': _CurrencyProfile('VND', '₫'),
  'ZA': _CurrencyProfile('ZAR', 'R'),
};

const Set<String> _euroCountries = {
  'AT',
  'BE',
  'CY',
  'DE',
  'EE',
  'ES',
  'FI',
  'FR',
  'GR',
  'HR',
  'IE',
  'IT',
  'LT',
  'LU',
  'LV',
  'MT',
  'NL',
  'PT',
  'SI',
  'SK',
};

const Map<String, String> _countryNames = {
  'AE': 'United Arab Emirates',
  'AU': 'Australia',
  'BD': 'Bangladesh',
  'BR': 'Brazil',
  'CA': 'Canada',
  'CH': 'Switzerland',
  'CN': 'China',
  'DE': 'Germany',
  'EG': 'Egypt',
  'ES': 'Spain',
  'FR': 'France',
  'GB': 'United Kingdom',
  'HK': 'Hong Kong',
  'ID': 'Indonesia',
  'IN': 'India',
  'IT': 'Italy',
  'JP': 'Japan',
  'KR': 'South Korea',
  'LK': 'Sri Lanka',
  'MY': 'Malaysia',
  'MX': 'Mexico',
  'NG': 'Nigeria',
  'NP': 'Nepal',
  'NZ': 'New Zealand',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'SA': 'Saudi Arabia',
  'SG': 'Singapore',
  'TH': 'Thailand',
  'TR': 'Türkiye',
  'TW': 'Taiwan',
  'US': 'United States',
  'VN': 'Vietnam',
  'ZA': 'South Africa',
  'ZZ': 'Other / Custom',
};

const Map<String, String> _defaultTimezones = {
  'AE': 'Asia/Dubai',
  'BD': 'Asia/Dhaka',
  'CN': 'Asia/Shanghai',
  'GB': 'Europe/London',
  'HK': 'Asia/Hong_Kong',
  'ID': 'Asia/Jakarta',
  'IN': 'Asia/Kolkata',
  'JP': 'Asia/Tokyo',
  'KR': 'Asia/Seoul',
  'LK': 'Asia/Colombo',
  'MY': 'Asia/Kuala_Lumpur',
  'NP': 'Asia/Kathmandu',
  'PH': 'Asia/Manila',
  'PK': 'Asia/Karachi',
  'SA': 'Asia/Riyadh',
  'SG': 'Asia/Singapore',
  'TH': 'Asia/Bangkok',
  'TW': 'Asia/Taipei',
  'US': 'America/New_York',
  'VN': 'Asia/Ho_Chi_Minh',
};

_CurrencyProfile _currencyProfileForCountry(String countryCode) {
  if (_euroCountries.contains(countryCode)) {
    return const _CurrencyProfile('EUR', '€');
  }
  return _countryCurrencies[countryCode] ?? const _CurrencyProfile('USD', r'$');
}

class RegionSettings {
  static const int schemaVersion = 1;

  final String userId;
  final String countryCode;
  final String countryName;
  final String timezone;
  final String languageCode;
  final String currencyCode;
  final String currencySymbol;
  final MeasurementSystem measurementSystem;
  final HeightUnit heightUnit;
  final WeightUnit weightUnit;
  final DistanceUnit distanceUnit;
  final TemperatureUnit temperatureUnit;
  final TimeFormatPreference timeFormat;
  final String dateFormat;
  final WeekStartDay weekStartDay;
  final FoodVocabularyMode foodVocabularyMode;
  final PaymentRegion paymentRegion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RegionSettings({
    required this.userId,
    required this.countryCode,
    required this.countryName,
    required this.timezone,
    required this.languageCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.measurementSystem,
    required this.heightUnit,
    required this.weightUnit,
    required this.distanceUnit,
    required this.temperatureUnit,
    required this.timeFormat,
    required this.dateFormat,
    required this.weekStartDay,
    required this.foodVocabularyMode,
    required this.paymentRegion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RegionSettings.defaultForUser(String userId) {
    return RegionSettings.forCountry(
      userId: userId,
      countryCode: PlatformDispatcher.instance.locale.countryCode ?? '',
    );
  }

  factory RegionSettings.forCountry({
    required String userId,
    required String countryCode,
    String countryName = '',
  }) {
    final code = countryCode.trim().toUpperCase();
    if (code == 'IN') return RegionSettings.india(userId: userId);
    if (code == 'US') return RegionSettings.unitedStates(userId: userId);
    if (code == 'JP') return RegionSettings.japan(userId: userId);
    if (code == 'GB') return RegionSettings.unitedKingdom(userId: userId);

    final now = DateTime.now();
    final resolvedCode = code.length == 2 ? code : 'ZZ';
    final currency = _currencyProfileForCountry(resolvedCode);
    final imperial = const {'LR', 'MM'}.contains(resolvedCode);
    final resolvedName = countryName.trim().isNotEmpty
        ? countryName.trim()
        : (_countryNames[resolvedCode] ?? 'Other / Custom');
    return RegionSettings(
      userId: userId,
      countryCode: resolvedCode,
      countryName: resolvedName,
      timezone: _defaultTimezones[resolvedCode] ?? 'UTC',
      languageCode:
          PlatformDispatcher.instance.locale.languageCode.trim().isEmpty
          ? 'en'
          : PlatformDispatcher.instance.locale.languageCode,
      currencyCode: currency.code,
      currencySymbol: currency.symbol,
      measurementSystem: imperial
          ? MeasurementSystem.imperial
          : MeasurementSystem.metric,
      heightUnit: imperial ? HeightUnit.ftIn : HeightUnit.cm,
      weightUnit: imperial ? WeightUnit.lb : WeightUnit.kg,
      distanceUnit: imperial ? DistanceUnit.mile : DistanceUnit.km,
      temperatureUnit: TemperatureUnit.celsius,
      timeFormat: TimeFormatPreference.system,
      dateFormat: 'dd/MM/yyyy',
      weekStartDay: WeekStartDay.monday,
      foodVocabularyMode: FoodVocabularyMode.global,
      paymentRegion: PaymentRegion.global,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RegionSettings.india({required String userId}) {
    final now = DateTime.now();
    return RegionSettings(
      userId: userId,
      countryCode: 'IN',
      countryName: 'India',
      timezone: 'Asia/Kolkata',
      languageCode: 'en',
      currencyCode: 'INR',
      currencySymbol: '₹',
      measurementSystem: MeasurementSystem.metric,
      heightUnit: HeightUnit.cm,
      weightUnit: WeightUnit.kg,
      distanceUnit: DistanceUnit.km,
      temperatureUnit: TemperatureUnit.celsius,
      timeFormat: TimeFormatPreference.system,
      dateFormat: 'dd/MM/yyyy',
      weekStartDay: WeekStartDay.monday,
      foodVocabularyMode: FoodVocabularyMode.india,
      paymentRegion: PaymentRegion.indiaUpi,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RegionSettings.unitedStates({required String userId}) {
    final now = DateTime.now();
    return RegionSettings(
      userId: userId,
      countryCode: 'US',
      countryName: 'United States',
      timezone: 'America/New_York',
      languageCode: 'en',
      currencyCode: 'USD',
      currencySymbol: r'$',
      measurementSystem: MeasurementSystem.imperial,
      heightUnit: HeightUnit.ftIn,
      weightUnit: WeightUnit.lb,
      distanceUnit: DistanceUnit.mile,
      temperatureUnit: TemperatureUnit.fahrenheit,
      timeFormat: TimeFormatPreference.twelveHour,
      dateFormat: 'MM/dd/yyyy',
      weekStartDay: WeekStartDay.sunday,
      foodVocabularyMode: FoodVocabularyMode.global,
      paymentRegion: PaymentRegion.global,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RegionSettings.japan({required String userId}) {
    final now = DateTime.now();
    return RegionSettings(
      userId: userId,
      countryCode: 'JP',
      countryName: 'Japan',
      timezone: 'Asia/Tokyo',
      languageCode: 'ja',
      currencyCode: 'JPY',
      currencySymbol: '¥',
      measurementSystem: MeasurementSystem.metric,
      heightUnit: HeightUnit.cm,
      weightUnit: WeightUnit.kg,
      distanceUnit: DistanceUnit.km,
      temperatureUnit: TemperatureUnit.celsius,
      timeFormat: TimeFormatPreference.twentyFourHour,
      dateFormat: 'yyyy/MM/dd',
      weekStartDay: WeekStartDay.monday,
      foodVocabularyMode: FoodVocabularyMode.japan,
      paymentRegion: PaymentRegion.global,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RegionSettings.unitedKingdom({required String userId}) {
    final now = DateTime.now();
    return RegionSettings(
      userId: userId,
      countryCode: 'GB',
      countryName: 'United Kingdom',
      timezone: 'Europe/London',
      languageCode: 'en',
      currencyCode: 'GBP',
      currencySymbol: '£',
      measurementSystem: MeasurementSystem.mixed,
      heightUnit: HeightUnit.ftIn,
      weightUnit: WeightUnit.lb,
      distanceUnit: DistanceUnit.mile,
      temperatureUnit: TemperatureUnit.celsius,
      timeFormat: TimeFormatPreference.system,
      dateFormat: 'dd/MM/yyyy',
      weekStartDay: WeekStartDay.monday,
      foodVocabularyMode: FoodVocabularyMode.global,
      paymentRegion: PaymentRegion.global,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RegionSettings.europe({required String userId}) {
    final now = DateTime.now();
    return RegionSettings(
      userId: userId,
      countryCode: 'EU',
      countryName: 'Europe',
      timezone: 'Europe/Berlin',
      languageCode: 'en',
      currencyCode: 'EUR',
      currencySymbol: '€',
      measurementSystem: MeasurementSystem.metric,
      heightUnit: HeightUnit.cm,
      weightUnit: WeightUnit.kg,
      distanceUnit: DistanceUnit.km,
      temperatureUnit: TemperatureUnit.celsius,
      timeFormat: TimeFormatPreference.twentyFourHour,
      dateFormat: 'dd/MM/yyyy',
      weekStartDay: WeekStartDay.monday,
      foodVocabularyMode: FoodVocabularyMode.global,
      paymentRegion: PaymentRegion.global,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory RegionSettings.other({required String userId}) {
    final now = DateTime.now();
    return RegionSettings(
      userId: userId,
      countryCode: 'ZZ',
      countryName: 'Other / Custom',
      timezone: 'UTC',
      languageCode: 'en',
      currencyCode: 'USD',
      currencySymbol: r'$',
      measurementSystem: MeasurementSystem.metric,
      heightUnit: HeightUnit.cm,
      weightUnit: WeightUnit.kg,
      distanceUnit: DistanceUnit.km,
      temperatureUnit: TemperatureUnit.celsius,
      timeFormat: TimeFormatPreference.system,
      dateFormat: 'yyyy-MM-dd',
      weekStartDay: WeekStartDay.monday,
      foodVocabularyMode: FoodVocabularyMode.custom,
      paymentRegion: PaymentRegion.manualOnly,
      createdAt: now,
      updatedAt: now,
    );
  }

  RegionSettings copyWith({
    String? userId,
    String? countryCode,
    String? countryName,
    String? timezone,
    String? languageCode,
    String? currencyCode,
    String? currencySymbol,
    MeasurementSystem? measurementSystem,
    HeightUnit? heightUnit,
    WeightUnit? weightUnit,
    DistanceUnit? distanceUnit,
    TemperatureUnit? temperatureUnit,
    TimeFormatPreference? timeFormat,
    String? dateFormat,
    WeekStartDay? weekStartDay,
    FoodVocabularyMode? foodVocabularyMode,
    PaymentRegion? paymentRegion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RegionSettings(
      userId: userId ?? this.userId,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      timezone: timezone ?? this.timezone,
      languageCode: languageCode ?? this.languageCode,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      measurementSystem: measurementSystem ?? this.measurementSystem,
      heightUnit: heightUnit ?? this.heightUnit,
      weightUnit: weightUnit ?? this.weightUnit,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      timeFormat: timeFormat ?? this.timeFormat,
      dateFormat: dateFormat ?? this.dateFormat,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      foodVocabularyMode: foodVocabularyMode ?? this.foodVocabularyMode,
      paymentRegion: paymentRegion ?? this.paymentRegion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'userId': userId,
      'schemaVersion': schemaVersion,
      'countryCode': countryCode,
      'countryName': countryName,
      'timezone': timezone,
      'languageCode': languageCode,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'measurementSystem': measurementSystem.name,
      'heightUnit': heightUnit.name,
      'weightUnit': weightUnit.name,
      'distanceUnit': distanceUnit.name,
      'temperatureUnit': temperatureUnit.name,
      'timeFormat': timeFormat.name,
      'dateFormat': dateFormat,
      'weekStartDay': weekStartDay.name,
      'foodVocabularyMode': foodVocabularyMode.name,
      'paymentRegion': paymentRegion.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toFirestoreMap() {
    return {
      'userId': userId,
      'schemaVersion': schemaVersion,
      'countryCode': countryCode,
      'countryName': countryName,
      'timezone': timezone,
      'languageCode': languageCode,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'measurementSystem': measurementSystem.name,
      'heightUnit': heightUnit.name,
      'weightUnit': weightUnit.name,
      'distanceUnit': distanceUnit.name,
      'temperatureUnit': temperatureUnit.name,
      'timeFormat': timeFormat.name,
      'dateFormat': dateFormat,
      'weekStartDay': weekStartDay.name,
      'foodVocabularyMode': foodVocabularyMode.name,
      'paymentRegion': paymentRegion.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RegionSettings.fromMap(Map<String, dynamic> map) {
    final userId = map['userId'] as String? ?? '';
    final defaults = RegionSettings.defaultForUser(userId);
    return RegionSettings(
      userId: userId,
      countryCode: map['countryCode'] as String? ?? defaults.countryCode,
      countryName: map['countryName'] as String? ?? defaults.countryName,
      timezone: map['timezone'] as String? ?? defaults.timezone,
      languageCode: map['languageCode'] as String? ?? defaults.languageCode,
      currencyCode: map['currencyCode'] as String? ?? defaults.currencyCode,
      currencySymbol:
          map['currencySymbol'] as String? ?? defaults.currencySymbol,
      measurementSystem: _enumByName(
        MeasurementSystem.values,
        map['measurementSystem'],
        defaults.measurementSystem,
      ),
      heightUnit: _enumByName(
        HeightUnit.values,
        map['heightUnit'],
        defaults.heightUnit,
      ),
      weightUnit: _enumByName(
        WeightUnit.values,
        map['weightUnit'],
        defaults.weightUnit,
      ),
      distanceUnit: _enumByName(
        DistanceUnit.values,
        map['distanceUnit'],
        defaults.distanceUnit,
      ),
      temperatureUnit: _enumByName(
        TemperatureUnit.values,
        map['temperatureUnit'],
        defaults.temperatureUnit,
      ),
      timeFormat: _enumByName(
        TimeFormatPreference.values,
        map['timeFormat'],
        defaults.timeFormat,
      ),
      dateFormat: map['dateFormat'] as String? ?? defaults.dateFormat,
      weekStartDay: _enumByName(
        WeekStartDay.values,
        map['weekStartDay'],
        defaults.weekStartDay,
      ),
      foodVocabularyMode: _enumByName(
        FoodVocabularyMode.values,
        map['foodVocabularyMode'],
        defaults.foodVocabularyMode,
      ),
      paymentRegion: _enumByName(
        PaymentRegion.values,
        map['paymentRegion'],
        defaults.paymentRegion,
      ),
      createdAt: _dateTimeFromMapValue(map['createdAt']) ?? defaults.createdAt,
      updatedAt: _dateTimeFromMapValue(map['updatedAt']) ?? defaults.updatedAt,
    );
  }

  factory RegionSettings.fromFirestoreMap(Map<String, dynamic> map) {
    return RegionSettings.fromMap(map);
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  return fallback;
}

DateTime? _dateTimeFromMapValue(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

extension RegionSettingsLabels on RegionSettings {
  String get measurementLabel {
    return switch (measurementSystem) {
      MeasurementSystem.metric => 'Metric',
      MeasurementSystem.imperial => 'Imperial',
      MeasurementSystem.mixed => 'Mixed',
    };
  }

  String get heightWeightLabel {
    return '${heightUnit.label} / ${weightUnit.label}';
  }

  String get distanceLabel => distanceUnit.label;

  String get weekStartLabel => weekStartDay.label;

  String get timeFormatLabel => timeFormat.label;

  String get foodVocabularyLabel => foodVocabularyMode.label;

  String get paymentRegionLabel => paymentRegion.label;
}

extension HeightUnitLabel on HeightUnit {
  String get label {
    return switch (this) {
      HeightUnit.cm => 'cm',
      HeightUnit.ftIn => 'ft/in',
    };
  }
}

extension WeightUnitLabel on WeightUnit {
  String get label {
    return switch (this) {
      WeightUnit.kg => 'kg',
      WeightUnit.lb => 'lb',
    };
  }
}

extension DistanceUnitLabel on DistanceUnit {
  String get label {
    return switch (this) {
      DistanceUnit.km => 'km',
      DistanceUnit.mile => 'mile',
    };
  }
}

extension WeekStartDayLabel on WeekStartDay {
  String get label {
    return switch (this) {
      WeekStartDay.monday => 'Monday',
      WeekStartDay.sunday => 'Sunday',
      WeekStartDay.saturday => 'Saturday',
    };
  }
}

extension TimeFormatPreferenceLabel on TimeFormatPreference {
  String get label {
    return switch (this) {
      TimeFormatPreference.system => 'System',
      TimeFormatPreference.twelveHour => '12 hour',
      TimeFormatPreference.twentyFourHour => '24 hour',
    };
  }
}

extension FoodVocabularyModeLabel on FoodVocabularyMode {
  String get label {
    return switch (this) {
      FoodVocabularyMode.global => 'Global',
      FoodVocabularyMode.india => 'India',
      FoodVocabularyMode.japan => 'Japan',
      FoodVocabularyMode.custom => 'Custom',
    };
  }
}

extension PaymentRegionLabel on PaymentRegion {
  String get label {
    return switch (this) {
      PaymentRegion.global => 'Local payment later',
      PaymentRegion.indiaUpi => 'India UPI + manual',
      PaymentRegion.manualOnly => 'Manual only',
    };
  }
}
