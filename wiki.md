# League Points Calculator — Wiki

Source of truth for what's in this repository, how it works, and what it's for.
Last generated: 2026-07-09. Last updated: 2026-08-14 (§0 — worktree-per-task workflow
made a repo-wide rule; §3/§3A — the kartTimeCinci input-selection and console-lifecycle
improvements were backported into `kart_sorter.py`, with its kart classification ranges
deliberately left unchanged; §3.5/§3.6/§3A — `kart_sorter.py` alone gained printer
detection with a terminal fallback; §3.2/§3.4/§3A — the report gained `Run Time` and
`Total Laps` columns in **both** builds; §3.3/§3A/§8 — both builds now delete their own
report `.txt` files older than 24 hours on every run, and §3's subsections were
renumbered to fit the new function in).

---

## 0. How work gets done in this repo (worktree → merge to `main`)

**All work happens in a git worktree on its own branch, then gets merged into `main`.**
`main` is the trunk and the only long-lived branch — there is no PR/review gate and no
`develop` branch. Work just isn't done *directly in the primary checkout*.

```
# from the repo root, start a task
git worktree add ../lpc-<task-slug> -b claude/<task-slug>

# ...do the work, commit small and often, in that worktree...

# finish: merge back to main and publish
git -C <repo root> checkout main
git -C <repo root> merge claude/<task-slug>
git -C <repo root> push origin main

# clean up
git worktree remove ../lpc-<task-slug>
git branch -d claude/<task-slug>
```

Why, given that everything lands on `main` anyway:

- The primary checkout stays clean and buildable. `flutter run`/`flutter build` and
  PyInstaller both hold file locks and write large caches (`build/`, `.dart_tool/`);
  a worktree keeps a half-finished task from wedging the tree you fall back to.
- Abandoning or parking a task is `git worktree remove`, not unpicking a dirty tree.
- Multiple Claude Code sessions can run at once without clobbering each other — see
  `workInstructions.md` for the full parallel-session rules (file-ownership scoping,
  single-owner lockfiles, merge/test/wiki-update order). Those rules were written for
  `league_points_app/` but the worktree-per-task rule applies repo-wide.

Keep `<task-slug>` short — Windows path limits bite fast with nested worktree paths.

Two standing conventions that apply to every branch before it merges:

- **`wiki.md` is updated in the same change**, never as a follow-up (see the README).
- **Rebuild and commit the affected `.exe`** if you changed `kart_sorter.py` or
  `kartTimeCinci.py` — the committed binary is what operators actually run, so a
  source-only commit ships nothing (§6).

> **Both `.exe`s are back in sync with their source as of 2026-08-14.** The `Run Time` /
> `Total Laps` columns had been committed source-only, leaving the binaries behind; the
> report-cleanup change (§3.3) rebuilt both with PyInstaller (§6), so that release went
> out with it. Operators now get the six-column report *and* the 24-hour cleanup.

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
├── workInstructions.md                Flutter app getting-started + multi-Claude-session working rules
├── tasks.md                           Original 2026-07-09 request list for league_points_app (§9)
├── Newfeatures1.md                    Ranked upgrade roadmap + backlog for league_points_app (§9.14)
├── league template.xlsx               Manual season/points-tracking workbook
├── Kart time program/
│   ├── kart_sorter.py                 The actual source code (only .py file in that program)
│   ├── kart_sorter.spec               PyInstaller build spec for kart_sorter.py
│   ├── kart operation.csv             Sample lap-time data (NOT read by current code — see §5)
│   ├── cincinatti fleet divisions.txt Cincinnati kart-number division ranges — source spec for kartTimeCinci (§3A)
│   ├── build/                         PyInstaller intermediate build cache — gitignored, regenerated locally by `pyinstaller --onefile kart_sorter.py`
│   └── dist/                          PyInstaller output — what end users actually run
│       └── kart_sorter.exe            The compiled, distributable program (~33 MB)
├── kartTimeCinci/                     Cincinnati-fleet variant of the kart sorter — see §3A
│   ├── kartTimeCinci.py              Source (adapted from kart_sorter.py; differs in fleet ranges, output filename, and no printer detection — §3A)
│   ├── kartTimeCinci.spec            PyInstaller spec (generated as a build byproduct)
│   ├── build/                        PyInstaller intermediate cache — gitignored, regenerated locally
│   └── dist/
│       └── kartTimeCinci.exe          The compiled, distributable program (~33 MB)
└── league_points_app/                 Flutter replacement app — NOT yet committed to git, see §9
    ├── README.md                      Getting started + multi-Claude-session working rules
    └── lib/                           App source (models/, data/, screens/, widgets/)
```

As of the 2026-07-09 cleanup, the PyInstaller `build/` cache and the duplicate
`dist/kart operation.csv` are no longer committed to git (they're gitignored/deleted
— see §6 and §7 for what changed and why).

---

## 3. `kart_sorter.py` — how it actually works

The Full Throttle build of the kart sorter. Thirteen functions and a `main()`: four for
the core sort-and-report job (`get_kart_class`, `read_xls`, `save_kart_tables`,
`print_file`), three formatting helpers for the report columns (`parse_number`,
`format_run_time`, `format_total_laps`), one for housekeeping
(`cleanup_old_reports`), and five for printer detection and the terminal fallback
(`get_default_printer`, `list_printers`, `is_virtual_printer`,
`default_printer_status`, `show_in_terminal`). Everything but the first four was added
on 2026-08-14.

> **Changed 2026-08-14.** The input-selection and console-lifecycle improvements first
> written for the Cincinnati build (§3A) were backported here. `get_kart_class` and the
> output filename were **deliberately left alone** — the Full Throttle kart list is
> unchanged. See §3.2, §3.5, §3.6.
>
> **Also 2026-08-14:** `cleanup_old_reports()` (§3.3) was added, so old report files
> no longer pile up in Downloads. Subsections below §3.2 were renumbered to fit it in.

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
- Scans the current Windows user's `Downloads` folder for **all `*.xls` files** and
  reads the **most recently modified** one (`glob.glob` + `max(..., key=os.path.getmtime)`).
  The operator no longer has to rename the Clubspeed export to `Excel.xls` — they just
  download it and run. The chosen filename is echoed to the console
  (`Reading newest .xls export: <name>`) so it's obvious which file was used.
- If no `*.xls` exists at all it prints `"No .xls export found in Downloads: <path>"`
  and returns an empty list, falling through to the no-data path in `main()`.
- The "newest wins" heuristic does **not** validate that the file is actually a kart
  export. An unrelated `.xls` that happens to be newest will fail `pandas.read_html`,
  get caught, and land on the same no-data path.
- Loads it with `pandas.read_html()`, i.e. it expects an HTML table saved with an
  `.xls` extension (this is the typical export format from Clubspeed-style timing
  systems, which produce HTML tables that Excel/Windows treats as legacy `.xls`).
- Assumes the first table in the file has 6 columns and force-renames them to:
  `Kart No, # Heats, # Laps, Average Lap Time, Best Lap Time, Total Hour`.
