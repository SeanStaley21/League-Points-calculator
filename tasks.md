# league_points_app — Task list

Recorded 2026-07-09 from user requests. Not yet implemented — plan/implement each
one as its own change, update wiki.md alongside it, and check it off here when done.

## Priority 1: Dev launcher batch file (temporary) — DONE 2026-07-11

Create a `.bat` file (e.g. `run_app.bat` in `league_points_app/`) that runs the
app with a double-click, so the user doesn't have to type `flutter pub get` /
`flutter run -d windows` every time during development.

- **Temporary only** — once the app is far enough along to package as a real
  distributable `.exe` (`flutter build windows`, mirroring how
  `Kart time program/dist/kart_sorter.exe` is distributed today), delete this
  batch file. It's a dev convenience, not a shipping artifact.

## 1. Default racer weight to 0 — DONE 2026-07-11

When adding a racer to a division's roster, the weight field should default to
`0` if the operator leaves it blank, instead of being unset/null.

- Relevant files: `lib/screens/division_screen.dart` (`_showRacerDialog`),
  `lib/data/season_document.dart` (`addRacer`), `lib/models/weekly_result.dart`
  (`weight`).
- Resolved: confirmed with the user this is a new season-long default weight
  (`Racer.weight`), set once via a "Weight" field in the Add/Edit Racer
  dialog and copied into every week's `WeeklyResult.weight` at roster-add
  time — not the per-week weight entered later via the Kart Pick Order
  screen's `WeightCell`, which is unchanged and still separately editable.

## 2. Weekly standings table on the Home screen — DONE 2026-07-11

Below the division cards on the Home screen (see attached screenshot,
`Screenshot 2026-07-09 221918.png`), add:

- A **week toggle** (segmented control or similar), showing every week from 1 to
  the season's configured week count (`Season.weekCount`, set at season
  creation). Defaults to the last week the operator viewed, or week 1 if none
  has been selected yet (needs new persisted state — either in the `.lpts` file
  or local app state, TBD).
- Below the toggle, **one column-group per division, side by side** (e.g. `Pro 1`
  columns | `Pro 2` columns | `Pro 3` columns | `Juniors` columns), each showing
  that division's racers for the selected week:
  - Sorted **alphabetically by name** (not by points/finish).
  - Two columns: **Name** | **Finish** (finish position for that week).
- Relevant files: `lib/screens/home_screen.dart`, `lib/models/division.dart`,
  `lib/models/racer.dart`, `lib/models/weekly_result.dart`.
- Resolved: "TBD" persistence question resolved as local, non-persisted
  widget state (resets to week 1 on app restart, survives navigating in/out
  of a division). See wiki.md §9.4 for the reasoning and full implementation
  notes (`lib/widgets/weekly_standings_section.dart`).

## 3. Additional optional racer fields + auto-import name matching — PARTIAL 2026-07-11

In the "Add Racer" dialog, add optional fields:

- Racer name (used to match this person's rows in an auto-imported Clubspeed
  export — see below)
- Phone number
- Email

The user will drop an example race printout into
`C:\Users\Admin\Documents\repos\League-Points-calculator\media\` — use it to
confirm the exact format/column the "racer name" needs to match against for
auto-import (this feeds `lib/screens/auto_import_screen.dart`, currently a
placeholder, and the `kartNumber`/lap-time fields already on `WeeklyResult`).

- Relevant files: `lib/models/racer.dart`, `lib/screens/division_screen.dart`
  (`_showRacerDialog`), `lib/data/season_document.dart` (`addRacer`,
  `updateRacerInfo`), `lib/screens/auto_import_screen.dart`.
- Done: `Racer.importName`/`phone`/`email` fields, wired through
  `addRacer`/`updateRacerInfo`, and added to the Add/Edit Racer dialog. See
  wiki.md §9.6.
- Still blocked on: the media/ example file not uploaded yet, so
  `auto_import_screen.dart` matching/import logic is not implemented —
  confirm the racer-name matching format once the file is available.
