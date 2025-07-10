#!/usr/bin/env python3
"""
Extract fundamental argument coefficients from Skyfield source.
"""

import skyfield.nutationlib as nutlib
import inspect
import numpy as np

def extract_fundamental_coefficients():
    print("=== SKYFIELD FUNDAMENTAL ARGUMENT COEFFICIENTS ===")
    
    try:
        # Try to access the fundamental arguments function source
        print("Available functions in nutationlib:")
        for name in dir(nutlib):
            if 'fundamental' in name.lower():
                print(f"  {name}")
        
        # Check if we can access the source
        if hasattr(nutlib, 'fundamental_arguments'):
            print(f"\nfundamental_arguments function: {nutlib.fundamental_arguments}")
            try:
                source = inspect.getsource(nutlib.fundamental_arguments)
                print("Source code:")
                print(source)
            except:
                print("Could not get source code")
        
        # Try to access coefficients directly
        for attr in dir(nutlib):
            if any(x in attr.lower() for x in ['coeff', 'fa0', 'fa1', 'fa2', 'fa3', 'fa4']):
                print(f"\nFound coefficient attribute: {attr}")
                try:
                    value = getattr(nutlib, attr)
                    print(f"  Value: {value}")
                except:
                    print(f"  Could not access {attr}")
                    
    except Exception as e:
        print(f"Error accessing nutationlib: {e}")
    
    # Try to calculate and examine the result step by step
    print("\n=== STEP BY STEP CALCULATION ===")
    try:
        from skyfield.api import load, utc
        from datetime import datetime
        
        # Same test case
        dt = datetime(2024, 3, 15, 12, 0, 0, tzinfo=utc)
        ts = load.timescale()
        t = ts.from_datetime(dt)
        
        print(f"JD_TT: {t.tt}")
        print(f"Centuries from J2000: {(t.tt - 2451545.0) / 36525.0}")
        
        # Try to call fundamental arguments if it exists
        if hasattr(nutlib, 'fundamental_arguments'):
            fa = nutlib.fundamental_arguments(t.tt)
            print(f"Fundamental arguments result: {fa}")
        
    except Exception as e:
        print(f"Step-by-step calculation failed: {e}")

    # Try to inspect the Skyfield installation
    print(f"\n=== SKYFIELD INFO ===")
    try:
        import skyfield
        print(f"Skyfield version: {skyfield.__version__}")
        print(f"Skyfield location: {skyfield.__file__}")
        
        # Check for data files
        print("\nNutationlib attributes:")
        for attr in sorted(dir(nutlib)):
            if not attr.startswith('_'):
                print(f"  {attr}")
                
    except Exception as e:
        print(f"Skyfield info failed: {e}")

if __name__ == "__main__":
    extract_fundamental_coefficients()