#!/usr/bin/env python3

import sys
sys.path.append('/Users/neil/xuku/sgp4_ex/crap/python-skyfield')

from skyfield.nutationlib import _arrays

nals_t = _arrays['nals_t']
lunisolar_longitude_coefficients = _arrays['lunisolar_longitude_coefficients']

print("=== SKYFIELD COEFFICIENTS ===")
print(f"nals_t shape: {nals_t.shape}")
print(f"First multiplier: {nals_t[0]}")
print(f"First longitude coeff: {lunisolar_longitude_coefficients[0]}")

# Check if they match my data
print(f"\n=== COMPARISON ===")
print("My first multiplier: [0, 0, 0, 0, 1]")
print("My first longitude coeff: [-172064161.0, -174666.0, 33386.0]")

print(f"\nMultiplier match: {list(nals_t[0]) == [0, 0, 0, 0, 1]}")
print(f"Coeff match: {list(lunisolar_longitude_coefficients[0]) == [-172064161.0, -174666.0, 33386.0]}")

# Check a few more  
print(f"\nSecond multiplier: {nals_t[1]}")
print(f"Second longitude coeff: {lunisolar_longitude_coefficients[1]}")
print("My second longitude coeff: [-13170906.0, -1675.0, -13696.0]")