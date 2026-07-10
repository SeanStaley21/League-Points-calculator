# League Points Calculator — Wiki

Source of truth for what's in this repository, how it works, and what it's for.
Last generated: 2026-07-09.

---

## 1. What this repo is

This repo is a small toolkit used to run a go-kart racing league at what appears to be
a "Full Throttle Adrenaline Park" location (based on metadata embedded in the xlsx
file). It has three parts, **unrelated in code** to each other:

1. **`Kart time program/`** — a Python command-line tool (`kart_sorter.py`), packaged
   as a standalone Windows `.exe` via PyInstaller, that reads kart lap-time data
   exported from the track's timing system ("Clubspeed"), sorts karts into skill
   classes by kart number, ranks them by best lap time, writes a formatted `.txt`
   report, and sends it straight to the default printer.
2. **`league template.xlsx`** — a manually-maintained Excel workbook used to track
   league standings, weekly points, and divisions across a season. It is a template
   the league operator fills in by hand each week; it is **not** read or written by
   `kart_sorter.py`. There is no code integration between the two.
3. **`league_points_app/`** — a new Flutter desktop app (in progress, not yet
   committed to git) intended to replace the `league template.xlsx` workflow as the
   source of truth for season standings. See §9 for details.

Despite the repo's name ("League-Points-calculator"), there is currently no *shipped*
code that calculates league points — that logic still lives entirely inside the Excel
workbook's formulas today, though `league_points_app/` is being built to take over
that role. The Python program only sorts/ranks single-session kart lap times.

---

## 2. Repository structure

```
League-Points-calculator/
├── .gitignore                         Excludes the PyInstaller build/ cache from version control
├── README.md                          Usage instructions for the .exe (end-user facing)
├── wiki.md                            This document
├── league template.xlsx               Manual season/points-tracking workbook
├── Kart time program/
│   ├── kart_sorter.py                 The actual source code (only .py file in that program)
│   ├── kart_sorter.spec               PyInstaller build spec for kart_sorter.py
│   ├── kart operation.csv             Sample lap-time data (NOT read by current code — see §5)
│   ├── build/                         PyInstaller intermediate build cache — gitignored, regenerated locally by `pyinstaller --onefile kart_sorter.py`
│   └── dist/                          PyInstaller output — what end users actually run
│       └── kart_sorter.exe            The compiled, distributable program (~53 MB)
└── league_points_app/                 Flutter replacement app — NOT yet committed to git, see §9
    ├── README.md                      Getting started + multi-Claude-session working rules
    └── lib/                           App source (models/, data/, screens/, widgets/)
```

As of the 2026-07-09 cleanup, the PyInstaller `build/` cache and the duplicate
`dist/kart operation.csv` are no longer committed to git (they're gitignored/deleted
— see §6 and §7 for what changed and why).

---

## 3. `kart_sorter.py` — how it actually works

This is the only source file in the repo (94 lines of logic + a few trailing
comments). It has four functions and a `main()`.

### 3.1 `get_kart_class(kart_no)`
Classifies a kart number into a league division purely by numeric range:

| Kart # range | Class          |
|--------------|----------------|
| 11–28        | `Pro`          |
| 70–78        | `Junior`       |
| 95–98        | `Intermediate` |
| anything else (non-numeric, or outside the above) | `Other` |

This mapping is hard-coded and is the single source of truth for how karts get
grouped. Note it does **not** match the xlsx workbook's finer-grained divisions
(`Pro 1`, `Pro 2`, `Pro 3`, `Division 1/2/3` — see §4), which are apparently assigned
manually/elsewhere.

### 3.2 `read_xls()`
- Looks for a file literally named **`Excel.xls`** in the current Windows user's
  `Downloads` folder (`~/Downloads/Excel.xls`) — the filename is hard-coded, not
  passed as an argument or prompted for.
- Loads it with `pandas.read_html()`, i.e. it expects an HTML table saved with an
  `.xls` extension (this is the typical export format from Clubspeed-style timing
  systems, which produce HTML tables that Excel/Windows treats as legacy `.xls`).
- Assumes the first table in the file has 6 columns and force-renames them to:
  `Kart No, # Heats, # Laps, Average Lap Time, Best Lap Time, Total Hour`.