- Skips the first data row (`df.iloc[1:]`), assuming it's a repeated header or
  totals row.
- For each remaining row: strips commas from the lap-time fields (so `"1,229"`
  parses as `1229.0`), classifies the kart via `get_kart_class`, and appends a tuple
  `(kart_no, avg_lap, best_lap, kart_class, total_laps, run_hours)`.
- Rows whose **kart number or lap times** fail to parse (`ValueError`/`KeyError`) are
  silently skipped.
- `total_laps` (from `# Laps`) and `run_hours` (from `Total Hour`) are parsed *outside*
  that `try`, via `parse_number()`, which returns `None` rather than raising. This is
  deliberate: parsing them inside the `try` would make its `continue` drop a kart from
  the report entirely just because one of those cells was blank. A bad value costs the
  kart one cell (rendered `-` by `format_run_time` / `format_total_laps`), not its row.
- The two new fields are appended at **indices 4 and 5**, at the end of the tuple, on
  purpose — downstream code indexes this tuple positionally (`x[2]` is the sort key,
  `k[3]` the class filter, see §3.4), so inserting anywhere else would break it.
- If an error occurs while parsing, it prints the error and returns whatever it
  collected (possibly an empty list).

### 3.3 `cleanup_old_reports()` (added 2026-08-14)
Housekeeping run at the **start** of every `main()`. Deletes this tool's own report
files in Downloads whose mtime is more than 24 hours old, and returns how many it
removed.

- Before this existed, the only deletion anywhere was the same-path overwrite in
  `save_kart_tables` (§3.4), which clears **today's** file only. Every previous day's
  report stayed forever, so Downloads grew by one report per run-day, per tool,
  unbounded. That's what this fixes.
- **The glob is anchored to the `REPORT_PREFIX` module constant (`Kart_Results_`), not
  `*.txt` — this is a safety property, not a detail.** It runs against the operator's
  *real* Downloads folder, full of personal files, so it must never match anything the
  program didn't write. Do not "simplify" this to a bare `*.txt` sweep. The `.docx`
  case is excluded too: the pattern is `Kart_Results_*.txt`.
- Age comes from `os.path.getmtime`, **not** from the date parsed out of the filename
  — mtime is what "made in the last 24 hours" actually means, and it survives any
  future change to the filename format.
- Each delete is wrapped in its own `try/except OSError`, so a report the operator
  still has open in Notepad (`PermissionError`/`WinError 32` on Windows) is reported
  and skipped without aborting the loop or the run. **A failed cleanup must never stop
  the operator getting their printout** — that's why nothing here is fatal.
- Called first in `main()` (§3.6) *deliberately*: cleanup then still happens on runs
  that bail out early with no `.xls` found, which is exactly when Downloads tends to be
  cluttered. The freshly written report is never at risk — cleanup runs before the
  write, and its mtime is seconds old regardless.
- Age threshold lives in the `REPORT_MAX_AGE_HOURS` constant (`24`).

