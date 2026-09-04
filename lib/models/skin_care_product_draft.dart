class SkinCareDetectedProduct {
  final String name;
  final String brand;
  final String category;
  final String source;
  final List<String> keyIngredients;
  final List<String> possibleActives;
  final String usageHint;
  final String warningIfAny;
  final String confidence;

  const SkinCareDetectedProduct({
    this.name = '',
    this.brand = '',
    this.category = '',
    this.source = '',
    this.keyIngredients = const [],
    this.possibleActives = const [],
    this.usageHint = '',
    this.warningIfAny = '',
    this.confidence = '',
  });

  factory SkinCareDetectedProduct.fromValue(dynamic value) {
    if (value is String) {
      return SkinCareDetectedProduct(name: value.trim());
    }
    if (value is! Map) return const SkinCareDetectedProduct();
    return SkinCareDetectedProduct.fromMap(Map<String, dynamic>.from(value));
  }

  factory SkinCareDetectedProduct.fromMap(Map<String, dynamic> map) {
    return SkinCareDetectedProduct(
      name: _stringValue(map['name']).trim(),
      brand: _stringValue(map['brand']).trim(),
      category: _stringValue(map['category']).trim(),
      source: _stringValue(map['source']).trim(),
      keyIngredients: _stringListFromValue(
        map['keyIngredients'] ?? map['ingredients'],
      ),
      possibleActives: _stringListFromValue(
        map['possibleActives'] ?? map['actives'],
      ),
      usageHint: _stringValue(map['usageHint'] ?? map['usage']).trim(),
      warningIfAny: _stringValue(
        map['warningIfAny'] ?? map['warning'] ?? map['warnings'],
      ).trim(),
      confidence: _stringValue(map['confidence']).trim(),
    );
  }

  bool get hasMeaningfulData =>
      name.isNotEmpty ||
      brand.isNotEmpty ||
      category.isNotEmpty ||
      source.isNotEmpty ||
      keyIngredients.isNotEmpty ||
      possibleActives.isNotEmpty ||
      usageHint.isNotEmpty ||
      warningIfAny.isNotEmpty;

  String get displayName {
    final cleanName = name.trim();
    final cleanBrand = brand.trim();
    if (cleanName.isEmpty) return cleanBrand;
    if (cleanBrand.isEmpty ||
        cleanName.toLowerCase().contains(cleanBrand.toLowerCase())) {
      return cleanName;
    }
    return '$cleanBrand $cleanName';
  }

  String get fallbackLabel {
    final display = displayName.trim();
    if (display.isNotEmpty) return display;
    final categoryValue = category.trim().toLowerCase();
    if (categoryValue == 'sunscreen' || _metadataLooksLikeSunscreen(this)) {
      return 'Sunscreen';
    }
    if (categoryValue == 'cleanser' || _metadataLooksLikeCleanser(this)) {
      return 'Cleanser';
    }
    if (categoryValue == 'moisturizer' ||
        categoryValue == 'moisturiser' ||
        _metadataLooksLikeMoisturizer(this)) {
      return 'Moisturizer';
    }
    return hasMeaningfulData ? 'Skin-care product' : '';
  }

  List<String> get searchableFields => [
    displayName,
    fallbackLabel,
    name,
    brand,
    category,
    ...keyIngredients,
    ...possibleActives,
  ];

  Map<String, dynamic> toMap() => {
    'name': name,
    'brand': brand,
    'category': category,
    if (source.isNotEmpty) 'source': source,
    'keyIngredients': keyIngredients,
    'possibleActives': possibleActives,
    'usageHint': usageHint,
    'warningIfAny': warningIfAny,
    'confidence': confidence,
  };

  Map<String, dynamic> toCompactRoutinePayload() {
    final map = <String, dynamic>{};
    if (name.isNotEmpty) map['name'] = _truncate(name, 50);
    if (brand.isNotEmpty) map['brand'] = _truncate(brand, 40);
    if (category.isNotEmpty) map['category'] = _truncate(category, 30);
    if (keyIngredients.isNotEmpty) {
      map['keyIngredients'] = keyIngredients
          .take(4)
          .map((i) => _truncate(i, 30))
          .toList();
    }
    if (possibleActives.isNotEmpty) {
      map['possibleActives'] = possibleActives
          .take(3)
          .map((a) => _truncate(a, 30))
          .toList();
    }
    if (usageHint.isNotEmpty) map['usageHint'] = _truncate(usageHint, 60);
    if (warningIfAny.isNotEmpty) {
      map['warningIfAny'] = _truncate(warningIfAny, 60);
    }
    return map;
  }
}

bool _metadataLooksLikeSunscreen(SkinCareDetectedProduct product) {
  final text = product.searchableFields.join(' ').toLowerCase();
  return text.contains('sunscreen') ||
      text.contains('spf') ||
      text.contains('sun protection') ||
      text.contains('uv filter') ||
      text.contains('broad spectrum');
}

bool _metadataLooksLikeCleanser(SkinCareDetectedProduct product) {
  final text = product.searchableFields.join(' ').toLowerCase();
  return text.contains('cleanser') ||
      text.contains('face wash') ||
      text.contains('foaming wash') ||
      text.contains('cleansing gel') ||
      text.contains('micellar');
}

bool _metadataLooksLikeMoisturizer(SkinCareDetectedProduct product) {
  final text = product.searchableFields.join(' ').toLowerCase();
  return text.contains('moisturizer') ||
      text.contains('moisturiser') ||
      text.contains('cream') ||
      text.contains('lotion') ||
      text.contains('hydrating gel') ||
      text.contains('barrier cream');
}

String _stringValue(dynamic value) {
  if (value is String) return value;
  if (value == null) return '';
  return value.toString();
}

List<String> _stringListFromValue(dynamic value) {
  if (value is List) {
    return value
        .map((item) => _stringValue(item).trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return [value.trim()];
  }
  return const [];
}

String _truncate(String value, int maxLength) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return trimmed.substring(0, maxLength).trim();
}
