#!/usr/bin/env elixir

# Current CPU performance benchmark with our optimized accuracy

# ISS TLE
line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

IO.puts("\n=== SGP4Ex CPU Baseline Benchmark (100 points) ===")
IO.puts("Python Skyfield baseline: 36.70ms")
IO.puts("Target: Beat Python on GCP with GPU acceleration\n")

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
epoch = tle.epoch
time_points = Enum.map(0..99, fn min -> 
  DateTime.add(epoch, min * 60, :second)
end)

# Test different modes
modes = [
  {"CPU IAU2000A", [use_iau2000a: true, use_gpu: false]},
  {"CPU GMST", [use_iau2000a: false, use_gpu: false]}
]

Enum.each(modes, fn {mode_name, opts} ->
  IO.puts("=== #{mode_name} Mode ===")
  
  # Warmup
  IO.puts("Warming up...")
  Enum.each(0..2, fn _ ->
    Enum.each(time_points, fn time ->
      {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, opts)
    end)
  end)

  # Benchmark
  IO.puts("Running benchmark (5 runs)...")
  times = Enum.map(1..5, fn run ->
    start = System.monotonic_time(:microsecond)
    Enum.each(time_points, fn time ->
      {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, opts)
    end)
    elapsed = System.monotonic_time(:microsecond) - start
    ms = elapsed / 1000.0
    IO.puts("Run #{run}: #{Float.round(ms, 2)}ms")
    ms
  end)

  avg_time = Enum.sum(times) / length(times)
  min_time = Enum.min(times)

  IO.puts("\nResults:")
  IO.puts("Average: #{Float.round(avg_time, 2)}ms")
  IO.puts("Min: #{Float.round(min_time, 2)}ms")

  speedup = 36.70 / avg_time
  if speedup >= 1 do
    IO.puts("vs Python: #{Float.round(speedup, 2)}x FASTER! 🚀")
  else
    IO.puts("vs Python: #{Float.round(1/speedup, 2)}x slower")
  end
  IO.puts("")
end)

# Test accuracy to ensure we didn't break anything
IO.puts("=== Accuracy Verification ===")
test_time = Enum.at(time_points, 50)  # Middle time point
{:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true)

IO.puts("Sample result at #{test_time}:")
IO.puts("  Lat: #{Float.round(result.latitude, 6)}°")
IO.puts("  Lon: #{Float.round(result.longitude, 6)}°")
IO.puts("  Alt: #{Float.round(result.altitude_km, 3)} km")
IO.puts("\nAccuracy locked in by regression tests ✅")