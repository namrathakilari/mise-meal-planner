import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/config.dart';
import '../services/grocery_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../utils/formatters.dart';

/// Snapshot used for "Undo" after deleting a meal.
class DeletedMeal {
  const DeletedMeal(this.meal, this.entries);
  final Meal meal;
  final Map<String, String> entries;
}

class AiPlanOutcome {
  const AiPlanOutcome(this.filled, this.newMeals, this.source, this.note);
  final int filled;
  final int newMeals;
  final String source;
  final String? note;
}

class AiMergeOutcome {
  const AiMergeOutcome(this.merged, this.source, this.note);
  final int merged;
  final String source;
  final String? note;
}

/// Whether the grocery list covers the whole visible week or a single day.
enum GroceryScope { week, day }

class AppState extends ChangeNotifier {
  AppState(this._storage) {
    _serverUrl = _storage.serverUrl ?? defaultServerUrl();
    _api = ApiClient(_serverUrl);
    _sync = SyncService(
      onState: _onRemoteState,
      onOps: _applyOps,
      onStatus: (s) {
        _syncStatus = s;
        if (s != SyncStatus.online) _peers = 0;
        notifyListeners();
      },
      onPeers: (n) {
        _peers = n;
        notifyListeners();
      },
      onFatal: () {
        _householdCode = null;
        _storage.setHouseholdCode(null);
        notifyListeners();
      },
    );
  }
  final StorageService _storage;
  late final SyncService _sync;
  late ApiClient _api;
  late String _serverUrl;
  String? _householdCode;
  SyncStatus _syncStatus = SyncStatus.off;
  int _peers = 0;
  String _aiMode = 'unknown'; // unknown | groq | offline | unreachable
  Map<String, String> _aliases = <String, String>{};

  final Map<String, Meal> _meals = <String, Meal>{};
  Map<String, String> _plan = <String, String>{};
  Set<String> _checked = <String>{};
  DateTime _weekStart = mondayOf(DateTime.now());
  DateTime _todayStamp = _dateOnly(DateTime.now());
  GroceryScope _groceryScope = GroceryScope.week;
  int _selectedDay = 0;
  int _navIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;

  // ---------------------------------------------------------------- loading
  void load() {
    for (final m in _storage.loadMeals()) {
      _meals[m.id] = m;
    }
    _plan = _storage.loadPlan();
    _checked = _storage.loadChecked();
    final t = _storage.theme;
    _themeMode = t == 'dark' ? ThemeMode.dark : (t == 'light' ? ThemeMode.light : ThemeMode.system);
    _aliases = _storage.loadAliases();
    _weekStart = mondayOf(DateTime.now());
    _selectedDay = DateTime.now().weekday - 1;
    if (!_storage.seeded) {
      _applySamples();
      _storage.setSeeded();
    }
    _householdCode = _storage.householdCode;
    if (_householdCode != null) _startSync();
    refreshAiMode();
  }

  void _applySamples() {
    _meals
      ..clear()
      ..addEntries(sampleMeals().map((m) => MapEntry(m.id, m)));
    _plan = samplePlan(weekKey);
    _checked = <String>{};
    _aliases = <String, String>{};
    _saveMeals();
    _savePlan();
    _saveChecked();
    _saveAliases();
  }

  void resetToSamples() {
    _weekStart = mondayOf(DateTime.now());
    _selectedDay = DateTime.now().weekday - 1;
    _applySamples();
    _sync.sendRaw({'type': 'replace', 'state': _snapshotJson()});
    notifyListeners();
  }

  void _saveMeals() => _storage.saveMeals(_meals.values);
  void _savePlan() => _storage.savePlan(_plan);
  void _saveChecked() => _storage.saveChecked(_checked);
  void _saveAliases() => _storage.saveAliases(_aliases);

  // ------------------------------------------------------------------- sync
  SyncStatus get syncStatus => _syncStatus;
  int get peers => _peers;
  String? get householdCode => _householdCode;
  String get serverUrl => _serverUrl;
  String get aiMode => _aiMode;
  Map<String, String> get aliases => Map.unmodifiable(_aliases);

