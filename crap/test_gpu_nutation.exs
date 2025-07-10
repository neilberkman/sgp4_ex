#!/usr/bin/env elixir

# Configure EXLA for GPU
Application.put_env(:exla, :clients,
  cuda: [platform: :cuda, preallocate: false],
  host: [platform: :host]
)
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)

# ISS TLE
line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

IO.puts("\n=== SGP4Ex GPU Nutation Test ===")

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
epoch = tle.epoch
test_time = DateTime.add(epoch, 60 * 60, :second)  # 1 hour after epoch

# Test regular IAU2000A
IO.puts("\n1. Testing regular IAU2000A nutation...")
{:ok, result1} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true, use_gpu: false)
IO.inspect(result1, label: "Regular result")

# Test GPU IAU2000A
IO.puts("\n2. Testing GPU IAU2000A nutation...")
{:ok, result2} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true, use_gpu: true)
IO.inspect(result2, label: "GPU result")

# Compare results
lat_diff = abs(result1.latitude - result2.latitude)
lon_diff = abs(result1.longitude - result2.longitude)
alt_diff = abs(result1.altitude_km - result2.altitude_km)

IO.puts("\n3. Differences:")
IO.puts("Latitude diff: #{lat_diff} degrees")
IO.puts("Longitude diff: #{lon_diff} degrees")
IO.puts("Altitude diff: #{alt_diff} km")

if lat_diff < 0.0001 and lon_diff < 0.0001 and alt_diff < 0.001 do
  IO.puts("\n✅ GPU and CPU results match!")
else
  IO.puts("\n❌ Results differ significantly!")
end

# Benchmark
IO.puts("\n4. Running benchmark...")
time_points = Enum.map(0..99, fn min -> 
  DateTime.add(epoch, min * 60, :second)
end)

# CPU benchmark
IO.puts("\nCPU (10 runs):")
cpu_times = Enum.map(1..10, fn _ ->
  start = System.monotonic_time(:microsecond)
  Enum.each(time_points, fn time ->
    {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, use_iau2000a: true, use_gpu: false)
  end)
  elapsed = System.monotonic_time(:microsecond) - start
  elapsed / 1000.0
end)
cpu_avg = Enum.sum(cpu_times) / length(cpu_times)
IO.puts("Average: #{Float.round(cpu_avg, 2)}ms")

# GPU benchmark
IO.puts("\nGPU (10 runs):")
gpu_times = Enum.map(1..10, fn _ ->
  start = System.monotonic_time(:microsecond)
  Enum.each(time_points, fn time ->
    {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, use_iau2000a: true, use_gpu: true)
  end)
  elapsed = System.monotonic_time(:microsecond) - start
  elapsed / 1000.0
end)
gpu_avg = Enum.sum(gpu_times) / length(gpu_times)
IO.puts("Average: #{Float.round(gpu_avg, 2)}ms")

speedup = cpu_avg / gpu_avg
IO.puts("\n🚀 GPU speedup: #{Float.round(speedup, 2)}x")
IO.puts("Python baseline: 36.70ms")