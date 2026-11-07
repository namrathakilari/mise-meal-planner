import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'meal_picker_sheet.dart';

/// One breakfast / lunch / dinner slot. Empty slots invite a tap; filled slots
/// show the meal in its colour with a quick remove button.
class MealSlotCard extends StatelessWidget {
  const MealSlotCard({super.key, required this.day, required this.slot, this.large = false});

  final int day;
  final MealSlot slot;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final meal = app.mealAt(day, slot);
    final radius = BorderRadius.circular(large ? 22 : 18);
    final height = large ? 108.0 : 92.0;

    if (meal == null) {
      return SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: t.card.withOpacity(0.55),
              border: Border.all(color: t.line, width: 1.5),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: () => pickMealForSlot(context, day, slot),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: t.muted),
                    const SizedBox(width: 6),
                    Text('Add meal', style: TextStyle(color: t.muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final color = mealColor(meal.colorIndex);
    final emojiBox = large ? 58.0 : 46.0;
    final count = meal.ingredients.length;

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: t.mealTint(meal.colorIndex),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () => pickMealForSlot(context, day, slot),
            child: Padding(
              padding: EdgeInsets.fromLTRB(large ? 14 : 10, 10, 4, 10),
              child: Row(
                children: [
                  Container(
                    width: emojiBox,
                    height: emojiBox,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.card.withOpacity(t.dark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(large ? 18 : 14),
                    ),
                    child: Text(meal.emoji, style: TextStyle(fontSize: large ? 30 : 24)),
                  ),
                  SizedBox(width: large ? 14 : 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: large ? 17 : 14,
                            height: 1.2,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$count ingredient${count == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: t.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove from plan',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => app.clearSlot(day, slot),
                    icon: Icon(Icons.close_rounded, size: 18, color: t.muted),
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
