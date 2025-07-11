# GUY PEARCE MEMENTO TATTOO - THINGS CLAUDE KEEPS FORGETTING

## CRITICAL INFRASTRUCTURE FACTS
- **LOCAL MAC**: NO GPU! Uses CPU only (Metal doesn't work with EXLA)
- **GCP INSTANCE**: `sgp4-gpu-dl` in `us-central1-a` zone with NVIDIA L4 GPU + CUDA 12.4
- **SSH COMMAND**: `gcloud compute ssh sgp4-gpu-dl --zone=us-central1-a --command="..."`
- **ENVIRONMENT**: `. ~/.asdf/asdf.sh` MUST be sourced before running mix
- **COSTS**: User is paying $15/day for GCP instance, don't waste their money testing locally

## PERFORMANCE TESTING RULES
- **JIT COMPILATION**: First run is SLOW (100ms+), subsequent runs are fast
- **WARM START REQUIRED**: Always warm up operations before measuring performance  
- **REALISTIC TESTS**: Test fresh TLEs, not cached/repeated operations
- **PYTHON BASELINE**: 0.027ms per satellite (verified multiple times)
- **COMPARE APPLES TO APPLES**: Local warm vs GCP warm, not local warm vs GCP cold

## ACCURACY REQUIREMENTS (USER IS ADAMANT)
- **GAST REQUIRED**: Must use Greenwich Apparent Sidereal Time with full IAU 2000A nutation
- **NO APPROXIMATIONS**: User specifically rejected GMST-only approximation 
- **SKYFIELD COMPATIBILITY**: Must match Skyfield's default behavior exactly
- **FAST OPTION AVAILABLE**: gast_fast() exists but GAST is the default requirement

## IMPLEMENTATION LESSONS
- **TENSOR OVERHEAD**: Small tensor operations have massive GPU overhead
- **BATCH VS SINGLE**: GPU is for batches, not single satellite calculations  
- **COEFFICIENT CACHING**: Don't recalculate fundamental arguments every time
- **UNIFIED MODULE**: One module with Nx.Defn, automatic CPU/GPU backend selection

## TESTING WORKFLOW
1. Test accuracy first (make sure results are correct)
2. Test performance on GCP with warm start
3. Compare to Python baseline (0.027ms per satellite)
4. Don't waste time on local Mac performance claims

## PREVIOUS EPIC FAILURES TO AVOID
- ❌ Testing locally and claiming GPU performance
- ❌ Using approximations without permission  
- ❌ Measuring JIT compilation time as operation time
- ❌ Deleting working GPU code and replacing with CPU
- ❌ Claiming "beat Python" based on warm local tests
- ❌ Forgetting that Python uses FULL nutation too
- ❌ Oscillating between fast approximations and slow implementations

## CURRENT STATUS
- We have unified IAU 2000A nutation module (100% accuracy achieved)
- GCP instance has NVIDIA L4 GPU with CUDA working
- Performance is currently 777x slower than Python (21ms vs 0.027ms)
- Need to optimize the nutation calculation without breaking accuracy

## THE ACTUAL PROBLEM
Python Skyfield does full IAU 2000A nutation in 0.027ms. We do the same calculation in 21ms on GPU. The problem is OUR IMPLEMENTATION IS INEFFICIENT, not that nutation is inherently expensive.

## CRITICAL INSIGHTS FROM USER
- **NUTATION IS HIGHLY TENSORIZABLE** - Stop making excuses about GPU overhead
- **NO DIRECT EVIDENCE** - Don't assume "Python probably uses CPU" without proof
- **PRE-COMPILE CONSTANTS** - All constants should be pre-compiled anyway
- **SINGLE NEW TLE PERFORMANCE** - Focus on single, fresh TLE performance (caching comes later)
- **INVESTIGATE PYTHON CODE** - Actually look at what Python does instead of guessing
- **CHECK CPU->GPU BOUNCING** - Are we transferring between CPU and GPU within calculations?
- **PURE TENSOR OPERATIONS** - All nutation should be pure tensor ops, no CPU calls mixed in
- **NEVER CREATE CPU/GPU SPECIFIC CODE** - Use Nx only! Nx will choose the backend automatically!
- **20TH EPIPHANY ALERT** - I keep "discovering" the tensor bouncing issue then breaking it again

## WHEN FIXING ISSUES (CRITICAL PROCESS)
- **SOLVE INDIVIDUAL ISSUES** - One thing at a time, don't mix fixes
- **RERUN TESTS** - Always verify accuracy is maintained
- **DO NOT REDUCE ACCURACY TOLERANCES** - Only increase them, never decrease
- **REVIEW THIS TATTOO BEFORE COMMITTING** - Check all lessons learned
- **ONLY THEN COMMIT INCREMENTAL PROVEN CHANGES** - No big changes without verification

## NEVER FORGET
- Don't blame the calculation - blame the implementation
- Python proves it can be fast, so we can be fast too
- Always test on GCP where user is paying money
- JIT warmup is required for fair performance comparison
- INVESTIGATE PYTHON IMPLEMENTATION before making assumptions
- Pre-compile ALL constants, not just some
- Nutation should be highly optimized with tensors, not avoided