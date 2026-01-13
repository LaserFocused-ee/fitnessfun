/// Recursively convert snake_case keys to camelCase for Dart models
dynamic snakeToCamel(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((key, v) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      return MapEntry(camelKey, snakeToCamel(v));
    });
  } else if (value is List) {
    return value.map(snakeToCamel).toList();
  }
  return value;
}
