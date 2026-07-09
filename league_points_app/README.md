# League Points App

A Flutter desktop app (Windows-first, Android later) that replaces the manual
`league template.xlsx` workflow as the source of truth for league standings.
Each season is a portable `.lpts` JSON file opened/saved like a Word document
(File > New/Open/Save/Save As) — there is no central app database.

See the repo-level [wiki.md](../wiki.md) for full architecture notes and
[`.claude` memory](../../../.claude) plan history for the original design decisions.

## Getting started

```
flutter pub get
flutter run -d windows
```

Run tests with `flutter test` and static checks with `flutter analyze` before
merging any branch.

## Working with multiple Claude Code sessions on this app

These are working rules for running several Claude Code sessions on
`league_points_app/` at the same time without them clobbering each other's
edits, build artifacts, or git history.

### 0. Prerequisite: commit the baseline first

`league_points_app/` must be committed to `main` before any parallel-session
workflow starts. Git worktrees branch off committed history — they cannot
branch off an untracked working directory. If `git status` at the repo root
still shows `league_points_app/` as untracked, get one clean commit in on
`main` first, then start parallel sessions.

### 1. One git worktree per session, never two sessions in the same checkout

Each session works in its own worktree on its own branch, run from the repo
root (`League-Points-calculator/`):

```
git worktree add ../lpc-<task-slug> -b claude/<task-slug>
```

- Never run two Claude sessions directly against the same working directory
  at once — `flutter run`/`flutter build` hold file locks (especially
  `windows/CMakeFiles` and `build/`) and two sessions writing the same tree
  will corrupt each other's build state and stage each other's edits.
- Use a short `<task-slug>` (e.g. `season-setup`, `auto-import`) — Windows has
  path length limits and nested worktree paths add up fast.
- `.dart_tool/`, `build/`, and `.flutter-plugins-dependencies` are gitignored
  and per-checkout, so each worktree gets its own — run `flutter pub get`
  inside the new worktree before doing anything else.

### 2. Claim work before starting, scope it to distinct files

Before a session starts editing, state in the conversation (or in a shared
task-tracking doc if the user is coordinating several sessions) which files
or feature area it owns for this task — e.g. "this session owns
`lib/screens/auto_import_screen.dart`", not "this session works on the app."
Prefer splitting tasks along existing module boundaries (`lib/screens/`,
`lib/data/`, `lib/models/`, `lib/widgets/`) so two sessions rarely touch the
same file in the same window.

Treat `pubspec.yaml` / `pubspec.lock` as single-owner: only one session
should ever add/change a dependency at a time, since lockfile edits from two
branches conflict badly and can't be auto-merged.

### 3. Commit small, merge back often

Small, frequent commits on the task branch, merged (or PR'd) back to `main`
as soon as a task is done — the longer a worktree branch lives, the more
likely it drifts from what another session just merged. After merging,
other active sessions should `git fetch` and rebase their branch on the
latest `main` before continuing.

### 4. Before merging: test, then update wiki.md

Run `flutter test` and `flutter analyze` in the worktree before merging.
Per repo convention, `wiki.md` must be updated in the same change as any
repo change — do this as part of the same commit/PR, not as a follow-up.
If two sessions finish around the same time, whichever merges second should
just append its own dated subsection rather than rewriting the other
session's edits, to keep `wiki.md` merges trivial.

### 5. Clean up after merging

Once a branch is merged, remove its worktree and delete the branch:

```
git worktree remove ../lpc-<task-slug>
git branch -d claude/<task-slug>
```

Stale worktrees left lying around are easy to confuse with active work — if
you see one, check whether its branch was merged before removing it.
