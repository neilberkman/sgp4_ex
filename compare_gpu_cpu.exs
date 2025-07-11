#!/usr/bin/env elixir

# Compare GPU vs CPU GAST results
jd_ut1 = 2460384.999999894
jd_tt = 2460385.000800741

IO.puts("Comparing GPU vs CPU GAST calculations...")

# Test GPU version
gpu_result = Sgp4Ex.IAU2000ANutationGPU.gast_gpu(jd_ut1, jd_tt, 0.0, 0.0)
IO.puts("GPU GAST: #{gpu_result}")

# Test CPU version  
cpu_result = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt, 0.0, 0.0)
IO.puts("CPU GAST: #{cpu_result}")

# Expected from previous accuracy tests
expected = 23.57214131204937
IO.puts("Expected: #{expected}")

# Calculate differences
gpu_diff = abs(gpu_result - expected)
cpu_diff = abs(cpu_result - expected)

IO.puts("\nDifferences from expected:")
IO.puts("GPU diff: #{gpu_diff} hours (#{gpu_diff * 3600} seconds)")
IO.puts("CPU diff: #{cpu_diff} hours (#{cpu_diff * 3600} seconds)")

# Test coordinate transformation with GPU
test_teme = {-6045.0, -3490.0, 2500.0}
test_time = ~U[2024-03-15 12:00:00Z]

{:ok, gpu_geodetic} = Sgp4Ex.CoordinateSystems.teme_to_geodetic(test_teme, test_time, use_gpu: true)
{:ok, cpu_geodetic} = Sgp4Ex.CoordinateSystems.teme_to_geodetic(test_teme, test_time, use_gpu: false)

IO.puts("\nGeodesic coordinate comparison:")
IO.puts("GPU: lat=#{gpu_geodetic.latitude}, lon=#{gpu_geodetic.longitude}, alt=#{gpu_geodetic.altitude_km}")
IO.puts("CPU: lat=#{cpu_geodetic.latitude}, lon=#{cpu_geodetic.longitude}, alt=#{cpu_geodetic.altitude_km}")

lat_diff = abs(gpu_geodetic.latitude - cpu_geodetic.latitude)
lon_diff = abs(gpu_geodetic.longitude - cpu_geodetic.longitude)
alt_diff = abs(gpu_geodetic.altitude_km - cpu_geodetic.altitude_km)

IO.puts("Differences: lat=#{lat_diff}°, lon=#{lon_diff}°, alt=#{alt_diff}km")