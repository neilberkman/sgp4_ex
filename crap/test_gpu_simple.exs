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

IO.puts("\n=== Simple GPU vs CPU Test ===")

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
epoch = tle.epoch
time_points = Enum.map(0..9, fn min -> 
  DateTime.add(epoch, min * 60, :second)
end)

# Test CPU
IO.puts("\nCPU (10 points):")
cpu_start = System.monotonic_time(:microsecond)
Enum.each(time_points, fn time ->
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, use_iau2000a: true, use_gpu: false)
end)
cpu_time = (System.monotonic_time(:microsecond) - cpu_start) / 1000.0
IO.puts("Time: #{Float.round(cpu_time, 2)}ms")

# Test GPU  
IO.puts("\nGPU (10 points):")
gpu_start = System.monotonic_time(:microsecond)
Enum.each(time_points, fn time ->
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, time, use_iau2000a: true, use_gpu: true)
end)
gpu_time = (System.monotonic_time(:microsecond) - gpu_start) / 1000.0
IO.puts("Time: #{Float.round(gpu_time, 2)}ms")

IO.puts("\nSpeedup: #{Float.round(cpu_time / gpu_time, 2)}x")