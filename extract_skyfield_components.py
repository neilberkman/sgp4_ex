#!/usr/bin/env python3
"""
Extract intermediate IAU 2000A calculation values from Skyfield
for component-level testing.
"""

from skyfield.api import load, utc
from skyfield import earthlib, nutationlib, precessionlib
from datetime import datetime
import numpy as np

def extract_iau2000a_components():
    # Our test datetime
    dt = datetime(2024, 3, 15, 12, 0, 0, tzinfo=utc)
    ts = load.timescale()
    t = ts.from_datetime(dt)
    
    print("=== IAU 2000A Component Values from Skyfield ===")
    print(f"Test datetime: {dt}")
    print()
    
    # Level 1: Julian dates
    print("Level 1: Julian Dates")
    jd_ut1 = t.ut1
    jd_tt = t.tt
    print(f"JD_UT1: {jd_ut1}")
    print(f"JD_TT: {jd_tt}")
    print()
    
    # Level 2: Fundamental arguments
    print("Level 2: Fundamental Arguments (radians)")
    try:
        # Try to access Skyfield's fundamental arguments
        # This might require digging into internals
        fa = nutationlib.fundamental_arguments(jd_tt)
        print(f"l (Moon mean anomaly): {fa[0]}")
        print(f"l' (Sun mean anomaly): {fa[1]}")  
        print(f"F (Moon longitude - node): {fa[2]}")
        print(f"D (Moon-Sun elongation): {fa[3]}")
        print(f"Omega (Moon node longitude): {fa[4]}")
    except Exception as e:
        print(f"Could not extract fundamental arguments: {e}")
    print()
    
    # Level 3: Nutation values
    print("Level 3: Nutation Values (arcseconds)")
    try:
        delta_psi, delta_epsilon = nutationlib.iau2000a_nutation(jd_tt)
        print(f"delta_psi: {delta_psi}")
        print(f"delta_epsilon: {delta_epsilon}")
    except Exception as e:
        print(f"Could not extract nutation: {e}")
    print()
    
    # Level 4: Mean obliquity  
    print("Level 4: Mean Obliquity (arcseconds)")
    try:
        epsilon_0 = nutationlib.mean_obliquity(jd_tt)
        print(f"epsilon_0: {epsilon_0}")
    except Exception as e:
        print(f"Could not extract mean obliquity: {e}")
    print()
    
    # Level 5: True obliquity
    print("Level 5: True Obliquity (arcseconds)")
    try:
        epsilon = epsilon_0 + delta_epsilon
        print(f"epsilon (true): {epsilon}")
    except Exception as e:
        print(f"Could not calculate true obliquity: {e}")
    print()
    
    # Level 6: Sidereal time
    print("Level 6: Sidereal Time")
    try:
        gmst = earthlib.sidereal_time(t)
        # Try to get equation of equinoxes
        eq_eq = nutationlib.equation_of_the_equinoxes_complimentary_terms(jd_tt)
        gast = gmst + eq_eq
        print(f"GMST (hours): {gmst}")
        print(f"Equation of equinoxes (hours): {eq_eq}")
        print(f"GAST (hours): {gast}")
    except Exception as e:
        print(f"Could not extract sidereal time: {e}")
    print()
    
    # Alternative: Try to access lower-level functions
    print("=== Alternative Access Methods ===")
    try:
        # Try different Skyfield internal access
        import skyfield.iokit
        import skyfield.framelib
        
        # Get Earth orientation data
        with skyfield.iokit.open_file(ts._datadir + '/finals2000A.all') as f:
            earth_orientation_data = skyfield.framelib.parse_iau_2000_finals(f)
            
        print("Successfully accessed Earth orientation data")
    except Exception as e:
        print(f"Alternative access failed: {e}")

if __name__ == "__main__":
    extract_iau2000a_components()