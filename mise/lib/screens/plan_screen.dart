import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/ai_dialogs.dart';
import '../widgets/common.dart';
import '../widgets/meal_slot_card.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final grid = c.maxWidth >= 880;
        return Column(
          children: [
            _WeekHeader(horizontal: grid ? 28 : 20),
            Expanded(child: grid ? const _WeekGrid() : const _DayView()),
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.horizontal});
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final filled = app.plannedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          horizontal: horizontal,
          title: app.weekLabel,
          subtitle: '${app.weekYear}',
          trailing: [
            IconButton(
              tooltip: 'Previous week',
              onPressed: () => app.shiftWeek(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            if (!app.isCurrentWeek)
              TextButton(onPressed: app.goToToday, child: const Text('This week')),
            IconButton(
              tooltip: 'Next week',
              onPressed: () => app.shiftWeek(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                final messenger = ScaffoldMessenger.of(context);
                if (v == 'copy') {
                  final n = app.copyLastWeek();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(n == 0
                          ? 'Nothing to copy. Last week has no meals, or this week is already filled.'
                          : 'Copied $n meal${n == 1 ? '' : 's'} from last week'),
                    ));
                } else if (v == 'clear') {
                  final removed = app.clearWeek();
                  if (removed.isNotEmpty) {
                    showUndoSnack(context, 'Cleared ${removed.length} planned meals', () {
                      app.restorePlanEntries(removed);
                    });
                  }
                } else if (v == 'ai') {
                  showAiPlanDialog(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ai', child: Text('Plan this week with AI')),
                PopupMenuItem(value: 'copy', child: Text('Copy last week into empty slots')),
                PopupMenuItem(value: 'clear', child: Text('Clear this week')),
              ],
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: filled / 21),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: t.line,
                      color: t.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$filled of 21 meals planned',
                  style: TextStyle(color: t.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => showAiPlanDialog(context),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI plan'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- desktop grid

class _WeekGrid extends StatelessWidget {
  const _WeekGrid();

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const SizedBox(width: 96),
              for (final s in MealSlot.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(s.label,
                            style: TextStyle(fontWeight: FontWeight.w700, color: t.muted, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var d = 0; d < 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 92,
              child: Row(
                children: [
                  SizedBox(width: 96, child: _DayLabel(day: d)),
                  for (final s in MealSlot.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: MealSlotCard(day: d, slot: s),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day});
  final int day;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final today = app.isToday(day);
    final date = app.dateForDay(day);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: today ? t.accent : t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: today ? t.accent : t.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(weekdayShort(day),
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: today ? t.onAccent : t.muted)),
          const SizedBox(height: 2),
          Text('${date.day}', style: AppText.display(context, 26, color: today ? t.onAccent : t.ink)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- mobile day view

class _DayView extends StatelessWidget {
  const _DayView();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final day = app.selectedDay;
    final date = app.dateForDay(day);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(child: _DayChip(day: d, selected: d == day)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: ListView(
              key: ValueKey('${app.weekKey}-$day'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${weekdayLong(day)}, ${monthShort(date)} ${date.day}',
                          style: AppText.display(context, 22)),
                    ),
                    if (app.isToday(day)) const Pill('Today'),
                  ],
                ),
                const SizedBox(height: 14),
                for (final s in MealSlot.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Row(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(s.label,
                            style: TextStyle(fontWeight: FontWeight.w700, color: t.muted, fontSize: 14)),
                      ],
                    ),
                  ),
                  MealSlotCard(day: day, slot: s, large: true),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected});
  final int day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final t = Tones.of(context);
    final date = app.dateForDay(day);
    final hasMeals = app.plannedInDay(day) > 0;
    final today = app.isToday(day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? t.accent : t.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => app.selectDay(day),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? t.accent : (today ? t.accent : t.line), width: today ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Text(weekdayShort(day).substring(0, 3),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? t.onAccent : t.muted)),
                const SizedBox(height: 2),
                Text('${date.day}',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: selected ? t.onAccent : t.ink)),
                const SizedBox(height: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasMeals
                        ? (selected ? t.onAccent : AppPalette.tomato)
                        : Colors.transparent,
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
