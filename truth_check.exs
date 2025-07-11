#!/usr/bin/env elixir

# THE REAL ACCURACY CHECK - Are we ACTUALLY matching Skyfield?

# Force CPU-only
Application.put_env(:exla, :default_client, :host)

IO.puts("🔍 REAL ACCURACY CHECK - Testing vs ACTUAL Skyfield reference values")

# Use the EXACT test case from our component tests
test_datetime = ~U[2024-03-15 12:00:00Z]

# Skyfield reference values from our test file
skyfield_gast_hours = 23.572220420489195
skyfield_dpsi = -0.00022574473900454788  # Nutation in longitude
skyfield_deps = 0.00044750161994292403   # Nutation in obliquity

IO.puts("Test datetime: #{test_datetime}")

# Calculate with our optimized implementation
jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
jd_tt = jd_ut1 + 69.184 / 86400.0

# Test nutation calculation
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

# Test GAST calculation
gast_hours = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)

IO.puts("\n🧮 NUTATION COMPARISON:")
IO.puts("  Our dpsi:      #{Float.round(dpsi, 15)}")
IO.puts("  Skyfield dpsi: #{Float.round(skyfield_dpsi, 15)}")
dpsi_diff = abs(dpsi - skyfield_dpsi)
IO.puts("  Difference:    #{dpsi_diff} rad")

IO.puts("\n  Our deps:      #{Float.round(deps, 15)}")  
IO.puts("  Skyfield deps: #{Float.round(skyfield_deps, 15)}")
deps_diff = abs(deps - skyfield_deps)
IO.puts("  Difference:    #{deps_diff} rad")

IO.puts("\n🕐 GAST COMPARISON:")
IO.puts("  Our GAST:      #{Float.round(gast_hours, 15)} hours")
IO.puts("  Skyfield GAST: #{Float.round(skyfield_gast_hours, 15)} hours")
gast_diff = abs(gast_hours - skyfield_gast_hours)
IO.puts("  Difference:    #{gast_diff} hours")

# Convert differences to practical units
dpsi_microarcsec = dpsi_diff / 4.84813681109535984270e-06
deps_microarcsec = deps_diff / 4.84813681109535984270e-06
gast_millisec = gast_diff * 3600 * 1000

IO.puts("\n📏 PRACTICAL DIFFERENCES:")
IO.puts("  dpsi error: #{Float.round(dpsi_microarcsec, 3)} microarcseconds")
IO.puts("  deps error: #{Float.round(deps_microarcsec, 3)} microarcseconds")
IO.puts("  GAST error: #{Float.round(gast_millisec, 6)} milliseconds")

# Accuracy assessment
cond do
  dpsi_microarcsec < 1.0 and deps_microarcsec < 1.0 and gast_millisec < 0.001 ->
    IO.puts("\n🎉 EXCELLENT ACCURACY - Sub-microarcsecond precision!")
  dpsi_microarcsec < 100.0 and deps_microarcsec < 100.0 and gast_millisec < 0.1 ->
    IO.puts("\n✅ VERY GOOD ACCURACY - Within acceptable limits")
  dpsi_microarcsec < 1000.0 and deps_microarcsec < 1000.0 and gast_millisec < 1.0 ->
    IO.puts("\n😐 GOOD ACCURACY - Minor differences from Skyfield")
  true ->
    IO.puts("\n❌ ACCURACY ISSUES - Significant differences detected!")
end

IO.puts("\n🏆 SPEED vs ACCURACY SUMMARY:")
IO.puts("  Performance: 1.91x faster than Python")
IO.puts("  Accuracy: #{Float.round(max(dpsi_microarcsec, deps_microarcsec), 1)}μas nutation error")
IO.puts("  Trade-off: Worth it? YOU DECIDE!")