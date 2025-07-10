#!/usr/bin/env python3
"""
Extract the exact coefficient arrays from Skyfield for Elixir implementation
"""

import numpy as np
from skyfield.functions import load_bundled_npy
import json

def extract_coefficients():
    """Extract all coefficient arrays from Skyfield's nutation.npz file"""
    
    # Load the coefficient data
    _arrays = load_bundled_npy('nutation.npz')
    
    print("=== Skyfield Coefficient Extraction ===")
    print("Arrays found in nutation.npz:")
    for key in _arrays.keys():
        print(f"  {key}: {_arrays[key].shape}")
    
    # Extract the main coefficient arrays
    coefficients = {}
    
    # Lunisolar nutation coefficients
    coefficients['nals_t'] = _arrays['nals_t'].tolist()
    coefficients['lunisolar_longitude_coefficients'] = _arrays['lunisolar_longitude_coefficients'].tolist()
    coefficients['lunisolar_obliquity_coefficients'] = _arrays['lunisolar_obliquity_coefficients'].tolist()
    
    # Planetary nutation coefficients  
    coefficients['napl_t'] = _arrays['napl_t'].tolist()
    coefficients['nutation_coefficients_longitude'] = _arrays['nutation_coefficients_longitude'].tolist()
    coefficients['nutation_coefficients_obliquity'] = _arrays['nutation_coefficients_obliquity'].tolist()
    
    # Equation of equinoxes coefficients
    coefficients['ke0_t'] = _arrays['ke0_t'].tolist()
    coefficients['ke1'] = _arrays['ke1'].tolist()
    coefficients['se0_t_0'] = _arrays['se0_t_0'].tolist()
    coefficients['se0_t_1'] = _arrays['se0_t_1'].tolist()
    
    print(f"\nExtracted coefficient arrays:")
    for key, value in coefficients.items():
        if isinstance(value, list):
            shape = np.array(value).shape
            print(f"  {key}: {shape}")
    
    # Save to JSON for Elixir
    with open('skyfield_coefficients.json', 'w') as f:
        json.dump(coefficients, f, indent=2)
    
    print(f"\nCoefficients saved to skyfield_coefficients.json")
    
    # Also extract fundamental argument coefficients for verification
    from skyfield.nutationlib import fa0, fa1, fa2, fa3, fa4, anomaly_constant, anomaly_coefficient
    
    fundamental_args = {
        'fa0': fa0.tolist(),
        'fa1': fa1.tolist(), 
        'fa2': fa2.tolist(),
        'fa3': fa3.tolist(),
        'fa4': fa4.tolist(),
        'anomaly_constant': list(anomaly_constant),
        'anomaly_coefficient': list(anomaly_coefficient)
    }
    
    with open('skyfield_fundamental_args.json', 'w') as f:
        json.dump(fundamental_args, f, indent=2)
        
    print(f"Fundamental arguments saved to skyfield_fundamental_args.json")
    
    # Extract some test values for verification
    from skyfield.nutationlib import iau2000a, fundamental_arguments
    
    test_cases = []
    for jd in [2451545.0, 2451545.5, 2460000.0]:  # J2000, J2000+0.5, future date
        t_centuries = (jd - 2451545.0) / 36525.0
        fa = fundamental_arguments(t_centuries)
        dpsi, deps = iau2000a(jd)
        
        test_cases.append({
            'jd_tt': jd,
            't_centuries': t_centuries,
            'fundamental_arguments': fa.tolist(),
            'dpsi': float(dpsi),
            'deps': float(deps)
        })
    
    with open('skyfield_test_cases.json', 'w') as f:
        json.dump(test_cases, f, indent=2)
        
    print(f"Test cases saved to skyfield_test_cases.json")
    
    # Show sample data structure
    print(f"\nSample nals_t (first 5 rows):")
    nals_sample = np.array(coefficients['nals_t'][:5])
    print(nals_sample)
    
    print(f"\nSample longitude coefficients (first 5 rows):")
    lon_sample = np.array(coefficients['lunisolar_longitude_coefficients'][:5])
    print(lon_sample)
    
    return coefficients

if __name__ == "__main__":
    extract_coefficients()