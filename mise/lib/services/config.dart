import 'package:flutter/foundation.dart';

/// Override at build time:  flutter run -d chrome --dart-define=MISE_API=https://my-server.example.com
const String _envServer = String.fromEnvironment('MISE_API');

/// Where the Mise server lives when the user has not chosen one in the app.
///  * explicit --dart-define wins
///  * deployed web app served by the Mise server itself -> same origin
///  * otherwise the local dev server
String defaultServerUrl() {
  if (_envServer.isNotEmpty) return _envServer;
  if (kIsWeb) {
    final host = Uri.base.host;
    if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
      return Uri.base.origin;
    }
  }
  return 'http://localhost:8787';
}
