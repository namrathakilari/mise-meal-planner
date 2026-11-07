import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  final state = AppState(storage)..load();
  runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const MiseApp()));
}

class MiseApp extends StatefulWidget {
  const MiseApp({super.key});

  @override
  State<MiseApp> createState() => _MiseAppState();
}

class _MiseAppState extends State<MiseApp> with WidgetsBindingObserver {
  Timer? _dayWatcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Catches midnight (and Sunday -> Monday) while the app stays open.
    _dayWatcher = Timer.periodic(const Duration(minutes: 1), (_) => context.read<AppState>().syncToToday());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AppState>().syncToToday();
  }

  @override
  void dispose() {
    _dayWatcher?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Mise - Meal Planner',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}
