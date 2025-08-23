import csv
import os
from rich.console import Console
from rich.table import Table

def get_downloads_csv_path(filename="kart operation.csv"):
    downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
    return os.path.join(downloads_folder, filename)

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

def read_kart_data(filename):
    kart_data = []
    try:
        with open(filename, newline='') as csvfile:
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
        print(f"Could not find 'kart operation.csv' in your Downloads folder: {filename}")
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
    filename = get_downloads_csv_path()
    kart_data = read_kart_data(filename)
    if kart_data:
        print_kart_tables(kart_data)
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()

# File path
# C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

# compile code
#  "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py