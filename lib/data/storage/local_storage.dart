import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> contains(String key) async => (await _prefs).containsKey(key);

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    await (await _prefs).setString(key, jsonEncode(value));
  }

  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = (await _prefs).getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  Future<String?> getString(String key) async => (await _prefs).getString(key);

  Future<void> setStringList(String key, List<String> value) async {
    await (await _prefs).setStringList(key, value);
  }

  Future<List<String>> getStringList(String key) async =>
      (await _prefs).getStringList(key) ?? [];
}
