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

  ### If the window stays open
  It only stays open when there's something to read:
  - **"No .xls export found in Downloads" / "No kart data found."** — the export isn't in your Downloads folder, or the newest `.xls` there isn't a kart export. Re-download it and run again.
  - **"Could not print"** — the results file was still saved to your Downloads folder as `Kart_Results_<date>.txt`; you can open and print it manually.

  ## Cincinnati location
  `kartTimeCinci\dist\kartTimeCinci.exe` is the same program built for the Cincinnati kart fleet, which uses different kart number ranges. Use that one at Cincinnati and this one at Full Throttle — they save to differently-named files, so running both on the same day is fine.

  ## Documentation
  [wiki.md](wiki.md) is the source of truth for how this repo works (code, file structure, build process, known issues). Whenever anything in this repo changes — code, files, structure, or workflow — update wiki.md in the same change so it stays current.
