import '../models/models.dart';

/// Pure aggregation logic: planned meals in, shopping list out.
/// No storage, no widgets - which makes it trivial to unit-test.
class GroceryService {
  static String itemKey(String name, String unit) =>
      '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';

  /// [plannedMeals] contains one entry per planned slot (a meal planned twice
  /// appears twice), so quantities are naturally doubled.
  ///
  /// [aliases] maps a lowercase ingredient name to the name it should be merged
  /// into (e.g. "tomatoes" -> "Tomato"). Used by the AI "smart merge".
  static List<GroceryItem> aggregate(
    Iterable<Meal> plannedMeals, {
    Map<String, String> aliases = const {},
  }) {
    final qty = <String, double>{};
    final base = <String, RecipeIngredient>{};
    final toTaste = <String, bool>{};
    final sources = <String, List<String>>{};

    for (final meal in plannedMeals) {
      for (final ing in meal.ingredients) {
        final rawName = ing.name.trim();
        if (rawName.isEmpty) continue;
        final name = aliases[rawName.toLowerCase()] ?? rawName;
        final isToTaste = ing.quantity == null || ing.quantity! <= 0;
        // Different units stay on separate rows on purpose (no unit conversion).
        final key = itemKey(name, isToTaste ? '~' : ing.unit);
        base.putIfAbsent(
          key,
          () => RecipeIngredient(
            name: name,
            quantity: ing.quantity,
            unit: ing.unit,
            category: ing.category,
          ),
        );
        toTaste[key] = isToTaste;
        if (!isToTaste) {
          qty[key] = (qty[key] ?? 0) + ing.quantity!;
        }
        final list = sources.putIfAbsent(key, () => <String>[]);
        if (!list.contains(meal.name)) list.add(meal.name);
      }
    }

    final items = base.entries.map((e) {
      final ing = e.value;
      final taste = toTaste[e.key] ?? false;
      return GroceryItem(
        key: e.key,
        name: ing.name.trim(),
        unit: taste ? '' : ing.unit.trim(),
        quantity: taste ? 0 : double.parse((qty[e.key] ?? 0).toStringAsFixed(2)),
        toTaste: taste,
        category: ing.category,
        fromMeals: sources[e.key] ?? const [],
      );
    }).toList();

    items.sort((a, b) {
      final c = a.category.index.compareTo(b.category.index);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// Plain-text version of the list (for copy / share).
  static String toPlainText(List<GroceryItem> items, String Function(GroceryItem) amount) {
    final buffer = StringBuffer();
    IngredientCategory? current;
    for (final i in items) {
      if (i.category != current) {
        if (current != null) buffer.writeln();
        buffer.writeln(i.category.label);
        current = i.category;
      }
      buffer.writeln('- ${i.name} (${amount(i)})');
    }
    return buffer.toString().trim();
  }
}
