---
name: add-to-obsidian
description: "Save the concept the user just learned in the current chat into their Obsidian vault as a note. Use when the user types /add-to-obsidian, or says things like \"add this to obsidian\", \"save this to my notes\", \"note this down\", \"put this in my vault\". Works from any Claude Code session, in any directory."
---

# /add-to-obsidian

Turn the concept explained in the most recent part of this conversation into a note in the user's Obsidian vault.

## Vault

- Vault root: `/Users/karan.mannan/obsidian/knmn2000`
- If that path does not exist, read `~/Library/Application Support/obsidian/obsidian.json`, take the vault marked `"open": true`, and use its `path`.
- The vault is a git repo (`origin` = `github.com/knmn2000/obsidian-notes`, branch `main`). Each run ends with a commit and push as the `knmn2000` GitHub user, see step 5.

Folder layout (verify with `ls` before writing, the vault changes):

- `CSE stuff/General terms/` is the default home for a single technical concept (e.g. `Caching.md`, `deadlock.md`, `sharding.md`). One concept per file, flat, short title-case or lowercase names matching the existing files.
- `CSE stuff/Topics/` holds maps of content (MOCs), e.g. `System Design MOC.md`, and longer topic notes.
- `Workstuff/Refs/` is for tool or library reference (e.g. `typeORM.md`).
- Anything else (music, products, non-tech): pick the closest existing folder, or ask the user in one line if nothing fits.

## Steps

1. **Pick the concept.** Use the latest explanation in this conversation: what the user just asked about and what you answered. If the exchange covered several distinct concepts, write one note per concept. If it is ambiguous which concept the user means, ask in one line instead of guessing.
2. **Check for an existing note.** Search the vault case-insensitively for the title (`find <vault> -iname "<title>*.md" -not -path "*/.obsidian/*"`). Existing files are often empty stubs.
   - Exists and empty: fill it.
   - Exists with content: append a new section under a `## <short heading>` and do not rewrite or delete what is there.
   - Does not exist: create it.
3. **Write the note** from what was actually said in the chat. Do not add facts that were not discussed, and do not browse the web. Use this shape and drop sections that have nothing in them:

   ```markdown
   # <Concept>

   <One or two sentence definition in plain words.>

   ## Key points
   - ...

   ## Example
   <Small code block or scenario from the chat, if there was one.>

   ## Gotchas / trade-offs
   - ...

   ## Related
   - [[Existing Note]]

   _Added <YYYY-MM-DD> from a Claude chat._

   ## Quiz
   Q: <question>
   A: <answer>
   Q: <question>
   A: <answer>
   ```

   Keep it terse and skimmable. Preserve code snippets from the chat verbatim.

   **Quiz section (always write one, for notes under `CSE stuff/`; it feeds the Obsidian Nudge phone app):**
   - It must be the LAST section of the file, after `## Related` and the `_Added ..._` line. The app treats every line after `## Quiz` up to the next `#` or `##` heading as quiz text, so nothing else may follow it.
   - 3 to 5 questions. Each `Q:` and each `A:` is exactly ONE line. No blank lines inside the section, no bullets, no code fences, no `[[wikilinks]]`. Inline `code` is fine.
   - Purpose: clarify fundamentals. Ask what problem the concept solves, why it exists, how the core mechanism works, the key trade-off, how it differs from its nearest neighbour, and what goes wrong if it is missing. Avoid trivia and "list the types" recall. Each question must make sense without seeing the note and must not say "according to the note".
   - Answers: 1 to 3 plain sentences, self-contained, and grounded in what the note says (which comes from the chat). Do not add facts that were not discussed.
   - Appending to an existing note that already has a `## Quiz`: add the new `Q:`/`A:` lines to the end of that section instead of creating a second one. If the existing note has a quiz but also gains a new section, insert the new section above `## Quiz`.
   - Notes outside `CSE stuff/` (music, products, work refs): skip the quiz unless the user asks.
4. **Link both ways so the note shows up connected in the Obsidian graph.** The graph is built only from `[[wikilinks]]`, so an unlinked note is an orphan dot.
   - List every note name: `find <vault> -name "*.md" -not -path "*/.obsidian/*" -not -path "*/.git/*"`, and take the basenames. Include stubs and nested folders.
   - **Outgoing:** scan the new note's text for any existing note name or obvious alias (case-insensitive, whole word, e.g. "message queue" matches `message queues`). Turn the first mention in the body into `[[Note]]` (use `[[Note|shown text]]` when the wording differs), and list all matches under `## Related`. Link only to files that exist. Never create dangling links, they show as ghost nodes.
   - **Incoming:** for the 1 to 5 most closely related existing notes (and the matching MOC, e.g. `System Design MOC.md` "Core concepts" line), add `[[<Concept>]]` so the new note is reachable from them. Append it under an existing `## Related` section, or create one at the end of the file. For an MOC, add it to the matching line or section. Append only, never reorder or rewrite existing content.
   - If nothing in the vault is related, link to the nearest MOC so the note is not an orphan. If there is no MOC either, say so in the report.
5. **Commit and push as `knmn2000`.** Run from the vault root, staging only the files this run wrote or edited (never `git add -A`, other changes may be in progress):

   ```bash
   cd /Users/karan.mannan/obsidian/knmn2000
   git add -- "<each file written or edited>"
   git -c user.name=knmn2000 -c user.email=karan1501mannan@gmail.com commit -m "add: <Concept>" -m "Added via Claude (add-to-obsidian)"
   GH_TOKEN=$(gh auth token --user knmn2000) git -c credential.helper= -c credential.helper='!gh auth git-credential' pull --rebase --autostash origin main
   GH_TOKEN=$(gh auth token --user knmn2000) git -c credential.helper= -c credential.helper='!gh auth git-credential' push origin main
   ```

   - The `GH_TOKEN` prefix pushes as `knmn2000` for this command only. Do not run `gh auth switch`, it changes the active account for every other session. The user's default `gh` account stays `karan-mannan`.
   - Pull first because the Obsidian Git plugin also auto-commits to this repo. If the rebase conflicts, stop, run `git rebase --abort`, leave the commit local, and tell the user.
   - If `gh auth token --user knmn2000` fails (account not logged in), keep the local commit and tell the user to run `gh auth login`. Do not fall back to the other account.
   - Use a different commit message verb (`update:`) when appending to an existing note. Never force-push.
6. **Report.** Two or three lines: files written or appended, number of quiz questions added, links added (outgoing and incoming), and the pushed commit hash. Quote nothing else back.

## Quiz-only requests

When the user asks for more or better quiz questions on a note that already exists ("add quiz questions for kafka", "quiz me on Split brain", "backfill quizzes") and no new concept was learned, do not rewrite the note:

1. Find the note (step 2's `find`). Read it fully.
2. Write new questions that follow the quiz rules above and do not repeat existing `Q:` lines. Append them to the end of its `## Quiz` section, or create the section at the end of the file if there is none (nothing may follow it).
3. Commit with `update: quiz for <Note>` and push exactly as in step 5. The Obsidian Nudge app downloads the vault from GitHub on its next sync, so the phone gets the new questions without any cable or manual step.
4. Report the note and how many questions were added.

## Rules

- Never overwrite or delete existing note content. Append or fill empty files only.
- Never touch `.obsidian/` or any file outside the vault.
- Never push to any repo other than the vault's `origin`.
- Use the Write/Edit tools or plain shell (`cat`, `find`). The vault is local files, no Obsidian CLI or plugin is needed.
- Filenames: no `/ : * ? " < > |` characters. Keep spaces.
- Write the note in plain, normal prose even if the chat is in a terse style.
