# SGP4 Optimization Analysis: Python vs Elixir Implementation

## Executive Summary

After analyzing the Python SGP4 and Skyfield architecture, I've identified several key optimization patterns that our Elixir implementation is missing or could improve upon.

## 1. Separation of Initialization and Propagation ✓ PARTIALLY IMPLEMENTED

### Python Pattern:
- **Satrec.twoline2rv()**: Initializes satellite once, returns reusable object
- **satrec.sgp4()**: Propagates without re-initialization
- **satrec.sgp4_array()**: Batch propagation with single initialization

### Elixir Status:
- ✓ We have stateful API in `Sgp4Ex.Satellite` module
- ✓ NIF v2 supports stateful satellites
- ✗ Not consistently used throughout codebase
- ✗ Legacy API still re-initializes for each propagation

### Recommendations:
1. Make stateful API the default for all multi-epoch operations
2. Deprecate the legacy stateless API for batch operations
3. Update documentation to emphasize stateful pattern

## 2. Native Array Processing with OpenMP ✗ MISSING

### Python Pattern:
```cpp
#pragma omp parallel for
for (Py_ssize_t i=0; i < imax; i++) {
    elsetrec &satrec = raw_satrec_array[i];
    for (Py_ssize_t j=0; j < jmax; j++) {
        // Process in parallel
    }
}
```

### Elixir Status:
- ✗ No OpenMP parallelization in NIF
- ✗ Sequential processing only
- ✗ No batch processing at C++ level

### Recommendations:
1. Add OpenMP support to NIF for batch operations
2. Implement native batch processing that accepts arrays
3. Process multiple satellites/epochs in parallel at C++ level

## 3. Memory-Efficient Batch Operations ✗ MISSING

### Python Pattern:
- Pre-allocates output arrays
- Processes directly into pre-allocated memory
- Avoids intermediate allocations

### Elixir Status:
- Creates new Elixir terms for each result
- No pre-allocation strategy
- Potential memory churn for large batches

### Recommendations:
1. Implement batch NIF functions that return results in bulk
2. Consider using binary references for large result sets
3. Minimize term creation overhead

## 4. Caching Strategy Differences

### Python Pattern:
- Caches at object level (Satrec instance)
- No global caching
- User manages satellite instances

### Elixir Status:
- ✓ Global Cachex-based caching
- ✓ Automatic TTL management
- ✗ May have overhead for simple use cases

### Recommendations:
1. Keep Cachex for complex scenarios
2. Add lightweight in-process caching option
3. Allow users to choose caching strategy

## 5. Direct Buffer Access ✗ MISSING

### Python Pattern:
```cpp
PyObject_GetBuffer(jd_arg, &jd_buf, PyBUF_SIMPLE)
// Direct memory access without copying
```

### Elixir Status:
- Must convert between Elixir terms and C++ types
- No direct buffer access
- Overhead for large arrays

### Recommendations:
1. Investigate binary references for large data
2. Consider IOList-style data passing
3. Minimize data copying in NIF

## 6. Error Handling Optimization

### Python Pattern:
- Returns error codes in result array
- Batch operations continue despite individual errors
- NaN for invalid results

### Elixir Status:
- ✓ Good error handling
- ✗ May stop batch on first error
- ✗ No partial result support

### Recommendations:
1. Return error codes with results
2. Allow batch operations to continue
3. Provide partial results option

## 7. Specialized Array Types ✗ MISSING

### Python Pattern:
- `SatrecArray` for multiple satellites
- Optimized for satellite × time matrix operations
- Built-in broadcasting support

### Elixir Status:
- No specialized array types
- Manual iteration over satellites/times
- No matrix operation support

### Recommendations:
1. Create `SatelliteArray` module
2. Implement efficient matrix operations
3. Support broadcasting patterns

## 8. Frame-Specific Optimizations

### Python Pattern (Skyfield):
```python
def cheat(t):
    """Avoid computing expensive values that cancel out anyway."""
    t.gast = t.tt * 0.0
    t.M = t.MT = _identity
```

### Elixir Status:
- ✗ No frame-specific optimizations
- ✗ Always computes full transformations
- ✗ No shortcut paths

### Recommendations:
1. Identify transformation shortcuts
2. Add optimization flags
3. Skip unnecessary computations

## 9. Locale-Safe Numeric Parsing

### Python Pattern:
```cpp
char *old_locale = NULL;
if (switch_locale)
    old_locale = setlocale(LC_NUMERIC, "C");
```

### Elixir Status:
- ✓ Elixir parsing is locale-independent
- No issues here

## 10. GPU Acceleration Integration

### Python Status:
- No native GPU support
- Users must implement manually

### Elixir Status:
- ✓ EXLA/GPU support for IAU2000A nutation
- ✓ Potential for GPU batch processing
- ✗ Not integrated with SGP4 propagation

### Recommendations:
1. Extend GPU support to SGP4 propagation
2. Create hybrid CPU/GPU pipeline
3. Automatic GPU offloading for large batches

## Implementation Priority

1. **High Priority**:
   - Native batch processing with pre-allocation
   - OpenMP parallelization in NIF
   - Consistent use of stateful API

2. **Medium Priority**:
   - Direct buffer access optimization
   - Frame-specific shortcuts
   - Specialized array types

3. **Low Priority**:
   - Alternative caching strategies
   - Matrix operation support
   - Advanced error handling

## Next Steps

1. Benchmark current implementation vs Python
2. Implement OpenMP batch processing
3. Create native array operations
4. Profile and optimize memory usage
5. Document performance best practices