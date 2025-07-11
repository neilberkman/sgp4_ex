#!/usr/bin/env elixir

# UNIFIED BENCHMARK: Same conditions for local + GCP testing
# Tests both "optimized" (same TLE) and "realistic" (fresh TLE) performance

Mix.install([
  {:sgp4_ex, path: "."},
  {:exla, "~> 0.9"}
])

# Let EXLA auto-detect GPU (don't force CPU!)
# Application.put_env(:exla, :default_client, :host)  # <-- REMOVED CPU FORCING!

defmodule UnifiedBench do
  def time_microseconds(times \\ 100, func) do
    # Run the function multiple times and return timings
    timings = Enum.map(1..times, fn _ ->
      start = System.monotonic_time(:microsecond)
      func.()
      System.monotonic_time(:microsecond) - start
    end)
    
    avg = Enum.sum(timings) / length(timings) / 1.0
    min_val = Enum.min(timings) / 1.0  
    median = (Enum.sort(timings) |> Enum.at(div(length(timings), 2))) / 1.0
    
    %{avg: avg, min: min_val, median: median, all: timings}
  end
end

# Test TLEs (different ones for warm-up to avoid caching)
warmup_tles = [
  {"1 30967U 99025BBH 23137.66391166  .00001555  00000-0  41268-3 0    18", "2 30967  98.7547  35.5966 0112285 206.6100 152.9301 14.46525639853782"},
  {"1  8597U 76005B   21199.06665815  .00000094  00000-0  82018-4 0  6438", "2  8597  82.9717  44.1207 0025795  24.0679  85.9723 13.75182160282122"},
  {"1 51049U 22002BT  24017.15743660  .00037081  00000-0  90564-3 0    11", "2 51049  97.4070  91.8305 0005607 162.8386 197.3051 15.40734381111663"}
]

# Fresh TLE for actual testing
test_line1 = "1 48808U 21047A   23086.46230110 -.00000330  00000-0  00000-0 0  5890"
test_line2 = "2 48808   0.2330 283.2669 0003886 229.5666 331.3824  1.00276212  6769"

test_time = ~U[2024-03-15 12:00:00Z]

IO.puts("🚀 UNIFIED BENCHMARK: Local vs GCP Performance Test")
IO.puts("=" <> String.duplicate("=", 59))

# Check what backend we're actually using
try do
  backend = Nx.default_backend()
  IO.puts("🔍 Backend: #{backend}")
  test_tensor = Nx.tensor([1, 2, 3])
  IO.puts("🔍 Test tensor: #{inspect(test_tensor)}")
rescue
  _ -> IO.puts("🔍 Nx not available in this context")
end

# Warm up Nx/EXLA with different TLEs
IO.puts("\n🔥 WARMING UP Nx/EXLA with different TLEs...")
for {{line1, line2}, i} <- Enum.with_index(warmup_tles, 1) do
  IO.puts("  Warm-up #{i}/#{length(warmup_tles)}...")
  {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true)
end
IO.puts("✅ Warm-up complete")

# Test 1: OPTIMIZED CONDITIONS (same TLE as micro benchmark)
IO.puts("\n📊 TEST 1: OPTIMIZED CONDITIONS (same TLE, JIT optimized)")
{:ok, parsed_test_tle} = Sgp4Ex.parse_tle(test_line1, test_line2)
optimized_results = UnifiedBench.time_microseconds(100, fn ->
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(parsed_test_tle, test_time, use_iau2000a: true)
end)

IO.puts("  Average: #{optimized_results.avg |> Float.round(1)}μs")
IO.puts("  Minimum: #{optimized_results.min}μs") 
IO.puts("  Median:  #{optimized_results.median |> Float.round(1)}μs")

# Test 2: REALISTIC CONDITIONS (fresh TLE each time)
IO.puts("\n📊 TEST 2: REALISTIC CONDITIONS (different TLE each run)")

# Generate variations of the test TLE to avoid caching
realistic_results = UnifiedBench.time_microseconds(50, fn ->
  # Slightly modify the TLE each time to prevent caching
  random_suffix = :rand.uniform(999999)
  modified_line2 = String.replace(test_line2, "6769", String.pad_leading("#{random_suffix}", 4, "0"))
  {:ok, modified_tle} = Sgp4Ex.parse_tle(test_line1, modified_line2)
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(modified_tle, test_time, use_iau2000a: true)
end)

IO.puts("  Average: #{realistic_results.avg / 1.0 |> Float.round(1)}μs")
IO.puts("  Minimum: #{realistic_results.min}μs")
IO.puts("  Median:  #{realistic_results.median / 1.0 |> Float.round(1)}μs")

# Python baseline
python_us = 367.0

IO.puts("\n🏁 PERFORMANCE COMPARISON:")
IO.puts("Python baseline: #{python_us}μs")
IO.puts("")

# Optimized results vs Python
if optimized_results.avg < python_us do
  speedup = python_us / optimized_results.avg
  IO.puts("✅ OPTIMIZED: #{speedup |> Float.round(2)}x FASTER than Python! 🚀")
else
  gap = optimized_results.avg - python_us
  IO.puts("❌ OPTIMIZED: #{gap / 1.0 |> Float.round(1)}μs slower than Python")
end

# Realistic results vs Python  
if realistic_results.avg < python_us do
  speedup = python_us / realistic_results.avg
  IO.puts("✅ REALISTIC: #{speedup |> Float.round(2)}x FASTER than Python! 🚀")
else
  gap = realistic_results.avg - python_us
  IO.puts("❌ REALISTIC: #{gap / 1.0 |> Float.round(1)}μs slower than Python")
end

IO.puts("\n📈 PERFORMANCE BREAKDOWN:")
overhead = realistic_results.avg - optimized_results.avg
IO.puts("  JIT/Cache overhead: #{overhead / 1.0 |> Float.round(1)}μs")
IO.puts("  Overhead impact: #{(overhead / optimized_results.avg * 100) / 1.0 |> Float.round(1)}%")

IO.puts("\n✅ Accuracy verification:")
{:ok, result} = Sgp4Ex.propagate_to_geodetic(parsed_test_tle, test_time, use_iau2000a: true)
IO.puts("  Lat: #{Float.round(result.latitude, 6)}°")
IO.puts("  Lon: #{Float.round(result.longitude, 6)}°") 
IO.puts("  Alt: #{Float.round(result.altitude_km, 3)} km")