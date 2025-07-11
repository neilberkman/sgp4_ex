#!/usr/bin/env python3

# Direct comparison with Skyfield to debug units

import sys
sys.path.append('/Users/neil/xuku/sgp4_ex/crap/python-skyfield')

from skyfield.nutationlib import iau2000a_radians, iau2000a
from skyfield.api import load

# Test values - same as Elixir
jd_tt = 2460385.000800741

# Create a Skyfield time object properly
ts = load.timescale()
t = ts.tt_jd(jd_tt)

# Get Skyfield IAU2000A nutation
dpsi_skyfield, deps_skyfield = iau2000a_radians(t)

print("=== SKYFIELD IAU2000A RESULTS ===")
print(f"Skyfield dpsi: {dpsi_skyfield}")
print(f"Skyfield deps: {deps_skyfield}")

# Expected values from our working CPU version  
expected_dpsi = -1.7623404327618933e-05
expected_deps = -2.186777146728807e-06

print("\n=== COMPARISON ===")
print(f"Expected dpsi: {expected_dpsi}")
print(f"Skyfield dpsi: {dpsi_skyfield}")
print(f"Ratio: {dpsi_skyfield / expected_dpsi}")

print(f"\nExpected deps: {expected_deps}")
print(f"Skyfield deps: {deps_skyfield}")
print(f"Ratio: {deps_skyfield / expected_deps}")

# Also test raw IAU2000A (before radians conversion)
from skyfield.nutationlib import iau2000a

dpsi_raw, deps_raw = iau2000a(jd_tt)
print(f"\n=== RAW IAU2000A (before conversion) ===")
print(f"Raw dpsi: {dpsi_raw} (units: 0.1 microarcseconds)")
print(f"Raw deps: {deps_raw} (units: 0.1 microarcseconds)")

# Manual conversion
ASEC2RAD = 4.84813681109535984270e-6
TENTH_USEC_2_RAD = ASEC2RAD / 1e7
manual_dpsi = dpsi_raw * TENTH_USEC_2_RAD
manual_deps = deps_raw * TENTH_USEC_2_RAD

print(f"\nManual conversion:")
print(f"Manual dpsi: {manual_dpsi}")
print(f"Manual deps: {manual_deps}")
print(f"Match radians? dpsi={abs(manual_dpsi - dpsi_skyfield) < 1e-15}, deps={abs(manual_deps - deps_skyfield) < 1e-15}")