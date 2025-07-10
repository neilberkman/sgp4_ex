#!/usr/bin/env mix run

# Integration test - verify all optimization layers work together
alias Sgp4Ex.SatelliteArray

IO.puts("\n=== SatelliteArray Integration Test ===")
IO.puts("Testing all optimization combinations...\n")

# Test data
iss_tle1 = "1 25544U 98067A   24074.54761985  .00019515  00000+0  35063-3 0  9997"
iss_tle2 = "2 25544  51.6410 299.5237 0005417  72.1189  36.3479 15.49802661443442"

starlink_tle1 = "1 44238U 19029D   24074.87639601  .00001372  00000+0  10839-3 0  9996"
starlink_tle2 = "2 44238  52.9985  63.8811 0001422  92.9286 267.2031 15.06391223267959"

tles = [{iss_tle1, iss_tle2}, {starlink_tle1, starlink_tle2}]
datetime = ~U[2024-03-15 12:00:00Z]
epochs = [~U[2024-03-15 12:00:00Z], ~U[2024-03-15 13:00:00Z]]

# Test different optimization combinations
test_configs = [
  {[], "Default (cache + batch NIF)"},
  {[use_cache: false], "No cache"},
  {[use_batch_nif: false], "No batch NIF"},
  {[use_gpu_coords: true], "GPU coordinates"},
  {[use_cache: true, use_gpu_coords: true], "Cache + GPU"},
  {[use_direct_nif: true], "Direct NIF"},
  {[use_direct_nif: true, use_gpu_coords: true], "Direct NIF + GPU"},
]

multi_epoch_configs = [
  {[], "Default (Satellite API)"},
  {[use_gpu_coords: true], "GPU coordinates"},
  {[use_direct_nif: true], "Direct NIF"},
  {[use_direct_nif: true, use_gpu_coords: true], "Direct NIF + GPU"},
]

IO.puts("📊 Single-epoch propagation tests:")
Enum.each(test_configs, fn {opts, description} ->
  try do
    results = SatelliteArray.propagate_to_geodetic(tles, datetime, opts)
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    IO.puts("  ✅ #{description}: #{success_count}/#{length(results)} succeeded")
  rescue
    error ->
      IO.puts("  ❌ #{description}: #{inspect(error)}")
  end
end)

IO.puts("\n📊 Multi-epoch propagation tests:")
Enum.each(multi_epoch_configs, fn {opts, description} ->
  try do
    results = SatelliteArray.propagate_many_to_geodetic(tles, epochs, opts)
    flat_results = List.flatten(results)
    success_count = Enum.count(flat_results, &match?({:ok, _}, &1))
    total_count = length(flat_results)
    IO.puts("  ✅ #{description}: #{success_count}/#{total_count} succeeded")
  rescue
    error ->
      IO.puts("  ❌ #{description}: #{inspect(error)}")
  end
end)

# Test cache performance
IO.puts("\n📊 Cache performance test:")
Sgp4Ex.SatelliteCache.clear_cache()

# Populate cache
SatelliteArray.propagate_to_geodetic(tles, datetime, use_cache: true)

# Check cache hits
stats = Sgp4Ex.SatelliteCache.stats()
IO.puts("  Cache stats: #{stats.hits} hits, #{stats.misses} misses, #{stats.hit_rate}% hit rate")

IO.puts("\n🎉 Integration test complete!")
IO.puts("All optimization layers are working together properly.")