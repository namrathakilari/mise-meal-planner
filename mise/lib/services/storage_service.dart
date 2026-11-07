import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Local-first persistence. On the web, shared_preferences uses the browser's
/// localStorage, so data survives refreshes (but is per-browser, per-device).
class StorageService {
  StorageService(this._prefs);
  final SharedPreferences _prefs;

  static Future<StorageService> create() async =>
      StorageService(await SharedPreferences.getInstance());

  List<Meal> loadMeals() {
    final raw = _prefs.getString('meals');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Meal.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMeals(Iterable<Meal> meals) =>
      _prefs.setString('meals', jsonEncode(meals.map((m) => m.toJson()).toList()));

  Map<String, String> loadPlan() {
    final raw = _prefs.getString('plan');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlan(Map<String, String> plan) => _prefs.setString('plan', jsonEncode(plan));

  Set<String> loadChecked() {
    final raw = _prefs.getString('checked');
    if (raw == null) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveChecked(Set<String> checked) =>
      _prefs.setString('checked', jsonEncode(checked.toList()));

  bool get seeded => _prefs.getBool('seeded') ?? false;
  Future<void> setSeeded() => _prefs.setBool('seeded', true);

  String? get theme => _prefs.getString('theme');
  Future<void> setTheme(String value) => _prefs.setString('theme', value);

  Map<String, String> loadAliases() {
    final raw = _prefs.getString('aliases');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAliases(Map<String, String> aliases) =>
      _prefs.setString('aliases', jsonEncode(aliases));

  String? get householdCode => _prefs.getString('household');
  Future<void> setHouseholdCode(String? code) =>
      code == null ? _prefs.remove('household') : _prefs.setString('household', code);

  String? get serverUrl => _prefs.getString('server');
  Future<void> setServerUrl(String url) => _prefs.setString('server', url);
}