- Skips the first data row (`df.iloc[1:]`), assuming it's a repeated header or
  totals row.
- For each remaining row: strips commas from the lap-time fields (so `"1,229"`
  parses as `1229.0`), classifies the kart via `get_kart_class`, and appends a tuple
  `(kart_no, avg_lap, best_lap, kart_class)`.
- Rows that fail to parse (`ValueError`/`KeyError`) are silently skipped.
- If the file isn't found or another error occurs while parsing, it prints an error
  and returns whatever it collected (possibly an empty list).

### 3.3 `save_kart_tables(kart_data)`
- Writes output to `~/Downloads/Kart_Results_<MM DD YYYY>.txt` (today's date, e.g.
  `Kart_Results_07 09 2026.txt`), deleting any existing file at that path first.
- For each class in the fixed order `Pro, Junior, Intermediate, Other`:
  - Filters karts belonging to that class.
  - Sorts them ascending by **best lap time** (index `2` of the tuple) — fastest
    first.
  - Writes a banner + a fixed-width table (`Rank`, `Kart No`, `Avg Lap`, `Best Lap`)
    to the text file.
- Returns the output filepath.

### 3.4 `print_file(filepath)`
- Calls `os.startfile(filepath, "print")` — a Windows-only API that hands the file
  to whatever application is associated with `.txt` and tells it to print using the
  **default printer**, with no print-preview or confirmation step.

### 3.5 `main()`
1. `read_xls()` → get parsed kart data.
2. If any data was found: `save_kart_tables()` then immediately `print_file()`.
3. If no data was found: print `"No kart data found."`.
4. `input("\nPress Enter to exit...")` — keeps the console window open (this is a
   double-clicked `.exe`, not run from a terminal, so without this the window would
   flash and close).

### 3.6 Trailing comments in the file (build notes, not code)
The bottom of `kart_sorter.py` (lines 98–105) contains developer notes, not
functional code:
```
File path: C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program
compile code: "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py
```
This tells you exactly how `dist/kart_sorter.exe` is (re)built: `pyinstaller --onefile kart_sorter.py` from within `Kart time program/`, using Python 3.13, on a machine where the repo lives under OneDrive at Full Throttle Adrenaline Park. It also confirms these are one-off manual builds, not CI-produced.

---

## 4. `league template.xlsx` — how it's structured

