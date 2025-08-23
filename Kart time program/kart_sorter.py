import csv
import os
import xlrd
from rich.console import Console
from rich.table import Table

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

def read_csv(filename="kart operation.csv"):
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    filepath = os.path.join(downloads_folder, filename)
    kart_data = []
    try:
        with open(filepath, newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                try:
                    kart_no = row['Kart No']
                    avg_lap = float(row['Average Lap Time'])
                    best_lap = float(row['Best Lap Time'])
                    kart_class = get_kart_class(kart_no)
                    kart_data.append((kart_no, avg_lap, best_lap, kart_class))
                except ValueError:
                    continue  # Skip rows with invalid data
    except FileNotFoundError:
        print(f"Could not find 'kart operation.csv' in your Downloads folder: {filepath}")
    return kart_data

def read_xls(filename="kart operation.xls"):
    
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    filepath = os.path.join(downloads_folder, filename)
    kart_data = []
    try:
        workbook = xlrd.open_workbook(filepath)
        sheet = workbook.sheet_by_index(0)
        # Find column indices by header names
        headers = [sheet.cell_value(0, col) for col in range(sheet.ncols)]
        try:
            kart_no_idx = headers.index('Kart No')
            avg_lap_idx = headers.index('Average Lap Time')
            best_lap_idx = headers.index('Best Lap Time')
        except ValueError:
            print("Required columns not found in the .xls file.")
            return kart_data

        for row_idx in range(1, sheet.nrows):
            try:
                kart_no = str(sheet.cell_value(row_idx, kart_no_idx))
                avg_lap = float(sheet.cell_value(row_idx, avg_lap_idx))
                best_lap = float(sheet.cell_value(row_idx, best_lap_idx))
                kart_class = get_kart_class(kart_no)
                kart_data.append((kart_no, avg_lap, best_lap, kart_class))
            except ValueError:
                continue  # Skip rows with invalid data
    except FileNotFoundError:
        print(f"Could not find 'kart operation.xls' in your Downloads folder: {filepath}")
    except Exception as e:
        print(f"Error reading .xls file: {e}")
    return kart_data

def print_kart_tables(kart_data):
    console = Console()
    classes = ["Pro", "Junior", "Intermediate", "Other"]
    for kart_class in classes:
        class_karts = [k for k in kart_data if k[3] == kart_class]
        if class_karts:
            sorted_karts = sorted(class_karts, key=lambda x: x[2])
            table = Table(title=f"{kart_class} Karts")
            table.add_column("Rank", justify="center")
            table.add_column("Kart No", justify="center")
            table.add_column("Avg Lap", justify="center")
            table.add_column("Best Lap", justify="center")

            for rank, (kart_no, avg_lap, best_lap, _) in enumerate(sorted_karts, start=1):
                table.add_row(str(rank), kart_no, f"{avg_lap:.3f}", f"{best_lap:.3f}")

            console.print(table)

def main():
    print("Select file type to read:")
    print("1. Excel (.xls)")
    print("2. CSV (.csv)")
    choice = input("Enter 1 for Excel or 2 for CSV: ").strip()
    if choice == "1":
        kart_data = read_xls()
    elif choice == "2":
        kart_data = read_csv()
    else:
        print("Invalid choice. Exiting.")
        return
    if kart_data:
        print_kart_tables(kart_data)
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()

# File path
# C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

# compile code
#  "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py