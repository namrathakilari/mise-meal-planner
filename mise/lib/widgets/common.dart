import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Page title with optional subtitle and trailing actions.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
    this.horizontal = 20,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal - 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(context, 30), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(color: t.muted, fontSize: 14)),
                ],
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final String emoji;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
                child: Text(emoji, style: const TextStyle(fontSize: 42)),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: AppText.display(context, 24)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontSize: 15, height: 1.4)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 22),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.background, this.foreground, this.icon});
  final String text;
  final Color? background;
  final Color? foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    final fg = foreground ?? t.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? t.accentSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

Future<void> confirmReset(BuildContext context) async {
  final app = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset to sample data?'),
      content: const Text(
          'This replaces your meals, plan and grocery checkmarks with the demo set. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset data')),
      ],
    ),
  );
  if (ok == true) {
    app.resetToSamples();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Sample data loaded')));
    }
  }
}

void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ));
}
