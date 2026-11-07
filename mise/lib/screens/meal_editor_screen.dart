import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

const _emojiChoices = [
  '🍳', '🥣', '🥪', '🍗', '🍝', '🍛', '🥗', '🥞', '🍓', '🍕',
  '🌮', '🍜', '🍣', '🥘', '🍔', '🥙', '🍲', '🥦', '🥑', '🍤',
];

/// 1.5 -> "1.5", 2.0 -> "2" (digits only, so the quantity parser can read it back).
String _plainNumber(double q) {
  var s = q.toStringAsFixed(2);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

/// One editable ingredient row (owns its controllers).
class _Draft {
  _Draft({String name = '', String qty = '', String unit = '', this.category = IngredientCategory.produce})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty),
        unit = TextEditingController(text: unit),
        focus = FocusNode();

  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController unit;
  final FocusNode focus;
  final Key key = UniqueKey();
  IngredientCategory category;

  void dispose() {
    name.dispose();
    qty.dispose();
    unit.dispose();
    focus.dispose();
  }
}

class MealEditorScreen extends StatefulWidget {
  const MealEditorScreen({super.key, this.meal, this.isDraft = false});
  final Meal? meal;

  /// A prefilled meal (e.g. from AI) that is saved as a NEW meal.
  final bool isDraft;

  @override
  State<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends State<MealEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _emoji;
  late int _color;
  late int _servings;
  late final List<_Draft> _drafts;

  bool get _isEdit => widget.meal != null && !widget.isDraft;

  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    _name = TextEditingController(text: m?.name ?? '');
    _emoji = m?.emoji ?? _emojiChoices.first;
    _color = m?.colorIndex ?? 0;
    _servings = m?.servings ?? 2;
    _drafts = m == null
        ? [_Draft()]
        : m.ingredients
            .map((i) => _Draft(
                  name: i.name,
                  qty: i.quantity == null ? '' : _plainNumber(i.quantity!),
                  unit: i.unit,
                  category: i.category,
                ))
            .toList();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _drafts.add(_Draft()));

  void _removeRow(_Draft d) {
    setState(() => _drafts.remove(d));
    // Dispose after the frame so the removed row is no longer built.
    WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Add at least one ingredient')));
      return;
    }
    final app = context.read<AppState>();
    final id = _isEdit ? widget.meal!.id : 'm${DateTime.now().microsecondsSinceEpoch}';
    final meal = Meal(
      id: id,
      name: _name.text.trim(),
      emoji: _emoji,
      colorIndex: _color,
      servings: _servings,
      ingredients: _drafts.map((d) {
        final q = parseQuantity(d.qty.text);
        return RecipeIngredient(
          name: d.name.text.trim(),
          quantity: q,
          unit: d.unit.text.trim(),
          category: d.category,
        );
      }).toList(),
    );
    app.upsertMeal(meal);
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final catalog = context.read<AppState>().ingredientCatalog;
    final color = mealColor(_color);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? 'Edit meal' : 'New meal', style: AppText.display(context, 22)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save meal'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: t.mealTint(_color),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.card.withOpacity(t.dark ? 0.55 : 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_emoji, style: const TextStyle(fontSize: 36)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.sentences,
                              style: AppText.display(context, 22),
                              decoration: const InputDecoration(hintText: 'Meal name'),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Give this meal a name' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in _emojiChoices)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => _emoji = e),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: e == _emoji ? t.card : Colors.transparent,
                                  border: Border.all(
                                      color: e == _emoji ? color : Colors.transparent, width: 2),
                                ),
                                child: Text(e, style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < AppPalette.mealColors.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => setState(() => _color = i),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppPalette.mealColors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: i == _color ? t.ink : Colors.transparent, width: 2.5),
                                  ),
                                  child: i == _color
                                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text('Servings', style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text('$_servings',
                                textAlign: TextAlign.center,
                                style: AppText.display(context, 22)),
                          ),
                          IconButton.filledTonal(
                            onPressed: _servings < 12 ? () => setState(() => _servings++) : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Ingredients', style: AppText.display(context, 24)),
                const SizedBox(height: 4),
                Text(
                  'Leave the amount empty for things like salt. Type "1/2" or "1 1/2" for fractions. '
                  'Matching amounts are added up on the grocery list.',
                  style: TextStyle(color: t.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                for (final d in _drafts)
                  _IngredientRow(
                    key: d.key,
                    draft: d,
                    catalog: catalog,
                    onRemove: () => _removeRow(d),
                    onChanged: () => setState(() {}),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add ingredient'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.draft,
    required this.catalog,
    required this.onRemove,
    required this.onChanged,
  });

  final _Draft draft;
  final List<RecipeIngredient> catalog;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RawAutocomplete<RecipeIngredient>(
                  textEditingController: draft.name,
                  focusNode: draft.focus,
                  displayStringForOption: (o) => o.name,
                  optionsBuilder: (TextEditingValue v) {
                    final q = v.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<RecipeIngredient>.empty();
                    return catalog
                        .where((i) => i.name.toLowerCase().contains(q) && i.name.toLowerCase() != q)
                        .take(5);
                  },
                  onSelected: (o) {
                    if (draft.unit.text.trim().isEmpty) draft.unit.text = o.unit;
                    draft.category = o.category;
                    onChanged();
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Ingredient, e.g. Tomato'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name this ingredient' : null,
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(14),
                        color: t.card,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 340),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, i) {
                              final o = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: Text(o.category.emoji, style: const TextStyle(fontSize: 18)),
                                title: Text(o.name),
                                subtitle: Text(o.category.label),
                                onTap: () => onSelected(o),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove ingredient',
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: t.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: TextFormField(
                    controller: draft.qty,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(hintText: 'Amount'),
                    validator: (v) => (v != null && parseQuantity(v) == -1) ? 'Not a number' : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextFormField(
                    controller: draft.unit,
                    decoration: const InputDecoration(hintText: 'Unit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<IngredientCategory>(
                    value: draft.category,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      for (final c in IngredientCategory.values)
                        DropdownMenuItem(
                          value: c,
                          child: Text('${c.emoji} ${c.label}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (c) {
                      if (c != null) {
                        draft.category = c;
                        onChanged();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
