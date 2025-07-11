# Investigate remaining sources of error

# Test multiple time points to see if error is consistent
test_times = [
  ~U[2024-03-15 12:00:00Z],
  ~U[2024-03-15 06:00:00Z], 
  ~U[2024-03-15 18:00:00Z],
  ~U[2024-06-21 12:00:00Z],  # Different season
  ~U[2024-12-21 12:00:00Z]   # Opposite season
]

line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

IO.puts("Testing multiple time points:")
IO.puts("Time                     | Lat Error (°)      | Lon Error (°)      | Alt Error (km)")
IO.puts("-------------------------|--------------------|--------------------|------------------")

Enum.each(test_times, fn datetime ->
  {:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, datetime, use_iau2000a: true)
  
  # For simplicity, just show pattern - would need Skyfield reference for each time
  IO.puts("#{DateTime.to_string(datetime)} | #{result.latitude} | #{result.longitude} | #{result.altitude_km}")
end)

IO.puts("")
IO.puts("=== Potential remaining error sources ===")
IO.puts("1. Complementary terms in equation of equinoxes (currently omitted)")
IO.puts("2. Precision differences in fundamental arguments (we're ~1e-6 off)")
IO.puts("3. Earth rotation angle vs GMST calculation differences")
IO.puts("4. Time scale conversion precision (UT1 vs UTC, TT vs TDB)")
IO.puts("5. Planetary nutation terms (we use 687/687, might need all 1365)")
IO.puts("6. Rounding/truncation differences in coefficient tables")
IO.puts("7. Different polynomial evaluation order (Horner vs direct)")
IO.puts("8. Machine precision accumulation over 1431 nutation terms")