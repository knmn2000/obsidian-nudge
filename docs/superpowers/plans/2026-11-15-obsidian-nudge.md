# Obsidian Nudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Android app that pulls Karan's Obsidian notes from a private GitHub repo and notifies him about every 5 hours to re-read one, with spaced-repetition rating.

**Architecture:** Flutter app. Pure-Dart logic (note parsing, scheduling, quiet hours) is unit-tested in isolation. A daily WorkManager task syncs the repo zipball into an app-private cache; a ~5h WorkManager task picks the most overdue cached note and shows a local notification. Review state lives in SharedPreferences, the token in secure storage. No LLM, no backend.

**Tech Stack:** Flutter 3.38 / Dart 3.10, `http`, `archive`, `shared_preferences`, `flutter_secure_storage`, `flutter_local_notifications`, `workmanager`, `path_provider`, a markdown renderer (`flutter_markdown_plus`). Latest compatible versions.

**Spec:** `docs/superpowers/specs/2026-11-15-obsidian-nudge-design.md`

## Global Constraints

- Source repo `knmn2000/obsidian-notes`, branch `main` (defaults, editable in Settings). Private: needs a fine-grained read-only token (Contents: read) pasted in the Setup screen. Never log or print the token.
- Read-only: the app never writes to GitHub.
- Skip: `.obsidian/`, `.git/`, `Excalidraw/`, `KANBAN.md`, files named `YYYY-MM-DD.md`, non-`.md` files, empty/whitespace-only files.
- Nudge cadence default 5 hours (setting). Sync once a day plus "Sync now". Quiet hours 23:00-08:00 local (setting).
- Rating intervals: Didn't get it, then due again at the next nudge; Forgot 1 day; Meh 3 days; Know it 21 days. Unrated notified note snoozed 1 day. Never-seen notes are due immediately.
- No notification when nothing is due, nothing is cached, or inside quiet hours.
- Local git only, no remotes. Commit as `git -c user.name=knmn2000 -c user.email=karan1501mannan@gmail.com commit`, message ending with the line `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Project root `/Users/karan.mannan/personal/obsidian-nudge`. Phone adb serial `RZGL6054TDJ`.
- Run `flutter analyze` and `flutter test` green before every commit.

## Review Focus

1. Zip entries carry a top-level folder `knmn2000-obsidian-notes-<sha>/`; paths with spaces and non-ASCII must survive. (Task 4 test)
2. Note with no `# ` heading, with YAML frontmatter, or whose first body line is a code fence or `[[wikilink]]`: title falls back to filename, nudge text is still sensible. (Task 1 tests)
3. Sync fails (offline, 401 expired token, 404): cache is kept intact and nudges keep working from it. (Task 4 test)
4. Quiet window crosses midnight (23-8); boundaries 23:00 inside, 08:00 outside. (Task 2 test)
5. Review state references a note deleted upstream, or a tapped notification points at a missing note: no crash, ignored / "note no longer exists". (Tasks 2 and 6 tests)

---

### Task 1: Scaffold and note parsing

**Files:**
- Create: Flutter project in the project root via `flutter create --org com.knmn2000 --project-name obsidian_nudge --platforms android .`
- Create: `lib/notes/note.dart`
- Test: `test/notes/note_test.dart`

**Interfaces:**
- Produces:
  - `class Note { final String path; final String title; final String firstLine; final String body; }`
  - `bool isNotePath(String path)`
  - `Note? parseNote(String path, String content)` returns null when `!isNotePath` or content is blank.

