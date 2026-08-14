import os
import glob
import math
import ctypes
from ctypes import wintypes
import pandas as pd
from datetime import datetime

# --- Windows printer inspection -------------------------------------------
# Used to decide, before printing, whether the default printer can actually put
# ink on paper. If it can't (no printer, a print-to-PDF/XPS style virtual
# printer, or an offline one), main() shows the report in the terminal instead
# of firing os.startfile and closing the window on a print that never happens.
#
# This talks to winspool.drv through ctypes rather than pywin32 on purpose:
# ctypes is stdlib, so it adds no dependency, no PyInstaller hidden imports, and
# no size to the shipped .exe.

PRINTER_ATTRIBUTE_WORK_OFFLINE = 0x400
PRINTER_STATUS_PAUSED = 0x001
PRINTER_STATUS_ERROR = 0x002
PRINTER_STATUS_OFFLINE = 0x080
PRINTER_STATUS_NOT_AVAILABLE = 0x1000
PRINTER_STATUS_UNUSABLE = (
    PRINTER_STATUS_PAUSED
    | PRINTER_STATUS_ERROR
    | PRINTER_STATUS_OFFLINE
    | PRINTER_STATUS_NOT_AVAILABLE
)

PRINTER_ENUM_LOCAL = 0x02
PRINTER_ENUM_CONNECTIONS = 0x04

# Ports that mean "this printer writes a file, it does not produce paper."
VIRTUAL_PRINTER_PORTS = {"portprompt:", "nul:", "nul", "file:", "xpsport:", "shrfax:"}

# Name fallback, for third-party virtual printers sitting on ordinary-looking
# ports (CutePDF, Foxit, PDF24, Bullzip, Adobe PDF...).
VIRTUAL_PRINTER_NAME_HINTS = (
    "pdf", "xps", "onenote", "fax", "print to file", "document writer",
)


class PRINTER_INFO_2(ctypes.Structure):
    """Win32 PRINTER_INFO_2. Only pPrinterName/pPortName/Attributes/Status are
    read, but every field has to be declared, in order, or the offsets shift and
    the interesting ones come back as garbage.
    """
    _fields_ = [
        ("pServerName", wintypes.LPWSTR),
        ("pPrinterName", wintypes.LPWSTR),
        ("pShareName", wintypes.LPWSTR),
        ("pPortName", wintypes.LPWSTR),
        ("pDriverName", wintypes.LPWSTR),
        ("pComment", wintypes.LPWSTR),
        ("pLocation", wintypes.LPWSTR),
        ("pDevMode", ctypes.c_void_p),
        ("pSepFile", wintypes.LPWSTR),
        ("pPrintProcessor", wintypes.LPWSTR),
        ("pDatatype", wintypes.LPWSTR),
        ("pParameters", wintypes.LPWSTR),
        ("pSecurityDescriptor", ctypes.c_void_p),
        ("Attributes", wintypes.DWORD),
        ("Priority", wintypes.DWORD),
        ("DefaultPriority", wintypes.DWORD),
        ("StartTime", wintypes.DWORD),
        ("UntilTime", wintypes.DWORD),
        ("Status", wintypes.DWORD),
        ("cJobs", wintypes.DWORD),
        ("AveragePPM", wintypes.DWORD),
    ]


def get_default_printer():
    """Return the default printer's name, or None if there isn't one."""
    winspool = ctypes.WinDLL("winspool.drv")
    size = wintypes.DWORD(512)
    buf = ctypes.create_unicode_buffer(size.value)
    if not winspool.GetDefaultPrinterW(buf, ctypes.byref(size)):
        return None
    return buf.value or None


def list_printers():
    """Return [(name, port, attributes, status)] for every installed printer.

    EnumPrintersW is called twice, as the API requires: once with a null buffer
    to learn the size, then again to actually fill it.
    """
    winspool = ctypes.WinDLL("winspool.drv")
    flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS
    needed = wintypes.DWORD()
    returned = wintypes.DWORD()

    winspool.EnumPrintersW(
        flags, None, 2, None, 0, ctypes.byref(needed), ctypes.byref(returned)
    )
    if not needed.value:
        return []

    buf = ctypes.create_string_buffer(needed.value)
    if not winspool.EnumPrintersW(
        flags, None, 2, buf, needed.value, ctypes.byref(needed), ctypes.byref(returned)
    ):
        return []

    printers = ctypes.cast(buf, ctypes.POINTER(PRINTER_INFO_2))
    return [
        (
            printers[i].pPrinterName,
            printers[i].pPortName,
            printers[i].Attributes,
            printers[i].Status,
        )
        for i in range(returned.value)
    ]


