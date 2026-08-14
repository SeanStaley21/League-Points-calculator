import os
import re
import glob
import math
import pandas as pd
from datetime import datetime

def get_kart_class(kart_no):
    """Classify a kart number into a Cincinnati-fleet division by numeric range.

    Cincinnati fleet (from 'cincinatti fleet divisions.txt'):
        Pro          11-59
        Junior       60-80
        Intermediate 90-99
        Unknown       2-9
        else         Other  (0-1, 10, 81-89, 100+, or non-numeric)

    The number goes through parse_number rather than a bare int(): pandas hands
    back "12.0" for a Kart No column it typed as numeric, and int("12.0") raises
    ValueError. That used to mean every kart in such an export fell through to
    "Other" and the whole report collapsed into one section.
    """
    num = parse_number(kart_no)
    if num is None:
        return "Other"
    num = int(num)
    if 11 <= num <= 59:
        return "Pro"
    elif 60 <= num <= 80:
        return "Junior"
    elif 90 <= num <= 99:
        return "Intermediate"
    elif 2 <= num <= 9:
        return "Unknown"
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


# --- Reporting period ------------------------------------------------------
# The export covers a date range the operator picked in Clubspeed (e.g. a whole
# month, 4:00 AM to 3:59 AM -- the track's day boundary, not midnight). Nothing
# in the kart table records it, so the printed report used to carry only the day
# it was generated, which tells you nothing about what the numbers cover.
#
# The range is read out of the raw file text rather than via pandas, on purpose:
# it lives outside the kart table (pandas only ever sees tables[0] here), and a
# text scan doesn't care whether it sits in a caption, a header table, or a
# stray line of markup. If nothing is found the report simply omits the line --
# a missing period must never cost the operator their printout.

RANGE_SEPARATOR = r"\s*(?:-{1,2}|–|—|to|through|thru)\s*"

# How far apart two timestamps may sit and still be read as one range, once the
# markup is stripped. Generous enough for "From: <a> To: <b>" in a header table,
# tight enough to never pair the range with a footer date.
MAX_RANGE_GAP = 40

