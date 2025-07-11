# Test the actual coordinate conversion
teme_pos_km = {3539.16119041, 5309.74825448, 2343.88774417}
datetime = ~U[2024-03-15 12:00:00Z]

{:ok, result} = Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_pos_km, datetime, use_iau2000a: true)
IO.puts("Lat: #{result.latitude}, Lon: #{result.longitude}, Alt: #{result.altitude_km}")

# Expected from Skyfield
expected_lat = -50.39847319815834
expected_lon = 172.14031164763892
expected_alt = 436.5103397439415

IO.puts("Expected - Lat: #{expected_lat}, Lon: #{expected_lon}, Alt: #{expected_alt}")
IO.puts("Lat diff: #{result.latitude - expected_lat}")
IO.puts("Lon diff: #{result.longitude - expected_lon}") 
IO.puts("Alt diff: #{result.altitude_km - expected_alt}")