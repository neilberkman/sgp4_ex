#!/usr/bin/env elixir

# ISS TLE
line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

# Parse TLE once to use in direct test
{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
epoch = tle.epoch
time_points = Enum.map(0..99, fn min -> 
  DateTime.add(epoch, min * 60, :second)
end)

IO.puts("\n=== SGP4Ex Cache Performance Test ===")

# Test 1: Direct calls (no caching)
IO.puts("\n1. Direct calls (current implementation):")
direct_start = System.monotonic_time(:microsecond)
Enum.each(time_points, fn time ->
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time)
end)
direct_time = (System.monotonic_time(:microsecond) - direct_start) / 1000.0
IO.puts("Time: #{Float.round(direct_time, 2)}ms")

# Test 2: Using cached server
IO.puts("\n2. Using SatelliteServer (cached):")
cache_start = System.monotonic_time(:microsecond)
results = Sgp4Ex.SatelliteServer.propagate_many_to_geodetic(line1, line2, time_points)
cache_time = (System.monotonic_time(:microsecond) - cache_start) / 1000.0
IO.puts("Time: #{Float.round(cache_time, 2)}ms")

# Verify results match
IO.puts("\n3. Verifying results match...")
direct_results = Enum.map(time_points, fn time ->
  {:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, time)
  result
end)

cached_results = Enum.map(results, fn {:ok, result} -> result end)

matches = Enum.zip(direct_results, cached_results)
|> Enum.all?(fn {d, c} -> 
  abs(d.latitude - c.latitude) < 0.00001 &&
  abs(d.longitude - c.longitude) < 0.00001 &&
  abs(d.altitude_km - c.altitude_km) < 0.001
end)

if matches do
  IO.puts("✅ Results match!")
else
  IO.puts("❌ Results differ!")
end

# Show cache stats
IO.puts("\n4. Cache statistics:")
stats = Sgp4Ex.SatelliteServer.stats()
IO.inspect(stats)

IO.puts("\n5. Performance comparison:")
IO.puts("Direct: #{Float.round(direct_time, 2)}ms")
IO.puts("Cached: #{Float.round(cache_time, 2)}ms")
if cache_time < direct_time do
  speedup = direct_time / cache_time
  IO.puts("🚀 Cache is #{Float.round(speedup, 2)}x faster!")
else
  IO.puts("❌ Cache is slower (overhead from GenServer)")
end

IO.puts("\nPython Skyfield baseline: 36.70ms")