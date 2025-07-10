# PRIME DIRECTIVE

## SOLE POINT
Run a fair benchmark comparing Python Skyfield vs Elixir SGP4Ex with GPU acceleration to see if EXLA GPU can match/beat NumPy's optimized performance.

## NON-NEGOTIABLE SUCCESS CRITERIA

1. **Must run on the GCP GPU instance** (not local Mac)
   - Instance: sgp4-gpu-dl (35.202.182.71)
   - NOT on local macOS

2. **Must FIRST verify EXLA GPU is working**
   - Run simple Elixir script before any benchmark
   - MUST see "cuda:0" in tensor output
   - NO cuDNN errors allowed

3. **Must use `propagate_to_geodetic()`** 
   - Includes coordinate conversion like Skyfield does
   - NOT just SGP4 propagation

4. **Must get actual timing numbers**
   - Python Skyfield baseline: ~36.70ms for 100 propagations
   - SGP4Ex with EXLA GPU: ??? (measure this)

5. **Must use correct versions**
   - Erlang 28.0.1
   - Elixir 1.18.4-otp-28

## WORKFLOW
1. SSH to GCP instance
2. Verify GPU with simple script
3. Fix any cuDNN errors
4. Run fair benchmark
5. Report numbers

That's it. Everything else is noise.