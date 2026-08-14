# Python Program
*Created with help from copilot both microsoft and github*

  ## Pre requisites before running the program
  1) The program requires to get the user to save the excel file of the kart times from clubspeed
  2) save the file to your downloads folder — you do **not** need to rename it. The program automatically picks up the most recently downloaded `.xls` file.

  ## Actual program
  you just run the .exe file that is in the dist folder (League-Points-calculator\Kart time program\dist)
  the program sorts the kart data into groups of Pros, Juniors, and Intermediates (by kart number)
  it then organizes the fastest 'best lap' times towards the top and slowest to the bottom of the list within each group
  saves the results to a .txt file in your downloads folder and automatically sends it to your default printer
  once it prints, the window closes on its own — nothing to press

  ### If there's no printer
  Before printing, the program checks whether your default printer can actually put ink on paper. If it can't, **it prints the results into the window instead** so you can read them right off the screen. This happens when:
  - your default printer is a "save to a file" one like **Microsoft Print to PDF**, XPS, OneNote, or Fax — you'd otherwise just get a Save As dialog
  - the printer is **offline, paused, or unplugged**
  - there's **no default printer** set up at all

  The `.txt` file is still saved to your Downloads folder as `Kart_Results_<date>.txt` in every case, so you can always open and print it by hand later. If you wanted a real printout, set a working printer as your Windows default and run it again.

  ### If the window stays open
  It only stays open when there's something to read:
  - **the results themselves** — see above; press Enter when you're done reading.
  - **"No .xls export found in Downloads" / "No kart data found."** — the export isn't in your Downloads folder, or the newest `.xls` there isn't a kart export. Re-download it and run again.
  - **"Could not print"** — the print couldn't be sent. The results are shown in the window and saved to Downloads.

  ## Cincinnati location
  `kartTimeCinci\dist\kartTimeCinci.exe` is the same program built for the Cincinnati kart fleet, which uses different kart number ranges. Use that one at Cincinnati and this one at Full Throttle — they save to differently-named files, so running both on the same day is fine.

  Note: the no-printer fallback described above is **only in the Full Throttle program** right now. The Cincinnati one still just tries to print. It can be added there too if it's wanted.

  ## Documentation
  [wiki.md](wiki.md) is the source of truth for how this repo works (code, file structure, build process, known issues). Whenever anything in this repo changes — code, files, structure, or workflow — update wiki.md in the same change so it stays current.

  ## Contributing
  **All work is done in a git worktree on its own branch, then merged onto `main`.** Don't work directly in the primary checkout. `main` is the trunk and gets pushed to directly — there's no PR gate.

  ```
  git worktree add ../lpc-<task-slug> -b claude/<task-slug>
  # work + commit in the worktree, then merge onto main and push
  git worktree remove ../lpc-<task-slug>
  ```

  See [wiki.md §0](wiki.md) for the full rationale and [workInstructions.md](workInstructions.md) for the rules on running several Claude Code sessions in parallel.
