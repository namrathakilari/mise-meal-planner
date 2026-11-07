'use strict';
// Built-in recipe knowledge base used when no GROQ_API_KEY is set (or the
// AI call fails). Each recipe: [name, emoji, baseServings, slots, keywords, ingredients]
// ingredient: [name, quantity|null, unit, category]
const R = (name, emoji, servings, slots, keywords, ings) => ({
  name, emoji, servings, slots, keywords,
  ingredients: ings.map(([n, q, u, c]) => ({ name: n, quantity: q, unit: u, category: c })),
});

const RECIPES = [
  R('Veggie omelette', '🍳', 2, 'b', ['omelette', 'omelet', 'egg', 'eggs', 'breakfast'], [
    ['Eggs', 4, '', 'dairy'], ['Bell pepper', 1, '', 'produce'], ['Onion', 0.5, '', 'produce'],
    ['Cheddar', 40, 'g', 'dairy'], ['Butter', 1, 'tbsp', 'dairy'], ['Salt', null, '', 'pantry']]),
  R('Banana pancakes', '🥞', 2, 'b', ['pancake', 'pancakes', 'banana', 'breakfast'], [
    ['Banana', 2, '', 'produce'], ['Eggs', 2, '', 'dairy'], ['Rolled oats', 1, 'cup', 'pantry'],
    ['Milk', 0.5, 'cup', 'dairy'], ['Honey', 1, 'tbsp', 'pantry']]),
  R('Avocado toast', '🥑', 2, 'b', ['avocado', 'toast', 'breakfast'], [
    ['Bread', 4, 'slices', 'pantry'], ['Avocado', 2, '', 'produce'], ['Lemon', 0.5, '', 'produce'],
    ['Cherry tomatoes', 100, 'g', 'produce'], ['Salt', null, '', 'pantry']]),
  R('Overnight oats', '🥣', 1, 'b', ['oats', 'oatmeal', 'porridge', 'overnight', 'breakfast'], [
    ['Rolled oats', 1, 'cup', 'pantry'], ['Milk', 1, 'cup', 'dairy'], ['Banana', 1, '', 'produce'],
    ['Honey', 1, 'tbsp', 'pantry']]),
  R('Berry smoothie', '🍓', 1, 'b', ['smoothie', 'berry', 'berries', 'breakfast'], [
    ['Frozen berries', 200, 'g', 'frozen'], ['Banana', 1, '', 'produce'], ['Milk', 1, 'cup', 'dairy'],
    ['Yogurt', 150, 'g', 'dairy']]),
  R('Greek salad', '🥗', 2, 'l', ['salad', 'greek', 'feta', 'cucumber', 'light', 'vegetarian'], [
    ['Cucumber', 2, '', 'produce'], ['Tomato', 3, '', 'produce'], ['Feta', 100, 'g', 'dairy'],
    ['Olives', 80, 'g', 'pantry'], ['Onion', 1, '', 'produce'], ['Olive oil', 2, 'tbsp', 'pantry']]),
  R('Chicken Caesar wrap', '🌯', 2, 'l', ['wrap', 'caesar', 'chicken', 'sandwich', 'lunch'], [
    ['Chicken breast', 300, 'g', 'meat'], ['Tortilla wraps', 2, '', 'pantry'], ['Romaine lettuce', 1, 'head', 'produce'],
    ['Parmesan', 30, 'g', 'dairy'], ['Caesar dressing', 3, 'tbsp', 'pantry']]),
  R('Tuna salad sandwich', '🥪', 2, 'l', ['tuna', 'sandwich', 'lunch', 'fish'], [
    ['Canned tuna', 2, 'cans', 'pantry'], ['Bread', 4, 'slices', 'pantry'], ['Mayonnaise', 2, 'tbsp', 'pantry'],
    ['Celery', 1, 'stalk', 'produce'], ['Lettuce', 4, 'leaves', 'produce']]),
  R('Caprese sandwich', '🥪', 2, 'l', ['caprese', 'mozzarella', 'sandwich', 'vegetarian', 'lunch'], [
    ['Tomato', 2, '', 'produce'], ['Mozzarella', 150, 'g', 'dairy'], ['Basil', 1, 'bunch', 'produce'],
    ['Ciabatta', 2, '', 'pantry'], ['Olive oil', 1, 'tbsp', 'pantry']]),
  R('Pasta pomodoro', '🍝', 3, 'd', ['pasta', 'spaghetti', 'tomato', 'italian', 'pomodoro', 'vegetarian'], [
    ['Spaghetti', 250, 'g', 'pantry'], ['Tomato', 6, '', 'produce'], ['Garlic', 3, 'cloves', 'produce'],
    ['Basil', 1, 'bunch', 'produce'], ['Parmesan', 40, 'g', 'dairy'], ['Olive oil', 2, 'tbsp', 'pantry'],
    ['Salt', null, '', 'pantry']]),
  R('Chicken stir-fry', '🍗', 3, 'd', ['stir-fry', 'stirfry', 'chicken', 'asian', 'quick'], [
    ['Chicken breast', 500, 'g', 'meat'], ['Bell pepper', 2, '', 'produce'], ['Broccoli', 1, 'head', 'produce'],
    ['Garlic', 2, 'cloves', 'produce'], ['Soy sauce', 3, 'tbsp', 'pantry'], ['Rice', 1, 'cup', 'pantry']]),
  R('Chickpea curry', '🍛', 4, 'd', ['curry', 'chickpea', 'chickpeas', 'vegan', 'vegetarian', 'indian'], [
    ['Chickpeas', 400, 'g', 'pantry'], ['Coconut milk', 400, 'ml', 'pantry'], ['Onion', 2, '', 'produce'],
    ['Spinach', 200, 'g', 'produce'], ['Tomato', 2, '', 'produce'], ['Garlic', 4, 'cloves', 'produce'],
    ['Rice', 1, 'cup', 'pantry'], ['Curry powder', 2, 'tbsp', 'pantry']]),
  R('Veggie fried rice', '🍚', 3, 'd', ['fried rice', 'rice', 'vegetable', 'veggie', 'vegetarian', 'quick'], [
    ['Rice', 1.5, 'cup', 'pantry'], ['Eggs', 3, '', 'dairy'], ['Frozen peas', 150, 'g', 'frozen'],
    ['Carrot', 2, '', 'produce'], ['Spring onion', 4, '', 'produce'], ['Soy sauce', 3, 'tbsp', 'pantry']]),
  R('Beef tacos', '🌮', 4, 'd', ['taco', 'tacos', 'beef', 'mexican'], [
    ['Ground beef', 400, 'g', 'meat'], ['Taco shells', 8, '', 'pantry'], ['Tomato', 2, '', 'produce'],
    ['Lettuce', 4, 'leaves', 'produce'], ['Cheddar', 80, 'g', 'dairy'], ['Taco seasoning', 2, 'tbsp', 'pantry']]),
  R('Lentil soup', '🍲', 4, 'd', ['soup', 'lentil', 'lentils', 'vegan', 'vegetarian', 'comfort'], [
    ['Red lentils', 250, 'g', 'pantry'], ['Carrot', 2, '', 'produce'], ['Onion', 1, '', 'produce'],
    ['Garlic', 3, 'cloves', 'produce'], ['Vegetable stock', 1, 'l', 'pantry'], ['Cumin', 1, 'tsp', 'pantry']]),
  R('Baked salmon & veg', '🐟', 2, 'd', ['salmon', 'fish', 'baked', 'healthy', 'omega'], [
    ['Salmon fillet', 2, '', 'meat'], ['Broccoli', 1, 'head', 'produce'], ['Lemon', 1, '', 'produce'],
    ['Olive oil', 1, 'tbsp', 'pantry'], ['Potatoes', 400, 'g', 'produce']]),
  R('Margherita pizza', '🍕', 2, 'd', ['pizza', 'margherita', 'cheese', 'vegetarian', 'italian'], [
    ['Pizza dough', 1, '', 'pantry'], ['Tomato', 3, '', 'produce'], ['Mozzarella', 200, 'g', 'dairy'],
    ['Basil', 1, 'bunch', 'produce'], ['Olive oil', 1, 'tbsp', 'pantry']]),
  R('Shakshuka', '🍳', 2, 'b', ['shakshuka', 'eggs', 'tomato', 'brunch', 'vegetarian'], [
    ['Tomato', 4, '', 'produce'], ['Onion', 1, '', 'produce'], ['Garlic', 3, 'cloves', 'produce'],
    ['Eggs', 4, '', 'dairy'], ['Olive oil', 2, 'tbsp', 'pantry'], ['Cumin', 1, 'tsp', 'pantry'],
    ['Salt', null, '', 'pantry']]),
];

