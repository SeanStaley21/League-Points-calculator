import csv
import os
import pandas as pd
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

def read_csv(base_filename):
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    filename = f"{base_filename}.csv"
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
        print(f"Could not find '{filename}' in your Downloads folder: {filepath}")
    return kart_data

def read_xls(base_filename):
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    filename = f"{base_filename}.xls"
    filepath = os.path.join(downloads_folder, filename)
    kart_data = []
    try:
        tables = pd.read_html(filepath, header=None)
        df = tables[0]  # Use the first table found
        # Manually set column names
        df.columns = [
            "Kart No", "# Heats", "# Laps", "Average Lap Time", "Best Lap Time", "Total Hour"
        ]
        for _, row in df.iloc[1:].iterrows():  # Skip the first row if it's a duplicate header
            try:
                kart_no = str(row['Kart No'])
                avg_lap = float(str(row['Average Lap Time']).replace(',', ''))
                best_lap = float(str(row['Best Lap Time']).replace(',', ''))
                kart_class = get_kart_class(kart_no)
                kart_data.append((kart_no, avg_lap, best_lap, kart_class))
            except (ValueError, KeyError):
                continue  # Skip rows with invalid data
    except FileNotFoundError:
        print(f"Could not find '{filename}' in your Downloads folder: {filepath}")
    except Exception as e:
        print(f"Error reading HTML table: {e}")
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
    base_filename = input("Enter the base filename (without extension): ").strip()
    print("Select file type to read:")
    print("1. EXCEL (.xls)")
    print("2. CSV (.csv)")
    choice = input("What would you like: ").strip()
    if choice == "1":
        kart_data = read_xls(base_filename)
    elif choice == "2":
        kart_data = read_csv(base_filename)
    else:
        print("Invalid choice. Exiting.")
        return
    if kart_data:
        print_kart_tables(kart_data)
    else:
        print("No kart data found.")
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()




#File path:
#C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

#compile code:
# "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py


