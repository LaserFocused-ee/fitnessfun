/// Recursively convert snake_case keys to camelCase for Dart models
/// Also handles type coercion for numeric values stored as strings
dynamic snakeToCamel(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((key, v) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      // Apply type coercion for known numeric fields
      final coercedValue = _coerceNumericFields(camelKey, snakeToCamel(v));
      return MapEntry(camelKey, coercedValue);
    });
  } else if (value is List) {
    return value.map(snakeToCamel).toList();
  }
  return value;
}

/// Coerce string values to numbers for known numeric fields
dynamic _coerceNumericFields(String key, dynamic value) {
  if (value == null) return value;

  // Known integer fields
  const intFields = {
    'setNumber', 'targetReps', 'targetRepsMax', 'reps',
    'targetRestMin', 'targetRestMax', 'restMin', 'restMax',
  };

  // Known double fields
  const doubleFields = {'targetWeight', 'weight'};

  if (intFields.contains(key) && value is String) {
    return int.tryParse(value);
  }

  if (doubleFields.contains(key) && value is String) {
    return double.tryParse(value);
  }

  return value;
}
