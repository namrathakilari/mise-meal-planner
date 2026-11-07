import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/grocery_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/ai_dialogs.dart';
import '../widgets/common.dart';

String _amount(GroceryItem i) =>
    amountLabel(quantity: i.quantity, unit: i.unit, toTaste: i.toTaste);

class GroceryScreen extends StatelessWidget {
  const GroceryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.groceryItems;
    final checked = items.where(app.isChecked).length;
    final label = app.groceryScopeLabel;
    final byDay = app.groceryScope == GroceryScope.day;

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final pad = wide ? 28.0 : 20.0;
      final header = ScreenHeader(horizontal: pad, title: 'Grocery list', subtitle: label, trailing: const [_AiMenu()]);
      final controls = Padding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 14),
        child: const Align(alignment: Alignment.centerLeft, child: _ScopeControls()),
      );

      if (items.isEmpty) {
        return Column(
          children: [
            header,
            controls,
            Expanded(
              child: EmptyState(
                emoji: '🛒',
                title: 'Nothing to buy yet',
                message: byDay
                    ? 'No meals planned for $label. Add one in the meal plan.'
                    : 'Plan a few meals for $label and your list builds itself.',
                actions: [
                  FilledButton(onPressed: () => app.setNav(0), child: const Text('Open meal plan')),
                ],
              ),
            ),
          ],
        );
      }

      final summary = _SummaryCard(total: items.length, checked: checked, scopeLabel: label, items: items);
      final list = _GroupedList(items: items);

      if (wide) {
        return Column(
          children: [
            header,
            controls,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 360,
                    child: Padding(padding: EdgeInsets.fromLTRB(pad, 0, 8, 0), child: summary),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(12, 0, pad, 28),
                      children: [list],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          header,
          controls,
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 28),
              children: [summary, const SizedBox(height: 16), list],
            ),
          ),
        ],
      );
    });
  }
}

/// "Whole week / By day" switch, plus a Mon-Sun picker when "By day" is on.
class _ScopeControls extends StatelessWidget {
  const _ScopeControls();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final byDay = app.groceryScope == GroceryScope.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<GroceryScope>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
          ),
          segments: const [
            ButtonSegment(
              value: GroceryScope.week,
              label: Text('Week', maxLines: 1, softWrap: false),
              icon: Icon(Icons.date_range_rounded, size: 18),
            ),
            ButtonSegment(
              value: GroceryScope.day,
              label: Text('Day', maxLines: 1, softWrap: false),
              icon: Icon(Icons.today_rounded, size: 18),
            ),
          ],
          selected: {app.groceryScope},
          onSelectionChanged: (s) => app.setGroceryScope(s.first),
        ),
        if (byDay) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var d = 0; d < 7; d++) ...[
                  if (d > 0) const SizedBox(width: 8),
                  _DayChip(
                    day: d,
                    selected: app.selectedDay == d,
                    today: app.isToday(d),
                    planned: app.plannedInDay(d),
                    dateNumber: app.dateForDay(d).day,
                    tones: t,
                    onTap: () => app.selectDay(d),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.today,
    required this.planned,
    required this.dateNumber,
    required this.tones,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool today;
  final int planned;
  final int dateNumber;
  final Tones tones;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tones;
    final fg = selected ? t.onAccent : t.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? t.accent : (today ? t.accent : t.line), width: today && !selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(weekdayShort(day), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? t.onAccent : t.muted)),
            const SizedBox(height: 2),
            Text('$dateNumber', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: planned > 0 ? (selected ? t.onAccent : t.accent) : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.checked,
    required this.scopeLabel,
    required this.items,
  });

  final int total;
  final int checked;
  final String scopeLabel;
  final List<GroceryItem> items;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final t = Tones.of(context);
    final left = total - checked;
    final done = left == 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: done ? AppPalette.basil : t.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: done ? AppPalette.basil : t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            done ? 'All in the basket' : '$left to buy',
            style: AppText.display(context, 38, color: done ? Colors.white : t.ink),
          ),
          const SizedBox(height: 6),
          Text(
            done
                ? 'Everything for $scopeLabel is ticked off.'
                : '$checked of $total items checked off',
            style: TextStyle(color: done ? Colors.white70 : t.muted, fontSize: 15),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: total == 0 ? 0 : checked / total),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: done ? Colors.white24 : t.line,
                color: done ? Colors.white : t.accent,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final text = GroceryService.toPlainText(items, _amount);
                  await Clipboard.setData(ClipboardData(text: 'Groceries for $scopeLabel\n\n$text'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('List copied to clipboard')));
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy list'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: done ? Colors.white : null,
                  side: BorderSide(color: done ? Colors.white54 : t.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (checked > 0)
                TextButton.icon(
                  onPressed: app.clearChecked,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Uncheck all'),
                  style: TextButton.styleFrom(foregroundColor: done ? Colors.white : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.items});
  final List<GroceryItem> items;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);

    final groups = <IngredientCategory, List<GroceryItem>>{};
    for (final i in items) {
      groups.putIfAbsent(i.category, () => []).add(i);
    }

    return Column(
      children: [
        for (final entry in groups.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
                      child: Text(entry.key.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.key.label, style: AppText.display(context, 20))),
                    Text(
                      '${entry.value.where(app.isChecked).length}/${entry.value.length}',
                      style: TextStyle(color: t.muted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var k = 0; k < entry.value.length; k++) ...[
                  if (k > 0) Divider(height: 1, color: t.line),
                  _ItemTile(
                    item: entry.value[k],
                    checked: app.isChecked(entry.value[k]),
                    onTap: () => app.toggleChecked(entry.value[k]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.checked, required this.onTap});

  final GroceryItem item;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? t.accent : Colors.transparent,
                border: Border.all(color: checked ? t.accent : t.muted, width: 2),
              ),
              child: checked ? Icon(Icons.check_rounded, size: 16, color: t.onAccent) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: checked ? t.muted.withOpacity(0.7) : t.ink,
                      decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: t.muted,
                    ),
                    child: Text(capitalize(item.name)),
                  ),
                  if (item.fromMeals.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.fromMeals.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: checked ? 0.5 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: item.toTaste ? Colors.transparent : t.accentSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _amount(item),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontStyle: item.toTaste ? FontStyle.italic : FontStyle.normal,
                    color: item.toTaste ? t.muted : t.ink,
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

/// AI tools for the list: merge duplicate names such as "Tomato" / "Tomatoes".
class _AiMenu extends StatelessWidget {
  const _AiMenu();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return PopupMenuButton<String>(
      tooltip: 'AI tools',
      icon: const Icon(Icons.auto_awesome),
      onSelected: (v) {
        if (v == 'merge') {
          runSmartMerge(context);
        } else if (v == 'unmerge') {
          app.clearAliases();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'merge', child: Text('Smart merge duplicate ingredients')),
        PopupMenuItem(
          value: 'unmerge',
          enabled: app.aliases.isNotEmpty,
          child: Text('Undo merges (${app.aliases.length})'),
        ),
      ],
    );
  }
}
