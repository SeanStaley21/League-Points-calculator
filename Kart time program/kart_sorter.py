import csv

filename = r"C:\Users\Asalt\OneDrive - Full Throttle Adrenaline Park\excel stuff\leagues\League-Points-calculator\Kart time program\kart operation.csv"
kart_data = []

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

# Sort by average lap time (ascending = faster)
top_karts = sorted(kart_data, key=lambda x: x[1])[:15]

# Display results
print("🏁 Top 15 Fastest Karts:")
for rank, (kart_no, avg_lap, best_lap) in enumerate(top_karts, start=1):
    print(f"{rank}. Kart {kart_no} — Avg Lap: {avg_lap:.3f} sec | Best Lap: {best_lap:.3f} sec")

input("\nPress Enter to exit...")