# Obsidian Nudge: design

Date: 2026-11-15. Status: draft, awaiting approval.

## Intent and why

Karan saves things he learns as notes in an Obsidian vault (via a
`/add-to-obsidian` Claude skill). He then forgets them. He wants an Android
app that pushes a notification roughly every 5 hours asking him to re-read
one of his own notes, so the knowledge sticks. Obsidian mobile cannot fire
scheduled notifications, which is the gap this app fills.

Success: a notification arrives a few times a day, tapping it opens the note
he wrote, and over weeks the notes he finds hard come back more often than
the ones he knows.

## Goals

- Notify about every ~5 hours with a note's title and first line.
- Tap notification: app opens on that note, rendered markdown.
- Spaced repetition: after reading, three buttons (Know it / Meh / Forgot)
  set when that note is next due. Next pick is the most overdue note.
- GitHub is the source of truth. App pulls from it. No LLM anywhere in the app.
- Skip empty notes (about 30 of 160 are blank stubs).
- Sideload to his own phone over USB. Single user.

## Non-goals (v1)

- Quizzes. Planned later: a note may carry a `## Quiz` section of `Q:` / `A:`
  lines, shown as flashcards. `/add-to-obsidian` would write them when saving
  a note; existing notes backfilled in one batch by Claude. Do NOT build
  quiz UI in v1. Do not design the data model to preclude it.
- Editing notes, writing back to GitHub.
- Play Store release, multi-user, iOS, account system.
- Rendering Obsidian-specific syntax beyond what is cheap (see builder section).

## Anti-goals

- Anything that makes the app a second vault manager. It reads only.
- A token with write access, or access to repos other than the notes repo.
- Notification spam: it must not fire when nothing is due or notes are empty.

## Constraints

- Source: private repo `knmn2000/obsidian-notes`, branch `main`. Obsidian Git
  plugin auto-commits to it, so `main` is always current.
- Vault shape: ~160 `.md` files, plain markdown, most start with `# Title`,
  then a one-line definition, bullets, code blocks, `[[wikilinks]]`. Folders
  include `CSE stuff/General terms/` (49 notes), `Workstuff/`, `musicTheory/`,
  `products/`, `quesBank/`. Also non-note files: `Excalidraw/*.md`, `KANBAN.md`,
  daily-note style files like `2026-09-07.md`, `Untitled.md`.
- Dev machine has Flutter 3.38 / Dart 3.10, Android SDK, JDK 21. Phone
  (serial `RZGL6054TDJ`) currently shows `unauthorized` in `adb`: the user
  must accept the USB-debugging prompt on the phone before install works.
- Access token must be a fine-grained GitHub PAT, read-only, scoped to the
  one repo. The user creates it and pastes it into the app once.

## Approaches considered

1. **Pull from GitHub (chosen).** App holds a read-only token, downloads the
   repo's markdown, caches it locally, re-syncs before each pick. Needs
   nothing set up on the phone beyond the token. Cost: a token lives on the
   phone; read-only and single-repo limits the damage. Reading works offline
   from cache.
2. Read a vault folder on the phone. No token, but depends on a sync tool on
   the phone (Syncthing / Obsidian Git) the app cannot see, adds Android
   folder-permission friction, and goes silently stale if sync breaks.
3. Bundle notes into the app at install. Rejected: stale immediately.

Quiz generation alternatives: classic ML (TF-IDF / keyphrase blanks) rejected
as low quality on prose; an in-app LLM rejected for v1 by the user's choice.
Chosen later path: Claude writes quizzes into the notes, app only reads them.

## Decisions made by Karan

- GitHub is the source of truth and the sync source.
- Cadence: about every 5 hours.
- Nudge content: note title plus first line; tap opens full note in-app.
- Spaced repetition included in v1.
- No LLM in the app.

## Decisions made by Claude (corrections welcome)

- Flutter, because it is installed and he is a TypeScript/web dev. Plugins
  like `flutter_local_notifications`, a background scheduler
  (`workmanager` or exact-alarm equivalent), `flutter_markdown`,
  `shared_preferences` or a small local DB for review state.
- Four-button rating mapped to next-due intervals: "Didn't get it" = due again
  at the next nudge (about 5 hours, so it comes back the same day), "Forgot" =
  1 day, "Meh" = 3 days, "Know it" = 21 days. Simple, not full SM-2.
  Brand-new notes are due immediately. (The "Didn't get it" button is Karan's
  request; its exact interval is Claude's call.)
- Pick order: most overdue first; ties broken randomly so he is not served
  the same folder every time.
- Quiet hours: no notifications between 23:00 and 08:00 local time. Exposed
  as a setting.
- A note that was notified but never rated stays the most overdue pick. The
  notification itself does not count as a review. To avoid repeating the same
  note every 5 hours, an unrated note is snoozed for about one day.
- Review state (last seen, next due, per note) is stored on the phone only,
  keyed by file path. It is not written back to GitHub.
- Sync runs once a day (Karan's choice), plus a manual "Sync now" in Settings.
  Notes written today appear in the app by tomorrow's sync.
- Sync by downloading the repo archive (zipball) via the GitHub API with the
  token, rather than per-file calls.

## Left to the builder

- Exact scheduling mechanism for "~5 hours" under Android battery
  restrictions (WorkManager periodic vs exact alarm). Approximate timing is
  fine; being a few minutes or even an hour off is acceptable.
- Which files count as notes: exclude `.obsidian/`, `.git/`, `Excalidraw/`,
  empty files. Whether to also exclude `KANBAN.md` and daily-date files is
  the builder's call, defaulting to exclude them.
- How to render `[[wikilinks]]` (plain text acceptable in v1).
- Token storage (secure storage preferred).
- Screens beyond: Setup (paste token, repo name), Note view with the three
  rating buttons, minimal Settings (interval, sync now).
- Handling notification permission on Android 13+.
