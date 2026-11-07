import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/meal_editor_screen.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _engine(String source) => source == 'groq' ? 'Groq' : 'built-in engine';

// ------------------------------------------------------------------- AI meal

/// Asks for a description, generates a meal, then opens the editor so the user
/// can review and save it.
Future<void> showAiMealDialog(BuildContext context) async {
  final result = await showDialog<AiMealResult>(
    context: context,
    builder: (_) => const _AiMealDialog(),
  );
  if (result == null || !context.mounted) return;
  if (result.note != null) _snack(context, result.note!);
  await Navigator.of(context).push(MaterialPageRoute<String>(
    builder: (_) => MealEditorScreen(meal: result.meal, isDraft: true),
  ));
}

class _AiMealDialog extends StatefulWidget {
  const _AiMealDialog();

  @override
  State<_AiMealDialog> createState() => _AiMealDialogState();
}

class _AiMealDialogState extends State<_AiMealDialog> {
  final _prompt = TextEditingController();
  int _servings = 2;
  bool _busy = false;
  String? _error;

  static const _ideas = [
    'High-protein breakfast',
    'Quick vegetarian dinner',
    'Light summer lunch',
    'Cozy soup for a cold day',
  ];

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_prompt.text.trim().length < 2) {
      setState(() => _error = 'Describe the meal first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.read<AppState>().aiGenerateMeal(_prompt.text.trim(), _servings);
      if (mounted) Navigator.pop(context, r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Tones.of(context);
    return AlertDialog(
      title: const Text('Create a meal with AI'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _prompt,
                autofocus: true,
                enabled: !_busy,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. creamy mushroom risotto'),
                onSubmitted: (_) => _generate(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final idea in _ideas)
                    ActionChip(
                      label: Text(idea),
                      onPressed: _busy ? null : () => setState(() => _prompt.text = idea),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Servings', style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _servings > 1 && !_busy ? () => setState(() => _servings--) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('$_servings', textAlign: TextAlign.center, style: AppText.display(context, 20)),
                  ),
                  IconButton.filledTonal(
                    onPressed: _servings < 12 && !_busy ? () => setState(() => _servings++) : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: AppPalette.tomato, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Thinking...' : 'Generate'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ AI plan

Future<void> showAiPlanDialog(BuildContext context) async {
  final outcome = await showDialog<AiPlanOutcome>(
    context: context,
    builder: (_) => const _AiPlanDialog(),
  );
  if (outcome == null || !context.mounted) return;
  if (outcome.filled == 0) {
    _snack(context, outcome.note ?? 'Nothing was planned.');
    return;
  }
  final extra = outcome.newMeals > 0 ? ' and added ${outcome.newMeals} new meal${outcome.newMeals == 1 ? '' : 's'}' : '';
  _snack(context, 'Planned ${outcome.filled} meal${outcome.filled == 1 ? '' : 's'}$extra (${_engine(outcome.source)})');
}

class _AiPlanDialog extends StatefulWidget {
  const _AiPlanDialog();

  @override
  State<_AiPlanDialog> createState() => _AiPlanDialogState();
}

class _AiPlanDialogState extends State<_AiPlanDialog> {
  final _prefs = TextEditingController();
  bool _allowNew = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _prefs.dispose();
    super.dispose();
  }

  Future<void> _plan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.read<AppState>().aiPlanWeek(_prefs.text.trim(), allowNew: _allowNew);
      if (mounted) Navigator.pop(context, r);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final empty = 21 - app.plannedCount;
    return AlertDialog(
      title: const Text('Plan this week with AI'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                empty == 0
                    ? 'Every slot is already planned. Clear some slots first.'
                    : 'Fills the $empty empty slot${empty == 1 ? '' : 's'} of ${app.weekLabel}. Meals you already planned stay untouched.',
                style: TextStyle(color: t.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _prefs,
                enabled: !_busy,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Preferences, e.g. vegetarian, quick dinners, no mushrooms',
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _allowNew,
                onChanged: _busy ? null : (v) => setState(() => _allowNew = v ?? true),
                title: const Text('Let AI add new meals for variety'),
                subtitle: const Text('Otherwise it only uses your meal library'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_error!, style: const TextStyle(color: AppPalette.tomato, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy || empty == 0 ? null : _plan,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Planning...' : 'Plan my week'),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- smart merge

Future<void> runSmartMerge(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Looking for duplicate ingredients...'), duration: Duration(seconds: 30)));
  try {
    final r = await app.aiSmartMerge();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(r.merged == 0
            ? 'No duplicates found (${_engine(r.source)})'
            : 'Merged ${r.merged} duplicate name${r.merged == 1 ? '' : 's'} (${_engine(r.source)})'),
      ));
  } on ApiException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
  }
}
