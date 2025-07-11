# Test the full propagation that was supposed to be working
line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
datetime = ~U[2024-03-15 12:00:00Z]

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
{:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, datetime, use_iau2000a: true)

# Expected from Skyfield
expected_lat = -50.39847319815834
expected_lon = 172.14031164763892
expected_alt = 436.5103397439415

IO.puts("Our result:")
IO.puts("  Lat: #{result.latitude}")
IO.puts("  Lon: #{result.longitude}")
IO.puts("  Alt: #{result.altitude_km}")

IO.puts("")
IO.puts("Expected:")
IO.puts("  Lat: #{expected_lat}")
IO.puts("  Lon: #{expected_lon}")  
IO.puts("  Alt: #{expected_alt}")

IO.puts("")
IO.puts("Differences:")
IO.puts("  Lat: #{result.latitude - expected_lat}")
IO.puts("  Lon: #{result.longitude - expected_lon}")
IO.puts("  Alt: #{result.altitude_km - expected_alt}")