import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Small status pill: "Local only", "Live · 2 online", "Offline". Tap to manage sync.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);

    late final IconData icon;
    late final String label;
    late final Color color;
    if (app.householdCode == null) {
      icon = Icons.cloud_off_outlined;
      label = compact ? 'Local' : 'Local only';
      color = t.muted;
    } else {
      switch (app.syncStatus) {
        case SyncStatus.online:
          icon = Icons.cloud_done_rounded;
          label = (!compact && app.peers > 1) ? 'Live · ${app.peers} online' : 'Live';
          color = AppPalette.basil;
          break;
        case SyncStatus.connecting:
          icon = Icons.cloud_sync_rounded;
          label = compact ? '...' : 'Connecting...';
          color = t.muted;
          break;
        case SyncStatus.offline:
        case SyncStatus.off:
          icon = Icons.cloud_off_rounded;
          label = compact ? 'Offline' : 'Offline, will sync';
          color = AppPalette.tomato;
          break;
      }
    }

    return Tooltip(
      message: 'Real-time sync and AI settings',
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => showSyncDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSyncDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SyncDialog());

class _SyncDialog extends StatefulWidget {
  const _SyncDialog();

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  late final TextEditingController _code = TextEditingController();
  late final TextEditingController _url =
      TextEditingController(text: context.read<AppState>().serverUrl);
  bool _busy = false;
  String? _error;
  String? _urlMsg;

  @override
  void dispose() {
    _code.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await job();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  String _aiLabel(String mode) {
    switch (mode) {
      case 'groq':
        return 'AI: Groq is connected';
      case 'offline':
        return 'AI: built-in engine (add GROQ_API_KEY on the server to use Groq)';
      case 'unreachable':
        return 'AI: server not reachable';
      default:
        return 'AI: checking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Tones.of(context);
    final code = app.householdCode;

    return AlertDialog(
      title: Text(code == null ? 'Real-time sync' : 'Household is live'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (code == null) ...[
                Text(
                  'Create a household to share your meals, plan and grocery checkmarks across devices. '
                  'Everyone who joins with the same code sees changes instantly.',
                  style: TextStyle(color: t.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _run(app.createHousehold),
                    icon: const Icon(Icons.add_home_rounded),
                    label: const Text('Create a household'),
                  ),
                ),
                const SizedBox(height: 18),
                Text('or join one', style: TextStyle(color: t.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: const InputDecoration(hintText: 'Code, e.g. K7M2QX', counterText: ''),
                        onSubmitted: (_) => _run(() => app.joinHousehold(_code.text)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _run(() => app.joinHousehold(_code.text)),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Share this code', style: TextStyle(color: t.muted, fontSize: 12)),
                            const SizedBox(height: 2),
                            SelectableText(code, style: AppText.display(context, 30, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Copy code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(const SnackBar(content: Text('Code copied')));
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  switch (app.syncStatus) {
                    SyncStatus.online => app.peers > 1
                        ? 'Connected. ${app.peers} devices are online right now.'
                        : 'Connected. You are the only one online right now.',
                    SyncStatus.connecting => 'Connecting...',
                    _ => 'Offline. Your edits are saved here and will sync when the server is back.',
                  },
                  style: TextStyle(color: t.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          app.leaveHousehold();
                          setState(() => _error = null);
                        },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Leave household (keeps a local copy)'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppPalette.tomato, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 18),
              Divider(color: t.line),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Server & AI', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_aiLabel(app.aiMode), style: TextStyle(color: t.muted, fontSize: 12)),
                  children: [
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'Mise server address'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() {
                                  _busy = true;
                                  _urlMsg = null;
                                });
                                final err = await app.setServerUrl(_url.text);
                                if (!mounted) return;
                                setState(() {
                                  _busy = false;
                                  _urlMsg = err ?? 'Connected to the server.';
                                });
                              },
                        child: const Text('Save and test'),
                      ),
                    ),
                    if (_urlMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_urlMsg!, style: TextStyle(color: t.muted)),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
