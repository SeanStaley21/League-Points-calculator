# league_points_app — Upgrade plan (Newfeatures1)

Written 2026-07-15. Companion to [`tasks.md`](tasks.md) (which tracks the original
2026-07-09 request list) and [`wiki.md`](wiki.md) (source of truth for what exists).

Format: a **ranked roadmap** of items specced enough to implement, then a
**backlog** of everything else worth doing someday.

---

## Context

The app has replaced most of `league template.xlsx`'s data entry — divisions,
racers, weekly finishes, weights, kart assignment, and contacts all live in the
`.lpts` season file now (wiki §9.1–§9.13). But it has **no way to get data back
out**. Every consumer of this data today is still analogue: results get posted for
racers to read, and the legacy `kart_sorter.exe` still prints a fixed-width `.txt`
to the default Windows printer. The app can't print, export, or email anything —
the only two file outputs (`writeSeason`, `writeKartRoster`) are machine formats
for reloading the app's own state.

Two consequences shape this plan:

1. **The xlsx workflow can't actually be retired until the app can print.** That
   makes reporting the headline item, not a nice-to-have.
2. **The season file is the only copy of a season's data, and it's fragile.**
   Closing the window discards unsaved work silently, and a corrupt file throws an
   unhandled exception. Reporting makes the data more valuable, which makes losing
   it worse — so data safety is sequenced alongside it.

Priorities confirmed with the user: print/export reports (with selectable scope,
layout, and an email path), data safety, and leaderboard/reporting views. Android
is a real target, so this plan builds the seams for it now and scaffolds later.

---

## Ranked roadmap

### 1. Reports: print, export, and email

The headline feature. The operator picks **what** to output and **how it's laid
out**, previews it, then prints / saves / emails it.

**Scope selection** is two independent axes, which yields the four required
combinations naturally by treating `null` as "all":

| | One division | All divisions |
|---|---|---|
| **One week** | Pro 1, Week 3 | Every division, Week 3 |
| **All weeks** | Pro 1, full season | Everything |

**Architecture — a pure report layer, then dumb renderers.** This is the core
decision. A pure module turns `(Season, scope, layout, columns)` into an abstract
`ReportDocument`; each renderer just draws it. Scope and layout logic is then
unit-testable without a printer, a PDF, or a Flutter binding — mirroring how
`lib/data/points_calculator.dart` is already pure and heavily tested.

New `lib/reports/` (its own layer, deliberately quarantined so `package:pdf` never
leaks into the pure code):

- `report_model.dart` — `ReportScope {weekNumber?, divisionIndex?}`, `ReportKind`
  (standings / weeklyResults / kartPickOrder / contacts), `ReportLayout`
  (racersAsRows | weeksAsRows — the "vertical vs horizontal" ask),
  `ReportOrientation`, `ReportColumn`, and `ReportTable` / `ReportDocument`.
  Rows are **pre-formatted strings plus an alignment vector**, so the fixed-width
  text renderer and the PDF renderer share one source of truth for column widths.
- `report_builder.dart` — the scope/layout logic:

  ```dart
  ReportDocument buildReport({required Season season, required ReportKind kind,
      required ReportScope scope, required ReportLayout layout,
      required List<ReportColumn> columns, DateTime? generatedAt});

  // exposed for direct unit testing rather than only through buildReport
  List<Division> resolveDivisions(Season season, ReportScope scope);
  List<int> resolveWeeks(Season season, ReportScope scope);
  ```

  `generatedAt` is injectable so tests are deterministic.
  **Reuses `rankByTotalPoints` / `computeTotal` / `pointsForResult`** — no scoring
  is reimplemented.

  Also here, and more load-bearing than it looks:

  ```dart
  /// "Pro 1 — Week 3" | "All divisions — Week 3" | "Pro 1 — All weeks"
  String describeScope(Season season, ReportScope scope);
  /// Filesystem-sanitized: "Summer 2026 - Pro 1 - Week 3.pdf"
  String reportFileName(Season season, ReportScope scope, String ext);
  ```

  The email subject, the email body, the PDF filename, and the report's own on-page
  subtitle **all derive from these two functions**, so they cannot drift apart. Both
  are pure and trivially unit-testable. Don't hand-roll scope strings or filenames at
  the call sites.
