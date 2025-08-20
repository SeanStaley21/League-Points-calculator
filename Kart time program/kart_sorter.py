import csv
import os

# Get the path to the user's Downloads folder
downloads_folder = os.path.join(os.path.expanduser("~"), "Downloads")
filename = os.path.join(downloads_folder, "kart operation.csv")
kart_data = []

try:
    with open(filename, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        
        for row in reader:
            try:
                kart_no = row['Kart No']
                avg_lap = float(row['Average Lap Time'])
                best_lap = float(row['Best Lap Time'])
                kart_data.append((kart_no, avg_lap, best_lap))
            except ValueError:
                continue  # Skip rows with invalid data

    # Sort by best lap time (ascending = faster)
    top_karts = sorted(kart_data, key=lambda x: x[2])[:15]

    # Display results
    print("🏁 Top 15 Fastest Karts (by Best Lap):")
    for rank, (kart_no, avg_lap, best_lap) in enumerate(top_karts, start=1):
        print(f"{rank}. Kart {kart_no} — Avg Lap: {avg_lap:.3f} sec | Best Lap: {best_lap:.3f} sec")
except FileNotFoundError:
    print(f"Could not find 'kart operation.csv' in your Downloads folder: {filename}")

input("\nPress Enter to exit...")