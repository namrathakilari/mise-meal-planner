import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiMealResult {
  const AiMealResult(this.meal, this.source, this.note);
  final Meal meal;

  /// "groq" or "offline" (built-in engine).
  final String source;
  final String? note;
}

class PlanAssignment {
  const PlanAssignment(this.day, this.slot, this.mealId);
  final int day;
  final int slot;
  final String mealId;
}

class AiPlanResult {
  const AiPlanResult(this.assignments, this.newMeals, this.source, this.note);
  final List<PlanAssignment> assignments;

  /// Meals the AI invented, keyed by the temporary id used in [assignments].
  final Map<String, Meal> newMeals;
  final String source;
  final String? note;
}

class AiMergeResult {
  const AiMergeResult(this.aliases, this.source, this.note);
  final Map<String, String> aliases;
  final String source;
  final String? note;
}

int _idCounter = 0;
String _newMealId() => 'm${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

Meal _mealFromServer(Map<String, dynamic> j) {
  final name = (j['name'] ?? '') as String;
  return Meal.fromJson({
    ...j,
    'id': _newMealId(),
    'colorIndex': name.codeUnits.fold<int>(0, (a, b) => a + b) % 8,
  });
}

/// Thin HTTP client for the Mise server (households + AI endpoints).
class ApiClient {
  ApiClient(String baseUrl) : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Uri wsUri(String code) {
    final u = Uri.parse(baseUrl);
    return Uri(
      scheme: u.scheme == 'https' ? 'wss' : 'ws',
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: '/ws',
      queryParameters: {'code': code},
    );
  }

  Future<http.Response> _run(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException('The server took too long to answer.');
    } catch (_) {
      throw ApiException('Cannot reach the Mise server at $baseUrl. Is it running?');
    }
  }

  Map<String, dynamic> _decode(http.Response r) {
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    if (r.statusCode >= 400) {
      throw ApiException((body['error'] ?? 'Request failed (${r.statusCode})').toString());
    }
    return body;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await _run(() => http.post(
          _u(path),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        ));
    return _decode(r);
  }

  // ------------------------------------------------------------- households
  Future<Map<String, dynamic>> health() async => _decode(await _run(() => http.get(_u('/api/health'))));

  Future<String> createHousehold() async {
    final body = await _post('/api/households', {});
    return body['code'] as String;
  }

  Future<bool> householdExists(String code) async {
    final r = await _run(() => http.get(_u('/api/households/$code')));
    if (r.statusCode == 404) return false;
    _decode(r);
    return true;
  }

  // --------------------------------------------------------------------- AI
  Future<AiMealResult> generateMeal(String prompt, int servings) async {
    final body = await _post('/api/ai/meal', {'prompt': prompt, 'servings': servings});
    return AiMealResult(
      _mealFromServer(Map<String, dynamic>.from(body['meal'] as Map)),
      (body['source'] ?? 'offline') as String,
      body['note'] as String?,
    );
  }

  Future<AiPlanResult> planWeek({
    required String preferences,
    required List<Meal> meals,
    required List<Map<String, int>> slots,
    required bool allowNew,
  }) async {
    final body = await _post('/api/ai/plan', {
      'preferences': preferences,
      'allowNew': allowNew,
      'slots': slots,
      'meals': meals
          .map((m) => {
                'id': m.id,
                'name': m.name,
                'ingredients': m.ingredients
                    .map((i) => {'name': i.name, 'category': i.category.name})
                    .toList(),
              })
          .toList(),
    });
    final newMeals = <String, Meal>{};
    for (final raw in (body['newMeals'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      final tempId = j['tempId'] as String?;
      if (tempId != null) newMeals[tempId] = _mealFromServer(j);
    }
    final assignments = <PlanAssignment>[];
    for (final raw in (body['assignments'] as List? ?? const [])) {
      final j = Map<String, dynamic>.from(raw as Map);
      assignments.add(PlanAssignment(
        (j['day'] as num).toInt(),
        (j['slot'] as num).toInt(),
        j['mealId'] as String,
      ));
    }
    return AiPlanResult(
      assignments,
      newMeals,
      (body['source'] ?? 'offline') as String,
      body['note'] as String?,
    );
  }

  Future<AiMergeResult> normalize(List<String> names) async {
    final body = await _post('/api/ai/normalize', {'names': names});
    final aliases = <String, String>{};
    (body['aliases'] as Map? ?? const {}).forEach((k, v) => aliases['$k'] = '$v');
    return AiMergeResult(aliases, (body['source'] ?? 'offline') as String, body['note'] as String?);
  }
}
