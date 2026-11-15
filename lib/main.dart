import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/store.dart';
import 'nudge/background.dart';
import 'ui/home_screen.dart';
import 'ui/note_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/setup_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store(
    await SharedPreferences.getInstance(),
    const SecureTokenStore(),
  );
  final cacheDir = await notesCacheDir();
  await initBackground();

  void openNote(String path) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => NoteScreen(path: path, store: store, cacheDir: cacheDir),
    ),
  );

  final sink = await LocalNotificationSink.create(onTap: openNote);
  await requestNotificationPermission();
  await scheduleWork(await store.settings());
  final launch = await launchPayload();
  final hasToken = ((await store.token()) ?? '').isNotEmpty;

  Widget home() => HomeScreen(store: store, cacheDir: cacheDir, sink: sink);

  runApp(
    MaterialApp(
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
