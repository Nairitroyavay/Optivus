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

class RegionSettings {
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
    return RegionSettings.unitedStates(userId: userId);
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