- [ ] **Step 1:** In the project root run `git init -b main`, then the `flutter create` command above (the existing `docs/` folder stays). Add the dependencies from the Tech Stack with `flutter pub add`. Remove the generated counter test and sample app body. Commit.
- [ ] **Step 2: Write failing tests** in `test/notes/note_test.dart`:
  - `isNotePath` false for `.obsidian/x.md`, `Excalidraw/d.excalidraw.md`, `KANBAN.md`, `2026-09-07.md`, `a.txt`; true for `CSE stuff/General terms/redis.md`.
  - `parseNote('x/kafka.md', '# Kafka\n\na log of events\n- b')` gives title `Kafka`, firstLine `a log of events`.
  - No heading: title is `kafka` (filename without `.md`).
  - Frontmatter `---\ntags: a\n---\n# T\nline` gives title `T`, firstLine `line`.
  - First body line is a code fence: firstLine is the first non-fence prose line, or `''` if none.
  - `[[Redis|cache]] is fast` gives firstLine `cache is fast`; `[[Redis]]` gives `Redis`.
  - firstLine truncated to 140 chars with `…`.
  - `parseNote('a.md', '  \n')` is null.
- [ ] **Step 3:** Run `flutter test test/notes/note_test.dart`, expect FAIL (undefined).
- [ ] **Step 4:** Implement in `lib/notes/note.dart`. Title is first `# ` heading line after any frontmatter. firstLine is the first non-empty line that is not heading, frontmatter, or inside a code fence, with wikilinks flattened to display text.
- [ ] **Step 5:** Run tests, expect PASS. Commit `feat: note parsing`.

### Task 2: Scheduling logic (pure)

**Files:**
- Create: `lib/review/scheduler.dart`
- Test: `test/review/scheduler_test.dart`

**Interfaces:**
- Consumes: `Note` (Task 1).
- Produces:
  - `enum Rating { didntGetIt, forgot, meh, knowIt }`
  - `class ReviewState { final DateTime dueAt; final DateTime? snoozedUntil; Map<String,dynamic> toJson(); factory ReviewState.fromJson(Map<String,dynamic>) }`
  - `ReviewState rate(Rating r, DateTime now)`: `didntGetIt` is due at `now + 4h` (4h, not 5h, so WorkManager jitter cannot make it miss the next nudge), `forgot` +1d, `meh` +3d, `knowIt` +21d; `snoozedUntil` null.
  - `ReviewState snooze(ReviewState? s, DateTime now)`: keeps `dueAt` (epoch if `s` null), sets `snoozedUntil = now + 1d`.
  - `Note? pickNext(List<Note> notes, Map<String, ReviewState> states, DateTime now, Random rng)`: eligible = `dueAt <= now` and (`snoozedUntil` null or `<= now`); never-seen = due at epoch; smallest `dueAt` wins; ties broken with `rng`; null if none eligible. States for paths not in `notes` are ignored.
  - `bool inQuietHours(DateTime now, {int startHour = 23, int endHour = 8})`: true when `now.hour >= startHour || now.hour < endHour`, correct when the window wraps midnight and when start < end.

- [ ] **Step 1: Write failing tests**: each rating's exact `dueAt`; snooze keeps dueAt and sets +1d; `pickNext` returns most overdue, skips snoozed and not-yet-due, ignores a stale state path, null on empty list, picks never-seen over a seen-overdue note, tie-break deterministic with `Random(1)`; `inQuietHours` true at 23:00 and 07:59, false at 08:00 and 22:59, and a non-wrapping window (1,5) works.
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement per signatures above.
- [ ] **Step 4:** Run, expect PASS. Commit `feat: spaced repetition scheduling`.

### Task 3: Settings and persistence

**Files:**
- Create: `lib/data/store.dart`
- Test: `test/data/store_test.dart`

**Interfaces:**
- Produces:
  - `class Settings { final String repo; final String branch; final int nudgeHours; final int quietStart; final int quietEnd; }` defaults `knmn2000/obsidian-notes`, `main`, 5, 23, 8; `copyWith`.
  - `abstract class TokenStore { Future<String?> read(); Future<void> write(String t); }` with `SecureTokenStore` (flutter_secure_storage) and `MemoryTokenStore` for tests.
  - `class Store { Store(SharedPreferences prefs, TokenStore tokens); Future<String?> token(); Future<void> setToken(String); Future<Settings> settings(); Future<void> saveSettings(Settings); Future<Map<String,ReviewState>> loadStates(); Future<void> saveStates(Map<String,ReviewState>); DateTime? lastSync; Future<void> setLastSync(DateTime); String? lastSyncError; Future<void> setLastSyncError(String?) }`

