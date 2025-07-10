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

IO.puts("\n=== SGP4Ex GPU Benchmark (100 points) ===")
IO.puts("Python Skyfield baseline: 36.70ms\n")

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
epoch = tle.epoch
time_points = Enum.map(0..99, fn min -> 
  DateTime.add(epoch, min * 60, :second)
end)

# Warmup
IO.puts("Warming up...")
Enum.each(0..4, fn _ ->
  Enum.each(time_points, fn time ->
    {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, use_iau2000a: true, use_gpu: true)
  end)
end)

# Benchmark
IO.puts("Running benchmark (5 runs)...")
times = Enum.map(1..5, fn run ->
  start = System.monotonic_time(:microsecond)
  Enum.each(time_points, fn time ->
    {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, use_iau2000a: true, use_gpu: true)
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
IO.puts("\nPython Skyfield: 36.70ms")

speedup = 36.70 / avg_time
if speedup >= 1 do
  IO.puts("\n🚀 Elixir SGP4Ex + GPU is #{Float.round(speedup, 2)}x FASTER!")
else
  IO.puts("\nPython is #{Float.round(1/speedup, 2)}x faster")
end