### 3.4 `save_kart_tables(kart_data)`
- Writes output to `~/Downloads/Kart_Results_<MM DD YYYY>.txt` (today's date, e.g.
  `Kart_Results_07 09 2026.txt`), deleting any existing file at that path first
  (same-day rerun overwrite; the older-than-24h sweep is §3.3's job).
- For each class in the fixed order `Pro, Junior, Intermediate, Other`:
  - Filters karts belonging to that class.
  - Sorts them ascending by **best lap time** (index `2` of the tuple) — fastest
    first.
  - Writes a banner + a fixed-width table (`Rank`, `Kart No`, `Avg Lap`, `Best Lap`,
    `Run Time`, `Total Laps`) to the text file. The banner/rule width is `78`, sized to
    the six columns and still inside an 80-column printed page — if a column is ever
    added or widened, that `78` has to move with it.
- Returns the output filepath.

**`Run Time` / `Total Laps` (added 2026-08-14, both builds).** Both values come straight
from the Clubspeed export and needed no new data source — `Run Time` is the `Total Hour`
column and `Total Laps` is `# Laps`; `read_xls()` simply used to discard them (§3.2).
Two helpers render them:

| Helper | Input | Output |
|--------|-------|--------|
| `parse_number(value)` | any cell, incl. thousands-separated `"1,229"` | `float`, or `None` if unparseable |
| `format_run_time(hours)` | decimal hours from `Total Hour`, e.g. `8.79` | `"8h 47m"` (`"-"` if `None`) |
| `format_total_laps(laps)` | lap count, e.g. `1229.0` | `"1229"` (`"-"` if `None`) |

The export gives run time as **decimal hours**; it is converted to hours + minutes for
the printout because that's what the operator reads off paper. `format_run_time` rounds
minutes and carries `60` up to the next hour, so `8.999` prints `9h 00m`, never `8h 60m`.

### 3.5 Printing: `default_printer_status()`, `print_file()`, `show_in_terminal()`

**Added 2026-08-14 — Full Throttle build only.** `os.startfile(..., "print")` can't tell
you whether anything will actually come out of a printer, so the tool used to "succeed"
and close the window while the operator got a PDF Save-As dialog, or nothing at all.
`default_printer_status()` answers that question *before* printing; when the answer is no,
`main()` shows the report in the console instead (§3.6). This is **not** in
`kartTimeCinci.py` — see §3A.

#### `default_printer_status()` → `(can_print, reason)`
Talks to `winspool.drv` through **`ctypes`, not pywin32** — deliberately, since `ctypes`
is stdlib and so adds no dependency, no PyInstaller hidden imports, and essentially no
size to the `.exe` (the rebuild grew ~4 KB). Two Win32 calls:

- `GetDefaultPrinterW` → the default printer's name.
- `EnumPrintersW` (level 2, `LOCAL | CONNECTIONS`) → name, port, attributes and status
  for every installed printer. Called twice, as the API requires: once with a null
  buffer to learn the size, then again to fill it. This needs the full `PRINTER_INFO_2`
  struct declared — **all 21 fields, in order**, even though only four are read, or the
  offsets shift and the values come back as garbage.

The decision, in order:

| # | Condition | Result |
|---|-----------|--------|
| 1 | No default printer at all | `False` — "No default printer is set up on this computer." |
| 2 | Port is a virtual one (`PORTPROMPT:`, `nul:`, `FILE:`, `XPSPort:`, `SHRFAX:`), **or** the name contains `pdf`/`xps`/`onenote`/`fax`/`print to file`/`document writer` | `False` — "…saves to a file instead of printing on paper." |
| 3 | `PRINTER_ATTRIBUTE_WORK_OFFLINE`, or status has OFFLINE / NOT_AVAILABLE / ERROR / PAUSED | `False` — "…is offline or unavailable." |
| 4 | Default printer isn't in the enumeration | `True` — don't second-guess it, let the print attempt happen |
| 5 | Otherwise | `True` |

Port is the primary signal and the name check is the fallback, which is what catches
third-party virtual printers (CutePDF, Foxit, PDF24, Bullzip) sitting on ordinary-looking
ports. The name check is the one that can misfire — a real printer with "PDF" in its
model name would be treated as virtual. That was accepted knowingly: the cost is that the
operator reads the results on screen and can still print the `.txt` by hand.

**It fails open.** The whole body is wrapped in `try/except Exception` returning
`(True, "")`. If printer detection breaks on some unexpected Windows configuration, the
tool must behave exactly as it did before this check existed — refusing to print because
*detection* failed would be worse than the problem it solves. Nothing is lost, because a
print that then fails to dispatch still falls back to the terminal.

#### `show_in_terminal(filepath)`
Reads the saved `.txt` back and `print()`s it. It deliberately does **not** re-render the
tables: the fixed-width layout is built inline inside `save_kart_tables()` with no
reusable formatter, so re-rendering would mean a second copy of that loop free to drift.
Reading the file back is byte-for-byte what was saved.

#### `print_file(filepath)`
- Calls `os.startfile(filepath, "print")` — a Windows-only API that hands the file
  to whatever application is associated with `.txt` and tells it to print using the
  **default printer**, with no print-preview or confirmation step.
- Returns `True` if the job was **dispatched**, `False` if it could not be (catches
  `OSError`). `main()` uses this return value to decide whether to close.
- Important caveat: `True` means "dispatched," not "paper came out." `os.startfile`
  wraps Windows `ShellExecuteW` and returns as soon as the print handler launches. It
  only raises `OSError` when no print verb is registered for `.txt`. A **missing,
  offline, or paused default printer does not raise** — the handler launches fine and
  fails later in its own UI. This is the strongest signal Windows exposes without a
  heavier print API — which is precisely why the `default_printer_status()` pre-check
  above exists. The caveat still stands for everything that gets past that check.

### 3.6 `main()`
The whole body is wrapped in a `try/except Exception`, so an unexpected error (e.g. a
file-write failure) prints its message and holds the window rather than slamming a
double-clicked `.exe` shut before it can be read.

1. `cleanup_old_reports()` → clear reports older than 24 h (§3.3). First, so it runs
   even on the no-data path below.
2. `read_xls()` → get parsed kart data.
3. **No data** → print `"No kart data found."` plus a hint to check that the `.xls`
   export is in Downloads, then wait for Enter. This path deliberately does **not**
   say "could not print" — nothing was ever sent to a printer.
4. **Data found** → `save_kart_tables()` (the `.txt` is written in every case below),
   then `default_printer_status()`:
   - **No usable printer** → print the reason, then `show_in_terminal()` the report,
     then the saved path, then wait for Enter. Nothing is dispatched to a printer.
   - **Printer looks usable** → `print_file()`:
     - **Dispatch succeeded** → return immediately; the console **closes on its own**,
       with no "Press Enter" prompt. This is the normal, everyday path.
     - **Dispatch failed** → `"Could not print -- showing the results here instead."`,
       then `show_in_terminal()` and wait for Enter. (Before 2026-08-14 this branch
       just said "Could not print" and left the operator with nothing on screen.)

The rule this settles on: **the window auto-closes only when paper is actually coming
out.** Every path that puts results on screen holds the window, because the whole point
of those paths is that the operator reads them there.

### 3.7 Trailing comments in the file (build notes, not code)
The bottom of `kart_sorter.py` contains developer notes, not functional code:
```
File path: C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program
compile code: "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py
```
This tells you exactly how `dist/kart_sorter.exe` is (re)built: `pyinstaller --onefile kart_sorter.py` from within `Kart time program/`, using Python 3.13, on a machine where the repo lives under OneDrive at Full Throttle Adrenaline Park. It also confirms these are one-off manual builds, not CI-produced.

---

## 3A. `kartTimeCinci/` — the Cincinnati-fleet build (added 2026-08-01)

`kartTimeCinci/kartTimeCinci.py` is a standalone second build of the kart sorter for
a **different location running a different kart fleet** (Cincinnati). It is a close
adaptation of `kart_sorter.py` (§3) — same functions (`get_kart_class`, `read_xls`,
`cleanup_old_reports`, `save_kart_tables`, `print_file`, `main`), same Clubspeed
HTML-table `.xls` input
format, same fixed-width `.txt` report, same print-to-default-printer flow. It is a
sibling of `Kart time program/`, not a replacement — both are shipped and both are
used, at their respective locations. (As of 2026-08-14 the Full Throttle build has three
functions Cincinnati doesn't — see difference 3 below.)

The division ranges come from `Kart time program/cincinatti fleet divisions.txt` and
are **baked into the code** (hardcoded, like the original — no external config file to
lose as a single `.exe`).

**Changed 2026-08-14.** This section used to list *four* differences from
`kart_sorter.py`. Two of them — newest-`.xls` input selection and the console
lifecycle — were general improvements that had nothing to do with Cincinnati, so they
were **backported into `kart_sorter.py`** (§3.2, §3.5, §3.6) and are now **shared
behavior**, not differences. Later the same day, printer detection was added to the Full
Throttle build only, creating a new difference in the other direction (item 4), and the
24-hour report cleanup (§3.3) was added to *both*, differing only in its prefix
constant (item 3). The current list:

1. **Classification ranges (`get_kart_class`)** — the Cincinnati fleet:

   | Kart # range | Class          |
   |--------------|----------------|
   | 11–59        | `Pro`          |
   | 60–80        | `Junior`       |
   | 90–99        | `Intermediate` |
   | 2–9          | `Unknown`      |
   | anything else (0–1, 10, 81–89, 100+, non-numeric) | `Other` |

   Class print order is `Pro, Junior, Intermediate, Unknown, Other`; empty classes
   are skipped, as in the original. Note the extra `Unknown` class — the Full Throttle
   build has no such class and its four-entry `classes` list is
   `Pro, Junior, Intermediate, Other`.

2. **Output filename** — `~/Downloads/KartTimeCinci_Results_<MM DD YYYY>.txt`,
   deliberately distinct from the original's `Kart_Results_<date>.txt` so running both
   tools on the same day doesn't clobber one report. This is why the backport left the
   original's filename alone.

3. **`REPORT_PREFIX`** — the cleanup constant (§3.3) is `KartTimeCinci_Results_` here.
   This follows directly from difference 2, and it means **each build only ever deletes
   its own reports**: running the Cincinnati tool leaves `Kart_Results_*.txt` untouched
   and vice versa. On a machine that runs both, each tool tidies up after itself the
   next time *it* runs. The cleanup function itself is otherwise identical in both — the
   prefix is the only line that differs.

4. **No printer detection / terminal fallback** (diverged 2026-08-14) — the Full Throttle
   build gained `default_printer_status()`, `show_in_terminal()`, and the `main()`
   branches that display the report in the console when there's no usable printer (§3.5,
   §3.6). `kartTimeCinci.py` does **not** have any of it: it still calls `print_file()`
   unconditionally and dead-ends on `"Could not print"`.

   This one is an **intentional divergence, not drift** — the change was explicitly
   scoped to the Full Throttle program at the user's request. It is *not* fleet-specific,
   though, so unlike differences 1 and 2 it is a reasonable candidate to port later.
   Doing so is a mechanical copy: the `ctypes`/`winspool` block and `PRINTER_INFO_2`
   struct, the four functions `get_default_printer` / `list_printers` /
   `is_virtual_printer` / `default_printer_status`, `show_in_terminal`, and the two new
   branches in `main()`. Nothing in it depends on the fleet or the output filename.

**Still identical in both builds** (documented in §3, don't re-document as differences):
newest-`.xls` input selection, the 24-hour `cleanup_old_reports()` sweep and where it's
called from in `main()` (§3.3 — same logic, only the prefix differs), `print_file` itself
returning dispatch success/failure with the dispatched-≠-printed caveat,
close-on-successful-print, the no-data message, the `try/except` wrapper around `main()`,
and the report's six columns including `Run Time` / `Total Laps` with their
`parse_number` / `format_run_time` / `format_total_laps` helpers (added to both files in
lockstep, 2026-08-14 — §3.2, §3.4).

**If you change one of those shared behaviors, change it in both files** — unless you are
deliberately diverging, in which case record it here as a numbered difference the way
item 4 does. They are independent copies, not a shared module; that is intentional (each
ships as a self-contained single-file `.exe`), but it means the two can silently drift.

**Build:** from inside `kartTimeCinci/`, `python -m PyInstaller --onefile
kartTimeCinci.py` (Python 3.13). This produces `dist/kartTimeCinci.exe` (~33 MB) and
**generates `kartTimeCinci.spec` as a byproduct** — the spec is not hand-written
(building from the `.py` would overwrite it anyway). `kartTimeCinci/build/` and
`kartTimeCinci/__pycache__/` are gitignored (same regenerable-cache reasoning as §6);
`dist/kartTimeCinci.exe` is committed as the shippable artifact, like
`dist/kart_sorter.exe`.

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
at all — it only reads `.xls` (an HTML table) via `pandas.read_html`. `README.md`
originally instructed the end user to convert the Clubspeed export to `.csv`, which
didn't match the code; it was corrected on 2026-07-09 to say `Excel.xls`, and updated
again on 2026-08-14 when `read_xls()` stopped requiring that specific filename (§3.2)
— the export now just has to be the newest `.xls` in Downloads, under any name.

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

**What was kept:** `Kart time program/dist/kart_sorter.exe` (~33 MB as currently
built — earlier history carried larger blobs) is still committed — it's the actual
shippable artifact end users double-click, per the README, and there's no GitHub
Releases workflow set up as an alternative distribution path. It will still grow the
repo/history on every rebuild; if that becomes a problem later, moving distribution to
GitHub Releases and gitignoring `dist/` too is the next lever to pull.

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
2. Saves the export to the Windows **Downloads** folder. **No renaming needed** — any
   filename works, as long as it's the newest `.xls` there.
3. Double-clicks `Kart time program/dist/kart_sorter.exe`.
4. Program first deletes any of its own `Kart_Results_*.txt` in Downloads older than
   24 hours (§3.3), so old printouts don't accumulate. Nothing else in Downloads is
   touched.
5. Program reads the newest `~/Downloads/*.xls`, classifies each kart as Pro / Junior /
   Intermediate / Other by kart number, ranks each class by best lap time.
6. Writes `~/Downloads/Kart_Results_<date>.txt`, then checks whether the default printer
   can actually produce paper (§3.5).
   - **Yes** → sends it to the default printer.
   - **No printer / print-to-PDF / offline** → prints the report into the console window
     instead, so the operator can read it off the screen. The `.txt` is saved either way.
7. On a successful print the console **closes by itself**. It stays open whenever there's
   something to read — the on-screen results, "No kart data found.", or an error.
8. Separately (no code link), the operator manually transcribes/keys weekly
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

### 9.3 Dev launcher batch file + season-long default racer weight (2026-07-11)

Both items from `tasks.md` Priority 1 and Task 1:

- **`league_points_app/run_app.bat`** — double-click dev launcher (`flutter
  pub get` then `flutter run -d windows`, with a `pause` so the console
  window stays open on error). Explicitly **temporary**: delete it once the
  app ships as a packaged `flutter build windows` `.exe`, mirroring how
  `Kart time program/dist/kart_sorter.exe` is distributed today.
- **`Racer.weight`** (`lib/models/racer.dart`) — a new non-nullable
  `double` field, default `0`, distinct from the existing per-week
  `WeeklyResult.weight` (§9.2, still entered later via the Kart Pick Order
  screen's `WeightCell`). This is a season-long default set once when the
  racer is added to the roster: the Add/Edit Racer dialog
  (`lib/screens/division_screen.dart`, `_showRacerDialog`) gained a "Weight
  (lbs)" text field (blank parses to `0`, same numeric-input-formatter
  pattern as `WeightCell`), and `SeasonDocument.addRacer` (added `weight`
  param, default `0`) copies that value into every week's
  `WeeklyResult.weight` at creation time. `SeasonDocument.updateRacerInfo`
  gained a matching `weight` param that only updates the racer's stored
  default — it does not retroactively rewrite already-created weekly
  results, which stay independently editable via Kart Pick Order.
  Confirmed with the user this was the intended reading of "default to 0
  when adding a racer to the roster" over the alternative (defaulting
  `WeeklyResult.weight` itself to 0 instead of null).
- Covered by two new cases in `test/season_document_test.dart`: `addRacer`
  defaulting/propagating weight into every week, and `updateRacerInfo`
  updating only the season-long default without touching existing weekly
  results.

### 9.4 Weekly standings table on the Home screen (2026-07-11)

Task 2 from `tasks.md`. Adds a `WeeklyStandingsSection`
(`lib/widgets/weekly_standings_section.dart`) below the division cards on
`HomeScreen`:

- A `SegmentedButton<int>` week toggle (`Wk 1`..`Wk Season.weekCount`).
  Selected week is kept in the section's own `State` (`_selectedWeek`,
  defaults to `1`), **not persisted** to the `.lpts` file or app-wide state —
  it resets to week 1 on next launch, but survives navigating into a
  division and back since `HomeScreen` (and this section) stay on the
  Navigator stack rather than being rebuilt from scratch. Fully persisting
  "last week viewed" was left TBD in the task and judged not worth a file
  schema change for a session-scoped convenience.