- [ ] **Step 1: Write failing tests** with `SharedPreferences.setMockInitialValues({})` and `MemoryTokenStore`: defaults returned on fresh store; settings round-trip; states round-trip including a null `snoozedUntil`; token round-trip; token is not stored in SharedPreferences.
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement (states as one JSON string keyed by note path). **Step 4:** Run, expect PASS. Commit `feat: store`.

### Task 4: GitHub sync

**Files:**
- Create: `lib/sync/github_sync.dart`
- Test: `test/sync/github_sync_test.dart`

**Interfaces:**
- Consumes: `isNotePath`, `parseNote`, `Note` (Task 1).
- Produces:
  - `class SyncException implements Exception { final int? statusCode; final String message; }`
  - `Future<int> syncNotes({required http.Client client, required String token, required String repo, required String branch, required Directory cacheDir})`: GET `https://api.github.com/repos/$repo/zipball/$branch` with headers `Authorization: Bearer $token`, `Accept: application/vnd.github+json`; returns count of notes written; throws `SyncException` on non-200 or network error.
  - `Future<List<Note>> loadCachedNotes(Directory cacheDir)`: reads every `.md` under `cacheDir`, runs `parseNote` with the cache-relative path, drops nulls.

- [ ] **Step 1: Write failing tests** using `http/testing` `MockClient` and a zip built in-test with `archive`: (a) zip entries under `owner-repo-abc123/` are written to the cache without the top-level folder, paths with spaces and `é` intact, `.obsidian/` and `KANBAN.md` entries not written; (b) request carries the Bearer header and hits the zipball URL; (c) 401 throws `SyncException(statusCode: 401)` and a pre-populated cache is untouched; (d) client throwing a `SocketException` throws `SyncException` and the cache is untouched; (e) a successful second sync removes a note deleted upstream.
- [ ] **Step 2:** Run, expect FAIL.
- [ ] **Step 3:** Implement. Extract into a sibling temp directory, then replace `cacheDir` (delete old, rename new) so a failed sync never leaves a half cache.
- [ ] **Step 4:** Run, expect PASS. Commit `feat: github zipball sync`.

### Task 5: Nudge job, notifications, background scheduling

**Files:**
- Create: `lib/nudge/nudge.dart`, `lib/nudge/background.dart`
- Modify: `android/app/src/main/AndroidManifest.xml` (POST_NOTIFICATIONS, and any receivers/services the plugins require), `android/app/build.gradle*` (core library desugaring if `flutter_local_notifications` requires it)
- Test: `test/nudge/nudge_test.dart`

**Interfaces:**
- Consumes: `Store`, `Settings` (Task 3); `pickNext`, `snooze`, `inQuietHours` (Task 2); `loadCachedNotes`, `syncNotes` (Task 4).
- Produces:
  - `abstract class NotificationSink { Future<void> show({required String title, required String body, required String payload}); }` with a `LocalNotificationSink` implementation (channel `nudges`, payload is the note path).
  - `Future<bool> runNudge({required Store store, required Directory cacheDir, required NotificationSink sink, required DateTime now, required Random rng, bool ignoreQuietHours = false})`: if in quiet hours (unless `ignoreQuietHours`) or no note picked, returns false and shows nothing. Otherwise shows title = note title, body = firstLine (or the title again when empty), payload = path, saves `snooze(...)` for that path, returns true.
  - `Future<void> runSync({required Store store, required Directory cacheDir, required http.Client client, required DateTime now})`: no token means no-op; on success `setLastSync(now)` and clears error; on `SyncException` stores its message via `setLastSyncError`, never throws.
  - `@pragma('vm:entry-point') void callbackDispatcher()` for workmanager, handling tasks `nudge` and `sync`.
  - `Future<void> scheduleWork(Settings s)`: registers periodic tasks `nudge` (every `s.nudgeHours` hours) and `sync` (every 24 hours), replacing existing registrations.

