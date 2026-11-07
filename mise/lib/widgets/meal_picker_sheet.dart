import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../screens/meal_editor_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'common.dart';

/// Opens the picker and assigns the chosen meal to the slot.
Future<void> pickMealForSlot(BuildContext context, int day, MealSlot slot) async {
  final app = context.read<AppState>();
  final id = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (_) => MealPickerSheet(day: day, slot: slot),
  );
  if (id != null) app.assignMeal(day, slot, id);
}

class MealPickerSheet extends StatefulWidget {
  const MealPickerSheet({super.key, required this.day, required this.slot});
  final int day;
  final MealSlot slot;

  @override
  State<MealPickerSheet> createState() => _MealPickerSheetState();
}

class _MealPickerSheetState extends State<MealPickerSheet> {
  String _query = '';

  Future<void> _createNew() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const MealEditorScreen()),
    );
    if (id != null && mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final current = app.mealAt(widget.day, widget.slot);
    final q = _query.trim().toLowerCase();
    final meals = app.mealList.where((m) => q.isEmpty || m.name.toLowerCase().contains(q)).toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '${weekdayLong(widget.day)} ${widget.slot.label.toLowerCase()}',
                style: AppText.display(context, 24),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Choose a meal for this slot', style: TextStyle(color: t.muted)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search your meals',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: meals.isEmpty
                  ? EmptyState(
                      emoji: '🍽️',
                      title: app.mealList.isEmpty ? 'No meals yet' : 'No match',
                      message: app.mealList.isEmpty
                          ? 'Create your first meal to put it on the plan.'
                          : 'Try a different word, or create a new meal.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: meals.length,
                      itemBuilder: (context, i) {
                        final m = meals[i];
                        final selected = current?.id == m.id;
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          selected: selected,
                          selectedTileColor: t.accentSoft,
                          leading: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: t.mealTint(m.colorIndex),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(m.emoji, style: const TextStyle(fontSize: 24)),
                          ),
                          title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            m.ingredients.take(4).map((e) => e.name).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected ? Icon(Icons.check_circle_rounded, color: t.accent) : null,
                          onTap: () => Navigator.of(context).pop(m.id),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createNew,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create a new meal'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
