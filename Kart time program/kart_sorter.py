import os
import glob
import pandas as pd
from datetime import datetime

def get_kart_class(kart_no):
    """Classify a kart number into a Full Throttle-fleet division by numeric range.

    Full Throttle fleet:
        Pro          11-28
        Junior       70-78
        Intermediate 95-98
        else         Other  (anything outside the above, or non-numeric)

    These ranges are deliberately different from the Cincinnati fleet's -- see
    kartTimeCinci/kartTimeCinci.py for that build. Do not merge the two.
    """
    try:
        num = int(kart_no)
        if 11 <= num <= 28:
            return "Pro"
        elif 70 <= num <= 78:
            return "Junior"
        elif 95 <= num <= 98:
            return "Intermediate"
        else:
            return "Other"
    except ValueError:
        return "Other"

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
            try:
                kart_no = str(row['Kart No'])
                avg_lap = float(str(row['Average Lap Time']).replace(',', ''))
                best_lap = float(str(row['Best Lap Time']).replace(',', ''))
                kart_class = get_kart_class(kart_no)
                kart_data.append((kart_no, avg_lap, best_lap, kart_class))
            except (ValueError, KeyError):
                continue
    except Exception as e:
        print(f"Error reading HTML table: {e}")
    return kart_data

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
                f.write(f"{'='*60}\n")
                f.write(f"{kart_class} Karts\n")
                f.write(f"{'='*60}\n")
                f.write(f"{'Rank':<8} {'Kart No':<12} {'Avg Lap':<15} {'Best Lap':<15}\n")
                f.write(f"{'-'*60}\n")
                for rank, (kart_no, avg_lap, best_lap, _) in enumerate(sorted_karts, start=1):
                    f.write(f"{rank:<8} {kart_no:<12} {avg_lap:<15.3f} {best_lap:<15.3f}\n")
    
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
        kart_data = read_xls()
        if not kart_data:
            # No .xls found, unreadable, or wrong format -- nothing was printed,
            # so this is NOT a "could not print" case.
            print("No kart data found.")
            print("Check that the .xls export is in your Downloads folder.")
            input("\nPress Enter to exit...")
            return

        output_file = save_kart_tables(kart_data)
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




#File path:
# C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

#compile code:
# "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py"


