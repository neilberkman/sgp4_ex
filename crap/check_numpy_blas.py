#!/usr/bin/env python3
"""
Check what BLAS backend NumPy is using on this Mac
"""

import numpy as np
import time

print("=== NumPy BLAS Configuration ===")
print(f"NumPy version: {np.__version__}")
print()

# Check BLAS configuration
try:
    config = np.__config__.show()
    print("NumPy build configuration:")
    print(config)
except:
    print("Could not get NumPy config")

print("\n=== BLAS Library Info ===")
try:
    from numpy.distutils.system_info import get_info
    blas_info = get_info('blas')
    print("BLAS info:", blas_info)
    
    lapack_info = get_info('lapack') 
    print("LAPACK info:", lapack_info)
except:
    print("Could not get BLAS/LAPACK info")

print("\n=== Matrix Operation Performance Test ===")

# Test matrix multiplication performance 
sizes = [100, 500, 1000]
for size in sizes:
    A = np.random.random((size, size))
    B = np.random.random((size, size))
    
    # Warm up
    np.dot(A, B)
    
    # Time it
    start = time.perf_counter()
    C = np.dot(A, B)
    elapsed = time.perf_counter() - start
    
    operations = 2 * size**3  # Approximate FLOPs for matrix multiply
    gflops = operations / elapsed / 1e9
    
    print(f"Matrix {size}x{size}: {elapsed*1000:.2f}ms ({gflops:.1f} GFLOPS)")

print("\n=== Check for Accelerate Framework ===")
try:
    import subprocess
    result = subprocess.run(['otool', '-L'], input=np.__file__, 
                          capture_output=True, text=True, shell=True)
    if 'Accelerate' in result.stdout:
        print("✅ NumPy appears to be linked with Accelerate framework")
    else:
        print("❌ No Accelerate framework detected")
except:
    print("Could not check Accelerate linkage")