- [ ] **Step 1: Write failing tests** for `runNudge` with a fake sink and a temp cache dir containing two notes: shows title/firstLine/path for a due note; shows nothing at 02:00 (quiet); shows nothing with an empty cache; after a nudge the same note is not picked again at `now + 5h` but the other one is; empty firstLine falls back to the title. For `runSync`: without token does nothing; with a 401 the stored error is set and the cache stays.
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS.
- [ ] **Step 5:** Wire `callbackDispatcher` and `scheduleWork` (used by Task 6), fix manifest and gradle until `flutter build apk --debug` succeeds. Commit `feat: nudge job and background scheduling`.

### Task 6: UI

**Files:**
- Create: `lib/ui/setup_screen.dart`, `lib/ui/note_screen.dart`, `lib/ui/settings_screen.dart`; replace `lib/main.dart`
- Test: `test/ui/note_screen_test.dart`, `test/ui/setup_screen_test.dart`

**Interfaces:**
- Consumes: `Store`, `Rating`/`rate`, `loadCachedNotes`, `runSync`, `runNudge`, `scheduleWork`.
- Produces:
  - `NoteScreen({required String path, required Store store, required Directory cacheDir})`: renders the note's markdown; four buttons labelled `Didn't get it`, `Forgot`, `Meh`, `Know it`; tapping one saves `rate(...)` for the path and pops. A missing path shows the text `This note no longer exists`.
  - `SetupScreen({required Store store, required VoidCallback onDone})`: token field (obscured), repo and branch fields prefilled from `Settings`, Save button stores token, runs a first sync, calls `onDone`; shows the sync error text on failure.
  - `SettingsScreen`: nudge interval (hours), quiet hours start/end, `Sync now`, `Nudge now` (calls `runNudge` with `ignoreQuietHours: true` so it works at any hour), last sync time and last sync error. Saving the interval calls `scheduleWork`.
  - `main.dart`: no token means `SetupScreen`; otherwise a home screen with Settings and a count of cached notes. On start requests notification permission (Android 13+), calls `scheduleWork`, and opens `NoteScreen(payload)` when launched from or tapped on a notification (cold start via `getNotificationAppLaunchDetails`, warm via the response callback).

- [ ] **Step 1: Write failing widget tests**: `NoteScreen` with a cached note shows its text and tapping `Meh` persists a `ReviewState` with `dueAt = now + 3d` (inject a clock) and pops; missing path shows `This note no longer exists`; `SetupScreen` Save stores the token (use `MemoryTokenStore`) and shows the error text when the sync callback throws.
- [ ] **Step 2:** Run, expect FAIL. **Step 3:** Implement. **Step 4:** Run, expect PASS. Commit `feat: screens`.

### Task 7: Install on the phone and verify

**Files:** none

- [ ] **Step 1:** `adb devices` must list `RZGL6054TDJ` as `device`.
- [ ] **Step 2:** Karan creates the fine-grained token (see the hand-off message). `flutter run -d RZGL6054TDJ` (or `flutter build apk --debug` then `flutter install -d RZGL6054TDJ`).
- [ ] **Step 3:** In the app, paste the token in Setup. Expected: setup completes, home screen shows a note count of roughly 100 to 130 (160 files, 30 empty, plus excluded ones).
- [ ] **Step 4:** Settings, `Nudge now`. Expected: a notification with a note title and first line. Tap it: the note renders. Tap `Meh`, then `Nudge now` again: a different note.
- [ ] **Step 5:** `adb shell dumpsys jobscheduler | grep obsidian_nudge` shows the nudge and sync jobs registered. Report anything that failed. Commit any fixes.
