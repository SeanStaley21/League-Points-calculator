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
        for kart_class in classes:
            class_karts = [k for k in kart_data if k[3] == kart_class]
            if class_karts:
                sorted_karts = sorted(class_karts, key=lambda x: x[2])
                f.write(f"\n{'='*60}\n")
                f.write(f"{kart_class} Karts\n")
                f.write(f"{'='*60}\n\n")
                f.write(f"{'Rank':<8} {'Kart No':<12} {'Avg Lap':<15} {'Best Lap':<15}\n")
                f.write(f"{'-'*60}\n")
                
                for rank, (kart_no, avg_lap, best_lap, _) in enumerate(sorted_karts, start=1):
                    f.write(f"{rank:<8} {kart_no:<12} {avg_lap:<15.3f} {best_lap:<15.3f}\n")
                f.write("\n")
    
    print(f"Results saved to: {output_filepath}")

def main():
    kart_data = read_xls()
    if kart_data:
        save_kart_tables(kart_data)
    else:
        print("No kart data found.")
    input("\nPress Enter to exit...")

if __name__ == "__main__":
    main()




#File path:
# C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program

#compile code:
# "C:\Users\Asalt\AppData\Local\Programs\Python\Python313\python.exe" -m PyInstaller --onefile kart_sorter.py


