#!/usr/bin/env python3
"""
Test Skyfield cold start performance - no warmup, single calculation
"""

import time
from skyfield.api import load, EarthSatellite, wgs84

# ISS TLE
line1 = '1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999'
line2 = '2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258'

def test_cold_start():
    """Test very first calculation with no warmup"""
    
    # Load timescale and create satellite (fresh every time)
    ts = load.timescale()
    satellite = EarthSatellite(line1, line2, 'ISS', ts)
    
    # Single time point
    t = ts.utc(2024, 5, 18, 12, 0, 0)
    
    # Measure VERY FIRST calculation
    start = time.perf_counter()
    geocentric = satellite.at(t)
    subpoint = wgs84.subpoint(geocentric)
    lat = subpoint.latitude.degrees
    lon = subpoint.longitude.degrees  
    alt = subpoint.elevation.m
    elapsed = time.perf_counter() - start
    
    print(f"COLD START (first ever calculation): {elapsed*1000:.3f} ms")
    
    # Now measure second calculation (potential caching)
    start = time.perf_counter()
    geocentric = satellite.at(t)
    subpoint = wgs84.subpoint(geocentric)
    lat = subpoint.latitude.degrees
    lon = subpoint.longitude.degrees
    alt = subpoint.elevation.m
    elapsed = time.perf_counter() - start
    
    print(f"Second calculation (same time): {elapsed*1000:.3f} ms")
    
    # Different time (new calculation needed)
    t2 = ts.utc(2024, 5, 18, 12, 1, 0)
    start = time.perf_counter()
    geocentric = satellite.at(t2)
    subpoint = wgs84.subpoint(geocentric)
    lat = subpoint.latitude.degrees
    lon = subpoint.longitude.degrees
    alt = subpoint.elevation.m
    elapsed = time.perf_counter() - start
    
    print(f"Different time: {elapsed*1000:.3f} ms")

if __name__ == "__main__":
    print("=== Skyfield Cold Start Test ===")
    test_cold_start()