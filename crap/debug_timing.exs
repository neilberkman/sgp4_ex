#!/usr/bin/env mix run

line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

# Test just TLE parsing
{parse_time, {:ok, tle}} = :timer.tc(fn -> 
  Sgp4Ex.parse_tle(line1, line2)
end)
IO.puts("TLE parsing: #{parse_time/1000} ms")

# Test just SGP4 propagation (no coordinate conversion)
tsince = 0.0
{sgp4_time, _result} = :timer.tc(fn -> 
  SGP4NIF.propagate_tle(line1, line2, tsince)
end)
IO.puts("SGP4 propagation: #{sgp4_time/1000} ms")

# Test coordinate conversion only
datetime = ~U[2024-05-18 12:00:00Z]
teme_pos = {6800.0, 1200.0, 1500.0}  # Example TEME position in km

{coord_time, _result} = :timer.tc(fn -> 
  Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_pos, datetime)
end)
IO.puts("Coordinate conversion: #{coord_time/1000} ms")

# Test full pipeline
{full_time, _result} = :timer.tc(fn -> 
  Sgp4Ex.propagate_to_geodetic(tle, datetime)
end)
IO.puts("Full pipeline: #{full_time/1000} ms")