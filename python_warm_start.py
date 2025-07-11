#!/usr/bin/env python3

import time
from skyfield.api import load, EarthSatellite
from datetime import datetime, timezone

print("\n=== PYTHON WARM START BENCHMARK ===")
print("Warming up with different TLEs, then testing fresh TLE\n")

# Different TLEs for warm-up (real TLEs from database)
warmup_tles = [
    ("1 30967U 99025BBH 23137.66391166  .00001555  00000-0  41268-3 0    18", "2 30967  98.7547  35.5966 0112285 206.6100 152.9301 14.46525639853782"),
    ("1  8597U 76005B   21199.06665815  .00000094  00000-0  82018-4 0  6438", "2  8597  82.9717  44.1207 0025795  24.0679  85.9723 13.75182160282122"),
    ("1 51049U 22002BT  24017.15743660  .00037081  00000-0  90564-3 0    11", "2 51049  97.4070  91.8305 0005607 162.8386 197.3051 15.40734381111663")
]

# Fresh TLE for actual benchmark (same as Elixir)
benchmark_line1 = "1 48808U 21047A   23086.46230110 -.00000330  00000-0  00000-0 0  5890"
benchmark_line2 = "2 48808   0.2330 283.2669 0003886 229.5666 331.3824  1.00276212  6769"

# Create timescale
ts = load.timescale()

# WARM-UP with different TLEs
print("🔥 WARMING UP with different TLEs (to avoid caching)...")
for i in range(50):
    line1, line2 = warmup_tles[i % 3]
    sat = EarthSatellite(line1, line2, f'WARMUP{i}', ts)
    test_time = ts.from_datetime(datetime(2024, 5, 17, 14, i, 0, tzinfo=timezone.utc))
    geocentric = sat.at(test_time)
    subpoint = geocentric.subpoint()

print("✅ Warm-up complete. Now testing FRESH TLE performance...\n")

# Create fresh satellite for benchmark
benchmark_satellite = EarthSatellite(benchmark_line1, benchmark_line2, 'BENCHMARK', ts)
benchmark_time = ts.from_datetime(datetime(2024, 5, 17, 15, 15, 0, tzinfo=timezone.utc))

# Test FRESH TLE multiple times
single_times = []
for run in range(1, 21):
    start = time.perf_counter()
    geocentric = benchmark_satellite.at(benchmark_time)
    subpoint = geocentric.subpoint()
    elapsed = time.perf_counter() - start
    ms = elapsed * 1000.0
    if run % 5 == 0:
        print(f"Run {run}: {ms:.3f}ms")
    single_times.append(ms)

avg_time = sum(single_times) / len(single_times)
min_time = min(single_times)
median_time = sorted(single_times)[len(single_times) // 2]

print(f"\n🐍 PYTHON RESULTS (single satellite, warm start):")
print(f"Average: {avg_time:.3f}ms")
print(f"Minimum: {min_time:.3f}ms")
print(f"Median:  {median_time:.3f}ms")

# Test accuracy
geocentric = benchmark_satellite.at(benchmark_time)
subpoint = geocentric.subpoint()
print(f"\n✅ Accuracy check:")
print(f"  Lat: {subpoint.latitude.degrees:.6f}°")
print(f"  Lon: {subpoint.longitude.degrees:.6f}°")
print(f"  Alt: {subpoint.elevation.km:.3f} km")