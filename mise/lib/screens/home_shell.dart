import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/sync_sheet.dart';
import 'grocery_screen.dart';
import 'meals_screen.dart';
import 'plan_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final wide = MediaQuery.of(context).size.width >= 840;
    final left = app.groceryLeftCount;
    const pages = <Widget>[PlanScreen(), MealsScreen(), GroceryScreen()];
    final body = IndexedStack(index: app.navIndex, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            const _SideNav(),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _CompactTopBar(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: app.navIndex,
        onDestinationSelected: app.setNav,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Meals',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: left > 0,
              label: Text('$left'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: left > 0,
              label: Text('$left'),
              child: const Icon(Icons.shopping_basket),
            ),
            label: 'Grocery',
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final size = compact ? 36.0 : 44.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.basil,
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: Text('🥘', style: TextStyle(fontSize: size * 0.52)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mise', style: AppText.display(context, compact ? 24 : 28, weight: FontWeight.w700)),
            if (!compact)
              Text('Plan the week. Shop once.', style: TextStyle(fontSize: 12, color: t.muted)),
          ],
        ),
      ],
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar();

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final app = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 0),
      child: Row(
        children: [
          const _Brand(compact: true),
          const Spacer(),
          const SyncChip(compact: true),
          const SizedBox(width: 2),
          IconButton(
            tooltip: t.dark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () => app.setDark(!t.dark),
            icon: Icon(t.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          IconButton(
            tooltip: 'Reset to sample data',
            onPressed: () => confirmReset(context),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final left = app.groceryLeftCount;

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(padding: EdgeInsets.only(left: 6), child: _Brand()),
              const SizedBox(height: 30),
              _NavTile(
                icon: Icons.calendar_month_rounded,
                label: 'Meal plan',
                selected: app.navIndex == 0,
                onTap: () => app.setNav(0),
              ),
              _NavTile(
                icon: Icons.menu_book_rounded,
                label: 'Meal library',
                selected: app.navIndex == 1,
                onTap: () => app.setNav(1),
                trailing: '${app.mealList.length}',
              ),
              _NavTile(
                icon: Icons.shopping_basket_rounded,
                label: 'Grocery list',
                selected: app.navIndex == 2,
                onTap: () => app.setNav(2),
                trailing: left > 0 ? '$left' : null,
                highlightTrailing: true,
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 0, 10),
                child: Align(alignment: Alignment.centerLeft, child: SyncChip()),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                secondary: Icon(t.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                value: t.dark,
                onChanged: app.setDark,
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.restart_alt_rounded),
                title: const Text('Reset sample data', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => confirmReset(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.highlightTrailing = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final bool highlightTrailing;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 22, color: selected ? t.accent : t.muted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
                      color: selected ? t.ink : t.muted,
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: highlightTrailing ? AppPalette.tomato : t.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      trailing!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: highlightTrailing ? Colors.white : t.ink,
                      ),
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
