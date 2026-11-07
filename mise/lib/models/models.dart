// Pure Dart (no Flutter imports) so it can be unit-tested anywhere.

enum MealSlot { breakfast, lunch, dinner }

extension MealSlotX on MealSlot {
  String get label {
    switch (this) {
      case MealSlot.breakfast:
        return 'Breakfast';
      case MealSlot.lunch:
        return 'Lunch';
      case MealSlot.dinner:
        return 'Dinner';
    }
  }

  String get emoji {
    switch (this) {
      case MealSlot.breakfast:
        return '🌅';
      case MealSlot.lunch:
        return '☀️';
      case MealSlot.dinner:
        return '🌙';
    }
  }
}

enum IngredientCategory { produce, dairy, meat, pantry, frozen, other }

extension IngredientCategoryX on IngredientCategory {
  String get label {
    switch (this) {
      case IngredientCategory.produce:
        return 'Produce';
      case IngredientCategory.dairy:
        return 'Dairy & eggs';
      case IngredientCategory.meat:
        return 'Meat & fish';
      case IngredientCategory.pantry:
        return 'Pantry';
      case IngredientCategory.frozen:
        return 'Frozen';
      case IngredientCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case IngredientCategory.produce:
        return '🥬';
      case IngredientCategory.dairy:
        return '🥛';
      case IngredientCategory.meat:
        return '🍗';
      case IngredientCategory.pantry:
        return '🥫';
      case IngredientCategory.frozen:
        return '🧊';
      case IngredientCategory.other:
        return '🛒';
    }
  }
}

/// One ingredient line inside a meal. [quantity] == null means "to taste".
class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity,
    this.unit = '',
    this.category = IngredientCategory.other,
  });

  final String name;
  final double? quantity;
  final String unit;
  final IngredientCategory category;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'category': category.name,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        name: (j['name'] ?? '') as String,
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: (j['unit'] ?? '') as String,
        category: IngredientCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => IngredientCategory.other,
        ),
      );
}

class Meal {
  const Meal({
    required this.id,
    required this.name,
    this.emoji = '🍽️',
    this.colorIndex = 0,
    this.servings = 2,
    this.ingredients = const [],
  });

  final String id;
  final String name;
  final String emoji;
  final int colorIndex;
  final int servings;
  final List<RecipeIngredient> ingredients;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorIndex': colorIndex,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        emoji: (j['emoji'] ?? '🍽️') as String,
        colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
        servings: (j['servings'] as num?)?.toInt() ?? 2,
        ingredients: ((j['ingredients'] as List?) ?? const [])
            .map((e) => RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// A computed row on the grocery list (never stored, always derived).
class GroceryItem {
  const GroceryItem({
    required this.key,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.toTaste,
    required this.category,
    required this.fromMeals,
  });

  final String key;
  final String name;
  final String unit;
  final double quantity;
  final bool toTaste;
  final IngredientCategory category;
  final List<String> fromMeals;
}

/// Key used for plan entries: "<weekMonday>|<dayIndex>|<slotIndex>".
String planKey(String weekKey, int day, MealSlot slot) => '$weekKey|$day|${slot.index}';
