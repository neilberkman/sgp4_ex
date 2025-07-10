#!/usr/bin/env python3
"""
Detailed analysis of Skyfield's performance optimizations
"""

import time
import numpy as np
from skyfield.api import load, EarthSatellite, wgs84
from skyfield.nutationlib import iau2000a, fundamental_arguments, build_nutation_matrix
from skyfield.functions import load_bundled_npy
from skyfield.earthlib import sidereal_time
from skyfield.framelib import itrs

def analyze_nutation_performance():
    """Analyze the nutation calculation performance in detail"""
    print("=== Nutation Performance Analysis ===")
    
    # Load precomputed arrays
    _arrays = load_bundled_npy('nutation.npz')
    nals_t = _arrays['nals_t']
    lunisolar_longitude_coefficients = _arrays['lunisolar_longitude_coefficients']
    lunisolar_obliquity_coefficients = _arrays['lunisolar_obliquity_coefficients']
    
    jd_tt = 2451545.0
    t_centuries = 0.0
    
    print(f"Coefficient array sizes:")
    print(f"  Lunisolar args: {nals_t.shape}")
    print(f"  Longitude coeffs: {lunisolar_longitude_coefficients.shape}")
    print(f"  Obliquity coeffs: {lunisolar_obliquity_coefficients.shape}")
    
    # 1. Test fundamental arguments computation
    times_fa = []
    for _ in range(10000):
        start = time.perf_counter()
        fa = fundamental_arguments(t_centuries)
        elapsed = time.perf_counter() - start
        times_fa.append(elapsed)
    
    print(f"\nFundamental arguments: {np.mean(times_fa)*1000:.4f} ms")
    
    # 2. Test matrix multiplication
    fa = fundamental_arguments(t_centuries)
    cutoff = 678
    
    times_matmul = []
    for _ in range(10000):
        start = time.perf_counter()
        arg = nals_t[:cutoff].dot(fa)
        elapsed = time.perf_counter() - start
        times_matmul.append(elapsed)
    
    print(f"Matrix multiplication: {np.mean(times_matmul)*1000:.4f} ms")
    
    # 3. Test sin/cos computation
    arg = nals_t[:cutoff].dot(fa)
    
    times_sincos = []
    for _ in range(10000):
        start = time.perf_counter()
        sarg = np.sin(arg)
        carg = np.cos(arg)
        elapsed = time.perf_counter() - start
        times_sincos.append(elapsed)
    
    print(f"Sin/cos computation: {np.mean(times_sincos)*1000:.4f} ms")
    
    # 4. Test coefficient multiplication
    sarg = np.sin(arg)
    carg = np.cos(arg)
    
    times_coeffs = []
    for _ in range(10000):
        start = time.perf_counter()
        dpsi = np.dot(sarg, lunisolar_longitude_coefficients[:cutoff,0])
        dpsi += np.dot(sarg, lunisolar_longitude_coefficients[:cutoff,1]) * t_centuries
        dpsi += np.dot(carg, lunisolar_longitude_coefficients[:cutoff,2])
        elapsed = time.perf_counter() - start
        times_coeffs.append(elapsed)
    
    print(f"Coefficient multiplication: {np.mean(times_coeffs)*1000:.4f} ms")
    
    # 5. Full IAU2000A
    times_full = []
    for _ in range(1000):
        start = time.perf_counter()
        dpsi, deps = iau2000a(jd_tt)
        elapsed = time.perf_counter() - start
        times_full.append(elapsed)
    
    print(f"Full IAU2000A: {np.mean(times_full)*1000:.4f} ms")
    
    total_components = (np.mean(times_fa) + np.mean(times_matmul) + 
                       np.mean(times_sincos) + np.mean(times_coeffs))
    print(f"Sum of components: {total_components*1000:.4f} ms")
    print(f"Overhead: {(np.mean(times_full) - total_components)*1000:.4f} ms")

