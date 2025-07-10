#!/usr/bin/env mix run

line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
datetime = ~U[2024-05-18 12:00:00Z]

# Warm up
Enum.each(1..10, fn _ ->
  Sgp4Ex.propagate_to_geodetic(tle, datetime)
end)

# Test after warmup
{time, _result} = :timer.tc(fn -> 
  Sgp4Ex.propagate_to_geodetic(tle, datetime)
end)
IO.puts("After warmup: #{time/1000} ms")

python_time = 0.0866
speedup = python_time / (time/1000)
IO.puts("vs Python: #{Float.round(speedup, 1)}x #{if speedup > 1, do: "faster", else: "slower"}")