  void _emit(Map<String, dynamic> op) => _sync.send(op);

  Map<String, dynamic> _snapshotJson() => {
        'meals': _meals.values.map((m) => m.toJson()).toList(),
        'plan': _plan,
        'checked': _checked.toList(),
        'aliases': _aliases,
      };

  void _startSync() {
    final code = _householdCode;
    if (code == null) return;
    _sync.start(_api.wsUri(code));
  }

  /// Full state from the server (on connect / reconnect / remote reset).
  void _onRemoteState(Map<String, dynamic> s) {
    final rev = (s['rev'] as num?)?.toInt() ?? 0;
    if (rev == 0 && (_meals.isNotEmpty || _plan.isNotEmpty)) {
      // Brand-new household: upload what this device already has.
      _sync.sendRaw({'type': 'snapshot', 'state': _snapshotJson()});
      return;
    }
    _meals
      ..clear()
      ..addEntries(((s['meals'] as List?) ?? const []).map((e) {
        final m = Meal.fromJson(Map<String, dynamic>.from(e as Map));
        return MapEntry(m.id, m);
      }));
    _plan = Map<String, String>.from((s['plan'] as Map?) ?? const {});
    _checked = Set<String>.from((s['checked'] as List?) ?? const []);
    _aliases = Map<String, String>.from((s['aliases'] as Map?) ?? const {});
    _saveMeals();
    _savePlan();
    _saveChecked();
    _saveAliases();
    notifyListeners();
  }

  /// Operations from other devices. Never re-emitted, so there are no echoes.
  void _applyOps(List<Map<String, dynamic>> ops) {
    for (final op in ops) {
      switch (op['t']) {
        case 'meal.set':
          {
            final raw = op['meal'];
            if (raw is Map) {
              final meal = Meal.fromJson(Map<String, dynamic>.from(raw));
              _meals[meal.id] = meal;
            }
            break;
          }
        case 'meal.del':
          {
            final id = op['id'] as String;
            _meals.remove(id);
            _plan.removeWhere((k, v) => v == id);
            break;
          }
        case 'plan.set':
          _plan[op['key'] as String] = op['id'] as String;
          break;
        case 'plan.del':
          _plan.remove(op['key'] as String);
          break;
        case 'check.set':
          {
            final k = op['key'] as String;
            if (op['on'] == true) {
              _checked.add(k);
            } else {
              _checked.remove(k);
            }
            break;
          }
        case 'alias.set':
          {
            final from = (op['from'] as String).trim().toLowerCase();
            final to = ((op['to'] as String?) ?? '').trim();
            if (to.isEmpty) {
              _aliases.remove(from);
            } else {
              _aliases[from] = to;
            }
            break;
          }
      }
    }
    _saveMeals();
    _savePlan();
    _saveChecked();
    _saveAliases();
    notifyListeners();
  }

