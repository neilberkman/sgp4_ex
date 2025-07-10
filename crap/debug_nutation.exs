#!/usr/bin/env mix run

# Debug the 67% error in GPU nutation calculation
# Compare CPU vs GPU nutation for the same Julian date

IO.puts("\n=== Debugging GPU Nutation Error ===\n")

# Use a test Julian date 
jd_tt = 2451545.0  # J2000 epoch

IO.puts("Testing Julian Date: #{jd_tt}")

# Test CPU nutation
{dpsi_cpu, deps_cpu} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
IO.puts("\nCPU Results:")
IO.puts("  dpsi: #{dpsi_cpu}")
IO.puts("  deps: #{deps_cpu}")

# Test GPU nutation  
{dpsi_gpu, deps_gpu} = Sgp4Ex.IAU2000ANutationGPU.iau2000a_nutation_gpu(jd_tt)
IO.puts("\nGPU Results:")
IO.puts("  dpsi: #{dpsi_gpu}")
IO.puts("  deps: #{deps_gpu}")

# Calculate differences
dpsi_diff = abs(dpsi_cpu - dpsi_gpu)
dpsi_percent_error = (dpsi_diff / abs(dpsi_cpu)) * 100

deps_diff = abs(deps_cpu - deps_gpu)
deps_percent_error = (deps_diff / abs(deps_cpu)) * 100

IO.puts("\nDifferences:")
IO.puts("  dpsi difference: #{dpsi_diff}")
IO.puts("  dpsi percent error: #{dpsi_percent_error}%")
IO.puts("  deps difference: #{deps_diff}")
IO.puts("  deps percent error: #{deps_percent_error}%")

if dpsi_percent_error > 1.0 or deps_percent_error > 1.0 do
  IO.puts("\n❌ SIGNIFICANT ERROR DETECTED!")
  IO.puts("This explains the coordinate transformation issues.")
else
  IO.puts("\n✅ Results are close")
end