def is_virtual_printer(name, port):
    """True if this printer saves to a file rather than printing on paper."""
    if (port or "").strip().lower() in VIRTUAL_PRINTER_PORTS:
        return True
    lowered = (name or "").lower()
    return any(hint in lowered for hint in VIRTUAL_PRINTER_NAME_HINTS)


def default_printer_status():
    """Decide whether printing is worth attempting.

    Returns (can_print, reason). 'reason' is an operator-facing sentence when
    can_print is False, and empty otherwise.

    Fails open: any unexpected error inspecting the print system returns
    (True, "") so the tool behaves exactly as it did before this check existed.
    Refusing to print because detection broke would be worse than the problem
    this solves -- and if the print then fails to dispatch, main() still falls
    back to the terminal anyway.
    """
    try:
        name = get_default_printer()
        if not name:
            return False, "No default printer is set up on this computer."

        for printer_name, port, attributes, status in list_printers():
            if printer_name != name:
                continue
            if is_virtual_printer(printer_name, port):
                return False, (
                    f'The default printer ("{name}") saves to a file '
                    "instead of printing on paper."
                )
            if attributes & PRINTER_ATTRIBUTE_WORK_OFFLINE or status & PRINTER_STATUS_UNUSABLE:
                return False, f'The default printer ("{name}") is offline or unavailable.'
            return True, ""

        # Default printer isn't in the enumeration -- unusual, but not a reason
        # to second-guess it. Let the print attempt happen.
        return True, ""
    except Exception:
        return True, ""


def get_kart_class(kart_no):
    """Classify a kart number into a Full Throttle-fleet division by numeric range.

    Full Throttle fleet:
        Pro          11-28
        Junior       70-78
        Intermediate 95-98
        else         Other  (anything outside the above, or non-numeric)

    These ranges are deliberately different from the Cincinnati fleet's -- see
    kartTimeCinci/kartTimeCinci.py for that build. Do not merge the two.

    The number goes through parse_number rather than a bare int(): pandas hands
    back "12.0" for a Kart No column it typed as numeric, and int("12.0") raises
    ValueError. That used to mean every kart in such an export fell through to
    "Other" and the whole report collapsed into one section.
    """
    num = parse_number(kart_no)
    if num is None:
        return "Other"
    num = int(num)
    if 11 <= num <= 28:
        return "Pro"
    elif 70 <= num <= 78:
        return "Junior"
    elif 95 <= num <= 98:
        return "Intermediate"
    else:
        return "Other"

def parse_number(value):
    """Parse a numeric cell from the export, or None if it isn't a usable number.

    Values above 999 arrive thousands-separated and quoted ("1,229"), so commas
    are stripped before conversion -- the same idiom the lap-time fields use.

    NaN and infinity are rejected as hard as unparseable text is. This matters
    because a blank cell reaches here as a pandas NaN, and str(NaN) is the string
    "nan", which float() happily accepts -- so without the isfinite check this
    returns NaN instead of None, every "is None" guard downstream silently misses
    it, and int(NaN) blows up mid-report. Anything this returns is safe to do
    arithmetic, comparisons and int() on.
    """
    try:
        number = float(str(value).replace(',', '').strip())
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def format_kart_no(value):
    """Render the Kart No cell the way the operator knows it: "12", not "12.0".

    Same root cause as get_kart_class's: pandas types a numeric Kart No column
    as float, so the raw cell arrives as 12.0 and printing it straight puts
    "12.0" in the report. Ids that aren't whole numbers are passed through
    untouched rather than guessed at, so nothing is silently renamed.
    """
    number = parse_number(value)
    if number is None:
        text = str(value).strip()
        return text if text and text.lower() != "nan" else "-"
    if number != int(number):
        return str(value).strip()
    return str(int(number))


