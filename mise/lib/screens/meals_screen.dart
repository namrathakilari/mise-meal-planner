import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_dialogs.dart';
import '../widgets/common.dart';
import 'meal_editor_screen.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  String _query = '';

  void _openEditor([Meal? meal]) {
    Navigator.of(context).push(MaterialPageRoute<String>(builder: (_) => MealEditorScreen(meal: meal)));
  }

  void _delete(Meal meal) {
    final app = context.read<AppState>();
    final snapshot = app.deleteMeal(meal.id);
    final n = snapshot.entries.length;
    showUndoSnack(
      context,
      n == 0 ? 'Deleted ${meal.name}' : 'Deleted ${meal.name} and removed it from $n planned slot${n == 1 ? '' : 's'}',
      () => app.restoreMeal(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.mealList;
    final q = _query.trim().toLowerCase();
    final meals = all
        .where((m) =>
            q.isEmpty ||
            m.name.toLowerCase().contains(q) ||
            m.ingredients.any((i) => i.name.toLowerCase().contains(q)))
        .toList();

    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth >= 880 ? 28.0 : 20.0;
      return Column(
        children: [
          ScreenHeader(
            horizontal: pad,
            title: 'Meal library',
            subtitle: all.isEmpty ? 'No meals yet' : '${all.length} meal${all.length == 1 ? '' : 's'} saved',
            trailing: [
              if (c.maxWidth >= 600)
                FilledButton.tonalIcon(
                  onPressed: () => showAiMealDialog(context),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI meal'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                )
              else
                IconButton.filledTonal(
                  tooltip: 'Create a meal with AI',
                  onPressed: () => showAiMealDialog(context),
                  icon: const Icon(Icons.auto_awesome),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New meal'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          if (all.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 14),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search by meal or ingredient',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
          Expanded(
            child: all.isEmpty
                ? EmptyState(
                    emoji: '🍲',
                    title: 'Your meal library is empty',
                    message: 'Add a meal with its ingredients, or start with a set of samples.',
                    actions: [
                      FilledButton(onPressed: () => _openEditor(), child: const Text('Create a meal')),
                      OutlinedButton(
                        onPressed: () {
                          for (final m in sampleMeals()) {
                            app.upsertMeal(m);
                          }
                        },
                        child: const Text('Add sample meals'),
                      ),
                    ],
                  )
                : meals.isEmpty
                    ? const EmptyState(
                        emoji: '🔍',
                        title: 'No meals match',
                        message: 'Try another meal name or ingredient.',
                      )
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 204,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                        ),
                        itemCount: meals.length,
                        itemBuilder: (context, i) {
                          final m = meals[i];
                          return _MealCard(
                            meal: m,
                            timesPlanned: app.timesPlanned(m.id),
                            onTap: () => _openEditor(m),
                            onDelete: () => _delete(m),
                          );
                        },
                      ),
          ),
        ],
      );
    });
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.timesPlanned,
    required this.onTap,
    required this.onDelete,
  });

  final Meal meal;
  final int timesPlanned;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final color = mealColor(meal.colorIndex);
    final radius = BorderRadius.circular(24);
    final names = meal.ingredients.map((i) => i.name).toList();
    final preview = names.take(3).join(', ') + (names.length > 3 ? '  +${names.length - 3} more' : '');

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: t.mealTint(meal.colorIndex),
          borderRadius: radius,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.card.withOpacity(t.dark ? 0.55 : 0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(meal.emoji, style: const TextStyle(fontSize: 30)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Meal options',
                      icon: Icon(Icons.more_vert_rounded, color: t.muted),
                      onSelected: (v) => v == 'edit' ? onTap() : onDelete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit meal')),
                        PopupMenuItem(value: 'delete', child: Text('Delete meal')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(meal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(context, 21)),
                const SizedBox(height: 4),
                Text(preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.muted, fontSize: 13, height: 1.3)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pill('Serves ${meal.servings}', background: t.card.withOpacity(t.dark ? 0.5 : 0.8)),
                      if (timesPlanned > 0)
                        Pill('On the plan ${timesPlanned}x',
                            background: color, foreground: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
