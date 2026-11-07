import 'package:flutter_test/flutter_test.dart';
import 'package:mise/models/models.dart';
import 'package:mise/services/grocery_service.dart';

Meal meal(String name, List<RecipeIngredient> ings) =>
    Meal(id: name, name: name, ingredients: ings);

RecipeIngredient ing(String n, double? q, String u) => RecipeIngredient(
    name: n, quantity: q, unit: u, category: IngredientCategory.produce);

void main() {
  group('GroceryService aliases (AI smart merge)', () {
    final meals = [
      meal('Shakshuka', [ing('Tomato', 4, '')]),
      meal('Pasta', [ing('Tomatoes', 6, '')]),
    ];

    test('without aliases the spellings stay separate', () {
      expect(GroceryService.aggregate(meals).length, 2);
    });

    test('an alias merges the rows and sums the quantities', () {
      final items = GroceryService.aggregate(meals, aliases: {'tomatoes': 'Tomato'});
      expect(items.length, 1);
      expect(items.single.name, 'Tomato');
      expect(items.single.quantity, 10);
      expect(items.single.fromMeals, ['Shakshuka', 'Pasta']);
    });
  });
}
