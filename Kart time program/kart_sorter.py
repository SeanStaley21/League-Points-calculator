import csv
import os

# Get the path to the user's Downloads folder
downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
filename = os.path.join(downloads_folder, "kart operation.csv")
kart_data = []

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

    # Organize karts by class
    classes = ["Pro", "Junior", "Intermediate", "Other"]
    for kart_class in classes:
        class_karts = [k for k in kart_data if k[3] == kart_class]
        if class_karts:
            # Sort by best lap time (ascending = faster)
            sorted_karts = sorted(class_karts, key=lambda x: x[2])
            print(f"\n===== {kart_class} Karts =====")
            for rank, (kart_no, avg_lap, best_lap, _) in enumerate(sorted_karts, start=1):
                print(f"{rank}. Kart {kart_no} — Avg Lap: {avg_lap:.3f} sec | Best Lap: {best_lap:.3f} sec")
except FileNotFoundError:
    print(f"Could not find 'kart operation.csv' in your Downloads folder: {filename}")

input("\nPress Enter to exit...")