- Below the toggle, one `_DivisionWeekColumn` card per division, laid out
  side by side in a horizontally scrollable `Row`. Each card sorts its
  racers **alphabetically by `fullName`** (not `sortOrder`/points) and shows
  a two-column `DataTable`: Name | Finish, where Finish is **editable in
  place** (added 2026-07-11) via the same `WeekPositionCell`
  (`lib/widgets/week_position_cell.dart`) used on `DivisionScreen` — a
  numeric text field that commits on blur/submit, shows the computed
  points below it, and calls `SeasonDocument.updateWeeklyFinishPosition`.
  Row height bumped from 32 to 76 (`dataRowMinHeight`/`dataRowMaxHeight`)
  to fit the cell's Pos field + points line without overflowing.
  - Since racers are displayed alphabetically but `SeasonDocument`
    addresses them by their index in `Division.racers`' stored (insertion)
    order, `_DivisionWeekColumn` pairs each racer with its original index
    before sorting (`indexedRacers`) and uses that original index — not
    its position in the alphabetical list — when calling
    `updateWeeklyFinishPosition`. Getting this backwards would silently
    write the wrong racer's result after the first name added out of
    alphabetical order.
- `HomeScreen`'s division `GridView` gained `shrinkWrap: true` +
  `NeverScrollableScrollPhysics` and now sits inside a `SingleChildScrollView`
  alongside this new section (previously the `GridView` alone filled the
  `Expanded` area via its own scrolling).
