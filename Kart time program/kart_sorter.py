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
    kart_data = read_xls()
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


