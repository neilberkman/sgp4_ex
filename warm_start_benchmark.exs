#!/usr/bin/env elixir

# Force CPU-only for all operations
Application.put_env(:exla, :clients, host: [platform: :host])
Application.put_env(:exla, :default_client, :host)
Nx.default_backend(EXLA.Backend)
IO.puts("🔵 FORCED CPU backend for all operations")

# Different TLEs for warm-up (real TLEs from database)
warmup_tles = [
  {"1 30967U 99025BBH 23137.66391166  .00001555  00000-0  41268-3 0    18", "2 30967  98.7547  35.5966 0112285 206.6100 152.9301 14.46525639853782"},
  {"1  8597U 76005B   21199.06665815  .00000094  00000-0  82018-4 0  6438", "2  8597  82.9717  44.1207 0025795  24.0679  85.9723 13.75182160282122"},
  {"1 51049U 22002BT  24017.15743660  .00037081  00000-0  90564-3 0    11", "2 51049  97.4070  91.8305 0005607 162.8386 197.3051 15.40734381111663"}
]

# Fresh TLE for actual benchmark (different from warm-up)
benchmark_line1 = "1 48808U 21047A   23086.46230110 -.00000330  00000-0  00000-0 0  5890"
benchmark_line2 = "2 48808   0.2330 283.2669 0003886 229.5666 331.3824  1.00276212  6769"

IO.puts("\n=== WARM START BENCHMARK ===")
IO.puts("Warming up Nx JIT with different TLEs, then testing fresh TLE\n")

# EXTENSIVE warm-up with DIFFERENT TLEs - force XLA compilation
IO.puts("🔥 WARMING UP Nx JIT (different TLEs to avoid caching)...")
Enum.each(1..50, fn i ->
  {line1, line2} = Enum.at(warmup_tles, rem(i, 3))
  {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
  test_time = DateTime.add(tle.epoch, i * 60, :second)
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true)
end)

IO.puts("✅ JIT warm-up complete. Now testing FRESH TLE performance...\n")

# Parse the fresh benchmark TLE
{:ok, benchmark_tle} = Sgp4Ex.parse_tle(benchmark_line1, benchmark_line2)
benchmark_time = DateTime.add(benchmark_tle.epoch, 75 * 60, :second)

# Test FRESH TLE multiple times 
single_times = Enum.map(1..20, fn run ->
  start = System.monotonic_time(:microsecond)
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(benchmark_tle, benchmark_time, use_iau2000a: true)
  elapsed = System.monotonic_time(:microsecond) - start
  ms = elapsed / 1000.0
  if rem(run, 5) == 0, do: IO.puts("Run #{run}: #{Float.round(ms, 3)}ms")
  ms
end)

avg_time = Enum.sum(single_times) / length(single_times)
min_time = Enum.min(single_times)
median_time = Enum.sort(single_times) |> Enum.at(div(length(single_times), 2))

IO.puts("\n🚀 ELIXIR RESULTS (single satellite, warm start):")
IO.puts("Average: #{Float.round(avg_time, 3)}ms")
IO.puts("Minimum: #{Float.round(min_time, 3)}ms") 
IO.puts("Median:  #{Float.round(median_time, 3)}ms")
IO.puts("\nCompare this to Python Skyfield: 36.70ms per 100 satellites = 0.367ms per satellite")

python_per_satellite = 36.70 / 100.0
speedup = python_per_satellite / avg_time

if speedup >= 1 do
  IO.puts("🎉 Elixir is #{Float.round(speedup, 2)}x FASTER than Python per satellite!")
else
  IO.puts("❌ Python is #{Float.round(1/speedup, 2)}x faster per satellite")
end

# Test accuracy
{:ok, result} = Sgp4Ex.propagate_to_geodetic(benchmark_tle, benchmark_time, use_iau2000a: true)
IO.puts("\n✅ Accuracy check:")
IO.puts("  Lat: #{Float.round(result.latitude, 6)}°")
IO.puts("  Lon: #{Float.round(result.longitude, 6)}°") 
IO.puts("  Alt: #{Float.round(result.altitude_km, 3)} km")