- Covered by `test/weekly_standings_section_test.dart`, which pumps the
  widget directly (not through `HomeScreen`) to avoid a pre-existing,
  unrelated layout overflow in `StandingsSnapshotCard` that only surfaces
  once a division has a leader with points — out of scope for this task,
  not fixed here. Includes a case entering text into a Finish field and
  asserting the change lands on the underlying `SeasonDocument`.
- Manually verified end-to-end in the built Windows app, including editing
  a Finish cell directly from the Home screen and seeing the division
  card's leader/points snapshot update immediately.

### 9.5 Kart pool + kart assignment on the Kart Pick Order screen (2026-07-11)

Extends §9.2's `KartPickOrderScreen` so the operator can actually record which
physical kart each racer picked, not just the pick order itself. Requested
because the league runs two physically distinct kart pools (faster Pro karts,
slower Junior karts for the Juniors division), the same Pro kart number can be
driven by one racer from each Pro division in the same week since those
divisions race at different times, and karts regularly need to be marked
broken/out of service for a given week.

- **`KartClass`** (`lib/models/kart.dart`) — `enum { pro, junior }` with a
  `.label` extension. **`Kart`** (same file) is `{number, classType,
  downWeeks}` — `downWeeks` is a `Set<int>` of week numbers that kart is
  marked down for, since a kart can be broken one week and fine the next.
- **`Division.kartClass`** (`lib/models/division.dart`) — new field, default
  `KartClass.pro`, added so the app knows which pool a division draws from.
  Set via a `DropdownButton<KartClass>` on each division row and the "new
  division" row in `SeasonSetupScreen`; `SeasonDocument.addDivision` gained a
  `kartClass` param and `updateDivisionClass(divisionIndex, kartClass)` was
  added to change it after the fact (needed since divisions created before
  this feature default to Pro, e.g. a pre-existing "Juniors" division).
- **`Season.kartPool`** (`lib/models/season.dart`) — a `List<Kart>`, season-wide
  (not per-division/per-week): the Pro pool is shared by every Pro division,
  the Junior pool by the Juniors division. `SeasonDocument` gained
  `addKart(number, kartClass)` (no-ops on a duplicate number),
  `removeKart(number)`, and `setKartDownForWeek(number, week, isDown)`.
- **`WeeklyResult.kartNumber`** existed already but had no write path or clear
  semantics. `WeeklyResult.copyWith` gained a `clearKartNumber` flag (mirroring
  `clearWeight`/`clearFinishPosition`), and `SeasonDocument` gained
  `updateWeeklyKartNumber(divisionIndex, racerIndex, weekNumber, kartNumber)`.
- **`KartPickOrderScreen`** (`lib/screens/kart_pick_order_screen.dart`):
  tapping a racer's row selects it (highlighted via `ListTile.selected`) and
  expands a row of `FilterChip`s directly beneath it, showing that division's
  kart pool (filtered by `Division.kartClass`). A chip is disabled and
  labeled "(down)" if the kart is marked down for the currently viewed week,
  or "(taken)" if another racer **in the same division** already has it
  assigned that week — kart-taken tracking is scoped per division, not
  globally across the whole Pro pool, so the same kart number can be picked by
  one Pro 1 racer and one Pro 2 racer in the same week without conflict.
  Tapping the selected racer's already-assigned kart again clears it. An
  AppBar settings icon opens **`KartPoolDialog`**
  (`lib/widgets/kart_pool_dialog.dart`), which lists Pro/Junior karts with a
  checkbox for "down for the week currently being viewed", a delete button,
  and a small form to add a new kart number + class.
- Covered by new cases in `test/season_document_test.dart` (kart
  add/remove/dedupe-by-number, per-week down marking, `updateDivisionClass`,
  `updateWeeklyKartNumber` set/clear) and `test/kart_pick_order_screen_test.dart`
  (selecting a racer filters the pool to their division's class, tapping a
  chip assigns it, a down kart is disabled, a kart taken within the same
  division is disabled for a different racer).
- Manually verified end-to-end in the built Windows app: added a Pro division,
  a racer with a season-long weight, opened Kart Pick Order, added a Pro kart
  via the settings dialog, selected the racer, and confirmed tapping the kart
  chip assigned it (row updated to show "Pro 1 · Kart 14", chip showed
  selected/checked).
- **Reworked same day** (see §9.7) from a single cross-division list into one
  column per division — the user wanted each division's own pick order kept
  separate and visible side by side, matching §9.4's Weekly Standings layout,
  not merged into one ranked list.

### 9.6 Optional racer contact/import-name fields (2026-07-11, partial — Task 3)

Model/dialog half of Task 3 from `tasks.md`. The auto-import matching itself
stays blocked: the user hasn't yet dropped an example Clubspeed race printout
into `media/`, so the exact name/column format to match against is still
unknown and `lib/screens/auto_import_screen.dart` is untouched.