def format_run_time(hours):
    """Render the export's decimal 'Total Hour' value as '8h 47m'."""
    if hours is None:
        return "-"
    whole = int(hours)
    minutes = int(round((hours - whole) * 60))
    if minutes == 60:  # 8.999 -> 9h 00m, not 8h 60m
        whole, minutes = whole + 1, 0
    return f"{whole}h {minutes:02d}m"


def format_total_laps(laps):
    """Render the export's '# Laps' value as a plain integer."""
    return "-" if laps is None else f"{int(laps)}"


def read_xls():
    """Read the newest *.xls export from the user's Downloads folder.

    Instead of a fixed 'Excel.xls' filename, this picks the most recently
    modified *.xls in Downloads, so the operator can just download the Clubspeed
    export and run without renaming it. The export is an HTML table saved with an
    .xls extension, parsed via pandas.read_html.
    """
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    xls_files = glob.glob(os.path.join(downloads_folder, "*.xls"))
    kart_data = []
    if not xls_files:
        print(f"No .xls export found in Downloads: {downloads_folder}")
        return kart_data
    filepath = max(xls_files, key=os.path.getmtime)
    print(f"Reading newest .xls export: {os.path.basename(filepath)}")
    try:
        tables = pd.read_html(filepath, header=None)
        df = tables[0]
        df.columns = [
            "Kart No", "# Heats", "# Laps", "Average Lap Time", "Best Lap Time", "Total Hour"
        ]
        for _, row in df.iloc[1:].iterrows():
            # Lap times decide whether a row is usable at all -- a kart with no
            # time can't be ranked, so it's dropped. They arrive as plain
            # xx.xxx / xxx.xxx decimals, so parse_number is all that's needed;
            # its NaN rejection is the point here, because a blank cell reaches
            # this loop as NaN and float() would accept it, keeping an unrankable
            # kart in the list where it silently scrambles the sort order.
            avg_lap = parse_number(row.get('Average Lap Time'))
            best_lap = parse_number(row.get('Best Lap Time'))
            if avg_lap is None or best_lap is None:
                continue
            kart_no = format_kart_no(row.get('Kart No'))
            # Run time and lap count are parsed leniently: a kart with a blank or
            # malformed 'Total Hour' should lose that one cell (rendered as "-"),
            # not disappear from the report entirely.
            total_laps = parse_number(row.get('# Laps'))
            run_hours = parse_number(row.get('Total Hour'))
            kart_class = get_kart_class(kart_no)
            kart_data.append(
                (kart_no, avg_lap, best_lap, kart_class, total_laps, run_hours)
            )
    except Exception as e:
        print(f"Error reading HTML table: {e}")
    return kart_data

REPORT_PREFIX = "Kart_Results_"
REPORT_MAX_AGE_HOURS = 24

def cleanup_old_reports():
    """Delete this tool's own report files in Downloads older than 24 hours.

    Every run writes a new Kart_Results_<date>.txt, and nothing ever removed the
    previous days' files, so Downloads grew by one report per run-day forever.

    The glob is deliberately anchored to REPORT_PREFIX rather than "*.txt": this
    runs against the operator's real Downloads folder, which is full of personal
    files, so it must never match anything this program didn't write. Age comes
    from the file's mtime, not from the date in its name -- that's what "made in
    the last 24 hours" actually means, and it doesn't break if the filename
    format ever changes.

    Returns the number of files deleted.
    """
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    cutoff = datetime.now().timestamp() - REPORT_MAX_AGE_HOURS * 3600
    deleted = 0
    for filepath in glob.glob(os.path.join(downloads_folder, f"{REPORT_PREFIX}*.txt")):
        try:
            if os.path.getmtime(filepath) < cutoff:
                os.remove(filepath)
                deleted += 1
                print(f"Removed old report: {os.path.basename(filepath)}")
        except OSError as e:
            # Most likely the file is open in Notepad (PermissionError). Skip it
            # -- a failed cleanup must never stop the operator getting a printout.
            print(f"Could not remove {os.path.basename(filepath)}: {e}")
    return deleted