A 7-sheet Excel workbook (created 2015-06-05, last modified 2025-08-23, author "Sean
Staley"). No macros/VBA detected — it's plain formulas/tables.

| Sheet             | Purpose (inferred from headers/tables) |
|-------------------|------------------------------------------|
| `Roster`          | Master list of racers (First Name / Last Name / Kart # etc.) |
| `Leaderboards`     | Aggregated standings pulled from the division sheets |
| `Points calculator` | The only sheet meant to be hand-edited per the in-sheet note *"Only edit points in the points calculator sheet"*; converts finishing position → points |
| `Juniors`         | Junior division weekly tracking (`Junior ~~ Weekly Points Calculator`) |
| `Division 1`      | Pro 1 weekly tracking (`Pro 1 ~~ Weekly Points Calculator`) |
| `Division 2`      | Pro 2 weekly tracking |
| `Division 3`      | Pro 3 weekly tracking |

Each division sheet tracks, per racer, per week (`Week 1`…`Week 8` observed):
`Kart #`, `Start`, `Finish`, `Best Time`, `Average Time`, `Weight`, `Points`, `Total`.
A note in the shared strings ("Kart times pulled from: 8/18 - 8/25") confirms the
weekly workflow: results are copied in from a timing-system export (by hand) each
week, and this workbook computes points/standings from them.

**This workbook is entirely separate from `kart_sorter.py`.** The Python program does
not read from or write to this file in any way. Any "points calculation" happens only
inside Excel formulas here.

---

## 5. Data file: `kart operation.csv` and the code/README mismatch (fixed)

`Kart time program/kart operation.csv` holds 32 rows of sample kart lap-time data for
kart numbers 11–28, 70–78, 95–98, matching the class ranges in `get_kart_class`. It
used to also exist as a byte-for-byte duplicate at `Kart time program/dist/kart
operation.csv` — that duplicate was deleted on 2026-07-09 (see §7).

**Inconsistency that was found and fixed:** `kart_sorter.py` never reads a `.csv` file
at all — it only reads `~/Downloads/Excel.xls` via `pandas.read_html`. `README.md`
previously instructed the end user to convert the Clubspeed export to `.csv`, which
didn't match the code. The README has been corrected to say the export should be
saved as `Excel.xls` in the Downloads folder (matching the actual hard-coded
filename/format in `read_xls()`).

---

## 6. Build artifacts and git hygiene (cleaned up 2026-07-09)

Previously there was no `.gitignore` in this repository, so every PyInstaller build
had been committed in full, repeatedly. `git log --stat` showed the same ~53 MB
binary blobs and ~7,000-line `.toc` text diffs re-committed on nearly every change to
`kart_sorter.py` (e.g. commits `a848fe2`, `533a7a3`, `d87c550`, `cea757d`, `1aae659`,
`5f4434d`, `5a7eabd`).

**What changed:**
- The entire `Kart time program/build/` directory (14 files, ~70 MB — PyInstaller's
  intermediate cache: `.toc` files, `base_library.zip`, `kart_sorter.pkg`, the
  `warn-`/`xref-` reports, and `localpycs/*.pyc`) was untracked and deleted from disk.
  None of it was source; all of it regenerates automatically the next time someone
  runs PyInstaller.
- A root-level `.gitignore` was added with `Kart time program/build/` in it, so the
  cache won't get re-committed on the next build.

**What was kept:** `Kart time program/dist/kart_sorter.exe` (~53 MB) is still
committed — it's the actual shippable artifact end users double-click, per the
README, and there's no GitHub Releases workflow set up as an alternative distribution
path. It will still grow the repo/history on every rebuild; if that becomes a problem
later, moving distribution to GitHub Releases and gitignoring `dist/` too is the next
lever to pull.

---

## 7. Cleanup performed on 2026-07-09

1. **Deleted** `Kart time program/dist/kart operation.csv` — it was an exact
   duplicate of `Kart time program/kart operation.csv` and wasn't read by the code
   either way. The one remaining copy lives at `Kart time program/kart operation.csv`.
2. **Deleted** the entire `Kart time program/build/` directory (14 files, ~70 MB) —
   PyInstaller's regenerable intermediate cache, not source. Re-run
   `pyinstaller --onefile kart_sorter.py` from `Kart time program/` if you need it
   back locally.
3. **Added** a root-level `.gitignore` containing `Kart time program/build/`, so the
   cache doesn't get re-committed on the next build.
4. **Fixed** `README.md`'s pre-requisite steps, which told users to convert the
   Clubspeed export to `.csv` — the code only ever reads `Excel.xls`. It now says to
   save the export as `Excel.xls` in Downloads.

Nothing else in the repo was found to be duplicated or dead: `kart_sorter.py`,
`kart_sorter.spec`, `league template.xlsx`, `kart operation.csv`, and
`dist/kart_sorter.exe` each serve a distinct, currently-used purpose.

---

## 8. Quick reference: end-to-end workflow (as documented today)

1. Operator pulls lap-time results from Clubspeed at the track.
2. Saves the export to the Windows **Downloads** folder as `Excel.xls`.
3. Double-clicks `Kart time program/dist/kart_sorter.exe`.
4. Program reads `~/Downloads/Excel.xls`, classifies each kart as Pro / Junior /
   Intermediate / Other by kart number, ranks each class by best lap time.
5. Writes `~/Downloads/Kart_Results_<date>.txt` and immediately sends it to the
   default printer.
6. Console prompts "Press Enter to exit."
7. Separately (no code link), the operator manually transcribes/keys weekly
   results and standings into `league template.xlsx` to track season-long league
   points across `Division 1/2/3` and `Juniors`.

---

## 9. `league_points_app/` — new Flutter replacement app (in progress)

A Flutter desktop app (Windows-first, Android later), intended to eventually replace
`league template.xlsx` as the source of truth for season standings. Document-based
storage, like Microsoft Word: each season is a portable `.lpts` JSON file the user
opens/saves via a File menu (`file_picker`), not a central app-owned database.

Status as of 2026-07-09: committed to git (`lib/models/{division,racer,season,weekly_result}.dart`,
`lib/data/{file_service,points_calculator,season_document}.dart`,
`lib/screens/{home,season_setup,division,auto_import}_screen.dart`, plus widgets and
unit tests). `Kart time program/` and `league template.xlsx` are explicitly out of
scope for this app and remain untouched until/unless a later phase absorbs
`kart_sorter.py`'s auto-import logic into it (the app already has an Auto Import
placeholder screen reserved for that — see §9.1 for where it now lives in the UI).

See `league_points_app/README.md` for getting-started commands and — importantly —
the working rules for running multiple Claude Code sessions on this app in parallel
(one git worktree per session, file-ownership scoping, merge/test/wiki-update order)
so concurrent sessions don't step on each other's edits or build artifacts.

### 9.1 Home screen navigation (changed 2026-07-09)

`HomeScreen` no longer uses a `TabBar`/`TabBarView` to switch between divisions
and the placeholder auto-import screen. The tab row was visually just a strip of
empty underlines once there were several divisions, and made "Auto Import" look
like a per-week worksheet instead of a one-off file action. It now works like a
normal document app:

- **Auto Import moved into the File menu** (`AppMenuBar`, `lib/widgets/app_menu_bar.dart`)
  as an "Auto Import..." item below a divider, under New/Open/Save/Save As. Selecting
  it pushes a `MaterialPageRoute` to a `Scaffold` wrapping the unchanged
  `AutoImportScreen` placeholder.
- **Division cards on the home screen are now the navigation**, not just a read-only
  snapshot: `StandingsSnapshotCard` (`lib/widgets/standings_snapshot_card.dart`) gained
  an optional `onTap` callback, wired in `HomeScreen` to push a `MaterialPageRoute` to a
  `Scaffold(appBar: AppBar(title: Text(division.name)), body: DivisionScreen(...))`.
  Tapping a division's card is now how you open its weekly-points table; there is no
  tab bar anymore. The cards render in a `GridView` (`SliverGridDelegateWithMaxCrossAxisExtent`,
  220px tiles) instead of a fixed-height horizontal `ListView`, since they're no longer
  paired with a tab strip below them.

`DivisionScreen` itself is unchanged (still addressed by `divisionIndex`); it's just
hosted in a pushed route instead of a `TabBarView` page now.

### 9.2 Driver weight input and Kart Pick Order screen (added 2026-07-09)

Adds the ability to record each racer's weight per week and see a cross-division
pick order by weight — this replaces an earlier attempt at the same feature that
had been built into `kart_sorter.py` (see the now-reverted §3/§8 history); it
belongs here instead since weight is a per-racer/per-week fact that lives in the
season document, not something the single-session lap-time sorter has any
concept of.

- **`WeeklyResult.weight`** already existed on the model (mirroring the xlsx
  template's per-week `Weight` column) but had no write path. `SeasonDocument`
  gained `updateWeeklyWeight(divisionIndex, racerIndex, weekNumber, weight)`
  (`lib/data/season_document.dart`), and `WeeklyResult.copyWith` gained a
  `clearWeight` flag (mirroring the existing `clearFinishPosition` pattern) so
  passing `null` actually clears a previously recorded weight instead of being a
  no-op.
- **`WeightCell`** (`lib/widgets/weight_cell.dart`) is a small inline-editable
  numeric text field, styled like the existing `WeekPositionCell` (commit on
  blur/submit, syncs back if the underlying value changes while unfocused).
- **`KartPickOrderScreen`** (`lib/screens/kart_pick_order_screen.dart`) is a new
  screen reachable from a "Kart Pick Order" (`Icons.scale_outlined`) icon button
  on the Home screen, next to the Season Setup gear (see §9.1 for where Home
  screen actions live). It has a Week dropdown in its `AppBar`, and lists every
  racer across every division for that week — flattened into one list, sorted
  descending by weight so the heaviest driver is first — since kart pick order
  happens once across the whole session, not per division. Editing a weight via
  `WeightCell` re-sorts the list live.
- Covered by `test/season_document_test.dart` (the update/clear path) and
  `test/kart_pick_order_screen_test.dart` (cross-division sort order, live
  re-sort on edit).