# Richest formats first: the first pattern that yields a usable pair wins, so a
# full timestamp is never truncated to a bare date.
DATE_PATTERNS = (
    (r"\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}(?::\d{2})?\s*[AP]M",
     ("%m/%d/%Y %I:%M:%S %p", "%m/%d/%Y %I:%M %p")),
    (r"\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}:\d{2}(?::\d{2})?",
     ("%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M")),
    (r"\d{4}-\d{2}-\d{2}[ T]\d{1,2}:\d{2}(?::\d{2})?",
     ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M")),
    (r"\d{1,2}/\d{1,2}/\d{4}", ("%m/%d/%Y",)),
    (r"\d{4}-\d{2}-\d{2}", ("%Y-%m-%d",)),
)


def export_text(filepath):
    """The export's visible text: markup stripped, entities and spacing tamed."""
    with open(filepath, "rb") as f:
        raw = f.read().decode("utf-8", errors="ignore")
    text = re.sub(r"<[^>]+>", " ", raw)
    text = text.replace("&nbsp;", " ").replace("\xa0", " ")
    # "4:00:00 a.m." and "4:00:00 AM" are the same instant; normalise so one
    # set of strptime formats covers both.
    text = re.sub(r"\b([AaPp])\.\s*([Mm])\.", r"\1\2", text)
    return re.sub(r"\s+", " ", text).upper()


def parse_moment(text, formats):
    """First format that parses `text`, or None."""
    cleaned = " ".join(text.split())
    for fmt in formats:
        try:
            return datetime.strptime(cleaned, fmt)
        except ValueError:
            continue
    return None


def extract_date_range(filepath):
    """Return (start, end) datetimes covered by the export, or (None, None).

    Two passes. First look for two timestamps joined by a range separator
    ("-", "to", "through") -- that shape is unambiguous, and it steps around a
    stray "Printed: <date>" being mistaken for one end of the period. Only if
    that finds nothing does it fall back to the first two dates in the file.

    Never raises: an unreadable or date-free export yields (None, None) and the
    report goes out without the period line.
    """
    try:
        text = export_text(filepath)
    except OSError:
        return None, None

    for pattern, formats in DATE_PATTERNS:
        pair = re.search(f"({pattern}){RANGE_SEPARATOR}({pattern})", text, re.IGNORECASE)
        if pair:
            start = parse_moment(pair.group(1), formats)
            end = parse_moment(pair.group(2), formats)
            if start and end and start <= end:
                return start, end

    for pattern, formats in DATE_PATTERNS:
        hits = list(re.finditer(pattern, text, re.IGNORECASE))
        for first, second in zip(hits, hits[1:]):
            # Adjacency is the safety rail. Two dates sitting next to each other
            # are a range; two dates at opposite ends of the file are a range end
            # and something else entirely (a "printed on" stamp, a session date),
            # and pairing those would print a confidently wrong period on a
            # document the league actually hands out. Better no line than a lie.
            if second.start() - first.end() > MAX_RANGE_GAP:
                continue
            start = parse_moment(first.group(), formats)
            end = parse_moment(second.group(), formats)
            if start and end and start <= end:
                return start, end
    return None, None


def format_moment(moment):
    """'Wednesday, July 1, 2026 4:00 AM'.

    The day and hour are interpolated rather than left to strftime because the
    no-leading-zero flag is spelled %-d on Unix and %#d on Windows; building the
    string by hand sidesteps that entirely.
    """
    hour = moment.hour % 12 or 12
    meridiem = "AM" if moment.hour < 12 else "PM"
    return f"{moment:%A}, {moment:%B} {moment.day}, {moment.year} {hour}:{moment:%M} {meridiem}"


def format_date_range(start, end):
    """The period line for the report header, or "" if the range is unknown."""
    if start is None or end is None:
        return ""
    return f"{format_moment(start)} to {format_moment(end)}"


def read_xls():
    """Read the newest *.xls export from the user's Downloads folder.

    Instead of a fixed 'Excel.xls' filename, this picks the most recently
    modified *.xls in Downloads, so the operator can just download the Clubspeed
    export and run without renaming it. The export is an HTML table saved with an
    .xls extension, parsed via pandas.read_html.

    Returns (kart_data, date_range) -- the second being the formatted reporting
    period for the report header, or "" when the export doesn't carry one.
    """
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    xls_files = glob.glob(os.path.join(downloads_folder, "*.xls"))
    kart_data = []
    if not xls_files:
        print(f"No .xls export found in Downloads: {downloads_folder}")
        return kart_data, ""
    filepath = max(xls_files, key=os.path.getmtime)
    print(f"Reading newest .xls export: {os.path.basename(filepath)}")
    date_range = format_date_range(*extract_date_range(filepath))
    if date_range:
        print(f"Reporting period: {date_range}")
    try:
        tables = pd.read_html(filepath, header=None)
        df = tables[0]
        df.columns = [
            "Kart No", "# Heats", "# Laps", "Average Lap Time", "Best Lap Time", "Total Hour"
        ]
        for _, row in df.iloc[1:].iterrows():
            # Lap times decide whether a row is usable at all -- a kart with no
            # time can't be ranked, so it's dropped. Per the league operator a
            # lap time is ALWAYS a plain xx.xxx / xxx.xxx decimal -- never mm:ss,
            # never "DNF" -- so parse_number is all that's needed and a time
            # parser here would only be a new way to misread a good value;
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
    return kart_data, date_range

REPORT_PREFIX = "KartTimeCinci_Results_"
REPORT_MAX_AGE_HOURS = 24

def cleanup_old_reports():
    """Delete this tool's own report files in Downloads older than 24 hours.

    Every run writes a new KartTimeCinci_Results_<date>.txt, and nothing ever
    removed the previous days' files, so Downloads grew by one report per run-day
    forever.

    The glob is deliberately anchored to REPORT_PREFIX rather than "*.txt": this
    runs against the operator's real Downloads folder, which is full of personal
    files, so it must never match anything this program didn't write. That also
    means this build leaves the Full Throttle build's Kart_Results_*.txt alone --
    each tool cleans up only after itself. Age comes from the file's mtime, not
    from the date in its name -- that's what "made in the last 24 hours" actually
    means, and it doesn't break if the filename format ever changes.

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

def save_kart_tables(kart_data, date_range=""):
    # Get the user's Downloads folder
    script_dir = os.path.join(os.path.expanduser("~"), "Downloads")
    current_date = datetime.now().strftime("%m %d %Y")
    output_filename = f"KartTimeCinci_Results_{current_date}.txt"
    output_filepath = os.path.join(script_dir, output_filename)

    # Delete the file if it already exists
    if os.path.exists(output_filepath):
        os.remove(output_filepath)

    classes = ["Pro", "Junior", "Intermediate", "Unknown", "Other"]

    with open(output_filepath, 'w') as f:
        f.write(f"{current_date}\n")
        # The period the numbers cover, when the export told us. Distinct from
        # the line above, which is only the day the report was generated.
        if date_range:
            f.write(f"{date_range}\n")
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

def main():
    try:
        # First, so stale reports get cleared even on runs that bail out below.
        cleanup_old_reports()

        kart_data, date_range = read_xls()
        if not kart_data:
            # No .xls found, unreadable, or wrong format -- nothing was printed,
            # so this is NOT a "could not print" case.
            print("No kart data found.")
            print("Check that the .xls export is in your Downloads folder.")
            input("\nPress Enter to exit...")
            return

        output_file = save_kart_tables(kart_data, date_range)
        if print_file(output_file):
            # Successful dispatch -- close immediately, no prompt.
            return
        # Print could not be dispatched -- keep the window open with the error.
        print("Could not print")
        input("\nPress Enter to exit...")
    except Exception as e:
        # Catch-all so an unexpected error (e.g. a file-write failure) never
        # slams the double-clicked console window shut before it can be read.
        print(f"Unexpected error: {e}")
        input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()




# File path:
# ...\League-Points-calculator\kartTimeCinci

# compile code (run from inside kartTimeCinci/, Python 3.13):
# python -m PyInstaller --onefile kartTimeCinci.py
