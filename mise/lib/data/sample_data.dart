import '../models/models.dart';

const _p = IngredientCategory.produce;
const _d = IngredientCategory.dairy;
const _m = IngredientCategory.meat;
const _n = IngredientCategory.pantry;
const _f = IngredientCategory.frozen;

RecipeIngredient _i(String name, double? qty, String unit, IngredientCategory c) =>
    RecipeIngredient(name: name, quantity: qty, unit: unit, category: c);

/// Demo meals. Many share tomato / garlic / olive oil so the grocery list
/// visibly sums quantities.
List<Meal> sampleMeals() => [
      Meal(id: 'm_shakshuka', name: 'Shakshuka', emoji: '🍳', colorIndex: 0, servings: 2, ingredients: [
        _i('Tomato', 4, '', _p),
        _i('Onion', 1, '', _p),
        _i('Garlic', 3, 'cloves', _p),
        _i('Eggs', 4, '', _d),
        _i('Olive oil', 2, 'tbsp', _n),
        _i('Cumin', 1, 'tsp', _n),
        _i('Salt', null, '', _n),
      ]),
      Meal(id: 'm_oats', name: 'Overnight oats', emoji: '🥣', colorIndex: 1, servings: 1, ingredients: [
        _i('Rolled oats', 1, 'cup', _n),
        _i('Milk', 1, 'cup', _d),
        _i('Banana', 1, '', _p),
        _i('Honey', 1, 'tbsp', _n),
      ]),
      Meal(id: 'm_caprese', name: 'Caprese sandwich', emoji: '🥪', colorIndex: 2, servings: 2, ingredients: [
        _i('Tomato', 2, '', _p),
        _i('Mozzarella', 150, 'g', _d),
        _i('Basil', 1, 'bunch', _p),
        _i('Ciabatta', 2, '', _n),
        _i('Olive oil', 1, 'tbsp', _n),
      ]),
      Meal(id: 'm_stirfry', name: 'Chicken stir-fry', emoji: '🍗', colorIndex: 5, servings: 3, ingredients: [
        _i('Chicken breast', 500, 'g', _m),
        _i('Bell pepper', 2, '', _p),
        _i('Broccoli', 1, 'head', _p),
        _i('Garlic', 2, 'cloves', _p),
        _i('Soy sauce', 3, 'tbsp', _n),
        _i('Rice', 1, 'cup', _n),
      ]),
      Meal(id: 'm_pasta', name: 'Pasta pomodoro', emoji: '🍝', colorIndex: 0, servings: 3, ingredients: [
        _i('Spaghetti', 250, 'g', _n),
        _i('Tomato', 6, '', _p),
        _i('Garlic', 3, 'cloves', _p),
        _i('Basil', 1, 'bunch', _p),
        _i('Parmesan', 40, 'g', _d),
        _i('Olive oil', 2, 'tbsp', _n),
        _i('Salt', null, '', _n),
      ]),
      Meal(id: 'm_curry', name: 'Chickpea curry', emoji: '🍛', colorIndex: 1, servings: 4, ingredients: [
        _i('Chickpeas', 400, 'g', _n),
        _i('Coconut milk', 400, 'ml', _n),
        _i('Onion', 2, '', _p),
        _i('Spinach', 200, 'g', _p),
        _i('Tomato', 2, '', _p),
        _i('Garlic', 4, 'cloves', _p),
        _i('Rice', 1, 'cup', _n),
        _i('Curry powder', 2, 'tbsp', _n),
      ]),
      Meal(id: 'm_greek', name: 'Greek salad', emoji: '🥗', colorIndex: 2, servings: 2, ingredients: [
        _i('Cucumber', 2, '', _p),
        _i('Tomato', 3, '', _p),
        _i('Feta', 100, 'g', _d),
        _i('Olives', 80, 'g', _n),
        _i('Onion', 1, '', _p),
        _i('Olive oil', 2, 'tbsp', _n),
      ]),
      Meal(id: 'm_pancakes', name: 'Banana pancakes', emoji: '🥞', colorIndex: 6, servings: 2, ingredients: [
        _i('Banana', 2, '', _p),
        _i('Eggs', 2, '', _d),
        _i('Rolled oats', 1, 'cup', _n),
        _i('Milk', 0.5, 'cup', _d),
        _i('Honey', 1, 'tbsp', _n),
      ]),
      Meal(id: 'm_smoothie', name: 'Berry smoothie', emoji: '🍓', colorIndex: 4, servings: 1, ingredients: [
        _i('Frozen berries', 200, 'g', _f),
        _i('Banana', 1, '', _p),
        _i('Milk', 1, 'cup', _d),
        _i('Yogurt', 150, 'g', _d),
      ]),
    ];

/// A pre-filled week so the grocery list is impressive on first launch.
Map<String, String> samplePlan(String weekKey) {
  final plan = <String, String>{};
  void put(int day, MealSlot slot, String id) => plan[planKey(weekKey, day, slot)] = id;
  put(0, MealSlot.breakfast, 'm_shakshuka');
  put(0, MealSlot.dinner, 'm_pasta'); // shares tomato + garlic with shakshuka
  put(1, MealSlot.breakfast, 'm_oats');
  put(1, MealSlot.lunch, 'm_greek');
  put(1, MealSlot.dinner, 'm_stirfry');
  put(2, MealSlot.lunch, 'm_caprese');
  put(2, MealSlot.dinner, 'm_curry');
  put(3, MealSlot.breakfast, 'm_pancakes');
  put(4, MealSlot.breakfast, 'm_smoothie');
  return plan;
}
