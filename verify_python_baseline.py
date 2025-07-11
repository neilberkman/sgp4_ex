#!/usr/bin/env python3

import sys
import time
sys.path.append('/Users/neil/xuku/sgp4_ex/crap/python-skyfield')

from skyfield.api import load, EarthSatellite
from datetime import datetime, timezone

# Test TLE
line1 = "1 25544U 98067A   24074.54761985  .00019515  00000+0  35063-3 0  9997"
line2 = "2 25544  51.6410 299.5237 0005417  72.1189  36.3479 15.49802661443442"

print("🐍 PYTHON SKYFIELD BASELINE VERIFICATION")
print("=" * 60)

# Create satellite
satellite = EarthSatellite(line1, line2, 'ISS')
ts = load.timescale()
test_time = ts.utc(2024, 3, 15, 12, 0, 0)

print(f"Testing single satellite at {test_time.utc_datetime()}")

# Warm up
for i in range(5):
    geocentric = satellite.at(test_time)
    subpoint = geocentric.subpoint()

print("Warm-up complete. Starting timing...")

# Time single propagation
times = []
for i in range(100):
    start = time.perf_counter()
    
    # Full propagation to geodetic
    geocentric = satellite.at(test_time)
    subpoint = geocentric.subpoint()
    lat = subpoint.latitude.degrees
    lon = subpoint.longitude.degrees  
    alt = subpoint.elevation.km
    
    end = time.perf_counter()
    duration_ms = (end - start) * 1000
    times.append(duration_ms)

avg_ms = sum(times) / len(times)
min_ms = min(times)
median_ms = sorted(times)[len(times)//2]

print(f"\n🎯 PYTHON SKYFIELD RESULTS:")
print(f"Average: {avg_ms:.3f}ms per satellite")
print(f"Minimum: {min_ms:.3f}ms per satellite") 
print(f"Median:  {median_ms:.3f}ms per satellite")

print(f"\n✅ Final result: Lat={lat:.6f}°, Lon={lon:.6f}°, Alt={alt:.3f}km")

# Check if this matches your 0.367ms claim
if avg_ms < 1.0:
    print(f"✅ FAST: {avg_ms:.3f}ms is indeed sub-millisecond")
else:
    print(f"❌ SLOW: {avg_ms:.3f}ms is NOT the 0.367ms you mentioned")
    print("   This suggests the 0.367ms was for batch/100 satellites, not single")