- **`Racer.importName`, `Racer.phone`, `Racer.email`** (`lib/models/racer.dart`)
  — three new optional (`String?`) fields, all default `null`. `importName` is
  distinct from `firstName`/`lastName`: it exists so an operator can record
  how a racer's name appears on the Clubspeed export when that differs from
  their roster name (nickname, middle name on file at the track, etc.) —
  future auto-import matching should fall back to `fullName` when
  `importName` is unset. `Racer.copyWith` gained `clearImportName`/
  `clearPhone`/`clearEmail` flags (same pattern as `WeeklyResult`'s
  `clearWeight`) so the Edit Racer dialog can blank out a previously-set
  value, not just leave it unchanged.
- **`SeasonDocument.addRacer`** and **`updateRacerInfo`**
  (`lib/data/season_document.dart`) gained matching optional params
  (`importName`, `phone`, `email` on both; `clearImportName`/`clearPhone`/
  `clearEmail` on `updateRacerInfo`).
- **Add/Edit Racer dialog** (`lib/screens/division_screen.dart`,
  `_showRacerDialog`) gained three more optional text fields below Weight:
  "Import name (optional)", "Phone (optional)", "Email (optional)". Blank
  text is treated as "clear this field" on save, not "leave unchanged" —
  matches how the rest of this dialog already treats blank weight as `0`.
- Covered by a new case in `test/season_document_test.dart` setting all
  three fields via `addRacer` then clearing them via `updateRacerInfo`.
- Still to do once the `media/` example export is available: confirm the
  exact name/column format Clubspeed exports use, then wire matching +
  actual import logic into `auto_import_screen.dart` using
  `importName`/`fullName` against that format.

### 9.7 Kart Pick Order: per-division columns instead of one combined list (2026-07-11)

Follow-up to §9.5, same day: the user clarified (with a screenshot of the
Weekly Standings side-by-side layout as the reference) that Kart Pick Order
should show **one column per division**, each independently sorted
heaviest-first, not one list flattened across all divisions. Kart-assignment
exclusivity was already scoped per division (§9.5), so that part of the
behavior didn't change — only the list's shape did.