  Future<String?> createHousehold() async {
    try {
      final code = await _api.createHousehold();
      return await joinHousehold(code);
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> joinHousehold(String raw) async {
    final code = raw.trim().toUpperCase();
    if (!RegExp(r'^[A-Z2-9]{6}$').hasMatch(code)) {
      return 'Codes are 6 characters, letters and digits.';
    }
    try {
      if (!await _api.householdExists(code)) return 'No household found with that code.';
    } on ApiException catch (e) {
      return e.message;
    }
    _householdCode = code;
    await _storage.setHouseholdCode(code);
    _startSync();
    notifyListeners();
    return null;
  }

  void leaveHousehold() {
    _sync.stop();
    _householdCode = null;
    _storage.setHouseholdCode(null);
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> setServerUrl(String raw) async {
    var url = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'Start the address with http:// or https://';
    }
    final candidate = ApiClient(url);
    try {
      final h = await candidate.health();
      _aiMode = (h['ai'] ?? 'offline') as String;
    } on ApiException catch (e) {
      return e.message;
    }
    _serverUrl = url;
    _api = candidate;
    await _storage.setServerUrl(url);
    if (_householdCode != null) _startSync();
    notifyListeners();
    return null;
  }

  // --------------------------------------------------------------------- AI
  Future<void> refreshAiMode() async {
    try {
      final h = await _api.health();
      _aiMode = (h['ai'] ?? 'offline') as String;
    } catch (_) {
      _aiMode = 'unreachable';
    }
    notifyListeners();
  }

  /// Throws [ApiException] on failure (message is user-friendly).
  Future<AiMealResult> aiGenerateMeal(String prompt, int servings) async {
    final r = await _api.generateMeal(prompt, servings);
    _aiMode = r.source;
    notifyListeners();
    return r;
  }

  /// Fills the empty slots of the visible week.
  Future<AiPlanOutcome> aiPlanWeek(String preferences, {required bool allowNew}) async {
    final slots = <Map<String, int>>[];
    for (var d = 0; d < 7; d++) {
      for (final s in MealSlot.values) {
        if (mealAt(d, s) == null) slots.add({'day': d, 'slot': s.index});
      }
    }
    if (slots.isEmpty) {
      return const AiPlanOutcome(0, 0, 'offline', 'Every slot this week is already planned.');
    }
    final r = await _api.planWeek(
      preferences: preferences,
      meals: mealList,
      slots: slots,
      allowNew: allowNew,
    );
    _aiMode = r.source;
    var filled = 0;
    final created = <String>{};
    for (final a in r.assignments) {
      if (a.day < 0 || a.day > 6 || a.slot < 0 || a.slot > 2) continue;
      final fresh = r.newMeals[a.mealId];
      final id = fresh?.id ?? a.mealId;
      if (fresh != null && !_meals.containsKey(id)) {
        upsertMeal(fresh);
        created.add(id);
      }
      if (!_meals.containsKey(id)) continue;
      assignMeal(a.day, MealSlot.values[a.slot], id);
      filled++;
    }
    notifyListeners();
    return AiPlanOutcome(filled, created.length, r.source, r.note);
  }

  /// Merges duplicate ingredient names ("Tomatoes" -> "Tomato") on the grocery list.
  Future<AiMergeOutcome> aiSmartMerge() async {
    final names = <String>{};
    for (final m in _meals.values) {
      for (final i in m.ingredients) {
        final n = i.name.trim();
        if (n.isNotEmpty) names.add(n);
      }
    }
    final r = await _api.normalize(names.toList());
    _aiMode = r.source;
    var merged = 0;
    for (final e in r.aliases.entries) {
      final from = e.key.toLowerCase();
      if (_aliases[from] == e.value) continue;
      _aliases[from] = e.value;
      _emit({'t': 'alias.set', 'from': from, 'to': e.value});
      merged++;
    }
    _saveAliases();
    notifyListeners();
    return AiMergeOutcome(merged, r.source, r.note);
  }

  void clearAliases() {
    for (final k in _aliases.keys) {
      _emit({'t': 'alias.set', 'from': k, 'to': ''});
    }
    _aliases.clear();
    _saveAliases();
    notifyListeners();
  }

  // ------------------------------------------------------------- navigation
  int get navIndex => _navIndex;
  void setNav(int i) {
    _navIndex = i;
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  void setDark(bool dark) {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    _storage.setTheme(dark ? 'dark' : 'light');
    notifyListeners();
  }

  // ------------------------------------------------------------------ weeks
  DateTime get weekStart => _weekStart;
  String get weekKey => isoDate(_weekStart);
  String get weekLabel => weekRangeLabel(_weekStart);
  int get weekYear => _weekStart.year;
  bool get isCurrentWeek => isSameDay(_weekStart, mondayOf(DateTime.now()));
  DateTime dateForDay(int day) => addDays(_weekStart, day);
  bool isToday(int day) => isSameDay(dateForDay(day), DateTime.now());

  int get selectedDay => _selectedDay;
  void selectDay(int d) {
    _selectedDay = d;
    notifyListeners();
  }

  void shiftWeek(int weeks) {
    _weekStart = addDays(_weekStart, 7 * weeks);
    notifyListeners();
  }

  void goToToday() {
    _weekStart = mondayOf(DateTime.now());
    _selectedDay = DateTime.now().weekday - 1;
    _todayStamp = _dateOnly(DateTime.now());
    notifyListeners();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Call when the app resumes or on a timer. If the calendar day changed
  /// while the app stayed open, a user who was looking at the current week is
  /// moved to the new current week (and today). Someone browsing another week
  /// is left where they are. Returns true when anything changed.
  bool syncToToday() {
    final now = DateTime.now();
    if (isSameDay(_todayStamp, now)) return false;
    final wasOnCurrentWeek = isSameDay(_weekStart, mondayOf(_todayStamp));
    _todayStamp = _dateOnly(now);
    if (wasOnCurrentWeek) {
      _weekStart = mondayOf(now);
      _selectedDay = now.weekday - 1;
    }
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------ meals
  List<Meal> get mealList {
    final list = _meals.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Meal? mealById(String id) => _meals[id];

  void upsertMeal(Meal meal) {
    _meals[meal.id] = meal;
    _saveMeals();
    _emit({'t': 'meal.set', 'meal': meal.toJson()});
    notifyListeners();
  }

  DeletedMeal deleteMeal(String id) {
    final meal = _meals.remove(id)!;
    final entries = <String, String>{};
    _plan.removeWhere((k, v) {
      if (v == id) {
        entries[k] = v;
        return true;
      }
      return false;
    });
    _saveMeals();
    _savePlan();
    _emit({'t': 'meal.del', 'id': id});
    notifyListeners();
    return DeletedMeal(meal, entries);
  }

  void restoreMeal(DeletedMeal d) {
    _meals[d.meal.id] = d.meal;
    _plan.addAll(d.entries);
    _saveMeals();
    _savePlan();
    _emit({'t': 'meal.set', 'meal': d.meal.toJson()});
    d.entries.forEach((k, v) => _emit({'t': 'plan.set', 'key': k, 'id': v}));
    notifyListeners();
  }

  /// Distinct ingredients seen across all meals (powers autocomplete).
  List<RecipeIngredient> get ingredientCatalog {
    final map = <String, RecipeIngredient>{};
    for (final m in _meals.values) {
      for (final i in m.ingredients) {
        final k = i.name.trim().toLowerCase();
        if (k.isEmpty) continue;
        map.putIfAbsent(k, () => RecipeIngredient(name: i.name.trim(), unit: i.unit, category: i.category));
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ------------------------------------------------------------------- plan
  Meal? mealAt(int day, MealSlot slot) {
    final id = _plan[planKey(weekKey, day, slot)];
    return id == null ? null : _meals[id];
  }

  void assignMeal(int day, MealSlot slot, String mealId) {
    final key = planKey(weekKey, day, slot);
    _plan[key] = mealId;
    _savePlan();
    _emit({'t': 'plan.set', 'key': key, 'id': mealId});
    notifyListeners();
  }

  void clearSlot(int day, MealSlot slot) {
    final key = planKey(weekKey, day, slot);
    _plan.remove(key);
    _savePlan();
    _emit({'t': 'plan.del', 'key': key});
    notifyListeners();
  }

  List<Meal> get plannedMeals {
    final out = <Meal>[];
    for (var d = 0; d < 7; d++) {
      for (final s in MealSlot.values) {
        final m = mealAt(d, s);
        if (m != null) out.add(m);
      }
    }
    return out;
  }

  int get plannedCount => plannedMeals.length;

  int timesPlanned(String mealId) => plannedMeals.where((m) => m.id == mealId).length;

  int plannedInDay(int day) => MealSlot.values.where((s) => mealAt(day, s) != null).length;

  /// Copies last week's plan into empty slots of this week. Returns how many were copied.
  int copyLastWeek() {
    final prev = isoDate(addDays(_weekStart, -7));
    var n = 0;
    for (var d = 0; d < 7; d++) {
      for (final s in MealSlot.values) {
        final src = _plan[planKey(prev, d, s)];
        if (src != null && _meals.containsKey(src)) {
          final k = planKey(weekKey, d, s);
          if (!_plan.containsKey(k)) {
            _plan[k] = src;
            _emit({'t': 'plan.set', 'key': k, 'id': src});
            n++;
          }
        }
      }
    }
    if (n > 0) {
      _savePlan();
      notifyListeners();
    }
    return n;
  }

  Map<String, String> clearWeek() {
    final prefix = '$weekKey|';
    final removed = <String, String>{};
    _plan.removeWhere((k, v) {
      if (k.startsWith(prefix)) {
        removed[k] = v;
        return true;
      }
      return false;
    });
    _savePlan();
    removed.keys.forEach((k) => _emit({'t': 'plan.del', 'key': k}));
    notifyListeners();
    return removed;
  }

  void restorePlanEntries(Map<String, String> entries) {
    _plan.addAll(entries);
    _savePlan();
    entries.forEach((k, v) => _emit({'t': 'plan.set', 'key': k, 'id': v}));
    notifyListeners();
  }

  // ---------------------------------------------------------------- grocery
  GroceryScope get groceryScope => _groceryScope;
  void setGroceryScope(GroceryScope s) {
    if (_groceryScope == s) return;
    _groceryScope = s;
    notifyListeners();
  }

  /// Meals planned on one day of the visible week (one entry per slot).
  List<Meal> plannedMealsForDay(int day) {
    final out = <Meal>[];
    for (final s in MealSlot.values) {
      final m = mealAt(day, s);
      if (m != null) out.add(m);
    }
    return out;
  }

  /// Everything to buy for the whole visible week.
  List<GroceryItem> get weekGroceryItems => GroceryService.aggregate(plannedMeals, aliases: _aliases);

  /// The list for the current scope: whole week, or just the selected day.
  List<GroceryItem> get groceryItems => _groceryScope == GroceryScope.week
      ? weekGroceryItems
      : GroceryService.aggregate(plannedMealsForDay(_selectedDay), aliases: _aliases);

  /// "Nov 9 – 15" for the week, or "Monday, Nov 9" for a single day.
  String get groceryScopeLabel {
    if (_groceryScope == GroceryScope.week) return weekLabel;
    final d = dateForDay(_selectedDay);
    return '${weekdayLong(_selectedDay)}, ${monthShort(d)} ${d.day}';
  }

  // Week ticks keep the original key format so existing data still works.
  // Day ticks live under their own key so the two lists stay independent.
  String _weekCheckKey(GroceryItem i) => '$weekKey|${i.key}';
  String _dayCheckKey(GroceryItem i) => '$weekKey|~d$_selectedDay|${i.key}';
  String _checkKey(GroceryItem i) =>
      _groceryScope == GroceryScope.week ? _weekCheckKey(i) : _dayCheckKey(i);
  bool isChecked(GroceryItem i) => _checked.contains(_checkKey(i));

  int get checkedCount => groceryItems.where(isChecked).length;

  /// Nav badge: items still to buy for the whole week, whichever scope is open.
  int get groceryLeftCount =>
      weekGroceryItems.where((i) => !_checked.contains(_weekCheckKey(i))).length;

  void toggleChecked(GroceryItem i) {
    final k = _checkKey(i);
    final nowOn = !_checked.remove(k);
    if (nowOn) _checked.add(k);
    _saveChecked();
    _emit({'t': 'check.set', 'key': k, 'on': nowOn});
    notifyListeners();
  }

  void clearChecked() {
    final dayPrefix = '$weekKey|~d';
    final bool Function(String) mine = _groceryScope == GroceryScope.week
        ? (k) => k.startsWith('$weekKey|') && !k.startsWith(dayPrefix)
        : (k) => k.startsWith('$dayPrefix$_selectedDay|');
    final gone = _checked.where(mine).toList();
    _checked.removeWhere(mine);
    _saveChecked();
    for (final k in gone) {
      _emit({'t': 'check.set', 'key': k, 'on': false});
    }
    notifyListeners();
  }
}
