import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

T? readSavedPreference<T>(SharedPreferences preferences, String key) {
  final value = preferences.get(key);
  if (value == null) return null;
  if (value is T) return value as T;
  _logInvalidPreference(key);
  return null;
}

List<String> readSavedStringList(SharedPreferences preferences, String key) {
  final value = readSavedPreference<List<Object?>>(preferences, key);
  if (value == null) return const [];
  if (value.every((item) => item is String)) return List<String>.from(value);
  _logInvalidPreference(key);
  return const [];
}

void _logInvalidPreference(String key) {
  // Log only the internal key; saved values may contain private media links.
  developer.log(
    'Ignoring invalid saved preference "$key"; using its default.',
    name: 'TurboSave.preferences',
  );
}
