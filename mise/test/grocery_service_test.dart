import 'package:flutter_test/flutter_test.dart';
import 'package:mise/models/models.dart';
import 'package:mise/services/grocery_service.dart';
import 'package:mise/utils/formatters.dart';

Meal meal(String name, List<RecipeIngredient> ings) =>
    Meal(id: name, name: name, ingredients: ings);

RecipeIngredient ing(String n, double? q, String u,
        [IngredientCategory c = IngredientCategory.produce]) =>
    RecipeIngredient(name: n, quantity: q, unit: u, category: c);

void main() {
  group('GroceryService.aggregate', () {
    test('sums the same ingredient across meals', () {
      final items = GroceryService.aggregate([
        meal('Shakshuka', [ing('Tomato', 4, '')]),
        meal('Pasta', [ing('tomato', 6, '')]),
      ]);
      expect(items.length, 1);
      expect(items.first.quantity, 10);
      expect(items.first.fromMeals, ['Shakshuka', 'Pasta']);
    });

    test('a meal planned twice counts twice', () {
      final m = meal('Oats', [ing('Banana', 1, '')]);
      final items = GroceryService.aggregate([m, m]);
      expect(items.single.quantity, 2);
    });

    test('different units stay on separate rows', () {
      final items = GroceryService.aggregate([
        meal('A', [ing('Garlic', 2, 'cloves')]),
        meal('B', [ing('Garlic', 1, 'tsp')]),
      ]);
      expect(items.length, 2);
    });

    test('to-taste items are not summed and flagged', () {
      final items = GroceryService.aggregate([
        meal('A', [ing('Salt', null, '', IngredientCategory.pantry)]),
        meal('B', [ing('Salt', null, '', IngredientCategory.pantry)]),
      ]);
      expect(items.single.toTaste, isTrue);
      expect(items.single.quantity, 0);
    });

    test('sorted by category then name', () {
      final items = GroceryService.aggregate([
        meal('A', [
          ing('Rice', 1, 'cup', IngredientCategory.pantry),
          ing('Zucchini', 1, ''),
          ing('Apple', 1, ''),
        ]),
      ]);
      expect(items.map((i) => i.name).toList(), ['Apple', 'Zucchini', 'Rice']);
    });

    test('floating point sums are rounded', () {
      final items = GroceryService.aggregate([
        meal('A', [ing('Milk', 0.1, 'l')]),
        meal('B', [ing('Milk', 0.2, 'l')]),
      ]);
      expect(items.single.quantity, 0.3);
    });
  });

  group('quantity helpers', () {
    test('parseQuantity', () {
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('2'), 2);
      expect(parseQuantity('1.5'), 1.5);
      expect(parseQuantity('1/2'), 0.5);
      expect(parseQuantity('1 1/2'), 1.5);
      expect(parseQuantity('abc'), -1);
      expect(parseQuantity('1/0'), -1);
    });

    test('formatQuantity', () {
      expect(formatQuantity(2), '2');
      expect(formatQuantity(0.5), '½');
      expect(formatQuantity(1.5), '1½');
      expect(formatQuantity(2.25), '2¼');
      expect(formatQuantity(0.3), '0.3');
    });
  });

  group('dates', () {
    test('mondayOf', () {
      expect(isoDate(mondayOf(DateTime(2026, 11, 7))), '2026-11-02'); // Saturday
      expect(isoDate(mondayOf(DateTime(2026, 11, 9))), '2026-11-09'); // Monday
    });

    test('weekRangeLabel crosses months', () {
      expect(weekRangeLabel(DateTime(2026, 11, 9)), 'Nov 9 – 15');
      expect(weekRangeLabel(DateTime(2026, 11, 30)), 'Nov 30 – Dec 6');
    });
  });
}
