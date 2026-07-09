import os
import pandas as pd
from datetime import datetime

def get_kart_class(kart_no):
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
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    filename = "Excel.xls"
    filepath = os.path.join(downloads_folder, filename)
    kart_data = []
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
    except FileNotFoundError:
        print(f"Could not find 'Excel.xls' in your Downloads folder: {filepath}")
    except Exception as e:
        print(f"Error reading HTML table: {e}")
    return kart_data

def get_weights(kart_data):
    """Prompt the user for each driver's weight (by kart number). Leave blank for 0."""
    print("\nEnter driver weight for each kart (leave blank for 0):")
    weighted_data = []
    for kart_no, avg_lap, best_lap, kart_class in kart_data:
        while True:
            raw = input(f"  Kart {kart_no} weight: ").strip()
            if raw == "":
                weight = 0.0
                break
            try:
                weight = float(raw)
                break
            except ValueError:
                print("    Please enter a number.")
        weighted_data.append((kart_no, avg_lap, best_lap, kart_class, weight))
    return weighted_data

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
                for rank, (kart_no, avg_lap, best_lap, _, _weight) in enumerate(sorted_karts, start=1):
                    f.write(f"{rank:<8} {kart_no:<12} {avg_lap:<15.3f} {best_lap:<15.3f}\n")

        # Kart Pick Order: every kart, heaviest driver first
        pick_order = sorted(kart_data, key=lambda x: x[4], reverse=True)
        f.write(f"{'='*60}\n")
        f.write("Kart Pick Order\n")
        f.write(f"{'='*60}\n")
        f.write(f"{'Rank':<8} {'Kart No':<12} {'Weight':<15} {'Class':<15}\n")
        f.write(f"{'-'*60}\n")
        for rank, (kart_no, avg_lap, best_lap, kart_class, weight) in enumerate(pick_order, start=1):
            f.write(f"{rank:<8} {kart_no:<12} {weight:<15.1f} {kart_class:<15}\n")

    print(f"Results saved to: {output_filepath}")
    return output_filepath

def print_file(filepath):
    """Automatically print the file using Windows default printer"""
    try:
        os.startfile(filepath, "print")
        print(f"Sending {os.path.basename(filepath)} to printer...")
    except Exception as e:
        print(f"Error printing file: {e}")

def main():
    kart_data = read_xls()
    if kart_data:
        kart_data = get_weights(kart_data)
        output_file = save_kart_tables(kart_data)
        print_file(output_file)
    else:
        print("No kart data found.")
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()




#File path:
# C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

#compile code:
# "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py"


