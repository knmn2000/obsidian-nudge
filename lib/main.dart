import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'nudge/background.dart';
import 'nudge/nudge.dart';
import 'ui/home_screen.dart';
import 'ui/note_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/setup_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class _NoSink implements NotificationSink {
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) => throw StateError('Notifications unavailable');
}

// Startup steps must never stop runApp; log (never the token) and fall back.
Future<T> _safe<T>(Future<T> step, T fallback) async {
  try {
    return await step;
  } catch (e) {
    debugPrint('startup step failed: $e');
    return fallback;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store(
    await SharedPreferences.getInstance(),
    const SecureTokenStore(),
  );
  final cacheDir = await notesCacheDir();
  await _safe(initBackground(), null);

  void openNote(String path) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => NoteScreen(path: path, store: store, cacheDir: cacheDir),
    ),
  );

  final NotificationSink sink = await _safe(
    LocalNotificationSink.create(onTap: openNote),
    _NoSink(),
  );
  await _safe(requestNotificationPermission(), false);
  await _safe(store.settings().then(scheduleWork), null);
  final launch = await _safe(launchPayload(), null);
  final hasToken = await _safe(
    store.token().then((t) => (t ?? '').isNotEmpty),
    false,
  );

  Widget home() => HomeScreen(store: store, cacheDir: cacheDir, sink: sink);

  runApp(
    MaterialApp(
      title: 'Obsidian Nudge',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: hasToken
          ? home()
          : SetupScreen(
              store: store,
              syncNow: () => syncOrThrow(store, cacheDir),
              onDone: () => navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute<void>(builder: (_) => home()),
              ),
            ),
    ),
  );

  if (launch != null && hasToken) {
    WidgetsBinding.instance.addPostFrameCallback((_) => openNote(launch));
  }
}
