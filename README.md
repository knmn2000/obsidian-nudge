# Obsidian Nudge

An Android app that nudges you to re-read, and quizzes you on, notes from an
Obsidian vault that lives in a GitHub repo. No LLM, no server: the phone pulls
the vault, picks a note on a spaced-repetition schedule and shows a
notification.

## How it works

- **Source of truth is GitHub.** The app downloads the vault as a zipball once a
  day (and on **Sync now**) using a fine-grained, read-only token. Review state
  stays on the phone.
- **Nudges.** About every 5 hours (a setting) a notification shows the note's
  title plus either one of its quiz questions or its first line. Quiet hours
  default to 23:00-08:00. Only notes under one vault folder are nudged (see
  `nudgeFolder` in `lib/nudge/nudge.dart`).
- **Tap the notification** to open the note. Quiz questions are at the top,
  tap one to reveal the answer. The top-bar icon opens the note in the Obsidian
  app via an `obsidian://` link (vault name in `lib/notes/obsidian_link.dart`).
- **Spaced repetition.** Rate a note after reading: *Didn't get it* (next
  nudge, ~4h), *Forgot* (1 day), *Meh* (3 days), *Know it* (21 days). A note
  that was notified but not rated is snoozed for a day.

## Quiz format

Put a `## Quiz` section at the **end** of a note. Each `Q:` and `A:` is one line:

```markdown
## Quiz
Q: Why does a log-based message broker allow replay?
A: Messages are kept in an append-only log and consumers track an offset, so they can rewind and re-read.
Q: What goes wrong without fencing during failover?
A: The old leader may still accept writes, so you get two writers (split brain).
```

Everything after `## Quiz` up to the next `#` or `##` heading is read as quiz
text, so nothing else may follow it. The section is hidden from the note body.
`skills/add-to-obsidian/SKILL.md` is the Claude Code skill used to write notes
and their quizzes into the vault and push them, so new questions reach the
phone on its next sync with no cable. It contains my own vault path and GitHub
user, so treat it as an example to adapt.

## Setup

1. Create a **fine-grained personal access token** limited to your vault repo
   with *Contents: Read-only*.
2. Build and install (Android, USB debugging on):

   ```bash
   flutter build apk --release
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

3. Open the app, paste the token, set the repo (`owner/name`) and branch, and
   save. The token is kept in Android secure storage only.
4. In the phone's battery settings set the app to **Unrestricted**, otherwise
   Android may delay or skip the background nudges.

Defaults (repo, branch, folder, vault name) are hardcoded for my own vault;
change `Settings` in `lib/data/store.dart`, `nudgeFolder` and `obsidianVault`.

## Development

```bash
flutter analyze
flutter test
```

Pure-Dart logic (note parsing, scheduling, quiet hours) is unit tested.
Design and plan: `docs/superpowers/`.