- `text_report_renderer.dart` — fixed-width plain-text export, in the *style* of
  `kart_sorter.py`'s `{'Rank':<8} {'Kart No':<12}` output. It is *not* the email body
  (see the email section), and **not** a byte-for-byte replacement for the legacy
  printout: that report is a **kart lap-time** table (`kart_sorter.py:67`), and no
  `ReportKind` here carries lap times — `bestLapTimeMs`/`averageLapTimeMs` exist on
  `WeeklyResult` but nothing writes them (see backlog). True parity needs a lap-times
  report kind *and* the auto-import that feeds it; both are out of scope for item 1.
- `csv_report_renderer.dart` — hand-rolled RFC 4180 quoting (~15 lines; not worth a
  dependency, and it belongs in the tested pure layer). Emits **CRLF + UTF-8 BOM**
  or Excel mangles non-ASCII names. Flattens to one table with a `Division` column
  — multi-table CSV is hostile to Excel.
- `pdf_report_renderer.dart` — the **only** file importing `package:pdf`. Uses
  `pw.TableHelper.fromTextArray` (`Table.fromTextArray` is deprecated in pdf 3.x).
  Orientation via `PdfPageFormat.letter.landscape` / `.portrait`.

**Packages** (verified against plugin source, not just the README):

- `printing: ^5.15.0` + `pdf: ^3.13.0`. Windows support is genuine: `listPrinters()`
  flags the system default via `GetDefaultPrinter()`, so `directPrintPdf` reproduces
  the legacy **print-to-default-printer-without-a-dialog mechanism**
  (`os.startfile(f, "print")`, `kart_sorter.py:78`) — the mechanism, not the report
  itself, which is a different document (see `text_report_renderer.dart` above);
  `layoutPdf` with no printer name opens the native Windows print dialog;
  `canRaster: true` makes in-app `PdfPreview` work.
- `url_launcher: ^6.3.1` for mailto.

**Email — "Share / Email" (decided 2026-07-15).** The app never sends mail itself and
never stores a password. It produces the PDF and hands off to whatever the OS
already has. Two platform-shaped flows behind one seam
(`lib/data/export_service.dart`):

```dart
abstract class ExportService {
  Future<void> deliver(Uint8List bytes, String filename);   // Export PDF / CSV
  Future<void> emailReport(Uint8List pdf, String filename,
                           String subject, String body);    // Share / Email
}
// WindowsExportService: save + explorer /select + mailto
// AndroidExportService: Printing.sharePdf(...)
```

The Windows/Android split is chosen **by platform, not by
`Printing.info().canShare`** — Windows reports `canShare: true`, but its share path
merely `ShellExecute`s the PDF open, so capability-gating would silently pick the
wrong flow. This is a deliberate exception to the runtime-capability rule used for
`canListPrinters` (item 4); stated so it isn't "corrected" later.

- **Windows:** render the PDF → save it to a predictable reports folder (no save
  dialog — fewer clicks) → **reveal it in Explorer** with the file preselected
  (`explorer.exe /select,"<path>"` via `Process.run`; no package needed) → open the
  default mail app with a prefilled subject and short body via `mailto:`. The race
  director **drags the revealed PDF into the draft**. That drag is the one manual
  step, and it's deliberate: see "Why not auto-attach" below.
- **Android:** `Printing.sharePdf(bytes:, filename:, subject:, body:)` → the system
  share sheet, **with the PDF already attached**. Pick Gmail, hit send. One tap, no
  drag, no folder. Mobile is genuinely the better experience here.

**Why the sender is not configurable.** An earlier draft of this plan had a
`Season.raceDirectorEmail` used as the sender. **Dropped** — `mailto:` has no `from`
parameter, and a handed-off draft always sends as whatever account the mail client is
signed into. On the race director's own PC that already *is* them, so the field bought
nothing. Forcing a specific sender requires the app to send the mail itself over SMTP,
which means storing an app password — explicitly rejected. No season model change, and
`mailer` / `flutter_secure_storage` are **not** dependencies.

**Why not auto-attach.** Worth recording so it isn't re-litigated:

- `mailto:` **cannot attach a file.** RFC 6068 defines only `to`/`cc`/`bcc`/`subject`/
  `body`, and §5 requires clients to *ignore* MIME headers in the URI. Clients that
  once honored `&attach=` removed it as a security hole.
