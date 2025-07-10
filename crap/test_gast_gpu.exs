#!/usr/bin/env elixir

# Start the application
Application.ensure_all_started(:sgp4_ex)

# Test the GPU-optimized GAST calculation

# Sample date - use a known Julian Date
jd_ut1 = 2460384.0  # 2024-03-15 12:00:00 UTC
jd_tt = jd_ut1 + 69.184 / 86400.0

IO.puts("Testing GAST calculations...")
IO.puts("JD UT1: #{jd_ut1}")
IO.puts("JD TT: #{jd_tt}")

# Test CPU version
cpu_gast = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
IO.puts("\nCPU GAST: #{cpu_gast} hours")

# Test GPU version
gpu_gast = Sgp4Ex.IAU2000ANutationGPU.gast_gpu(jd_ut1, jd_tt)
IO.puts("GPU GAST: #{gpu_gast} hours")

# Compare
diff = abs(cpu_gast - gpu_gast)
IO.puts("\nDifference: #{diff} hours (#{diff * 3600} seconds)")

# Test batch rotation
teme_positions = Nx.tensor([
  [7000.0, 0.0, 0.0],
  [0.0, 7000.0, 0.0],
  [0.0, 0.0, 7000.0]
], type: :f64)

IO.puts("\nTesting batch TEME to ECEF conversion...")
ecef_positions = Sgp4Ex.CoordinateSystems.teme_to_ecef_gpu_batch(teme_positions, jd_ut1, jd_tt)
IO.puts("ECEF positions shape: #{inspect(Nx.shape(ecef_positions))}")
IO.puts("ECEF positions:\n#{inspect(Nx.to_list(ecef_positions))}")

# Test a single position for comparison
IO.puts("\nComparing single position conversion...")
{x_ecef, y_ecef, z_ecef} = Sgp4Ex.CoordinateSystems.teme_to_ecef(
  {7000.0, 0.0, 0.0}, 
  ~U[2024-03-15 12:00:00.000000Z],
  use_gpu: true
)
IO.puts("Single ECEF: {#{x_ecef}, #{y_ecef}, #{z_ecef}}")

# Compare with batch result
batch_first = Nx.to_list(ecef_positions[0])
IO.puts("Batch ECEF[0]: #{inspect(batch_first)}")
IO.puts("Difference: #{abs(x_ecef - Enum.at(batch_first, 0))} km")