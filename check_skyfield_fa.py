#!/usr/bin/env python3

import sys
sys.path.append('/Users/neil/xuku/sgp4_ex/crap/python-skyfield')

import numpy as np
from skyfield.nutationlib import fundamental_arguments, fa0, fa1
from skyfield.constants import T0, ASEC360, ASEC2RAD

# Get the fundamental arguments calculation from Skyfield
jd_tt = 2460385.000800741
t = (jd_tt - T0) / 36525.0

print(f"T: {t}")

# Use Skyfield's function directly
fa_skyfield = fundamental_arguments(t, 5)

print(f"Skyfield FA[0]: {fa_skyfield[0]}")

# Check Skyfield's actual coefficients
print(f"\n=== Skyfield coefficients ===")
print(f"fa0: {fa0.flatten()}")
print(f"fa1: {fa1.flatten()}")

# My coefficients
fa0_mine = [3.154384999847899, 2.357551718265301, 1.6280158027288272, 5.198471222772339, 2.182438624381695]
fa1_mine = [628_307_584_999.0, 8_399_684.6073, 8_433_463.1576, 7_771_374.8964, -33.86238]

print(f"\n=== My coefficients ===")
print(f"fa0: {fa0_mine}")
print(f"fa1: {fa1_mine}")

# Manual calculation using Skyfield's approach
print(f"\n=== Skyfield manual calculation ===")
# Skyfield: a = fa0[0] + fa1[0]*t, then fmod(a, ASEC360), then * ASEC2RAD
skyfield_a0 = fa0[0,0] + fa1[0,0] * t
skyfield_a0_mod = np.fmod(skyfield_a0, ASEC360)
skyfield_a0_rad = skyfield_a0_mod * ASEC2RAD
print(f"Skyfield FA[0] manual: {skyfield_a0_rad}")
print(f"Matches Skyfield function: {np.allclose(skyfield_a0_rad, fa_skyfield[0])}")

print(f"\n=== Converting my coefficients to Skyfield format ===")
# I think my coefficients might be using different units
# Let me see if they match when converted
asec2rad = 4.848136811095359935899141e-6
my_to_skyfield_fa0 = fa0_mine[0] / asec2rad  # Convert radians to arcseconds
my_to_skyfield_fa1 = fa1_mine[0] / asec2rad  # Convert arcseconds/century to arcseconds/century
print(f"My fa0[0] in arcseconds: {my_to_skyfield_fa0}")
print(f"My fa1[0] in arcseconds: {my_to_skyfield_fa1}")
print(f"Skyfield fa0[0]: {fa0[0,0]}")  
print(f"Skyfield fa1[0]: {fa1[0,0]}")