def save_kart_tables(kart_data):
    # Get the user's Downloads folder
    script_dir = os.path.join(os.path.expanduser("~"), "Downloads")
    current_date = datetime.now().strftime("%m %d %Y")
    output_filename = f"Kart_Results_{current_date}.txt"
    output_filepath = os.path.join(script_dir, output_filename)
    
    # Delete the file if it already exists
    if os.path.exists(output_filepath):
        os.remove(output_filepath)
    
    classes = ["Pro", "Junior", "Intermediate", "Other"]
    
    with open(output_filepath, 'w') as f:
        f.write(f"{current_date}\n")
        for kart_class in classes:
            class_karts = [k for k in kart_data if k[3] == kart_class]
            if class_karts:
                sorted_karts = sorted(class_karts, key=lambda x: x[2])
                f.write(f"{'='*78}\n")
                f.write(f"{kart_class} Karts\n")
                f.write(f"{'='*78}\n")
                f.write(
                    f"{'Rank':<8} {'Kart No':<12} {'Avg Lap':<15} {'Best Lap':<15} "
                    f"{'Run Time':<12} {'Total Laps':<10}\n"
                )
                f.write(f"{'-'*78}\n")
                for rank, (kart_no, avg_lap, best_lap, _, total_laps, run_hours) in enumerate(
                    sorted_karts, start=1
                ):
                    f.write(
                        f"{rank:<8} {kart_no:<12} {avg_lap:<15.3f} {best_lap:<15.3f} "
                        f"{format_run_time(run_hours):<12} {format_total_laps(total_laps):<10}\n"
                    )
    
    print(f"Results saved to: {output_filepath}")
    return output_filepath

def print_file(filepath):
    """Send the file to the Windows default printer.

    Returns True if the print job was successfully *dispatched* to the print
    handler, False if it could not be dispatched.

    Limitation: os.startfile calls Windows ShellExecuteW and returns as soon as
    the print handler is launched. It only raises OSError when no print verb is
    registered for .txt (the no-association case). A missing, offline, or paused
    default printer does NOT raise here -- the handler launches fine and fails
    later in its own UI. So True means "dispatched," not "paper came out"; it's
    the strongest signal Windows exposes without a heavier print API.
    """
    try:
        os.startfile(filepath, "print")
        print(f"Sending {os.path.basename(filepath)} to printer...")
        return True
    except OSError as e:
        print(f"Error printing file: {e}")
        return False

def show_in_terminal(filepath):
    """Echo the saved report to the console, for when printing isn't possible.

    Reads the file back rather than re-formatting the tables. The fixed-width
    layout is built inline in save_kart_tables(), so re-rendering it here would
    mean a second copy of that loop that could drift; reading the file back is
    byte-for-byte what was saved.
    """
    with open(filepath) as f:
        print(f.read())

def main():
    try:
        # First, so stale reports get cleared even on runs that bail out below.
        cleanup_old_reports()

        kart_data = read_xls()
        if not kart_data:
            # No .xls found, unreadable, or wrong format -- nothing was printed,
            # so this is NOT a "could not print" case.
            print("No kart data found.")
            print("Check that the .xls export is in your Downloads folder.")
            input("\nPress Enter to exit...")
            return

        output_file = save_kart_tables(kart_data)

        # Nothing to print to (no printer, a print-to-PDF style one, or an
        # offline one) -- show the results here rather than firing a print that
        # produces a Save As dialog, or nothing at all, and closing the window.
        can_print, reason = default_printer_status()
        if not can_print:
            print(f"\n{reason}")
            print("Showing the results here instead.\n")
            show_in_terminal(output_file)
            print(f"Saved to: {output_file}")
            input("\nPress Enter to exit...")
            return

        if print_file(output_file):
            # Successful dispatch -- close immediately, no prompt.
            return

        # Dispatch failed -- show the results rather than dead-ending on an error.
        print("Could not print -- showing the results here instead.\n")
        show_in_terminal(output_file)
        print(f"Saved to: {output_file}")
        input("\nPress Enter to exit...")
    except Exception as e:
        # Catch-all so an unexpected error (e.g. a file-write failure) never
        # slams the double-clicked console window shut before it can be read.
        print(f"Unexpected error: {e}")
        input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()




#File path:
# C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

#compile code:
# "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py"


