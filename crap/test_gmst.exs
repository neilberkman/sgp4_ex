#!/usr/bin/env mix run

line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
datetime = ~U[2024-05-18 12:00:00Z]

# Test with IAU 2000A (current default)
{iau_time, _result} = :timer.tc(fn -> 
  Sgp4Ex.propagate_to_geodetic(tle, datetime, use_iau2000a: true)
end)
IO.puts("With IAU 2000A: #{iau_time/1000} ms")

# Test with classical GMST
{gmst_time, _result} = :timer.tc(fn -> 
  Sgp4Ex.propagate_to_geodetic(tle, datetime, use_iau2000a: false)
end)
IO.puts("With GMST: #{gmst_time/1000} ms")

speedup = iau_time / gmst_time
IO.puts("GMST speedup: #{Float.round(speedup, 1)}x faster")