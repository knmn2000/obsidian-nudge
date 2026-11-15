import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/store.dart';
import '../review/scheduler.dart';
import '../sync/github_sync.dart';

abstract class NotificationSink {
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  });
}

/// Shows one due note. Returns true only when a notification was shown.
Future<bool> runNudge({
  required Store store,
  required Directory cacheDir,
  required NotificationSink sink,
  required DateTime now,
  required Random rng,
  bool ignoreQuietHours = false,
}) async {
  final s = await store.settings();
  if (!ignoreQuietHours &&
      inQuietHours(now, startHour: s.quietStart, endHour: s.quietEnd)) {
    return false;
  }
  final states = await store.loadStates();
  final note = pickNext(await loadCachedNotes(cacheDir), states, now, rng);
  if (note == null) return false;
  await sink.show(
    title: note.title,
    body: note.firstLine.isEmpty ? note.title : note.firstLine,
    payload: note.path,
  );
  states[note.path] = snooze(states[note.path], now);
  await store.saveStates(states);
  return true;
}

/// Never throws: failures land in [Store.lastSyncError].
Future<void> runSync({
  required Store store,
  required Directory cacheDir,
  required http.Client client,
  required DateTime now,
}) async {
  final token = await store.token();
  if (token == null || token.isEmpty) return;
  final s = await store.settings();
  try {
    await syncNotes(
      client: client,
      token: token,
      repo: s.repo,
      branch: s.branch,
      cacheDir: cacheDir,
    );
    await store.setLastSync(now);
    await store.setLastSyncError(null);
  } on SyncException catch (e) {
    await store.setLastSyncError(e.message);
  }
}