const MEAT_CATEGORY = 'meat';
const isVegetarian = (r) => !r.ingredients.some((i) => i.category === MEAT_CATEGORY);

function scale(recipe, servings) {
  const f = servings && servings > 0 ? servings / recipe.servings : 1;
  const round = (q) => (q == null ? null : Math.max(0.25, Math.round(q * f * 4) / 4));
  return {
    name: recipe.name,
    emoji: recipe.emoji,
    servings: servings || recipe.servings,
    ingredients: recipe.ingredients.map((i) => ({ ...i, quantity: round(i.quantity) })),
  };
}

function score(recipe, words) {
  let s = 0;
  const name = recipe.name.toLowerCase();
  for (const w of words) {
    if (name.includes(w)) s += 3;
    if (recipe.keywords.includes(w)) s += 2;
    if (recipe.ingredients.some((i) => i.name.toLowerCase().includes(w))) s += 1;
  }
  return s;
}

const words = (text) =>
  String(text || '').toLowerCase().split(/[^a-z-]+/).filter((w) => w.length > 2);

function generateMeal(prompt, servings) {
  const w = words(prompt);
  let best = null;
  let bestScore = 0;
  for (const r of RECIPES) {
    const s = score(r, w);
    if (s > bestScore) { best = r; bestScore = s; }
  }
  if (best) return scale(best, servings);
  // Nothing matched: build a simple, sensible skeleton from the user's words.
  const title = String(prompt || 'Custom meal').trim().slice(0, 60) || 'Custom meal';
  return {
    name: title.charAt(0).toUpperCase() + title.slice(1),
    emoji: '🍽️',
    servings: servings || 2,
    ingredients: [
      { name: 'Main ingredient', quantity: 400, unit: 'g', category: 'other' },
      { name: 'Onion', quantity: 1, unit: '', category: 'produce' },
      { name: 'Garlic', quantity: 2, unit: 'cloves', category: 'produce' },
      { name: 'Olive oil', quantity: 1, unit: 'tbsp', category: 'pantry' },
      { name: 'Salt', quantity: null, unit: '', category: 'pantry' },
    ],
  };
}

module.exports = { RECIPES, generateMeal, scale, isVegetarian, words };
