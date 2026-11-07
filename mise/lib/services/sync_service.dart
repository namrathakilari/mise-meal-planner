import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

enum SyncStatus { off, connecting, online, offline }

/// Keeps one WebSocket open to the Mise server, reconnects with backoff, and
/// queues edits made while offline so nothing is lost.
class SyncService {
  SyncService({
    required this.onState,
    required this.onOps,
    required this.onStatus,
    required this.onPeers,
    required this.onFatal,
  });

  /// Full server state (sent on every (re)connect).
  final void Function(Map<String, dynamic> state) onState;

  /// Operations made by other devices (or our own queued ones, re-applied).
  final void Function(List<Map<String, dynamic>> ops) onOps;
  final void Function(SyncStatus status) onStatus;
  final void Function(int peers) onPeers;

  /// The household no longer exists on the server.
  final void Function() onFatal;

  Uri? _uri;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _wanted = false;
  bool _ready = false;
  int _attempt = 0;
  int _generation = 0;
  final List<Map<String, dynamic>> _pending = [];

  bool get active => _wanted;

  void start(Uri uri) {
    stop();
    _uri = uri;
    _wanted = true;
    _attempt = 0;
    _open();
  }

  void stop() {
    _wanted = false;
    _ready = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _pending.clear();
    onStatus(SyncStatus.off);
  }

  Future<void> _open() async {
    final uri = _uri;
    if (uri == null || !_wanted) return;
    final gen = ++_generation;
    onStatus(SyncStatus.connecting);
    try {
      final ch = WebSocketChannel.connect(uri);
      await ch.ready;
      if (gen != _generation || !_wanted) {
        ch.sink.close();
        return;
      }
      _channel = ch;
      _sub = ch.stream.listen(
        _onData,
        onDone: () => _lost(gen),
        onError: (Object _) => _lost(gen),
      );
    } catch (_) {
      _lost(gen);
    }
  }

  void _lost(int gen) {
    if (gen != _generation || !_wanted) return;
    _ready = false;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    onStatus(SyncStatus.offline);
    onPeers(0);
    _retry?.cancel();
    const backoff = [1, 2, 4, 8, 15];
    final secs = backoff[math.min(_attempt, backoff.length - 1)];
    _attempt++;
    _retry = Timer(Duration(seconds: secs), _open);
  }

  void _onData(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'state':
        _attempt = 0;
        onState(Map<String, dynamic>.from(msg['state'] as Map));
        final queued = List<Map<String, dynamic>>.from(_pending);
        _pending.clear();
        _ready = true;
        if (queued.isNotEmpty) {
          onOps(queued); // re-apply on top of the fresh server state
          sendRaw({'type': 'ops', 'ops': queued});
        }
        onStatus(SyncStatus.online);
        break;
      case 'ops':
        final ops = (msg['ops'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        onOps(ops);
        break;
      case 'presence':
        onPeers((msg['peers'] as num?)?.toInt() ?? 1);
        break;
      case 'fatal':
        stop();
        onFatal();
        break;
    }
  }

  /// Sends one edit now, or queues it until we are connected again.
  void send(Map<String, dynamic> op) {
    if (!_wanted) return;
    if (_ready && _channel != null) {
      sendRaw({'type': 'ops', 'ops': [op]});
    } else {
      _pending.add(op);
      if (_pending.length > 1000) _pending.removeAt(0);
    }
  }

  void sendRaw(Map<String, dynamic> msg) {
    final ch = _channel;
    if (_wanted && ch != null) ch.sink.add(jsonEncode(msg));
  }
}