- The **`.eml` + `X-Unsent: 1` draft trick** does attach, but is
  [unreliable in New Outlook](https://learn.microsoft.com/en-us/answers/questions/2242426/new-outlook-opening-eml-file-with-x-unsent-1-remov)
  — reports of the body arriving with the **attachment silently missing** — and
  Thunderbird never implemented it ([Mozilla bug 166541](https://bugzilla.mozilla.org/show_bug.cgi?id=166541), still open).
  A silently-dropped attachment is worse than an honest drag.
- **Win32 MAPI** (`MAPISendMail`, the old "Send to → Mail recipient") attaches
  properly, but needs a MAPI-registered client — classic Outlook or Thunderbird, *not*
  New Outlook — plus hand-written `dart:ffi`. Not worth it for one drag.
- `Printing.sharePdf()` does **not** rescue Windows: its `emails`/`subject`/`body`
  params are iOS/Android-only, and on Windows it just `ShellExecute`s the PDF open
  (launches Acrobat/Edge, not a mail client). It is the Android path only.

**Message text** — a short note, not the report. Per the user: *"here is the standings
for X"*, where X is the division name or "all divisions". Built from `describeScope` /
`reportFileName` (defined in `report_builder.dart` above) so subject, body, filename,
and the report's own on-page subtitle can never disagree:

- Subject: `Summer 2026 — Pro 1 — Week 3 standings`
- Body: `Here is the standings for Pro 1 — Week 3 of Summer 2026.` (attached as PDF.)
- Filename: `Summer 2026 - Pro 1 - Week 3.pdf` (filesystem-sanitized)

**Optional — recipients from Contacts.** `mailto:` prefills `to=` for free, so a
multi-select picker reusing `ContactsScreen`'s existing search/filter could prefill
recipients from `Racer.email` across the selected scope. **Not currently scoped** —
the flow above assumes the race director types the recipient. If added: use **BCC**
for multiple racers so their addresses aren't exposed to each other, skip racers with
no email, and mind that Windows `ShellExecute` caps `mailto:` URIs near **~2000 chars**
and truncates silently.

**Caveat to verify:** `mailto:` only works if a default mail client is **registered**.
A race director who lives in Gmail-in-a-browser has no mailto handler unless they've
set Chrome as one — in which case the button appears to do nothing. Detect via
`canLaunchUrl` and fall back to "PDF saved — folder opened", which is still a complete
outcome on its own.

**UI** — `lib/screens/reports_screen.dart`, a split pane: options left, live
`PdfPreview` right, so the operator confirms before burning paper. Reachable two
ways: a 5th **Reports** item in `AppSidebar` (discoverable nav) and **File >
Print / Export…** in `AppMenuBar` (matches the Word-style document model the app
already follows). Options: kind · week (`All` + 1..N) · division (`All` + each) ·
layout · orientation · columns (`FilterChip` wrap) → `[Print…] [Export PDF]
[Export CSV] [Share / Email]` — the last is labelled for sharing because the Android
path is a share sheet, not a mail client.

**Where the PDF lands** — two deliberately different behaviors, so this is a decision
rather than an accident:

- **Export PDF / CSV** → save dialog; the operator chooses the path.
- **Share / Email** → **no dialog** (fewer clicks, per the user). Auto-saves to a
  predictable reports folder using `reportFileName(...)`, then reveals it.
- *Open:* exact folder — suggest `Documents\League Points\Reports\` — and whether
  repeat exports of the same scope overwrite or accumulate.

**Also changed:** `pubspec.yaml`; `lib/utils/constants.dart` (new extensions);
`lib/data/file_service.dart` (add `writeBytes`/`writeText` + PDF/CSV pickers —
note `pickSavePath` and `pickKartRosterSavePath` are already near-duplicates, so
extract a shared `_pickSavePath` rather than paste a fourth); new
`lib/data/print_service.dart` (wraps `Printing.*`) and `lib/data/export_service.dart`
(the `deliver` / `emailReport` seam above) — both behind seams, mirroring the existing
unused `FileService?` injection point so exports are testable with fakes;
`lib/data/pick_order.dart` extracting the pick-order sort currently inlined at
`kart_pick_order_screen.dart:152` so the screen and the report can't drift.

**Phasing** — keeps native/build risk out of the repo until the logic is proven:

1. Model + builder + CSV/text renderers + unit tests. **Zero new deps.**
2. Add deps, PDF renderer, FileService paths, ReportsScreen, print/export.
3. Email.
4. Android seam (see item 4).

**Risks:**

- **pdfium downloads at CMake configure time** from `pdfium-binaries` releases. The
  first Windows build after adding `printing` **needs network** and will be slow; an
  offline machine fails to build. Biggest new-dependency risk.
- **`dist/LeaguePointsApp.exe` grows** by several MB (`pdfium.dll`). It still works and
  is still a genuine single file: per wiki §9.12 the launcher embeds a zip of the whole
  `Release/` folder as a resource and extracts it at runtime, so a new DLL just rides
  along inside — the artifact only gets bigger (~12 MB today).
- `PdfPreview` caches; swapping the build closure may not retrigger generation. Give
  it `key: ValueKey(options)` with `==`/`hashCode` on the options class.
- `Uri(queryParameters:)` encodes spaces as `+`, which some clients render literally.
  Build the query with `Uri.encodeComponent`.

### 2. Data safety

Ranked second only because item 1 is the reason the app exists — but these are
small, and **2a is a genuine data-loss bug**.

- **2a. No unsaved-changes guard on app exit.** `confirmDiscardUnsavedChanges`
  exists and is wired to New and Open (`app_menu_bar.dart:23,30`); its own doc
  comment at `confirm_dialog.dart:35` claims it covers "(New/Open/**Exit**)", but
  **no exit hook exists** — no `PopScope`, no window-close listener. Closing the
  window silently discards the season. Fix: `PopScope` at the app root; on Windows
  the window close button needs a handler (`WindowManager`-style) to be intercepted
  at all.
- **2b. File I/O has zero error handling.** `file_service.dart` contains no
  `try`/`catch`. A missing file, malformed JSON, or a wrong-shaped `'season'` key
  throws an uncaught exception straight through `openFromPicker` into the menu
  handler. The kart-roster paths already do this correctly (SnackBar on failure,
  `kart_pool_dialog.dart:45-50`) — apply the same treatment.
- **2c. `formatVersion` is written but never read.** `writeSeason` writes it
  (`file_service.dart:48`); `readSeason` (`:41-43`) reaches straight for
  `decoded['season']` and ignores it. The version field is currently decorative.
  Read it, reject a future version with a clear message, and leave a migration hook.
- **2d. Writes aren't atomic.** `writeSeason:52` writes directly over the target —
  a crash or full disk mid-write corrupts the only copy. Write to a temp file and
  rename.
- **2e. Index/`sortOrder` trap — wrong-racer data writes.**
  `division_screen.dart:114` sorts a *copy* of the racers, then passes that **sorted**
  index as `racerIndex` into `updateWeeklyFinishPosition` (`:185`), `updateRacerInfo`
  (`:207`), and `removeRacer` (`:228`) — but `SeasonDocument` addresses racers by their
  index in the **stored** list. The other two screens document and avoid this exact
  trap (`weekly_standings_section.dart:111-116`, `kart_pick_order_screen.dart:143-151`);
  Division screen is the outlier.
  Compounding it: `addRacer` sets `sortOrder = racers.length` (`season_document.dart:167`)
  while `removeRacer` just `removeAt`s (`:184`), so remove-then-add produces
  **duplicate** `sortOrder` values (add A,B,C → remove B → add D gives 0,2,2).

  **Why it doesn't fire today** — the reasoning matters, because the obvious version of
  it is wrong. It is *not* that `sortOrder` always tracks insertion order (the
  duplicates above prove it doesn't). It's that `sortOrder` is always **non-decreasing
  in storage order** — `addRacer` only ever appends `racers.length`, `removeRacer` only
  removes — so a **stable** sort by `sortOrder` is the identity, and the sorted copy
  matches storage. That holds only while the sort is stable: Dart's `List.sort` uses
  insertion sort below an internal **32-element** threshold and dual-pivot quicksort
  above it, and the API contract doesn't promise stability either way. So with **32+
  racers in one division** the duplicates can reorder the copy and the writes above hit
  the wrong racer **today** — no reordering feature required. Real divisions run ~13
  racers (`scoredPositions` = 13), so it stays latent in practice.
  It also goes live at *any* size the moment something reorders racers — itself a wanted
  feature (backlog), which is why that item depends on this one.

  Fix both halves: carry the original index like the other screens do, **and** assign
  `sortOrder` from a monotonic counter rather than `length`.
- **2f. Lowering `weekCount` silently destroys data.** `_resizeWeeklyResults`
  (`season_document.dart:117-124`) rebuilds to exactly `weekCount` entries, dropping
  results for removed weeks with no confirmation. Warn when the discarded weeks
  contain recorded results.

### 3. Season leaderboard and reporting views

The xlsx has a `Leaderboards` sheet; the app's only season-wide aggregate is
`Division.leader()` — a single name on a card. There is no ranked list anywhere,
and no way to see one racer's season.

- **3a. Division standings view** — the ranked table `StandingsSnapshotCard` only
  hints at: rank, racer, per-week points, total, points back from the leader. Pairs
  directly with the `standings` `ReportKind` from item 1 (same builder, two
  renderers: screen and paper).
- **3b. Cross-division / season leaderboard** — every racer ranked, grouped or flat.
  Needs a season-level ranking function. Note the baseline is lower than it looks:
  **nothing in `lib/` ranks anything today** — `rankByTotalPoints` has no callers
  outside its own test, and the only in-app aggregate is `Division.leader()`
  (`standings_snapshot_card.dart:20`), which surfaces a single name.
- **3c. Racer season detail** — no such screen exists. Week-by-week finishes,
  points, kart, weight, total, **and which week got dropped** (see the open question
  below — the drop rule is invisible in the UI today).

**Decide before printing anything official** (both surfaced by item 1):

- **Ties have no defined order.** `rankByTotalPoints` has no tie-break, so tied racers
  fall wherever the sort leaves them — and a Rank column would assign them arbitrary
  *distinct* ranks (…, 4, 5, …) rather than the equal ranks the tie deserves. That's
  the real defect and it's invisible on screen today (nothing in `lib/` ranks at all —
  see 3b), but it's on paper handed to racers.
  Two things this is **not**, so nobody chases them: Dart's sort is *deterministic* for
  a given input, so the same file printed twice gives the same order (non-stable ≠
  non-deterministic — the exposure is that order depends on stored racer order and
  could shift across SDK versions); and `Division.leader()` **agrees** with
  `rankByTotalPoints` — its `reduce` keeps the accumulator on `>=`
  (`division.dart:23-24`), so like the sort it yields the *first* max, not the last.
  Suggest a name tie-break + standard competition ranking (1, 2, 2, 4) — but **this is
  a league-rules call.**
- **Drop-lowest is a silent no-op until the season is complete.** `computeTotal`
  (`points_calculator.dart:27-34`) drops the single lowest entry of the list it's
  given, and a racer's `weeklyResults` **always holds `weekCount` entries** (generated
  up front by `addRacer`, `season_document.dart:172-175`; length maintained by
  `_resizeWeeklyResults`). So mid-season there is always an unraced 0-week to discard:
  week 1 = P1 with weeks 2–8 blank scores `[14,0,0,0,0,0,0,0]` → drops a 0 → **total
  14**, a plain sum. The rule only starts costing anyone points once every week is
  filled, at which point totals quietly stop being sums.
  (Not to be confused with `points_calculator_test.dart:36-41`, "only one week … leaving
  0" — that's a results list of *length 1*, i.e. `weekCount == 1`, not one week
  recorded out of eight.)
  Consequence for reports: a "Total" column means different things in week 3 and week 8.
  Suggest week-scoped reports show that week's points *and* season-to-date, with a
  footnote stating the rule and whether it's active yet.

### 4. Android readiness

Only `windows/` is scaffolded. The pure `lib/reports/` layer is **100% portable** —
that's the main argument for the split. Every problem is at the edges, so build the
seams during item 1 even though scaffolding comes later:

- **Android's Share / Email flow is strictly better than Windows'** and is the
  *primary* path there, not a fallback: `Printing.sharePdf()` is a real share sheet
  that **honors `emails`/`subject`/`body` and carries the attachment**. One tap, PDF
  already attached — no save folder, no drag. This is the payoff for putting the
  delivery seam in now.
- **`file_selector`'s `getSaveLocation` is not implemented on Android** — the whole
  export-to-path flow breaks. This is why `ExportService.deliver(bytes, filename)`
  exists: Windows → save dialog; Android → share sheet / SAF.
- **No `listPrinters` / no default-printer concept on Android** — the legacy-parity
  direct-print path can't work. Gate it on `Printing.info().canListPrinters` **at
  runtime**, not `Platform.isWindows`. `layoutPdf` works fine. (Contrast with the
  share path in item 1, which is gated by platform *on purpose* — `canShare` is true
  on Windows but means something different there.)
- `mailto` needs a `<queries>` entry in `AndroidManifest.xml` for API 30+ package
  visibility, or `canLaunchUrl` returns false. Only relevant if a mailto fallback is
  kept on Android — if `sharePdf` covers it, Android may not need `mailto` at all.
- Keep **all** IO behind `FileService` — no raw `File(path)` for user-visible dirs.
- **Layout:** the side-by-side per-division columns (`WeeklyStandingsSection`,
  `KartPickOrderScreen`) and the one-column-per-week `DataTable` won't fit a phone.
  Needs a responsive story, not just a scaffold.

---

## Backlog

Roughly ordered by value.

- **Undo/redo.** No history stack; every mutation replaces state via `_setSeason`.
  The immutable-model + `copyWith` design makes a snapshot stack cheap to add.
- **Auto-import from Clubspeed** — *still blocked*: `media/` is empty, so the export
  format is unknown. Note the export `kart_sorter.py` reads is **kart-level only**
  (Kart No, heats, laps, avg/best lap) with **no racer names**, so it can't feed
  finish positions — a *different* export is needed. `Racer.importName` and
  `WeeklyResult.startPosition`/`bestLapTimeMs`/`averageLapTimeMs` are already built
  and serialized for this, but nothing reads or writes them.
- **Recent files / reopen last season.** `newSeason()` starts blank every launch.
- **Autosave / `.bak` backup.** Depends on 2d.
- **Racer/division reordering**, and moving a racer between divisions. `sortOrder`
  exists and is read but is never rewritten. **Do 2e first** or this ships a bug.
- **Keyboard shortcuts.** Zero exist — no Ctrl+S/O/N, no accelerator labels.
- **`AppMenuBar` only mounts on Home**, despite its doc comment claiming "every
  screen" — so File/Save is unreachable from every sub-screen.
- **Range validation on inline cells.** You can type finish position `99` into a
  6-racer division; `scored_positions` overflow is only a helper-text warning
  (`season_setup_screen.dart:135-138`).
- **Base weight doesn't propagate.** `updateRacerInfo` doesn't push a changed
  `Racer.weight` into existing weeks, so editing weight in the Division dialog has
  no effect on kart pick order. Intentional per wiki §9.3 — but it surprises people.
- **`removeKart` has no confirmation** (`kart_pool_dialog.dart:133`), unlike racer
  and division removal.
- **Week/season model gaps:** no per-week date; blank finish means both "didn't
  race" and "not entered yet"; no DNF/absent distinction — which the drop-lowest
  rule can't currently tell apart.
- **`Season.endDate` can never be cleared** once set (`copyWith` has no `clear` flag,
  unlike `WeeklyResult`'s). Same for `startPosition`/lap times.
- **`defaultDivisionNames`** (`constants.dart:6`) is declared and unused.
- **Test gaps:** no `FileService` test at all (and its injection seam is never used);
  `save`/`saveAs`/`openFromPicker`/`newSeason` and all dirty-state transitions
  untested; `ThemeController`, `contacts_screen`, `division_screen`,
  `season_setup_screen`, `home_screen` uncovered.
- **Layout fragility:** unscrollable 6-`TextField` `Column` in the racer `AlertDialog`
  (vertical overflow on short windows); `ListTile.trailing` with a dropdown + 2 icon
  buttons in `season_setup_screen.dart:164-190`; no overflow handling on long
  division/racer names; wide `DataTable` with no frozen name column.
- **Perf:** `computeTotal` recomputes from scratch inside sort comparators, so it
  runs O(n log n) times per rank with no memoization. Irrelevant at league scale;
  noted only so it isn't rediscovered as a mystery.

---

## Verification

Baseline today: **30 tests pass** (`flutter test`), `flutter analyze` clean.

**Unit** (the bulk — pure, no Flutter binding, mirroring `points_calculator_test.dart`):

- `report_builder_test.dart` — all **4 scope combinations**; `resolveDivisions` /
  `resolveWeeks`; empty division / empty season / week out of range; column
  subsetting; both layouts; injected `generatedAt`; drop-lowest interaction; tie
  ordering once the rule is decided. Plus `describeScope` / `reportFileName` for all
  4 combinations, including a division name containing a character illegal in a
  Windows filename (`/`, `:`, `?`) — sanitization must not produce a broken save.
- `csv_report_renderer_test.dart` — quoting against a hostile name (`O'Brien, Jr.`),
  embedded newline, CRLF, BOM, empty table.
- `text_report_renderer_test.dart` — column widths / alignment / padding of the
  fixed-width output (in the style of `kart_sorter.py`, not byte-parity with it).
- `file_service_test.dart` (item 2) — round-trip, malformed JSON, missing file,
  missing `'season'` key, `formatVersion` read-back, atomic-write survival.
- `season_document_test.dart` — add cases for `_resizeWeeklyResults` truncation and
  `sortOrder` assignment after remove-then-add (2e/2f).

**Widget:**

- `report_options_panel_test.dart` — extract the options panel with an
  `onChanged(ReportOptions)` callback and test it in isolation. **Do not put
  `PdfPreview` in a widget test:** `Printing.*` goes over a MethodChannel and throws
  `MissingPluginException` under `flutter test`, and it needs pdfium. That's what the
  `PrintService` seam is for — export-action tests use a fake.
- `division_screen_test.dart` (**item 2e — don't skip this one**). The unit tests above
  only cover the `sortOrder` *counter* fix; the wrong-racer-write half has no coverage
  at all, and that's the data-corrupting half. Drive it through the widget: add racers,
  remove one, add another (producing duplicate `sortOrder`), then edit a finish position
  and remove a racer via the Division screen and assert the change landed on the
  *intended* racer in the underlying `SeasonDocument`. `weekly_standings_section_test.dart`
  already demonstrates the write-through assertion pattern to copy.

**Manual** (can't be automated — do these before calling item 1 done):

1. `flutter run -d windows`, open a season with ≥2 divisions and several weeks.
2. Each of the 4 scope combinations → preview renders, matches the on-screen data.
3. Portrait vs landscape; both layouts; column subsetting.
4. **Print to a real printer** — dialog appears, paper size/margins sane, page breaks
   correct with many racers, landscape columns fit. Try `windowsModernDialog` both
   ways (PrintDlgEx vs classic on Win11 is untested).
5. Direct-print to the default printer with **no dialog**, matching how
   `kart_sorter.exe` prints (the mechanism — the legacy lap-time *report* itself is a
   different document this feature doesn't reproduce).
6. Export PDF and CSV → reopen; **open the CSV in Excel** and confirm a name with a
   comma and a non-ASCII character survive.
7. **Share / Email on Windows** → PDF saved, Explorer opens with the file
   **preselected**, default mail app opens with subject/body prefilled, and the PDF
   drags into the draft and sends.
8. **No mail client registered** (e.g. a Gmail-in-a-browser machine) → `canLaunchUrl`
   returns false → app still reports "PDF saved — folder opened" rather than appearing
   to do nothing.
9. `describeScope` / `reportFileName` agree across the subject, body, filename, and
   the report's on-page subtitle for all 4 scope combinations.
10. Edit → close the window → **confirm the save prompt appears** (2a).
11. Corrupt a `.lpts` by hand → confirm a friendly error, not a crash (2b).
12. Rebuild the packaged exe per wiki §9.12 (`Launcher.cs`) and confirm it still
    launches with `pdfium.dll` bundled.
13. Android (once scaffolded): share sheet opens with the **PDF attached** and
    subject/body prefilled.

Per repo convention (README + `wiki.md`), any change here updates **`wiki.md` in the
same commit** (§9.14 records this roadmap itself, so the next free section is **§9.15**)
and ticks the item off in `tasks.md`.