def analyze_coordinate_transform_performance():
    """Analyze coordinate transformation performance"""
    print("\n=== Coordinate Transform Performance Analysis ===")
    
    # ISS TLE
    line1 = '1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999'
    line2 = '2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258'
    
    ts = load.timescale()
    satellite = EarthSatellite(line1, line2, 'ISS', ts)
    t = ts.utc(2024, 5, 18, 12, 0, 0)
    
    # 1. SGP4 propagation only
    times_sgp4 = []
    for _ in range(1000):
        start = time.perf_counter()
        r, v, error = satellite._position_and_velocity_TEME_km(t)
        elapsed = time.perf_counter() - start
        times_sgp4.append(elapsed)
    
    print(f"SGP4 propagation: {np.mean(times_sgp4)*1000:.4f} ms")
    
    # 2. TEME to GCRS transformation
    r, v, error = satellite._position_and_velocity_TEME_km(t)
    
    times_teme_gcrs = []
    for _ in range(1000):
        start = time.perf_counter()
        # This is what satellite.at() does internally
        r_au = r / 149597870.7  # Convert to AU
        v_au = v / 149597870.7 * 86400  # Convert to AU/day
        
        # Apply TEME to GCRS rotation
        from skyfield.sgp4lib import TEME
        R = TEME.rotation_at(t).T
        r_gcrs = np.dot(R, r_au)
        v_gcrs = np.dot(R, v_au)
        elapsed = time.perf_counter() - start
        times_teme_gcrs.append(elapsed)
    
    print(f"TEME to GCRS: {np.mean(times_teme_gcrs)*1000:.4f} ms")
    
    # 3. GCRS to geodetic
    geocentric = satellite.at(t)
    
    times_gcrs_geo = []
    for _ in range(1000):
        start = time.perf_counter()
        subpoint = wgs84.subpoint(geocentric)
        lat = subpoint.latitude.degrees
        lon = subpoint.longitude.degrees
        alt = subpoint.elevation.m
        elapsed = time.perf_counter() - start
        times_gcrs_geo.append(elapsed)
    
    print(f"GCRS to geodetic: {np.mean(times_gcrs_geo)*1000:.4f} ms")
    
    # 4. Full pipeline
    times_full = []
    for _ in range(1000):
        start = time.perf_counter()
        geocentric = satellite.at(t)
        subpoint = wgs84.subpoint(geocentric)
        lat = subpoint.latitude.degrees
        lon = subpoint.longitude.degrees
        alt = subpoint.elevation.m
        elapsed = time.perf_counter() - start
        times_full.append(elapsed)
    
    print(f"Full pipeline: {np.mean(times_full)*1000:.4f} ms")

def analyze_caching_impact():
    """Analyze the impact of caching on performance"""
    print("\n=== Caching Impact Analysis ===")
    
    ts = load.timescale()
    t = ts.utc(2024, 5, 18, 12, 0, 0)
    
    # Test repeated access to cached properties
    properties = ['gast', '_nutation_angles_radians', '_mean_obliquity_radians', 'M']
    
    for prop in properties:
        # First access (should compute)
        start = time.perf_counter()
        getattr(t, prop)
        first_access = time.perf_counter() - start
        
        # Subsequent accesses (should use cache)
        times_cached = []
        for _ in range(1000):
            start = time.perf_counter()
            getattr(t, prop)
            elapsed = time.perf_counter() - start
            times_cached.append(elapsed)
        
        cached_access = np.mean(times_cached)
        speedup = first_access / cached_access if cached_access > 0 else float('inf')
        
        print(f"{prop}:")
        print(f"  First access: {first_access*1000:.4f} ms")
        print(f"  Cached access: {cached_access*1000:.4f} ms")
        print(f"  Speedup: {speedup:.1f}x")

if __name__ == "__main__":
    analyze_nutation_performance()
    analyze_coordinate_transform_performance()
    analyze_caching_impact()