- `KartPickOrderScreen` no longer computes one global sorted `entries` list.
  Instead its body is a horizontally-scrollable `Row` of `_DivisionPickColumn`
  cards, one per `Season.divisions` entry (same `SingleChildScrollView` +
  `Row` shape as `WeeklyStandingsSection`'s `_DivisionWeekColumn`, §9.4).
- **`_DivisionPickColumn`** (private widget in the same file) sorts only its
  own division's racers by that week's weight, descending, and renders each as
  a `ListTile` with a rank badge scoped to that division (so division 2's
  heaviest racer is still "1", not a continuation of division 1's numbering).
- Racer selection state moved from a single "one selected racer overall"
  concept to a `(divisionIndex, racerIndex)` pair still held in
  `_KartPickOrderScreenState`, but the kart-assignment chip row now renders
  **inline, directly under the selected racer's own row within that
  division's card** (via `_buildRow`'s `if (isSelected) ...`), instead of in
  one shared panel pinned to the bottom of the screen — since each division
  is now its own visual column, there's no single "bottom of the list" that
  makes sense for all of them.
- `takenInDivision` (which karts are already assigned within a division, for
  disabling chips) is now computed per `_DivisionPickColumn` from just that
  division's entries, rather than once globally — mechanically simpler now
  that there's no cross-division list to derive it from, and it makes the
  per-division exclusivity/no-cross-division-conflict rule (§9.5) more
  obviously correct by construction.
- Updated `test/kart_pick_order_screen_test.dart` throughout for the new
  shape (e.g. the sort-order test now asserts each division's list
  independently instead of one global order) and added a new case asserting
  the same kart number can be assigned in two different divisions in the
  same week without either chip being disabled.
- Not re-verified live in the running Windows app this round — another
  Claude Code session was actively editing files in this same working
  directory (not an isolated worktree) at the time, and `flutter run -d
  windows` hit a transient build error from that race; `flutter analyze` and
  `flutter test` both pass cleanly against the settled code.

### 9.8 Settings screen with app-wide color/dark theme (2026-07-11)

Adds a top-level Settings screen (separate from the per-season "Season
Setup" screen, §9.1) with a Preferences section for changing the whole
app's color scheme and light/dark/system mode, persisted across restarts.

- **`ThemeController`** (`lib/data/theme_controller.dart`) is a
  `ChangeNotifier` holding the current seed `Color` and `ThemeMode`
  (default: deep orange, system), persisted via `shared_preferences` (new
  pubspec dependency) as an int ARGB value + mode name string. It loads
  asynchronously on construction and falls back to the defaults until that
  completes. `appColorOptions` in the same file is the fixed list of named
  color choices offered in the UI (Deep Orange, Blue, Indigo, Teal, Green,
  Purple, Pink, Red, Amber).
- **`main.dart`** now provides `ThemeController` alongside `SeasonDocument`
  via `MultiProvider` (was a single `ChangeNotifierProvider`).
  **`app.dart`**'s `LeaguePointsApp` watches it and builds `MaterialApp`
  with both `theme`/`darkTheme` (same seed color, `Brightness.light`/`.dark`)
  and `themeMode: themeController.themeMode` — so light/dark and the seed
  color both apply app-wide immediately when changed, no restart needed.
- **`SettingsScreen`** (`lib/screens/settings_screen.dart`) is a new screen
  with a "Preferences" section containing an "App Appearance" `ExpansionTile`
  (shows the current mode + color name as its subtitle). Tapping it expands
  **`AppAppearanceControls`** (`lib/widgets/app_appearance_controls.dart`)
  inline, directly under the tile — a `SegmentedButton<ThemeMode>` for
  Light/Dark/System plus a `Wrap` of tappable color swatches from
  `appColorOptions`, both writing straight through to `ThemeController` so
  the app re-themes live as you tap, no modal dialog involved. (An earlier
  version of this used an `AlertDialog`-based `AppAppearanceDialog`; the
  user asked for the controls to live inside the tile itself instead, so
  that file was replaced by the current inline widget.)
- Reachable from a new gear icon (`Icons.settings_outlined`, tooltip
  "Settings") on the Home screen's action row. The pre-existing Season
  Setup icon in that same row was changed from `Icons.settings_outlined` to
  `Icons.event_note_outlined` to avoid two identical-looking icons doing
  different things.
- `test/widget_test.dart` needed a `ThemeController` provider added to its
  `MultiProvider` test wrapper (`_wrapApp` helper) since `LeaguePointsApp`
  now reads it unconditionally; `flutter analyze` and `flutter test` both
  pass (29 tests).

### 9.9 Contacts screen (2026-07-11)

Adds a read-only directory listing every racer in the season with their
phone/email (§9.6 added those fields to `Racer` but nothing surfaced them
outside the per-division Edit Racer dialog).

- **`ContactsScreen`** (`lib/screens/contacts_screen.dart`) is a new screen:
  a search box (filters by name/phone/email, case-insensitive) over a
  `ListView` grouped by division (division name as a header, racers sorted
  by `sortOrder` beneath it, same sort as `DivisionScreen`). Each racer is a
  `ListTile` (`_ContactTile`) showing phone/email as subtitle lines, or "No
  contact info on file" if both are unset, with trailing phone/email icon
  buttons that copy the value to the clipboard via `Clipboard.setData`
  (`flutter/services`, no new dependency) and confirm with a `SnackBar`.
  Divisions/racers that don't match the search text are hidden entirely
  (a division header with zero matching racers isn't shown).
- Reachable from a new `Icons.contacts_outlined` icon button (tooltip
  "Contacts") on the Home screen's action row, added to the left of the
  Kart Pick Order icon (§9.2).
- Deliberately no `url_launcher`-style tap-to-call/email — that needs a new
  dependency plus platform config the app doesn't otherwise need; copy-to-
  clipboard covers the "share this contact info" use case without it.
- `flutter analyze` passes clean on the new/changed files. Not covered by a
  new widget test yet.

### 9.10 Kart column on Weekly Standings + Import name hint text (2026-07-11)

Two small, independent tweaks:

- **`WeeklyStandingsSection`** (`lib/widgets/weekly_standings_section.dart`,
  §9.4) gained a third, read-only **Kart** column next to Name/Finish in each
  division's `DataTable`, showing that racer's `WeeklyResult.kartNumber` for
  the selected week (or `-` if none assigned) — requested so the operator can
  see who had which kart, for which week, from the Home screen without
  opening Kart Pick Order (§9.5/§9.7, which remains the only place kart
  numbers are actually assigned/edited; this column is display-only). Covered
  by a new case in `test/weekly_standings_section_test.dart`.
- The Add/Edit Racer dialog's "Import name" field (`lib/screens/division_screen.dart`,
  §9.6) had its `hintText` shortened from a full sentence to **"For
  Auto-Import to work"** — the text that shows inside the box before typing.

### 9.11 Save/load kart roster to a standalone file (2026-07-11)

Requested so the operator doesn't have to retype every kart number each new
season: `KartPoolDialog` (§9.5) gained "Load karts from file" / "Save karts to
file" buttons above the add-kart row.

- **`kartRosterFileExtension = 'lktr'`** (`lib/utils/constants.dart`) — a
  separate file extension/format from the season file (`.lpts`), since a
  roster is just the kart pool, not a whole season.
- **`FileService`** (`lib/data/file_service.dart`) gained
  `pickKartRosterOpenPath`/`pickKartRosterSavePath` (same `file_selector`
  pattern as the season open/save paths) and `readKartRoster`/
  `writeKartRoster`. The roster file only stores `{number, classType}` per
  kart — `downWeeks` is deliberately dropped on both read and write, since
  "broken this week" is season/week-specific and meaningless carried into a
  freshly loaded roster.
- **`SeasonDocument.saveKartRosterToFile()`** writes the current season's
  `kartPool` out via a save-file picker (suggested filename `"<season name>
  karts"`). **`loadKartRosterFromFile()`** reads a roster via an open-file
  picker and **merges** it into the current pool: kart numbers already present
  are left untouched (so existing down-for-week marks on this season's karts
  survive a reload), only new numbers are added.
- `KartPoolDialog` wraps both calls in try/catch and reports success/failure
  via a `SnackBar` (`ScaffoldMessenger.of(context)`, available because
  `MaterialApp` provides one at the root).
- No automated test added (thin UI/file-IO wiring over already-tested
  `SeasonDocument` mutation logic); verified via `flutter analyze` (clean) and
  the existing `flutter test` suite (all 30 cases still pass unaffected).

### 9.12 Single-file `.exe` for sharing (2026-07-11)

The user wanted one literal `.exe` to hand to someone — not a folder, not a
zip. A stock `flutter build windows --release` output is never a single
file (it's `league_points_app.exe` + `flutter_windows.dll` +
`file_selector_windows_plugin.dll` + a `data/` folder — the `.exe` won't run
if copied out on its own), so producing a true single-file artifact needs an
extra packaging step on top of the Flutter build. This is the packaged-`.exe`
alternative to `run_app.bat` that §9.3 flagged as the eventual replacement
(`run_app.bat` itself was left in place — still useful for running from
source during development, not deleted).

- `flutter build windows --release` output is zipped to
  `league_points_app/dist/league_points_app_windows.zip` first (intermediate
  artifact, not the deliverable).
- **First attempt, abandoned:** Windows' built-in `iexpress.exe` (SED-file
  self-extractor) wrapping the zip + a launcher `.bat`. Rejected after
  testing — IExpress pops an install-confirmation window that didn't behave
  reliably (dismissing it via `SendKeys`/UI Automation sometimes closed the
  package instead of proceeding, sometimes left it hung with nothing
  extracted), which isn't good enough for a "just double-click it" artifact.
- **What's actually used:** a small C# launcher (`Launcher.cs`, compiled with
  the .NET Framework's built-in `csc.exe` — no extra install needed) with the
  zip embedded as a resource via `csc /resource:app.zip,app.zip`. At runtime
  it extracts the embedded zip to `%LOCALAPPDATA%\LeaguePointsApp\` (wiping
  any previous copy first, so it's always current) and starts
  `league_points_app.exe` from there — no dialogs, no companion files.
  Compiled with `/target:winexe` (no console flash) as
  `league_points_app/dist/LeaguePointsApp.exe` (~12.6 MB, single file).
  Verified end-to-end: double-click equivalent (`Start-Process`) → files
  land in `%LOCALAPPDATA%\LeaguePointsApp\` → `league_points_app` process
  comes up and responds.
- Rebuild recipe (no build script committed — this is a manual/occasional
  packaging step, not part of `flutter build`): `flutter build windows
  --release`, zip the `Release/` folder, `csc /nologo /target:winexe
  /platform:x64 /out:LeaguePointsApp.exe /resource:<zip>,app.zip
  /reference:System.IO.Compression.FileSystem.dll
  /reference:System.IO.Compression.dll Launcher.cs`.
- `league_points_app/.gitignore` gained `/dist/` — everything under it
  (the zip and the final `.exe`) is a regenerable build artifact, same
  reasoning as `/build/` already being ignored (§6 covers the same
  build-artifact-hygiene call for `kart_sorter.py`'s PyInstaller output).
  Nothing in `dist/` is committed to git.

  **Correction (2026-07-15):** `Launcher.cs` had only ever been written
  into `dist/`, so it was gitignored along with everything else there —
  the *source* for the packaged exe was silently un-recoverable, not just
  the build output. It's now committed at `league_points_app/packaging/Launcher.cs`
  (outside `/dist/`, so it survives), with the rebuild recipe as a comment
  at the top of the file. See §9.13.

### 9.13 Collapsible sidebar navigation + `Launcher.cs` recovered (2026-07-15)

- **`AppSidebar`** (`lib/widgets/app_sidebar.dart`) replaces the vertical
  column of unlabeled `IconButton`s that used to sit in the top-right of
  `HomeScreen`'s header (Contacts / Kart Pick Order / Season Setup /
  Settings — see §9.1/§9.2/§9.8/§9.9 for when each of those actions was
  added). It's now a proper left-hand navigation rail spanning the full
  body height, built with `AnimatedContainer` so the icon size/spacing stay
  identical between states and only the width (72px collapsed / 220px
  expanded) and label opacity animate — a 220ms `easeInOutCubic` transition
  rather than an instant swap. A `chevron_left`/`chevron_right` row pinned
  to the bottom (below a `Divider`, same row height as the nav items above
  it) toggles collapsed/expanded state, defaulting to expanded. Collapsed
  items get a `Tooltip` showing the label on hover, since the text itself
  is hidden. `HomeScreen`'s header `Row` (season name/dates/counts) moved
  into the remaining `Expanded` content pane since the icons no longer
  share that row.
- **`Launcher.cs` recovered.** While rebuilding the packaged exe for this
  change, discovered the C# launcher source described in §9.12 had never
  actually been committed anywhere — it was written directly into the
  gitignored `dist/` folder during the original packaging session, so it
  existed only on that one machine's disk and wasn't recoverable from git.
  Rewrote it from the §9.12 description (extract embedded `app.zip`
  resource to `%LOCALAPPDATA%\LeaguePointsApp\`, wiping any previous copy,
  then launch `league_points_app.exe` from there) and committed it at
  **`league_points_app/packaging/Launcher.cs`** — deliberately outside
  `/dist/` so this doesn't happen again. The rebuild recipe now lives as a
  comment at the top of that file instead of only in this wiki.
- Rebuilt and manually verified both artifacts end-to-end: `flutter build
  windows` (plain dev build) and the packaged single-file
  `dist/LeaguePointsApp.exe` (rezipped the fresh `Release/` output, recompiled
  the launcher with `csc`, launched it, confirmed it extracts to
  `%LOCALAPPDATA%\LeaguePointsApp\` and starts the app). Found and closed an
  orphaned `league_points_app.exe` left running from an earlier session's
  packaged-exe test (confirmed with the user before closing it, since it
  could otherwise have been mistaken for a window with unsaved work in it).
- `flutter analyze` clean. No new widget test added for `AppSidebar` (pure
  layout/UI-chrome change, navigation destinations and their `onTap`
  behavior are unchanged from §9.1/§9.2/§9.8/§9.9, already covered where
  those were introduced).

### 9.14 Upgrade roadmap recorded in `Newfeatures1.md` (2026-07-15)

Planning only — **no app code changed in this entry.** `Newfeatures1.md` (repo
root, alongside `tasks.md`) records a ranked upgrade roadmap plus a backlog,
written after an audit of the app as it stands at §9.13. Priorities confirmed
with the user: reporting (print/export/email), data safety, leaderboard views,
with Android as a real later target.

The four ranked items are: **(1)** a reports feature — print / PDF / CSV / email
with user-selected scope (one-or-all weeks × one-or-all divisions), orientation,
and layout, built on a pure `lib/reports/` layer that renders to an abstract
`ReportDocument` so scope/layout logic is unit-testable without a printer;
**(2)** data safety; **(3)** season leaderboard/standings views; **(4)** Android
seams. See the file itself for the full spec, package evaluation, risks, and
verification steps — it is not duplicated here.

Findings from the audit that are worth recording in the wiki itself, since they
describe the code as it exists today rather than a proposal:

- **No output path exists at all.** The only file writes are `writeSeason` and
  `writeKartRoster` — machine formats for reloading the app's own state. The
  xlsx workflow can't be fully retired until the app can print, since
  `kart_sorter.exe` still prints the fixed-width `.txt` the league uses.
- **`formatVersion` is written but never read.** `FileService.writeSeason`
  (`file_service.dart:48`) writes it; `readSeason` (`:41-43`) ignores it and
  reaches straight for `decoded['season']`. The field is currently decorative and
  no migration path exists.
- **No unsaved-changes guard on exit.** `confirmDiscardUnsavedChanges` covers
  New/Open only; its own doc comment (`confirm_dialog.dart:35`) claims
  "(New/Open/**Exit**)" but no `PopScope`/window-close hook exists, so closing
  the window silently discards the season. `file_service.dart` also has zero
  try/catch, so a corrupt `.lpts` throws unhandled.
- **`sortOrder` index trap — wrong-racer data writes.** `division_screen.dart:114`
  sorts a copy of `division.racers` and passes that *sorted* index to
  `updateWeeklyFinishPosition` (`:185`), `updateRacerInfo` (`:207`) and
  `removeRacer` (`:228`), while `SeasonDocument` addresses racers by their *stored*
  index — the same trap `weekly_standings_section.dart:111-116` and
  `kart_pick_order_screen.dart:143-151` explicitly document and avoid. Compounding
  it, `addRacer` assigns `sortOrder = racers.length` (`season_document.dart:167`)
  while `removeRacer` just `removeAt`s (`:184`), so remove-then-add yields
  duplicate `sortOrder` values (0,2,2).
  It doesn't fire today, but **not** because `sortOrder` tracks insertion order —
  the duplicates prove it doesn't. It's that `sortOrder` is always *non-decreasing
  in storage order* (adds only append, removes only remove), so a **stable** sort
  by it is the identity. Dart's `List.sort` is only stable below its internal
  32-element threshold (insertion sort; dual-pivot quicksort above, and the API
  promises nothing), so at **32+ racers in one division** the duplicates can
  reorder the copy and the writes hit the wrong racer — no reordering feature
  needed. Real divisions run ~13 racers, so it stays latent in practice. Fix both
  halves (carry the original index; assign `sortOrder` from a monotonic counter)
  before adding racer reordering, which makes it live at any size.
- **Auto-import (§9.6, `tasks.md` Task 3) is still blocked** — `media/` is empty.
  Additionally: the Clubspeed export `kart_sorter.py` reads is *kart-level only*
  (Kart No, heats, laps, avg/best lap, no racer names), so it cannot feed racer
  finish positions. A different export is required than the one the existing tool
  consumes.
