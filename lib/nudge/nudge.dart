import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/store.dart';
import '../notes/note.dart';
import '../review/scheduler.dart';
import '../sync/github_sync.dart';

abstract class NotificationSink {
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  });
}

/// Only notes under this vault folder get nudged.
const nudgeFolder = 'CSE stuff';

/// Notification text: a quiz question when the note has any, else its first line.
String nudgeBody(Note note, Random rng) {
  if (note.quiz.isNotEmpty) {
    return 'Quiz: ${note.quiz[rng.nextInt(note.quiz.length)].question}';
  }
  return note.firstLine.isEmpty ? note.title : note.firstLine;
}

/// Shows one due note from [folder] (null = whole vault). Returns true only
/// when a notification was shown.
Future<bool> runNudge({
  required Store store,
  required Directory cacheDir,
  required NotificationSink sink,
  required DateTime now,
  required Random rng,
  bool ignoreQuietHours = false,
  String? folder = nudgeFolder,
}) async {
  final s = await store.settings();
  if (!ignoreQuietHours &&
      inQuietHours(now, startHour: s.quietStart, endHour: s.quietEnd)) {
    return false;
  }
  final states = await store.loadStates();
  final notes = (await loadCachedNotes(
    cacheDir,
  )).where((n) => folder == null || n.path.startsWith('$folder/')).toList();
  final note = pickNext(notes, states, now, rng);
  if (note == null) return false;
  await sink.show(
    title: note.title,
    body: nudgeBody(note, rng),
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
